# codeWin.tcl --
#
#	This file implements the Code Window and the CodeBar APIs.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 
# SCCS: @(#) codeWin.tcl 1.16 98/05/02 14:01:16


package require parser

namespace eval code {
    # Handles to the CodeBar, LineBar and Code Windows.

    variable lineBar {}
    variable codeBar {}
    variable codeWin {}

    # There is currently a modal interface for settign BPs using
    # keystrokes.  Any key stroke between 0 and 9 is appended to
    # breakLineNum.  When Return is pressed the number stored
    # in this var will tobble the BP on or off.

    variable breakLineNum {}

    # Contains at least one newline for every line in the current block.  This
    # variable grows as needed.

    variable newlines "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
}

# code::createWindow --
#
#	Create the CodeBar, LineBar and the Code Window.
#
# Arguments:
#	masterFrm	The frame that contains the code widgets.
#
# Results:
#	The sub frame that contains the code widgets.

proc code::createWindow {masterFrm} {
    variable lineBar
    variable codeBar
    variable codeWin
    array set bar [system::getBar]

    set mainFrm    [frame $masterFrm.code]
    set codeFrm    [frame $mainFrm.code]
    set codeSubFrm [frame $codeFrm.subFrm -bd 2 -relief sunken]
    set codeBarFrm [frame $codeSubFrm.codeBarFrm \
	    -width $bar(width)]
    set codeBar [text $codeBarFrm.codeBar -width 1 -bd 0 \
	    -bg $bar(color)]
    set lineBar [text $codeSubFrm.lineBar -width 1 -bd 0]
    set codeWin [text $codeSubFrm.text -width 1 -bd 0]
    set yScroll [scrollbar $codeSubFrm.yScroll -command {code::scrollWindow}]
    set xScroll [scrollbar $codeSubFrm.xScroll -orient horizontal \
	    -command [list $codeWin xview]]
    
    pack $codeBar -fill both -expand true

    grid $codeBarFrm -row 0 -column 0  -sticky ns
    grid $lineBar -row 0 -column 1 -sticky ns
    grid $codeWin -row 0 -column 2 -sticky news
    grid rowconfigure $codeSubFrm [list 0] -weight 1
    grid columnconfigure $codeSubFrm [list 2] -weight 1

    # Turn off propagation of the CodeBar's containing frame.  This
    # way, we can explicitly set the size of the CodeBar to the size
    # of the largest icon.

    pack propagate $codeBarFrm 0
    pack $codeSubFrm -pady 2 -fill both -expand true
    pack $codeFrm -side bottom -fill both -expand true

    # Set default text bindings and override a few of the default
    # settings.  The CodeBar should have less padding, and the
    # Code Window should manage the adding/removing of the sb by
    # packing it in the containing frame, not inside the text widget.

    gui::setDbgTextBindings $codeBar
    gui::setDbgTextBindings $lineBar
    gui::setDbgTextBindings $codeWin
    $codeBar configure -padx 2
    $codeWin configure -yscroll "code::moveScrollbar $yScroll"
    $codeWin configure -xscroll "code::moveScrollbarX $xScroll"

    $codeWin configure -insertwidth 2
    code::updateTabStops

    # Now add the rest of the bindings to the CodeBar, LineBar
    # and Code Window.

    bind::addBindTags $codeBar [list codeDbgWin setBreakpoint]
    bind::addBindTags $lineBar [list codeDbgWin setBreakpoint]
    bind::addBindTags $codeWin [list codeDbgWin noEdit]
    bind::addBindTags $yScroll codeDbgWin

    gui::registerStatusMessage $codeBar \
	    "Click in the bar to set a line breakpoint."
    bind $codeWin <KeyPress> {
	code::updateStatusLine
    }
    bind $codeWin <ButtonRelease-1> {
	code::updateStatusLine
    }
    bind $codeWin <FocusIn> {
	code::changeFocus in
    } 
    bind $codeWin <FocusOut> {
	code::changeFocus out
    } 

    bind setBreakpoint <Button-1> {
	code::toggleLBP $code::codeBar @0,%y onoff
	break
    }
    bind setBreakpoint <Control-1> {
	code::toggleLBP $code::codeBar @0,%y enabledisable
	break
    }
    bind codeDbgWin <Return> {
	code::toggleLBP $code::codeBar \
		[code::getInsertLine].0 onoff
	break
    }
    bind codeDbgWin <Control-Return> {
	code::toggleLBP $code::codeBar \
		[code::getInsertLine].0 enabledisable
	break
    }
    return $mainFrm
}

