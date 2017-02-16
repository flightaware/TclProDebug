# procWin.tcl --
#
#	This file contains the implementation for the "procs" window
#	in the Tcl debugger.  It shows all the instrumented and
#	non-instrumented procedures in the running application.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 

namespace eval procWin {
    # Handles to widgets in the Proc Window.

    variable patEnt      {}
    variable procText    {}
    variable showBut     {}
    variable instruBut   {}
    variable uninstruBut {}
    variable patBut {}
    variable showChk {}

    # The <loc> cache of locations for each proc.  The showCode proc
    # uses this to display the proc.

    variable procCache

    variable showChkVar 1

    variable patValue "*"

    # Used to delay UI changes do to state change.
    variable afterID

    # This variable provides a data base of the useable UI names for
    # procedures and the "real" names of procedures in the application.

    variable origProcNames

}

# procWin::showWindow --
#
#	Create the procedure window that will display
#	all the procedures in the running application. 
#
# Arguments:
#	None.
#
# Results:
#	The name of the Proc Windows toplevel.

proc procWin::showWindow {} {
    set top $gui::gui(procDbgWin)
    if {[winfo exists $top]} {
	procWin::updateWindow
	wm deiconify $top
	focus $procWin::procText
	return $top
    } else {
	procWin::createWindow
	procWin::updateWindow
	focus $procWin::procText
	return $top
    }
}

# procWin::createWindow --
#
#	Create the procedure window that will display
#	all the procedures in the running application. 
#
# Arguments:
#	None.
#
# Results:
#	None.

proc procWin::createWindow {} {
    variable procText
    variable patEnt
    variable showBut
    variable instruBut
    variable uninstruBut
    variable patBut
    variable patValue
    variable showChk

    set top [toplevel $gui::gui(procDbgWin)]
    ::guiUtil::positionWindow $top 400x260
    wm minsize $top 175 100
    wm title $top "Procedures"
    wm transient $top $gui::gui(mainDbgWin)

    set bd 2
    set pad  6

    # Create the pattern entry interface.   The default pattern is "*".

    set mainFrm [frame $top.mainFrm -bd $bd -relief raised]
    set patLbl [label $mainFrm.patLbl -anchor w -text "Pattern:"]
    set patEnt [entry $mainFrm.patEnt -bd $bd \
	    -textvariable ::procWin::patValue]
    set patBut [button $mainFrm.patBut -text "Search" \
	    -command procWin::updateWindow]

    # Place a separating line between the var info and the 
    # value of the var.

    set sepFrm [frame $mainFrm.sep1 -bd $bd -relief groove -height $bd]
    
    # Create the text widget that displays all procs and the 
    # "Show Code" button.

    set showChk  [checkbutton $mainFrm.showChk -variable procWin::showChkVar \
	    -text "Show Uninstrumented Procs." -command procWin::updateWindow]
    set procText [text $mainFrm.procText -width 30 -height 5 \
	    -yscroll [list $mainFrm.procText.sb set]]
    set sb [scrollbar $procText.sb -command [list $procText yview]]
    set instLbl [label $mainFrm.instLbl \
	    -text "* means the procedure is uninstrumented"]

    set butFrm [frame $mainFrm.butFrm]
    set showBut [button $butFrm.showBut -text "Show Code" \
	    -command [list procWin::showCode $procText]]
    set instruBut [button $butFrm.instruBut -text "Instrument" \
	    -command [list procWin::instrument 1 $procText]]
    set uninstruBut [button $butFrm.uninstruBut -text "Uninstrument" \
	    -command [list procWin::instrument 0 $procText]]
    set closeBut [button $butFrm.closeBut -text "Close" \
	    -command {destroy $gui::gui(procDbgWin)}]
    pack $showBut $instruBut $uninstruBut $closeBut -fill x -pady 3

    grid $patLbl -row 0 -column 0 -sticky we -pady $pad
    grid $patEnt -row 0 -column 1 -sticky we -padx $pad -pady $pad
    grid $patBut -row 0 -column 2 -sticky we -padx $pad -pady $pad
    grid $sepFrm -row 1 -column 0 -sticky we -padx $pad -pady 3 -columnspan 3
    grid $showChk -row 2 -column 0 -sticky nw -columnspan 3
    grid $procText -row 3 -column 0 -sticky nswe -padx $pad -pady $pad \
	    -columnspan 2
    grid $butFrm  -row 3 -column 2 -sticky nwe -padx $pad -pady $pad
    grid $instLbl -row 4 -column 0 -sticky nw -padx $pad -columnspan 3
    grid columnconfigure $mainFrm 1 -weight 1
    grid rowconfigure $mainFrm 3 -weight 1

    pack $mainFrm -padx $pad -pady $pad -fill both -expand true

    # Add default bindings and define tab order.

    bind::addBindTags $patEnt procDbgWin
    bind::addBindTags $procText [list scrollText selectFocus selectLine \
	    selectRange moveCursor selectCopy procDbgWin]
    bind::addBindTags $showBut  procDbgWin
    bind::commonBindings procDbgWin [list $patEnt $patBut $procText \
	    $showBut $instruBut $uninstruBut $closeBut]
    gui::setDbgTextBindings $procText $sb

    sel::setWidgetCmd $procText all {
	procWin::checkState $procWin::procText
    }
    bind procDbgWin <<Dbg_ShowCode>> {
	procWin::showCode $procWin::procText
	break
    }
    bind $procText <Double-1> {
	if {![sel::indexPastEnd %W current]} {
	    procWin::showCode %W
	}
	break
    }
    bind $procText <Return> {
	procWin::showCode %W
	break
    }
    bind $patEnt <Return> {
	procWin::updateWindow
	break
    }

    bind $top <Escape> "$closeBut invoke; break"
    return
}

