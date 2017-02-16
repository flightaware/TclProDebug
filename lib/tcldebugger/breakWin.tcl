# breakWin.tcl --
#
#	This file implements the Breakpoint Window.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 

namespace eval bp {
    # The text window that displays the breakpoints.

    variable breakText {}
    variable breakBar  {}

    # An array that caches the handle to each breakpoint
    # in the nub.

    variable breakpoint

    # If the name of the file is empty, then it is assumed
    # to be a dynamic block.  Use this string to tell
    # the user.

    variable dynamicBlock {<Dynamic Block>}
}

# bp::showWindow --
#
#	Show the window to displays and set breakpoints.
#
# Arguments:
#	None.
#
# Results:
#	The handle top the toplevel window created.

proc bp::showWindow {} {
    # If the window already exists, show it, otherwise
    # create it from scratch.

    if {[info command $gui::gui(breakDbgWin)] == $gui::gui(breakDbgWin)} {
	bp::updateWindow
	wm deiconify $gui::gui(breakDbgWin)
	focus $bp::breakText
	return $gui::gui(breakDbgWin)
    } else {
	bp::createWindow
	bp::updateWindow
	focus $bp::breakText
	return $gui::gui(breakDbgWin)
    }    
}

# bp::createWindow --
#
#	Create the window that displays and manipulates breakpoints.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc bp::createWindow {} {
    variable breakText
    variable breakBar
    variable showBut
    variable remBut
    variable allBut

    set breakDbgWin [toplevel $gui::gui(breakDbgWin)]
    ::guiUtil::positionWindow $breakDbgWin 400x250
    wm minsize  $breakDbgWin 100 100
    wm title $breakDbgWin "Breakpoints"
    wm transient $breakDbgWin $gui::gui(mainDbgWin)

    set pad 3
    array set bar [system::getBar]
 
    # Create the table that lists the existing breakpoints.
    # This is a live, editable list that shows the current 
    # breakpoints and the state of each breakpoint.  Add
    # buttons to the right for editing the table.

    set mainFrm [frame $breakDbgWin.mainFrm]
    set breakFrm [frame $mainFrm.breakFrm -relief raised -bd 2]
    set breakLbl [label $breakFrm.breakLbl -text "Breakpoints: " -anchor w]
    set breakSubFrm [frame $breakFrm.subFrm -relief sunken -bd 2]
    set breakBarFrm [frame $breakSubFrm.barFrm -width $bar(width)]
    set breakBar [text $breakBarFrm.barTxt -width 1 -height 20 -bd 0 \
	    -bg $bar(color)]
    set breakText [text $breakSubFrm.breakText -width 10 -height 4 -bd 0]
    set sb [scrollbar $breakSubFrm.sb -command {bp::scrollWindow}]

    pack propagate $breakBarFrm 0
    pack $breakBarFrm -side left -fill y
    pack $breakBar    -side left -fill both -expand true
    pack $breakText   -side left -fill both -expand true

    set butFrm  [frame $breakFrm.butFrm]
    set showBut [button $butFrm.showBut -text "Show Code"  \
	    -command {bp::showCode} -state disabled]
    set remBut  [button $butFrm.remBut -text "Remove" \
	    -command {bp::removeSelected} -state disabled]
    set allBut  [button $butFrm.allBut -text "Remove All" \
	    -command {bp::removeAll} -state disabled]
    set closeBut  [button $butFrm.closeBut -text "Close" \
	    -command {destroy $gui::gui(breakDbgWin)}]
    pack $showBut $remBut $allBut $closeBut -fill x -padx $pad -pady 3

    grid $breakLbl -row 0 -column 0 -sticky nwe -columnspan 2 -padx 4
    grid $breakSubFrm -row 1 -column 0 -sticky nswe -padx $pad -pady $pad
    grid $butFrm  -row 1 -column 1 -sticky ns
    grid columnconfigure $breakFrm 0 -weight 1
    grid rowconfigure $breakFrm 1 -weight 1

    pack $breakFrm -side bottom -fill both -expand 1 -padx $pad -pady $pad
    pack $mainFrm -side bottom -fill both -expand true

    bind::addBindTags $breakText [list scrollText selectFocus selectLine \
	    selectRange moveCursor selectCopy breakDbgWin]
    bind::addBindTags $showBut breakDbgWin
    bind::addBindTags $remBut  breakDbgWin
    bind::addBindTags $allBut  breakDbgWin
    bind::commonBindings breakDbgWin [list $breakText $showBut \
	    $remBut $allBut $closeBut]

    sel::setWidgetCmd $breakText all {
	bp::checkState
    }

    # Set-up the default and window specific bindings.

    gui::setDbgTextBindings $breakText $sb
    gui::setDbgTextBindings $breakBar
    $breakBar configure -padx 2

    bind $breakBar <Button-1> {
	bp::toggleBreakState current
	break;
    }
    bind $breakText <Double-1> {
	if {![sel::indexPastEnd %W current]} {
	    bp::showCode
	}
	break
    }
    bind $breakText <<Dbg_RemSel>> {
	bp::removeSelected
	break
    }
    bind $breakText <<Dbg_RemAll>> {
	bp::removeAll
	break
    }
    bind $breakText <<Dbg_ShowCode>> {
	bp::showCode
	break
    }
    bind $breakText <Return> {
	bp::toggleBreakState [sel::getCursor %W].0
	break
    }
    bind $breakDbgWin <Escape> "$closeBut invoke; break"
}