# code::updateWindow --
#
#	Update the display of the Code Window and CodeBar 
#	after (1) a file is loaded (2) a breakpoint is hit 
#	or (3) a new stack frame was selected from the 
#	stack window.
#
# Arguments:
#	loc	Opaque <loc> type that contains the script.
#
# Results:
#	None.

proc code::updateWindow {loc} {
    variable codeBar
    variable lineBar
    variable codeWin

    # If the location is empty, then there is no source code
    # available to display.  Clear the Code Window, CodeBar,
    # and LineBar; set the currentBlock to empty; and update
    #  the Status window so no filename is displayed.

    if {$loc == {}} {
	code::resetWindow "No Source Code..."
	gui::setCurrentBlock {}
	gui::setCurrentFile  {}
	gui::setCurrentLine  {}
	return
    }

    set blk   [loc::getBlock $loc]
    set line  [loc::getLine $loc]
    set range [loc::getRange $loc]
    set file  [blk::getFile $blk]
    set ver   [blk::getVersion $blk]
    if {[catch {set src [blk::getSource $blk]} err]} {
	tk_messageBox -icon error -type ok -title "Error" \
		-parent [gui::getParent] -message $err
	return
    }


    # If the next block is different from the curent block,
    # delete contents of the Code Window, insert the new
    # data, and update the LineBar.  Otherwise, it's the
    # same block, just remove the highlighting from the Code
    # Window so we don't have multiple lines highlighted. 

    if {($blk != [gui::getCurrentBlock]) || ($ver != [gui::getCurrentVer])} {
	$codeWin delete 0.0 end
	$codeWin insert end [code::binaryClean $src]

	# Foreach line in the Code Window, add a line numer to
	# the LineBar.  Get the string length of the last line
	# number entered, and set the width of the LineBar.

	set numLines [code::getCodeSize]
	for {set i 1} {$i <= $numLines} {incr i} {
	    if {$i == 1} {
		set str "$i"
	    } else {
		append str "\n$i"
	    }
	}
	set lineBarWidth [string length $numLines]
	if {$lineBarWidth < 3} {
	    set lineBarWidth 3
	}
	$lineBar configure -width $lineBarWidth
	$lineBar delete 0.0 end
	$lineBar insert 0.0 $str right

	# Set the current GUI defaults for this block.

	gui::setCurrentBlock $blk
	gui::setCurrentVer   $ver
	gui::setCurrentFile  $file
    } else {
	$codeWin tag remove highlight 0.0 end
	$codeWin tag remove highlight_error 0.0 end
	$codeWin tag remove highlight_cmdresult 0.0 end
    }
    gui::setCurrentLine $line

    # show coverage ranges

    if {$::coverage::coverageEnabled} {
	coverage::highlightRanges $blk
    }

    # Calculate the beginning and ending indicies to be 
    # highlighted for the next statement.  If the line 
    # in the <loc> is empty, highlight nothing.  If the 
    # range in the <loc> is empty, highlight the entire 
    # line.  Otherwise, determine if the range spans 
    # multiple lines.  If it does, only highlight the
    # first line.  If it does not, then highlight the
    # entire range.

    if {$line == {}} {
	set cmdStart 0.0
	set cmdEnd [$codeWin index "0.0 - 1 chars"]
    } elseif {$range == {}} {
	set cmdStart [$codeWin index $line.0]
	set cmdEnd   [$codeWin index "$cmdStart lineend + 1 chars"]
    } else {
	set start [parse charindex $src $range]
	set end   [expr {$start + [parse charlength $src $range]}]
	set cmdStart [$codeWin index "0.0 + $start chars"]
	set cmdMid   [$codeWin index "$cmdStart lineend"]
	set cmdEnd   [$codeWin index "0.0 + $end chars"]
	
	# If cmdEnd is > cmdMid, the range spans multiple lines.
	if {[$codeWin compare $cmdEnd > $cmdMid]} {
	    set cmdEnd $cmdMid
	}
    }
    $codeWin tag add [code::getHighlightTag] $cmdStart $cmdEnd

    # Move the end of the command into view, then move the beginning
    # of the command into view.  Doing it in this order attempts to
    # bring as much of the statement into view as possible.  If the
    # entire statement is greater then the viewable region, then the
    # top of the statement is always in view.
    
    if {[$codeWin dlineinfo "$cmdStart+2 lines"] == ""} {
	$codeWin see "$cmdStart+2 lines"
    }
    $codeWin see "$cmdEnd linestart"
    $codeWin see $cmdStart

    # Move the insertion cursor to the beginning of the highlighted
    # statement.

    $codeWin mark set insert $cmdStart

    # Move the CodeBar and LineBar to the same viewable region as 
    # the Code Window.

    $codeBar yview moveto [lindex [$codeWin yview] 0]
    $lineBar yview moveto [lindex [$codeWin yview] 0]
}