# procWin::updateWindow --
#
#	Populate the Proc Windows list box with procedures
#	currently defined in the running app. 
#
# Arguments:
#	preserve	Preserve the selection status if true.
#
# Results:
#	None.

proc procWin::updateWindow {{preserve 0}} {
    variable patEnt
    variable showBut
    variable patBut
    variable procText
    variable procCache
    variable showChk
    variable afterID
    variable patValue

    if {![winfo exists $gui::gui(procDbgWin)]} {
	return
    }

    if {$preserve} {
	sel::preserve $procText
    }

    if {[info exists afterID]} {
	after cancel $afterID
	unset afterID
    }

    # If the state is not running or stopped, then delete
    # the display, unset the procCache and disable the
    # "Show Code" button

    set state [gui::getCurrentState]
    if {$state != "stopped"} {
	if {$state == "running"} {
	    set afterID [after $gui::afterTime ::procWin::resetWindow]
	} else {
	    procWin::resetWindow
	}
	return
    }

    set yview  [lindex [$procText yview] 0]
    $procText delete 0.0 end
    if {[info exists procCache]} {
	unset procCache
    }

    # If the user deletes the pattern, insert the star to provide
    # feedback that all procs will be displayed.

    if {$patValue == {}} {
	set patValue "*"
    }

    # The list returned from dbg::getProcs is a list of pairs 
    # containing {procName <loc>}.  For each item in the list
    # insert the proc name in the window if it matches the
    # pattern.  If the proc is not instrumented, then add the
    # "unistrumented" tag to alter the look of the display.

    if {[catch {set procs [dbg::getProcs]}]} {
	return
    }
    foreach x [lsort $procs]  {
	set loc  [lindex $x 1]
	set name [lindex $x 0]
	set procCache($name) $loc
	set name [procWin::trimProcName $name]

	if {[string match $patValue $name] == 0} {
	    continue
	}
	if {($loc != {}) && [blk::isInstrumented [loc::getBlock $loc]]} {
	    $procText insert end "  $name\n" procName
	} elseif {$procWin::showChkVar} {
	    $procText insert end "* $name\n" procName
	}
    }

    $showChk configure -state normal
    $patEnt configure -state normal
    $patBut configure -state normal

    $procText yview moveto $yview
    procWin::checkState $procText
    if {$preserve} {
	sel::restore $procText
    } else {
	sel::selectLine $procText 1.0
    }
    return
}

