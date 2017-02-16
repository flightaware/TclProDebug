# evalWin.tcl --
#
#	The file implements the Debuger interface to the 
#	TkCon console (or whats left of it...)
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 

namespace eval evalWin {

    # The handle to the text widget where commands are entered.

    variable evalText

    # The handle to the combo box that contains the list of 
    # valid level to eval commands in.

    variable levelCombo

    # Used to delay UI changes do to state change.
    variable afterID
}

# evalWin::showWindow --
#
#	Show the Eval Window.  If it already exists, just raise
#	it to the foreground.  Otherwise, create a new eval window.
#
# Arguments:
#	None.
#
# Results:
#	The toplevel window name for the Eval Window.

proc evalWin::showWindow {} {
    # If the window already exists, show it, otherwise
    # create it from scratch.

    if {[info command $gui::gui(evalDbgWin)] == $gui::gui(evalDbgWin)} {
	# evalWin::updateWindow
	wm deiconify $gui::gui(evalDbgWin)
	focus $evalWin::evalText
	return $gui::gui(evalDbgWin)
    } else {
	evalWin::createWindow
	evalWin::updateWindow
	focus $evalWin::evalText
	return $gui::gui(evalDbgWin)
    }    
}

# evalWin::createWindow --
#
#	Create the Eval Window.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc evalWin::createWindow {} {
    variable evalText
    variable levelCombo

    set bd 2
    set pad 6

    set top [toplevel $gui::gui(evalDbgWin)]
    ::guiUtil::positionWindow $top 400x250
    wm protocol $top WM_DELETE_WINDOW "wm withdraw $top"
    wm minsize $top 100 100
    wm title $top "Eval Console"
    wm transient $top $gui::gui(mainDbgWin)

    # Create the level indicator and combo box.

    set mainFrm [frame $top.mainFrm -bd $bd -relief raised]
    set levelFrm [frame $mainFrm.levelFrm]
    set levelLbl [label $levelFrm.levelLbl -text "Stack Level:"]
    set levelCombo [guiUtil::ComboBox $levelFrm.levelCombo -ewidth 8 \
	    -textvariable gui::gui(evalLevelVar) -strict 1 \
	    -listheight 1 -listwidth 8 -listexportselection 0]
    set closeBut [button $levelFrm.closeBut -text "Close" -width 10 \
	    -command {destroy $gui::gui(evalDbgWin)}]
    pack $levelLbl -side left
    pack $levelCombo -side left -padx 3
    pack $closeBut -side right

    # Place a separating line between the var info and the 
    # value of the var.

    set sepFrm [frame $mainFrm.sep1 -bd $bd -relief groove -height $bd]

    # Create the text widget that will be the eval console.

    set evalFrm  [frame $mainFrm.evalFrm]
    set evalText [tkCon::InitUI $evalFrm Console]

    pack $levelFrm -fill x -padx $pad -pady $pad
    pack $sepFrm -fill x  -padx $pad -pady $pad
    pack $evalFrm -fill both -expand true -padx $pad -pady $pad
    pack $mainFrm -fill both -expand true -padx $pad -pady $pad

    bind::addBindTags $evalText evalDbgWin
    bind::addBindTags $levelCombo evalDbgWin
    bind::commonBindings evalDbgWin {}
    bind $evalText <Control-minus> {
	evalWin::moveLevel -1; break
    }
    bind $evalText <Control-plus> {
	evalWin::moveLevel 1; break
    }
    foreach num [list 0 1 2 3 4 5 6 7 8 9] {
	bind $evalText <Control-Key-$num> "
	    evalWin::requestLevel $num; break
	"
    }
    if {[gui::getCurrentState] == "running"} {
	bind::addBindTags $evalText disableKeys
	evalWin::resetWindow
    }
    bind $top <Escape> "$closeBut invoke; break"
}