# bp::updateWindow --
#
#	Update the list of breakpoints so it shows the most
# 	current reprsentation of all breakpoints.  This proc
#	should be called after the bp::showWindow, after
#	any LBP events in the CodeBar, or any VBP events in 
#	the Var/Watch Windows.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc bp::updateWindow {} {
    variable breakText
    variable breakBar
    variable breakpoint

    # If the window is not current mapped, then there is no need to 
    # update the display.

    if {![winfo exists $gui::gui(breakDbgWin)]} {
	return
    }

    # Clear out the display and remove any breakpoint locs 
    # that may have been cached in previous displays.

    $breakText delete 0.0 end
    $breakBar  delete 0.0 end
    if {[info exists breakpoint]} {
	unset breakpoint
    }

    # This is used when inserting LBPs and VBPs.  The breakpoint
    # handles are stored in the "bp::breakpoint" array and are
    # accessed according to the line number of the bp in the 
    # text widget.

    set currentLine 1

    # The breakpoints are in an unordered list.  Create an array
    # so the breakpoints can be sorted in order of file name, 
    # line number and the test.

    set first 1
    set bps [dbg::getLineBreakpoints]
    if {$bps != {}} {
	foreach bp $bps {
	    set state [break::getState $bp]
	    set test  [break::getTest $bp]
	    set loc   [break::getLocation $bp]
	    set line  [loc::getLine $loc]
	    set blk   [loc::getBlock $loc]
	    set file  [file::getUniqueFile $blk]

	    set unsorted($file,$line,$test) [list $bp $file $line $state $test]
	}
	foreach name [lsort -dictionary [array names unsorted]] {
	    set bp    [lindex $unsorted($name) 0]
	    set file  [lindex $unsorted($name) 1]
	    set line  [lindex $unsorted($name) 2]
	    set state [lindex $unsorted($name) 3]
	    set test  [lindex $unsorted($name) 4]

	    set file [file tail $file]
	    if {$file == {}} {
		set file $bp::dynamicBlock
	    }

	    # The tab stop of the breakText text widget is large enough
	    # for the breakpoint icons.  Insert the breakpoint description
	    # after a tab so all of the descriptions remained lined-up
	    # even if the icon is removed.

	    if {!$first} {
		$breakText insert end "\n"
	    }
	    $breakText insert end "$file: $line" [list breakInfo LBP]
	    set first 0
	    if {$state == "enabled"} {
		icon::drawLBP $breakBar end enabledBreak
	    } else {
		icon::drawLBP $breakBar end disabledBreak
	    }
	    $breakBar insert end "\n" 

	    # Cache the <loc> object based on the line number of the
	    # description in the breakText widget.

	    set breakpoint($currentLine) $bp
	    incr currentLine
	}
	unset unsorted
    }

    # The breakpoints are in an unordered list.  Create an array
    # so the breakpoints can be sorted in order of the contents
    # in the VBP client data ({orig name & level} {new name & level})
    
    if {[gui::getCurrentState] == "stopped"} {
	set bps [dbg::getVarBreakpoints]
    } else {
	set bps {}
    }
    if {$bps != {}} {
	foreach bp $bps {
	    set state [break::getState $bp]
	    set test  [break::getTest $bp]
	    set data  [break::getData $bp]
	    set index [join $data { }]
	    set unsorted($index) [list $bp $state $test $data]
	}
	foreach name [lsort -dictionary [array names unsorted]] {
	    set bp    [lindex $unsorted($name) 0]
	    set state [lindex $unsorted($name) 1]
	    set test  [lindex $unsorted($name) 2]
	    set data  [lindex $unsorted($name) 3]
	    set oLevel [icon::getVBPOrigLevel $bp]
	    set oName  [code::mangle [icon::getVBPOrigName  $bp]]
	    set nLevel [icon::getVBPNextLevel $bp]
	    set nName  [code::mangle [icon::getVBPNextName  $bp]]

	    if {!$first} {
		$breakText insert end "\n"
	    }
	    set first 0
	    $breakText insert end "\{$oName: $oLevel\}"   [list breakInfo VBP]
	    if {($nName != "") || ($nLevel != "")} {
		$breakText insert end "\ \{$nName: $nLevel\}" \
			[list breakInfo VBP]
	    }
	    if {$state == "enabled"} {
		icon::drawVBP $breakBar end enabledBreak
	    } else {
		icon::drawVBP $breakBar end disabledBreak
	    }
	    $breakBar insert end "\n" 

	    set breakpoint($currentLine) $bp
	    incr currentLine
	}    
	unset unsorted
    }
    set index [sel::getCursor $breakText].0 
    if {[sel::indexPastEnd $breakText $index]} {
	sel::selectLine $breakText "end - 1l"
    } else {
	sel::selectLine $breakText $index
    }
    bp::checkState
}

