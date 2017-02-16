# inspectorWin.tcl --
#
#	This file implements the Inspector Window.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
#

namespace eval inspector {
    variable entVar   {}
    variable nameVar  {}
    variable levelVar {}
    variable viewVar  {}

    variable varText
    variable choiceBox

    variable levelCache {}
    variable nameCache  {}
    variable valueCache {}
    variable viewCache  {}
    
    variable dontLoop 0

    variable showResult 0
}

# inspector::showVariable --
#
#	Popup an Inspector window to display info on the selected 
#	variable.
#
# Arguments:
#	name	The variable name to show.
#	level	The stack level containing the variable.
#
# Results:
#	None.

proc inspector::showVariable {name level} {
    variable showResult
    variable entVar
    variable nameVar
    variable levelVar

    if {[gui::getCurrentState] != "stopped"} {
	return
    }

    # If the window already exists, show it, otherwise
    # create it from scratch.

    if {[info command $gui::gui(dataDbgWin)] != $gui::gui(dataDbgWin)} {
	inspector::createWindow
    }

    set showResult 0
    set entVar [code::mangle $name]
    set nameVar $entVar
    set levelVar $level
    inspector::updateWindow 1

    wm deiconify $gui::gui(dataDbgWin)
    focus $gui::gui(dataDbgWin)
    return $gui::gui(dataDbgWin)
}

# inspector::updateVarFromEntry --
#
#	Update the Data Display to show the variable named in the 
#	entry widget.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc inspector::updateVarFromEntry {} {
    variable nameVar
    variable entVar
    variable levelVar
    variable showResult

    set showResult 0
    set entVar [code::mangle $entVar]
    set nameVar $entVar
    set levelVar [gui::getCurrentLevel]

    inspector::updateWindow 1
    return
}

# inspector::showResult --
#
#	Popup an Inspector window to display info on the current
#	interpreter result value.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc inspector::showResult {} {
    variable showResult
    variable entVar
    variable nameVar
    variable levelVar

    if {[gui::getCurrentState] != "stopped"} {
	return
    }

    # If the window already exists, show it, otherwise
    # create it from scratch.

    if {[info command $gui::gui(dataDbgWin)] != $gui::gui(dataDbgWin)} {
	inspector::createWindow
    }

    # Set the inspector into showResult mode and refesh the window.

    set showResult 1
    set entVar {}
    set nameVar "<Interpreter Result>"
    set levelVar [dbg::getLevel]
    inspector::updateWindow 1

    wm deiconify $gui::gui(dataDbgWin)
    focus $gui::gui(dataDbgWin)
    return $gui::gui(dataDbgWin)
}

# inspector::createWindow --
#
#	Create an Inspector window that displays info on
#	a particular variable and allows the variables 
#	value to be changed and variable breakpoints to
#	be set and unset.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc inspector::createWindow {} {
    variable varText
    variable choiceBox

    set top [toplevel $gui::gui(dataDbgWin)]
    ::guiUtil::positionWindow $top 400x250
    wm minsize $top 100 100
    wm title $top "Data Display"
    wm transient $top $gui::gui(mainDbgWin)

    set relief groove
    set pad 6
    set bd 2

    # Create the info frame that displays the level and name.

    set mainFrm [frame $top.mainFrm -bd $bd -relief raised] 

    # Create the entry for adding new Watch variables.

    set inspectFrm [frame $mainFrm.inspectFrm]
    set inspectLbl [label $inspectFrm.inspectLbl -anchor w -text "Variable:"]
    set inspectEnt [entry $inspectFrm.inspectEnt \
	    -textvariable inspector::entVar]
    set inspectBut [button $inspectFrm.inspectBut -text "Display" -width 8 \
	    -command inspector::updateVarFromEntry]
    set closeBut [button $inspectFrm.closeBut -text "Close" -width 8 \
	    -command "destroy $gui::gui(dataDbgWin)"]

    pack $closeBut -side right -padx $pad
    pack $inspectBut -side right
    pack $inspectLbl -side left
    pack $inspectEnt -side left -padx $pad -fill x -expand true

    set dataFrm  [frame $mainFrm.infoFrm -bd $bd -relief groove]
    set infoFrm  [frame $dataFrm.infoFrm]
    set nameTitleLbl [label $infoFrm.nameTitleLbl -text "Variable Name:" ]
    set nameLbl [label $infoFrm.nameLbl -justify left \
	    -textvariable inspector::nameVar]
    set levelTitleLbl [label $infoFrm.levelTitleLbl -text "Stack Level:" ]
    set levelLbl [label $infoFrm.levelLbl -justify left \
	    -textvariable inspector::levelVar]
    pack $nameTitleLbl -pady 3 -side left
    pack $nameLbl -padx 3 -pady 3 -side left
    pack $levelTitleLbl -pady 3 -side left
    pack $levelLbl -padx 3 -pady 3 -side left

    # Place a separating line between the var info and the 
    # value of the var.

    set sep1Frm [frame $dataFrm.sep1 -bd $bd -relief $relief -height $bd]

    set choiceFrm [frame $dataFrm.choiceFrm]
    set choiceLbl [label $choiceFrm.choiceLbl -text "View As:" ]
    set choiceBox [guiUtil::ComboBox $choiceFrm.choiceCombo -listheight 4 \
	    -textvariable inspector::viewVar -strict 1 \
	    -command {inspector::updateWindow 0}]

    foreach choice {"Array" "List" "Raw Data" "Line Wrap"} {
	$choiceBox add $choice
    }
    set inspector::viewVar "Line Wrap"
    pack $choiceLbl -pady 3 -side left
    pack $choiceBox -padx 3 -pady 3 -side left

    # Place a separating line between the var info and the 
    # value of the var.

    set sep2Frm [frame $dataFrm.sep2 -bd $bd -relief $relief -height $bd]
    
    # Create an empty frame that will be populated in the updateWindow 
    # routine.

    set varFrm  [frame $dataFrm.varFrm]
    set varText [text $varFrm.varText -width 1 -height 2 \
	    -yscroll [list $varFrm.yscroll set] \
	    -xscroll [list $varFrm.xscroll set] ]
    set yscroll [scrollbar $varFrm.yscroll -command [list $varText yview]]
    set xscroll [scrollbar $varFrm.xscroll -command [list $varText xview] \
	    -orient horizontal]
    grid $varText -row 0 -column 0 -sticky nswe
    grid $yscroll -row 0 -column 1 -sticky ns
    grid $xscroll -row 1 -column 0 -sticky we
    grid columnconfigure $varFrm 0 -weight 1
    grid rowconfigure $varFrm 0 -weight 1

    pack $infoFrm -padx $pad -pady $pad -fill x
    pack $sep1Frm  -padx $pad -fill x
    pack $choiceFrm -padx $pad -pady $pad -fill x
    pack $sep2Frm  -padx $pad -fill x
    pack $varFrm  -padx $pad -pady $pad -expand true -fill both

    pack $dataFrm -padx $pad -pady $pad -fill both -expand true -side bottom
    pack $inspectFrm  -padx $pad -pady $pad -fill x -side bottom
    pack $mainFrm -padx $pad -pady $pad -fill both -expand true -side bottom

    gui::setDbgTextBindings $varText
    bind::addBindTags $varText [list noEdit dataDbgWin]
    bind::addBindTags $inspectEnt dataDbgWin
    bind::addBindTags $inspectBut dataDbgWin

    bind::commonBindings dataDbgWin [list $inspectEnt $inspectBut $varText]

    bind $inspectEnt <Return> {
	inspector::updateVarFromEntry
        break
    }
}