# procWin::resetWindow --
#
#	Reset the window to be blank, or leave a message 
#	in the text box.
#
# Arguments:
#	msg	If not empty, then put this message in the 
#		procText text widget.
#
# Results:
#	None.

proc procWin::resetWindow {{msg {}}} {
    variable procCache    
    variable procText
    
    if {![winfo exists $gui::gui(procDbgWin)]} {
	return
    }

    $procWin::showChk configure -state disabled
    $procWin::patEnt configure -state disabled
    $procWin::patBut configure -state disabled

    if {[info exists procCache]} {
	unset procCache
    }
    $procText delete 0.0 end
    checkState $procText
    if {$msg != {}} {
	$procText insert 0.0 $msg
    }
}

# procWin::showCode --
#
#	This function is run when we want to display the selected
#	procedure in the proc window.  It will interact with the
#	text box to find the selected procedure, find the corresponding
#	location, and tell the code window to display the procedure.
#
# Arguments:
#	text	The text window.
#
# Results:
#	None.

proc procWin::showCode {text} {
    variable procCache

    set state [gui::getCurrentState]
    if {$state != "running" && $state != "stopped"} {
	return
    }
    set line [sel::getCursor $text]
    if {[lsearch -exact [$text tag names $line.0] procName] < 0} {
	return
    }

    # If we can succesfully extracted a procName, 
    # verify that there is a <loc> cached for the 
    # procName.  If the <loc> is {}, then this may
    # be uninstrumented code.  Request a <loc> based
    # on the proc name.

    set loc {}
    set runningErr   0
    set updateStatus 0

    set procName [procWin::getProcName $text $line]
    if {[info exists procCache($procName)]} {
	set loc $procCache($procName)
	if {$loc == {}} {
	    if {[catch {set loc [dbg::getProcLocation $procName]}]} {
		set runningErr 1
	    }
	    set updateStatus 1
	}
    }
    gui::showCode $loc

    # An error will occur if dbg::getProcLocation is called while the
    # state is running.  If an error occured, provide feedback in the
    # CodeWindow.

    if {$runningErr} {
	code::resetWindow "Cannot show uninstrumented code while running."
    }
}

# procWin::instrument --
#
#	This function is run when we want to either instrument or
#	uninstrument the selected procedure in the proc window.  It will
#	interact with the text box to find the selected procedure, find the
#	corresponding location (if available), and the do the operation 
#	specified by the op argument.
#
# Arguments:
#	op	If 1 instrument the proc, if 0 uninstrument the proc.
#	text	The text window.
#
# Results:
#	None.

