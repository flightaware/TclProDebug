# varWin.tcl --
#
#	This file implements the Var Window (contained in the
#	main debugger window.)
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 


namespace eval var {
    # Handles to the text windows that display variable names 
    # and values.

    variable valuText {}
    variable nameText {}
    variable vbpText  {}
}

# var::createWindow --
#
#	Create the var window and all of the sub elements.
#
# Arguments:
#	masterFrm	The frame that contains the var frame.
#
# Results:
#	The frame that contains the Var Window.

proc var::createWindow {masterFrm} {
    variable nameText
    variable valuText
    variable vbpText
    
    array set bar [system::getBar]

    set varFrm [frame $masterFrm.varFrm]
    set nameFrm  [frame $varFrm.nameFrm]
    set vbpFrm   [frame $nameFrm.vbpFrm -width $bar(width)]
    set vbpText  [text $vbpFrm.vbpTxt -width 1 -height 20 -bd 0 \
	    -bg $bar(color)]
    set nameText [text $nameFrm.nameTxt -width 20 -height 20 -bd 0]
    set valuFrm  [frame $varFrm.valuFrm]
    set valuText [text $valuFrm.valuTxt -width 20 -height 20 -bd 0 \
	    -yscroll [list $valuFrm.sb set]]
    set sb [scrollbar $valuFrm.sb -command {watch::scrollWindow \
	    $var::nameText}]

    pack propagate $vbpFrm 0
    pack $vbpFrm   -side left -fill y
    pack $vbpText  -side left -fill both -expand true
    pack $nameText -side left -fill both -expand true
    grid $valuText -sticky wnse -row 0 -column 0
    grid columnconfigure $valuFrm 0 -weight 1
    grid rowconfigure $valuFrm 0 -weight 1
    guiUtil::tableCreate $varFrm $nameFrm $valuFrm \
	    -title1 "Variable" -title2 "Value" -percent 0.4

    # Create the mapping for Watch text widgets.  See the
    # description of the text variable in the namespace eval
    # statement of watchWin.tcl.

    set watch::text(name,$nameText) $nameText
    set watch::text(name,$valuText) $nameText
    set watch::text(name,$vbpText)  $nameText
    set watch::text(valu,$nameText) $valuText
    set watch::text(valu,$valuText) $valuText
    set watch::text(valu,$vbpText)  $valuText
    set watch::text(vbp,$nameText)  $vbpText
    set watch::text(vbp,$valuText)  $vbpText
    set watch::text(vbp,$vbpText)   $vbpText

    bind::addBindTags $valuText [list watchBind varDbgWin]
    bind::addBindTags $nameText [list watchBind varDbgWin]
    watch::internalBindings $nameText $valuText $vbpText $sb
    gui::registerStatusMessage $vbpText \
	    "Click in the bar to set a variable breakpoint"
    sel::setWidgetCmd $valuText all {
	watch::cleanupSelection $var::valuText
	var::checkState
    } {
	watch::seeCallback $var::valuText
    }

    bind varDbgWin <<Dbg_AddWatch>> {
	var::addToWatch
    }
    $valuText tag bind handle <Enter> {
	set gui::afterStatus(%W) [after 2000 \
		{gui::updateStatusMessage -msg \
		"Click to expand or flatten the array"}]
    }
    $valuText tag bind handle <Leave> {
	if {[info exists gui::afterStatus(%W)]} { 
	    after cancel $gui::afterStatus(%W)
	    unset gui::afterStatus(%W)
	    gui::updateStatusMessage -msg {}
	}
    }

    return $varFrm
}

# var::updateWindow --
#
#	Update the display of the Var window.  This routine 
#	expects the return of gui::getCurrentLevel to give
#	the level displayed in the Stack Window.
#
# Arguments:
#	None.
#
# Results: 
#	None.

proc var::updateWindow {} {
    variable nameText
    variable valuText
    variable vbpText

    if {[gui::getCurrentState] != "stopped"} {
	return
    }

    set level [gui::getCurrentLevel]
    set varList [lsort -dictionary -index 1 \
	    [watch::varDataAddVars $valuText $level]]

    # Call the internal routine that populates the var name and
    # var value windows.

    watch::updateInternal $nameText $valuText $vbpText $varList $level
}

# var::resetWindow --
#
#	Clear the contents of the window and display a
#	message in its place.
#
# Arguments:
#	msg	If not null, then display the contents of the
#		message in the window.
#
# Results:
#	None.

proc var::resetWindow {{msg {}}} {
    variable nameText
    variable valuText
    variable vbpText

    gui::unsetFormatData $nameText
    gui::unsetFormatData $valuText
    $nameText delete 0.0 end
    $valuText delete 0.0 end
    $vbpText delete 0.0 end

    if {$msg != {}} {
	$valuText insert 0.0 $msg message
    }
}

# var::checkState --
#
#	This proc is executed whenever the selection 
#	in the Var Window changes.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc var::checkState {} {
    variable valuText

    if {[focus] == $valuText} {
	watch::changeFocus $valuText in
    }
}

# watch::addToWatch --
#
#	Add the selected variables to the Watch Window.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc var::addToWatch {} {
    variable valuText

    set lineList [sel::getSelectedLines $valuText]
    foreach line $lineList {
	set oname [watch::varDataGet $valuText $line.0 "oname"]
	watch::addVar $oname
    }
}

# var::seeVarInWindow --
#
#	Move the Var Window to show the variable that was selected
#	in the Stack Window.  The Var Window is assumed to be updated
#	to the current frame and that the variable exists in the
#	frame.  
#
# Arguments:
#	varName		The name of the variable to be moved into
#			sight of the var window.
#	moveFocus	Boolean value, if true move the focus to the
#			Var Window after the word is shown.
#
# Results:
#	None.

proc var::seeVarInWindow {varName moveFocus} {
    variable nameText
    variable valuText

    # Build a list of line numbers, one foreach line in the
    # Var Window.  The pass this to watch::getVarNames to 
    # retrieve a list of all valid var names.

    set varNameList {}
    for {set i 1} {$i < [$var::nameText index end]} {incr i} {
	set oname [watch::varDataGet $valuText $i.0 "oname"]
	lappend varNameList [code::mangle $oname]
    }

    # Search the list of var names to see if the var exists in the
    # Var Window.  If so select the line and possibly force the 
    # focus to the Var WIndow.

    set line [expr {[lsearch $varNameList $varName] + 1}]
    if {$line >= 0} {
	watch::selectLine $nameText $line.0
	if {$moveFocus} {
	    focus $valuText
	}
    }
}