# inspector::updateWindow --
#
#	Update the display of the Inspector.  A Tcl variable
# 	may be aliased with different names at different 
#	levels, so update the name and level as well as the 
#	value.
#
# Arguments:
#	name		The variable name.
#	valu		The variable valu.  If the variable is an 
#			array, this is an ordered list of array
#			index and array value.
#	type		Variable type ('a' == array, 's' == scalar)
#	level		The stack level of the variable.
#
# Results:
#	None.

proc inspector::updateWindow {{setChoice 0}} {
    variable nameVar
    variable levelVar
    variable showResult
    variable varText
    variable choiceBox
    variable levelCache
    variable nameCache
    variable valueCache
    variable viewCache

    if {![winfo exists $gui::gui(dataDbgWin)]} {
	return
    }
    if {[gui::getCurrentState] != "stopped"} {
	return
    }

    if {$showResult} {
	# Fetch the interpreter result and update the level
	set type s
	set value [lindex [dbg::getResult -1] 1]
    } else {
	# Fetch the named variable
	if {[catch {
	    set varInfo [lindex [dbg::getVar $levelVar -1 [list $nameVar]] 0]
	}]} {
	    set varInfo {}
	}
	if {$varInfo == {}} {
	    set type  s
	    set value "<No-Value>"
	} else {
	    set type [lindex $varInfo 1]
	    set value [lindex $varInfo 2]
	}
    }
    set data {}
    if {$type == "a"} {
	foreach v $value {
	    lappend data [code::binaryClean $v]
	}
    } else {
	set data [code::binaryClean $value]
    }
    
    if {$setChoice} {
	if {$type == "a"} {
	    set inspector::viewVar "Array"
	} else {
	    set inspector::viewVar "Line Wrap"
	}
    }
    set view [$choiceBox get]

    if {($nameVar == $nameCache) && ($levelVar == $levelCache) \
	    && ($value == $valueCache) && ($view == $viewCache)} {
	if {[$varText get 1.0 1.1] != ""} {
	    return
	}
    }
    
    $varText delete 0.0 end
    switch $view {
	"Raw Data" {
	    $varText configure -wrap none -tabs {}
	    $varText insert 0.0 $value
	}
	"Line Wrap" {
	    $varText configure -wrap word -tabs {}
	    $varText insert 0.0 $value
	}
	"List" {
	    if {[catch {llength $value}]} {
		# If we get an error in llength then we can't
		# display as a list.

		$varText insert end "<Not a valid list>"
	    } else {
		$varText configure -wrap none -tabs {}
		foreach index $value {
		    $varText insert end "$index\n"
		}
	    }
	} 
	"Array" { 
	    if {[catch {set len [llength $value]}] || ($len % 2)} {
		# If we get an error in llength or we don't have
		# an even number of elements then we can't
		# display as aa array.

		$varText insert end "<Can't display as an array>"
	    } else {
		$varText configure -wrap none
	    
		set line 1
		set max 0
		set maxLine 1
		foreach {entry index} $value {
		    $varText insert end "$entry \n"
		    set len [string length $entry]
		    if {$len > $max} {
			set max $len
			set maxLine $line
		    }
		    incr line
		}

		$varText see $maxLine.0
		set maxWidth [lindex [$varText dlineinfo $maxLine.0] 2]
		$varText delete 0.0 end
		$varText configure -tabs $maxWidth

		array set temp $value

		foreach entry [lsort -dictionary [array names temp]] {
		    $varText insert end "$entry\t= $temp($entry)\n"
		}
	    }
	}
	default {
	    error "Unexpected view type \"$view\" in inspector::updateWindow"
	}
    }
    
    set nameCache  $nameVar
    set levelCache $levelVar
    set valueCache $value
    set viewCache  $view
    return
}