proc procWin::instrument {op text} {
    variable procCache

    set state [gui::getCurrentState]
    if {$state != "stopped"} {
	set msg "Cannot instrument or uninstrumented code while running."
	code::resetWindow $msg
	return
    }
    
    set lines [sel::getSelectedLines $text]
    foreach line $lines {
	if {[lsearch -exact [$text tag names $line.0] procName] < 0} {
	    continue
	}
	
	# If we can succesfully extracted a procName, 
	# verify that there is a <loc> cached for the 
	# procName.  If the <loc> is {}, then this may
	# be uninstrumented code.  Request a <loc> based
	# on the proc name.
	
	set loc {}
	set procName [procWin::getProcName $text $line]
	if {[info exists procCache($procName)]} {
	    set loc $procCache($procName)
	}

	if {$op} {
	    # Instrument the procedure

	    if {$loc != ""} {
		continue
	    }
	    set loc [dbg::getProcLocation $procName]
	    dbg::instrumentProc $procName $loc
	} else {
	    # Uninstrument the procedure

	    if {$loc == ""} {
		continue
	    }
	    dbg::uninstrumentProc $procName $loc
	}
    }

    # Extract and save the block number associated with the 
    # proc name pointed to by the selection cursor.  This
    # will be used to update the Code Window if the currently
    # displayed block number is identical to the block number
    # for the proc.

    if {$op} {
	set procName [procWin::getProcName $text [sel::getCursor $text]]
	set blk [loc::getBlock [dbg::getProcLocation $procName]]
    } elseif {[info exists procCache($procName)]} {
	set blk [loc::getBlock $procCache($procName)]
    } else {
	set blk {}
    }

    # Update the Proc Windows display.  This has the side affect 
    # of assigning new block numbers to each proc name.

    procWin::updateWindow 1

    # Display the code if the old proc body was being displayed.
    # This needs to be called after "procWin::updateWindow" is 
    # called, so the new block is displayed.

    if {($blk != {}) && ([gui::getCurrentBlock] == $blk) \
	    && [blk::isDynamic $blk]} {
	procWin::showCode $text
    }
    
    # The blocks have been changed.  Reset the block-to-filename 
    # relationship.
    
    file::update
}

# procWin::checkState --
#
#	Determine if the "Show Code" button should be normal
#	or disabled based on what is selected.
#
# Arguments:
#	text	The procText widget.
#
# Results:
#	None.

proc procWin::checkState {text} {
    variable showBut
    variable instruBut
    variable uninstruBut
    variable procText
    variable procCache

    set inst   0
    set uninst 0
    set lines [sel::getSelectedLines $text]
    foreach line $lines {
	if {[lsearch -exact [$procText tag names $line.0] procName] < 0} {
	    continue
	}
	set loc {}
	set procName [procWin::getProcName $text $line]
	if {[info exists procCache($procName)]} {
	    set loc $procCache($procName)
	}
	if {$loc == ""} {
	    set inst 1
	} else { 
	    set uninst 1
	}
    }
    if {$inst} {
	$procWin::instruBut configure -state normal
    } else {
	$procWin::instruBut configure -state disabled
    }
    if {$uninst} {
	$procWin::uninstruBut configure -state normal
    } else {
	$procWin::uninstruBut configure -state disabled
    }

    set cursor [sel::getCursor $text]
    if {[lsearch -exact [$procText tag names $cursor.0] procName] < 0} {
	$procWin::showBut configure -state disabled
    } else {
	$procWin::showBut configure -state normal
    }

    if {[focus] == $procText} {
	sel::changeFocus $procText in
    }
}

# procWin::trimProcName --
#
#	If the app is 8.0 or higher, then namespaces exist.  
#	This proc strips off the leading ::'s if the apps
#	tcl_version is 8.0 or greater.  This procedure will
#	also stip the name of characters that could cause
#	problems to the text widget like NULLS or newlines.
#
# Arguments:
#	procName	The name to trim.
#
# Results:
#	The normalized procName depending on namespaces.

proc procWin::trimProcName {procName} {
    variable origProcNames

    set orig $procName
    set procName [code::mangle $procName]

    set appVersion [dbg::getAppVersion]
    if {$appVersion != {} && $appVersion >= 8.0 \
	    && [string match {::*} $procName]} {
	set procName [string range $procName 2 end]
    }

    set origProcNames($procName) $orig
    return $procName
}

# procWin::getProcName --
#
#	Get the procName from the text widget.  If the 
#	app is 8.0 or higher, then namespaces exist.  
#	This proc appends the leading ::'s if the apps
#	tcl_version is 8.0 or greater.
#
# Arguments:
#	text	The porcWin's text widget.
#	line	The line number to search for procNames.
#
# Results:
#	A procName modified for use by the nub (if 8.0 or greater
#	append the leading ::'s)

proc procWin::getProcName {text line} {
    variable origProcNames

    set procName [$text get "$line.2" "$line.0 lineend"]
    set procName $origProcNames($procName)

    return $procName
}