# code::updateCodeBar --
#
#	Update the display of the CodeBar.  Get a list of all
#	the breakpoints for the current file and display one
#	icon for each line that contains a breakpoint.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc code::updateCodeBar {} {
    variable codeBar
    variable codeWin
    variable newlines

    dbg::Log timing {updateCodeBar}

    # If the current block is empty string, then we are in a hidden
    # frame that has no information on location, block etc.  Just
    # remove all icons from the code bar and return.

    $codeBar delete 0.0 end
    set blk [gui::getCurrentBlock]
    if {$blk == {}} {
	return
    }

    # A newline has to be inserted into the CodeBar for every
    # line of text in the Code Window, otherwise the images in 
    # the CodeBar will not line up with the Code Window.

    set validLines [blk::getLines $blk]
    set numLines [getCodeSize]

    # Ensure that we have enough newlines for the whole string.
    while {$numLines > [string length $newlines]} {
	append newlines $newlines
    }

    # Now add dashes on the lines where we can set breakpoints.

    if {$validLines == "-1"} {
	# All lines are valid at this point, so insert the dash
	# on every line.

	regsub -all \n [string range $newlines 0 [expr {$numLines - 1}]] \
		--\n str

	# Remove the last newline char so the ends of long code blocks
	# will line up with the dashes (fix for bug 2523).

	set str [string range $str 0 end-1]
    } else {

	set str {}
	set lastLine 1
	foreach codeLine $validLines {
	    append str [string range $newlines 0 \
		    [expr {$codeLine - $lastLine - 1}]] "--"
	    set lastLine $codeLine
	}
	# Pad the buffer with enough blank lines at the end so they match up.
	append str [string range $newlines 0 \
		[expr {$numLines - $lastLine - 1 }]]
    }

    $codeBar insert 0.0 $str codeBarText
    $codeBar tag configure codeBarText -foreground blue
    
    # Insert icons for each breakpoint.  Since breakpoints can
    # share the same location, only compute the type of icon to
    # draw for each unique location. 

    set bpLoc [loc::makeLocation $blk {}]
    set bpList [dbg::getLineBreakpoints $bpLoc]

    foreach bp $bpList {
	set theLoc [break::getLocation $bp]
	set breakLoc($theLoc) 1
    }
    set updateBp 0
    foreach bpLoc [array names breakLoc] {
	set breakState [icon::getLBPState $bpLoc]
	set nextLine [loc::getLine $bpLoc]
	if {$nextLine <= $numLines} {
	    icon::drawLBP $codeBar $nextLine.0 $breakState
	} else {
	    icon::setLBP noBreak $bpLoc
	    set updateBp 1
	}
    }
    if {$updateBp} {
	bp::updateWindow
    }

    # Draw the "PC" icon if we have an index for it.  Get the <loc>
    # for the currently selected stack frame.  If the block in the
    # selected stack frame is the same as the currently displayed
    # block, then draw the PC.

    set stackLoc [stack::getPC]
    if {$stackLoc != {}} {
	if {[loc::getBlock $stackLoc] == $blk} {
	    set pc [loc::getLine $stackLoc]
	    if {$pc != {}} {
		icon::setCurrentIcon $codeBar $pc.0 \
			[gui::getCurrentBreak] [stack::getPCType]
	    }
	}
    }

    # Move the CodeBar to the same viewable region as the Code Window.
    $codeBar yview moveto [lindex [$codeWin yview] 0]
}