# bp::scrollWindow --
#
#	Scroll the Break Text Window and the BreakBar in parallel.
#
# Arguments:
#	args	Args from the scroll callback.
#
# Results:
#	None.

proc bp::scrollWindow {args} {
    eval {$bp::breakText yview} $args
    $bp::breakBar yview moveto [lindex [$bp::breakText yview] 0]
}

# bp::showCode --
#
#	Show the block of code where the breakpoint is set.
#	At this point the Stack and Var Windows will be out
#	of synch with the Code Window.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc bp::showCode {} {
    variable breakText
    variable breakpoint

    # There may be more then one line highlighted.  Just
    # get the first line that's highlighted, and show
    # it's code.

    set line [sel::getCursor $breakText]
    if {[sel::indexPastEnd $breakText $line.0]} {
	return
    }
    if {[break::getType $breakpoint($line)] == "line"} {
	set loc  [break::getLocation $breakpoint($line)]
	
	# The BPs are preserved between sessions.  The 
	# file associated with the breakpoint may or may
	# not still exist.  To verify this, get the Block 
	# source.  If there is an error, set the loc to {}.
	# This way the BP dosent cause an error, but gives
	# feedback that the file cannot be found.
	
	if {[catch {blk::getSource [loc::getBlock $loc]}]} {
	    set loc {}
	}
	gui::showCode $loc
    }
}

# bp::removeAll --
#
#	Remove all of the breakpoints.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc bp::removeAll {} {
    variable breakpoint

    # Remove all of the BPs from the nub.
    set updateCodeBar  0
    set updateVarWatch 0
    foreach {line bp} [array get breakpoint] {
	if {[break::getType $bp] == "line"} {
	    set updateCodeBar  1
	} else {
	    set updateVarWatch 1
	}
	dbg::removeBreakpoint $bp
    }

    # Based on the type of breakpoints we removed, update 
    # related windows.

    if {$updateCodeBar} {
	pref::groupSetDirty Project 1
	code::updateCodeBar
    }
    if {$updateVarWatch} {
	var::updateWindow
	watch::updateWindow
    }
    bp::updateWindow
}

# bp::removeSelected --
#
#	Remove all of the highlighted breakpoints.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc bp::removeSelected {} {
    variable breakpoint
    variable breakText

    # Remove the selected BPs from the nub.  Set flags based
    # on what types of BPs were removed of related windows
    # can be updated.

    set updateCodeBar  0
    set updateVarWatch 0
    set cursor [sel::getCursor $breakText]
    set selectedLines [sel::getSelectedLines $breakText] 
    foreach line $selectedLines {
	if {[break::getType $breakpoint($line)] == "line"} {
	    set updateCodeBar  1
	} else {
	    set updateVarWatch 1
	}
	dbg::removeBreakpoint $breakpoint($line)
    }

    if {$selectedLines != {}} {
	bp::updateWindow
    }
    if {$updateCodeBar} {
	pref::groupSetDirty Project 1
	code::updateCodeBar
    }
    if {$updateVarWatch} {
	var::updateWindow
	watch::updateWindow
    }
}

# bp::checkState --
#
#	Check the state of the Breakpoint Window.  Enable the
#	"Remove All" button if there are entries in the window.
#	Enable the "Show Code" and "Remove" buttons if there 
#	are one or more selected lines.  Remove the first two
#	chars where the BP icons are located.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc bp::checkState {} {
    variable breakText
    variable breakBar
    variable breakpoint
    variable showBut
    variable remBut
    variable allBut
    
    # If the window is not current mapped, then there is no need to 
    # update the display.

    if {![winfo exists $gui::gui(breakDbgWin)]} {
	return
    }

    set lines [sel::getSelectedLines $breakText]

    # Check to see if there are valid highlighted lines.

    set state disabled
    foreach line $lines {
	if {[lsearch -exact [$breakText tag names $line.3] LBP] >= 0} {
	    set state normal
	}
	if {![sel::isTagInLine $breakText $line.0 breakInfo]} {
	    $breakText tag remove highlight $line.0 "$line.0 lineend"
	}
    }
    $showBut configure -state $state

    if {$lines == {}} {
	$remBut configure -state disabled
    } else {
	$remBut configure -state normal
    }

    # If the breakpoints array exists, then there are BPs displayed
    # in the window; Enable the "Remove All" button.  Otherwise
    # disable this button.

    if {[info exist breakpoint]} {
	$allBut configure -state normal
    } else {
	$allBut configure -state disabled
    }  
    if {[focus] == $breakText} {
	sel::changeFocus $breakText in
    }
    $breakBar yview moveto [lindex [$breakText yview] 0]
}