# evalWin::updateWindow --
#
#	Update the display of the Eval Window.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc evalWin::updateWindow {} {
    variable evalText
    variable levelCombo
    variable afterID

    if {![winfo exists $gui::gui(evalDbgWin)]} {
	return
    }

    if {[info exists afterID]} {
	after cancel $afterID
	unset afterID
    }

    # Enable typing in the console and remove the disabled
    # look of the console by removing the disabled tags.
    
    $evalText tag remove disable 0.0 "end + 1 lines"
    bind::removeBindTag $evalWin::evalText disableKeys

    set state [gui::getCurrentState]
    if {$state == "stopped"} {
	# Add the list of valid levels to the level combo box
	# and set the display in the combo entry to the top
	# stack level.

	set thisLevel $gui::gui(evalLevelVar)
	$levelCombo del 0 end
	set levels [evalWin::getLevels]
	eval {$levelCombo add} $levels
	$evalText configure -state normal

	# Set the default level.  If the "stopped" event was generated
	# by a "result" break type, use the last level as long as it
	# still exists.  Otherwise use the top-most level.

	set lastLevel [lindex $levels end]
	if {([gui::getCurrentBreak] == "result") && $thisLevel < $lastLevel} {
	    set gui::gui(evalLevelVar) $thisLevel
	} else {
	    set gui::gui(evalLevelVar) $lastLevel
	}
    } elseif {$state == "running"} {
	# Append the bindtag that will disable key strokes.
	bind::addBindTags $evalText disableKeys
	set afterID [after $gui::afterTime ::evalWin::resetWindow]
    } else {
	evalWin::resetWindow
    }
}

# evalWin::resetWindow --
#
#	Reset the display of the Eval Window.  If the message
#	passed in is not empty, display the contents of the
#	message in the evalText window.
#
# Arguments:
#	msg	If this is not an empty string then display this
#		message in the evatText window.
#
# Results:
#	None.

proc evalWin::resetWindow {{msg {}}} {
    variable evalText
    variable levelCombo

    if {![winfo exists $gui::gui(evalDbgWin)]} {
	return
    }

    $levelCombo del 0 end
    $evalText configure -state disabled
    $evalText tag add disable 0.0 "end + 1 lines"
}

# evalWin::evalCmd --
#
#	Evaluate the next command in the evalText window.
#	This proc is called by the TkCon code defined in
#	tkcon.tcl.
#
# Arguments:
#	cmd	The command to evaluate.
#
# Results:
#	The "pid" of the command.

proc evalWin::evalCmd {cmd} {
    return [gui::run [list dbg::evaluate $gui::gui(evalLevelVar) $cmd]]
}

# evalWin::evalResult --
#
#	Handler for the "result" message sent from the nub.
#	Pass the data to TkCon to display the result.
#
# Arguments:
#	id		The "pid" of the command.
#	code		Standard Tcl result code.
#	result		The result of evaluation.
#	errCode		The errorCode of the eval.
#	errInfo		The stack trace of the error.
#
# Results:
#	None.

proc evalWin::evalResult {id code result errCode errInfo} {
    set code    [code::binaryClean $code]
    set result  [code::binaryClean $result]
    set errCode [code::binaryClean $errCode]
    set errInfo [code::binaryClean $errInfo]

    tkCon::EvalResult $id $code $result $errCode $errInfo
}

# evalWin::moveLevel --
#
#	Move the current eval level up or down within range 
#	of acceptable levels.
#
# Arguments:
#	amount	The amount to increment/decrement to the
#		current level.
#
# Results:
#	None.

proc evalWin::moveLevel {amount} {
    variable levelCombo

    set level [expr {[$levelCombo get] + $amount}]
    set last  [lindex [evalWin::getLevels] end]

    if {$last == {}} {
	return
    }
    if {$level < 0} {
	set level 0
    }
    if {$level > $last} {
	set level $last
    }
    $levelCombo set $level
}

# evalWin::requestLevel --
#
#	Request a level, between 0 and 9, to evaluate the next 
#	command in.  If the level is invalid, do nothing.
#
# Arguments:
#	level	A requested eval level between 0 and 9.
#
# Results:
#	None.

proc evalWin::requestLevel {level} {
    variable levelCombo

    if {[lsearch [evalWin::getLevels] $level] >= 0} {
	$levelCombo set $level
    }
}

# evalWin::getLevels --
#
#	Get a list of valid level to eval the command in.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc evalWin::getLevels {} {
    variable evalText
    variable levelCombo
    
    set maxLevel [dbg::getLevel]
    set result {}
    for {set i 0} {$i <= $maxLevel} {incr i} {
	lappend result $i
    }
    return $result
}