# code::updateTabStops --
#
#	Reset the tab stops to be consistent with current preferences.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc code::updateTabStops {} {
    if {[winfo exists $code::codeWin]} {
	set tabWidth  [expr {$font::metrics(-width) * [pref::prefGet tabSize]}]
	$code::codeWin configure -tabs $tabWidth
    }
    return
}

# code::updateStatusLine --
#
#	Change the status message for the filename/line number
#	so the line number is always where the current cursor is.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc code::updateStatusLine {} {
    variable codeWin

    gui::updateStatusLine
}

# code::resetWindow --
#
#	Clear the contents of the CodeBar, LineBar and Code Window.  
# 	If msg is not null, display this message in the Code window.
#
# Arguments:
#	msg	A message to be placed in the Code Window.
#
# Results:
#	None.

proc code::resetWindow {{msg {}}} {
    $code::codeWin tag remove highlight 0.0 end
    $code::codeWin tag remove highlight_error 0.0 end
    $code::codeWin tag remove highlight_cmdresult 0.0 end
    code::changeFocus out
    icon::unsetCurrentIcon $code::codeBar currentImage
    if {$msg != {}} {
	$code::codeBar delete 0.0 end
	$code::lineBar delete 0.0 end
	$code::codeWin delete 0.0 end
	$code::codeWin insert 0.0 $msg message
	gui::setCurrentBlock {}
	gui::setCurrentFile  {}
	gui::setCurrentLine  {}
    }
}

# code::changeFocus --
#
#	Change the graphical feedback when focus changes.
#
# Arguments:
#	focus	The type of focus change (in or out.)
#
# Results:
#	None.

proc code::changeFocus {focus} {
    variable codeWin

    $codeWin tag remove focusIn 1.0 end
    if {$focus == "in"} {
	set ranges [$codeWin tag ranges [code::getHighlightTag]]
	foreach {start end} $ranges {
	    $codeWin tag add focusIn $start $end
	}
    }
}

# code::focusCodeWin --
#
#	If the Code Window already has the focus when
# 	"focus" is called on it, it will not report the
#	FocusIn event.   This will leave stale "focus
#	rings" in the display.  This proc circumvents
#	this from happening.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc code::focusCodeWin {} {
    if {[focus] == $code::codeWin} {
	code::changeFocus in
    } else {
	focus -force $code::codeWin
    }
}

# code::scrollWindow --
#
#	Scroll the Code Window and the CodeBar in parallel.
#
# Arguments:
#	args	Args from the scroll callback.
#
# Results:
#	None.

proc code::scrollWindow {args} {
    eval {$code::codeWin yview} $args
    $code::lineBar yview moveto [lindex [$code::codeWin yview] 0]
    $code::codeBar yview moveto [lindex [$code::codeWin yview] 0]
}

# code::moveScrollbar --
#
#	Move the elevator of the scrollbar while maintaining
#	the alignment between the CodeWin, CodeBar and LineBar.
#
# Arguments:
#	sb	The handle to the scrollbar to be updated.
#	args	Args to pass to the scrollbar that give the
#		new elevator locations.
#
# Results:
#	None.