# bp::toggleBreakState --
#
#	Toggle the state of the breakpoint between enabled and
#	disabled.  If there are multiple breakpoints highlighted,
#	then set all of them to the new state of the selected
#	breakpoint.
#
# Arguments:
#	index	The location of the selected icon.
#
# Results:
#	None.

proc bp::toggleBreakState {index} {
    variable breakText
    variable breakBar
    variable breakpoint
    
    set selLine [lindex [split [$breakBar index $index] .] 0]

    # If there is no info for the selected line, then 
    # the user has selected a line in the text widget that
    # does not contain a BP.  Return w/o doing anything.

    if {![info exists breakpoint($selLine)]} {
	return
    }
    set selType [break::getType $breakpoint($selLine)]

    # Get the state of breakpoint at index in the text widget.
    # Use this state to determine the new state of one or more
    # selected breakpoints.

    if {$selType == "line"} {
	set loc  [break::getLocation $breakpoint($selLine)]
	set breakState [icon::getLBPState $loc]
    } else {
	set level [icon::getVBPOrigLevel $breakpoint($selLine)]
	set name  [icon::getVBPOrigName  $breakpoint($selLine)]
	set breakState [icon::getVBPState $level $name]
    }

    # If the BP is not highlighted, only toggle the selected BP.
    # Otherwise, get a list of selected BPs, determine each type
    # and call the correct procedure to toggle the BPs

    set updateCodeBar  0
    set updateVarWatch 0
    if {[lsearch -exact [$breakText tag names "$index lineend"] \
	    highlight] < 0} {
	if {$selType == "line"} {
	    bp::toggleLBP $breakBar $selLine $breakState
	    set updateCodeBar 1
	} else {
	    bp::toggleVBP $breakBar $selLine $breakState
	    set updateVarWatch 1
	}
    } else {
	foreach line [sel::getSelectedLines $breakText] {
	    set type [break::getType $breakpoint($line)]
	    if {$type == "line"} {
		bp::toggleLBP $breakBar $line $breakState
		set updateCodeBar 1
	    } else {
		bp::toggleVBP $breakBar $line $breakState
		set updateVarWatch 1
	    }
	}
    } 
    
    # If one or more VBPs were toggled we need to update the Var
    # and Watch Windows.

    if {$updateVarWatch} {
	var::updateWindow
	watch::updateWindow
    }

    # If one or more LBPs were toggled we need to update the 
    # CodeBar to display the current LBPs.

    code::updateCodeBar
}

# bp::toggleLBP --
#
#	Toggle a line breakpoint in the Break Window.
#
# Arguments:
#	text		The Break Window's text widget.
#	line		The line number of the BP in the text widget.
#	breakState	The new state of the BP
#
# Results:
#	None.

proc bp::toggleLBP {text line breakState} {
    variable breakpoint

    set loc [break::getLocation $breakpoint($line)]
    icon::toggleLBPEnableDisable $text $line.0 $loc $breakState
}

# bp::toggleVBP --
#
#	Toggle a line breakpoint in the Break Window.
#
# Arguments:
#	text		The Break Window's text widget.
#	line		The line number of the BP in the text widget.
#	breakState	The new state of the BP
#
# Results:
#	None.

proc bp::toggleVBP {text line breakState} {
    variable breakpoint

    set level [icon::getVBPOrigLevel $breakpoint($line)]
    set name  [icon::getVBPOrigName  $breakpoint($line)]
    icon::toggleVBPEnableDisable $text $line.0 $level $name $breakState
}

# bp::setProjectBreakpoints --
#
#	Remove any existing breakpoints and restore 
#	the projects LBP from the bps list.
#
# Arguments:
#	bps	The list of breakpoints to restore
#
# Results:
#	None.

proc bp::setProjectBreakpoints {bps} {
    foreach lbp [dbg::getLineBreakpoints] {
	dbg::removeBreakpoint $lbp
    }
    break::restoreBreakpoints $bps
    file::update 1
    bp::updateWindow
}