proc code::moveScrollbar {sb args} {
    eval {gui::scrollDbgText $code::codeWin $sb \
	    [list grid $sb -row 0 -column 3 -sticky nse]} $args
    $code::lineBar yview moveto [lindex [$code::codeWin yview] 0]
    $code::codeBar yview moveto [lindex [$code::codeWin yview] 0]    
}

# code::moveScrollbarX --
#
#	Move the elevator of the scrollbar while maintaining
#	the alignment between the CodeWin, CodeBar and LineBar.
#
# Arguments:
#	sb	The handle to the scrollbar to be updated.
#	args	Args to pass to the scrollbar that give the
#		new elevator locations.
#
# Results:
#	None.

proc code::moveScrollbarX {sb args} {
    eval {gui::scrollDbgTextX $sb \
	    [list grid $sb -row 1 -column 1 -columnspan 2 -sticky ews]} $args
}

# code::tkTextAutoScan --
#
#	Override the <B1-Motion> binding on the CodeWin
#	with one that will scroll the CodeBar, LineBar
#	and CodeWin synchronously.
#
# Arguments:
#	w	The CodeBar window.
#
# Results:
#	None.

proc code::tkTextAutoScan {w} {
#    global tkPriv
    if {![winfo exists $w]} return
    if {$::tk::Priv(y) >= [winfo height $w]} {
	$code::codeBar yview scroll 2 units
	$code::lineBar yview scroll 2 units
	$code::codeWin yview scroll 2 units
    } elseif {$::tk::Priv(y) < 0} {
	$code::codeBar yview scroll -2 units
	$code::lineBar yview scroll -2 units
	$code::codeWin yview scroll -2 units
    } elseif {$::tk::Priv(x) >= [winfo width $w]} {
	$code::codeWin xview scroll 2 units
    } elseif {$::tk::Priv(x) < 0} {
	$code::codeWin xview scroll -2 units
    } else {
	return
    }
    set ::tk::Priv(afterId) [after 50 code::tkTextAutoScan $w]
}

# code::toggleLBP --
#
#	Toggle the breakpoint on/off or enable/disable.
#
# Arguments:
#	text	The CodeBar text widget.
#	index	The position in the CodeBar text widget to toggle
#		breakpoint state.
#	type	How to toggle ("onoff" or "enabledisable")
#	
#
# Results:
#	None.

proc code::toggleLBP {text index type} {
    # Don't allow users to set a LBP on an empty block.
    # The most common occurence of this is when a new
    # sessions begins and no files are loaded.

    if {[gui::getCurrentBlock] == {}} {
	return
    }
    if {(![blk::isInstrumented [gui::getCurrentBlock]]) && \
	    ([blk::getFile [gui::getCurrentBlock]] == {})} {
	return
    }
    set end  [code::getCodeSize]
    set line [lindex [split [$text index $index] .] 0]

    # Only let the user toggle a break point on valid locations
    # for break points.

    if {$line > $end} {
	return
    }
    set validLines [blk::getLines [gui::getCurrentBlock]]
    if {($validLines != "-1") && ([lsearch $validLines $line] == -1)} {
	return
    }

    switch $type {
	onoff {
	    code::ToggleLBPOnOff $text $index
	} 
	enabledisable {
	    code::ToggleLBPEnableDisable $text $index
	}
    }

    # Update the Breakpoint window to display the latest 
    # breakpoint setting.

    bp::updateWindow
}


# code::ToggleLBPOnOff --
#
#	Toggle the breakpoint at index to On or Off, 
#	adding or removing the breakpoint in the nub.
#
# Arguments:
#	text	The CodeBar text widget.
#	index	The position in the CodeBar text widget to toggle
#		breakpoint state.
#
# Results:
#	None.

proc code::ToggleLBPOnOff {text index} {

    set start  [$text index "$index linestart"]
    set loc [code::makeCodeLocation $text $index]
    set breakState [icon::getLBPState $loc]
    if {[icon::isCurrentIconAtLine $text $start]} {
	set pcType current
    } else {
	set pcType {}
    }
    icon::toggleLBPOnOff $text $start $loc $breakState $pcType
}

# code::ToggleLBPEnableDisable --
#
#	Toggle the breakpoint at index to Enabled or Disabled, 
#	enabling or disabling the breakpoint in the nub.
#
# Arguments:
#	text	The CodeBar text widget.
#	index	The position in the CodeBar text widget to toggle
#		breakpoint state.
#
# Results:
#	None.

proc code::ToggleLBPEnableDisable {text index} {
    set start  [$text index "$index linestart"]
    set loc [code::makeCodeLocation $text $start]
    set breakState [icon::getLBPState $loc]
    if {[icon::isCurrentIconAtLine $text $start]} {
	set pcType current
    } else {
	set pcType {}
    }
    icon::toggleLBPEnableDisable $text $start $loc $breakState $pcType
}

# code::makeCodeLocation --
#
#	Helper routine for making <loc> objects based on the 
#	line number of index, and the currently displayed block.
#
# Arguments:
#	text	Text widget that index referrs to.
#	index	Index to extract the line number from.
#
# Results:
#	A <loc> object.

proc code::makeCodeLocation {text index} {
    set line [lindex [split [$text index $index] .] 0]
    return [loc::makeLocation [gui::getCurrentBlock] $line]
}

# code::see --
#
#	Make all of the text widgets "see" the same region.
#
# Arguments:
#	index	An index into the Code Win that needs to be seen.
#
# Results:
#	None

proc code::see {index} {
    $code::codeWin see $index
    $code::codeBar yview moveto [lindex [$code::codeWin yview] 0]
    $code::lineBar yview moveto [lindex [$code::codeWin yview] 0]
}

# code::yview --
#
#	Set the yview of the Code Win while maintaining the
#	alignment in the text widgets.
#
# Arguments:
#	args	Yview arguments.
#
# Results:
#	None

proc code::yview {args} {
    eval {$code::codeWin yview} $args
    $code::codeBar yview moveto [lindex [$code::codeWin yview] 0]
    $code::lineBar yview moveto [lindex [$code::codeWin yview] 0]    
}

# code::getCodeSize --
#
#	Return, in line numbers, the length for the body of code.
#
# Arguments:
#	None.
#
# Results:
#	Return, in line numbers, the length for the body of code.

proc code::getCodeSize {} {
    set num [lindex [split [$code::codeWin index "end - 1c"] .] 0]
    return $num
}

# code::getInsertLine --
#
#	Return the line number of the insertion cursor or 1 if the 
#	window does not yet exist.
#
# Arguments:
#	None.
#
# Results:
#	Return the line number of the insertion cursor.

proc code::getInsertLine {} {
    if {[winfo exists $code::codeWin]} {
	return [lindex [split [$code::codeWin index insert] .] 0]
    } else {
	return 1
    }
}

# code::getHighlightTag --
#
#	Return the tag to be used for highlighting based on the current
#	break type.
#
# Arguments:
#	None.
#
# Results:
#	Return the tag to be used for highlighting.

proc code::getHighlightTag {} {
    switch -- [gui::getCurrentBreak] {
	error {
	    return highlight_error
	}
	cmdresult {
	    return highlight_cmdresult
	}
	default {
	    return highlight
	}
    }
}

# code::binaryClean --
#
#	Clean up strings to remove nulls.
#
# Arguments:
#	str	The string that should be cleaned.
#
# Results:
#	Return a "binary clean" string.

proc code::binaryClean {str} {
    set result {}
    while {[set index [string first "\0" $str]] >= 0} {
	append result "[string range $str 0 [expr {$index - 1}]]"
	set str [string range $str [expr {$index + 1}] end]
    }
    append result $str
    return $result
}

# code::mangle --
#
#	Clean up strings to remove nulls and newlines.
#
# Arguments:
#	str	The string that should be mangled.
#
# Results:
#	Return a "binary clean" string.

proc code::mangle {str} {
    regsub -all "\n" [code::binaryClean $str] {\n} result
    return $result
}


