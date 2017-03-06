# watchWin.tcl --
#
#	This file implements the Watch Window and the common APIs
#	used by the Watch Window and the Var Window.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 

namespace eval watch {
    # Handles to the text windows that display variable
    # names and values and the buttons in the Watch window.

    variable valuText   {}
    variable nameText   {}
    variable vbpText    {}
    variable inspectBut {}
    variable remBut     {}
    variable allBut     {}

    # The list of variable that are currently being watched.

    variable varList {}

    # The output message when the variable is undefined or 
    # out of scope.

    variable noValue {<No Value>}

    # Maintain a list of all the expanded arrays at a given level.
    # When update is called, the text in the window is deleted and
    # the current state is inserted.  This array will assure that
    # arrays expanded before the update are still expanded after
    # the update.

    variable expanded

    variable scalarVarData
    variable arrayVarData

    # The Var and Watch Windows share common functions.  To
    # get a mapping from one text widget (e.g., the var::nameText)
    # to the sister text widget (e.g., the var::valuText), the
    # text widgets are entered into this array in the following
    # format:
    #
    # text(name,$text)	Maps either text to the nameText widget.
    # text(valu,$text)	Maps either text to the valuText widget.
    #
    # This is useful for making bindings as simple as possible, by
    # using %W and extracting the correct widgets.

    variable text

    # The number of spaces to indent array entries that are displayed
    # below the array name and array handle.

    variable entryTab 2

    variable afterID
}

# watch::showWindow --
#
#	Show the Watch Window.  If the window exists then just
#	raise it to the foreground.  Otherwise, create the window.
#
# Arguments:
#	None.
#
# Results:
#	The name of the Watch Window's toplevel.

proc watch::showWindow {} {
    # If the window already exists, show it, otherwise
    # create it from scratch.

    if {[info command $gui::gui(watchDbgWin)] == $gui::gui(watchDbgWin)} {
	watch::updateWindow
	wm deiconify $gui::gui(watchDbgWin)
	focus $watch::valuText
	return $gui::gui(watchDbgWin)
    } else {
	watch::createWindow
	watch::updateWindow
	focus $watch::valuText
	return $gui::gui(watchDbgWin)
    }    
}

# watch::createWindow --
#
#	Create the Watch Window and all of the sub elements.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc watch::createWindow {} {
    variable nameText
    variable valuText
    variable vbpText
    variable inspectBut
    variable remBut
    variable allBut
    variable varList

    set bd 2
    set pad  6
    set pad2 [expr {$pad * 2}]
    array set bar [system::getBar]

    set top [toplevel $gui::gui(watchDbgWin)]
    ::guiUtil::positionWindow $top 400x250
    wm minsize $top 100 100
    wm title $top "Watch Variables"
    wm transient $top $gui::gui(mainDbgWin)

    # Create the entry for adding new Watch variables.

    set mainFrm [frame $top.mainFrm -bd $bd -relief raised]
    set addFrm [frame $mainFrm.addFrm]
    set addLbl [label $addFrm.addLbl -anchor w -text "Variable:"]
    set addEnt [entry $addFrm.addEnt]
    set addBut [button $mainFrm.addBut -text Add \
	    -command "watch::addVarFromEntry $addEnt"]
    pack $addLbl -side left
    pack $addEnt -side left -fill x -expand true -padx 3

    # Place a separating line between the var info and the 
    # value of the var.

    set sepFrm [frame $mainFrm.sep1 -bd $bd -relief groove -height $bd]
    
    # Create the table for displaying var names and values.

    set midFrm [frame $mainFrm.midFrm]
    set varFrm [frame $midFrm.varFrm]
    set nameFrm  [frame $varFrm.nameFrm]
    set vbpFrm   [frame $nameFrm.vbpFrm -width $bar(width)]
    set vbpText  [text $vbpFrm.vbpTxt -width 1 -height 20 -bd 0 \
	    -bg $bar(color)]
    set nameText [text $nameFrm.nameTxt -width 20 -height 20 -bd 0]
    set valuFrm  [frame $varFrm.valuFrm]
    set valuText [text $valuFrm.valuTxt -width 20 -height 20 -bd 0 \
	    -yscroll [list $valuFrm.sb set]]
    set sb [scrollbar $valuFrm.sb -command {watch::scrollWindow \
	    $watch::nameText}]

    pack propagate $vbpFrm 0
    pack $vbpFrm   -side left -fill y
    pack $vbpText  -side left -fill both -expand true
    pack $nameText -side left -fill both -expand true
    grid $valuText -sticky wnse -row 0 -column 0
    grid columnconfigure $valuFrm 0 -weight 1
    grid rowconfigure $valuFrm 0 -weight 1
    guiUtil::tableCreate $varFrm $nameFrm $valuFrm \
	    -title1 "Variable" -title2 "Value" -percent 0.4

    # Create the buttons to Inspect and remove vars.

    set butFrm [frame $mainFrm.butFrm]
    set inspectBut [button $butFrm.insBut -text "Data Display" \
	    -command [list watch::showInspectorFromIndex $nameText current] \
	    -state disabled]
    set remBut [button $butFrm.remBut -text "Remove" \
	    -command {watch::removeSelected} -state disabled] 
    set allBut [button $butFrm.allBut -text "Remove All" \
	    -command {watch::removeAll} -state disabled] 
    set closeBut [button $butFrm.closeBut -text "Close" \
	    -command {destroy $gui::gui(watchDbgWin)}] 
    pack $inspectBut $remBut $allBut $closeBut -fill x -pady 3

    grid $addFrm -row 0 -column 0 -sticky we -padx $pad -pady $pad
    grid $addBut -row 0 -column 1 -sticky we -padx $pad -pady $pad2
    grid $sepFrm -row 1 -column 0 -columnspan 2 -sticky we -padx $pad
    grid $midFrm -row 2 -column 0 -sticky nswe -padx $pad -pady $pad2
    grid $butFrm -row 2 -column 1 -sticky nwe -padx $pad -pady [expr {$pad2 - 3}]
    grid columnconfigure $mainFrm 0 -weight 1
    grid rowconfigure $mainFrm 2 -weight 1
    pack $mainFrm -fill both -expand true -padx $pad -pady $pad

    # Create the mapping for Watch text widgets.  See the
    # description of the text variable in the namespace eval
    # statement.

    set watch::text(name,$nameText) $nameText
    set watch::text(name,$valuText) $nameText
    set watch::text(name,$vbpText)  $nameText
    set watch::text(valu,$nameText) $valuText
    set watch::text(valu,$valuText) $valuText
    set watch::text(valu,$vbpText)  $valuText
    set watch::text(vbp,$nameText)  $vbpText
    set watch::text(vbp,$valuText)  $vbpText
    set watch::text(vbp,$vbpText)   $vbpText

    # Add all of the common bindings an create the tab focus
    # order for each widget that can get the focus.

    bind::commonBindings watchDbgWin [list $addEnt $addBut \
	    $valuText $inspectBut $remBut $allBut $closeBut]

    # Create common bindings and Watch Window specific bindings.

    bind::addBindTags $addEnt     watchDbgWin
    bind::addBindTags $nameText   [list watchBind watchDbgWin]
    bind::addBindTags $valuText   [list watchBind watchDbgWin]
    bind::addBindTags $inspectBut watchDbgWin
    bind::addBindTags $remBut     watchDbgWin
    bind::addBindTags $allBut     watchDbgWin
    watch::internalBindings $nameText $valuText $vbpText $sb
    
    # Define the command to be called after each selection event.
    
    sel::setWidgetCmd $valuText all {
	watch::cleanupSelection $watch::valuText
	watch::checkState
    } {
	watch::seeCallback $watch::valuText
    }

    # Define bindings specific to the Watch Window.

    bind watchDbgWin <<Dbg_RemSel>> {
	watch::removeSelected
    }
    bind watchDbgWin <<Dbg_RemAll>> {
	watch::removeAll
    }
    bind $addEnt <Return> "watch::addVarFromEntry $addEnt; break"
    bind $top <Escape> "$closeBut invoke; break"
}

# watch::updateWindow --
#
#	Update the display of the Watch Window.  
#
# Arguments:
#	None.
#
# Results: 
#	None.

proc watch::updateWindow {} {
    variable nameText
    variable valuText
    variable vbpText
    variable varList
    variable inspectBut
    variable afterID

    set state [gui::getCurrentState]
    set level [gui::getCurrentLevel]

    if {![winfo exists $gui::gui(watchDbgWin)]} {
	return
    }
    if {$state == "running"} {
	return
    }

    if {[info exists afterID]} {
	after cancel $afterID
	unset afterID
    }

    set varInfo {}
    if {$state == "stopped" && ![stack::isVarFrameHidden] \
	    && ($varList != {})} {
	set varInfo [watch::varDataAddVars $valuText $level $varList]
    } else {
	# The GUI is dead so there is no variable information.
	# Foreach var in varList, generate a dbg::getVar result
	# that indicates the var does not exist.
	# {mname oname type exist}
	
	foreach var $varList {
	    lappend varInfo [list [code::mangle $var] $var n 0]
	}
    }


    # Call the internal routine that populates the var name and
    # var value windows.

    if {$state == "running"} {
	set afterID [after $gui::afterTime [list
		watch::updateInternal $nameText $valuText $vbpText \
		\{$varInfo\} $level; watch::checkState 
	]]

    } else {
	watch::updateInternal $nameText $valuText $vbpText $varInfo $level
	watch::checkState
    }
}

# watch::resetWindow --
#
#	Clear the contents of the window and display a
#	message in its place, or set all of the values
#	to <No Value> for the case that the Var Frame is 
#	hidden.
#
# Arguments:
#	msg		If not null, then display the contents 
#			of the message in the window.
#
# Results:
#	None.

proc watch::resetWindow {msg} {
    variable nameText
    variable valuText
    variable vbpText
    variable varList
    variable inspectBut

    if {![winfo exists $gui::gui(watchDbgWin)]} {
	return
    }

    $inspectBut configure -state disabled
    if {[stack::isVarFrameHidden]} {
	# The var frame is hidden so there is no variable information
	# Foreach var in varList, generate a dbg::getVar result
	# that indicates the var does not exist.

	foreach var $varList {
	    lappend varInfo [list [code::mangle $var] $var s 0]
	}

	# Call the internal routine that populates the var name and
	# var value windows.
	
	watch::updateInternal $nameText $valuText $vbpText $varInfo \
		[gui::getCurrentLevel]
    } else {
	gui::unsetFormatData $valuText
	$valuText delete 0.0 end
	if {$msg != {}} {
	    $valuText insert 0.0 $msg message
	}
    }
}

# watch::addVar --
#
#	Add newVar to the list of watched variables as long as
#	newVar is not a duplicate or an empty string.
#
# Arguments:
#	newVar	The new variable to add to the Watch window.
#
# Results:
#	None.

proc watch::addVar {newVar} {
    variable varList
    
    if {($newVar != {}) && ([lsearch $varList $newVar] < 0)} {
	lappend varList $newVar
	watch::setVarList $varList
    }
    return
}

# watch::addVarFromEntry --
#
#	Add a variable to the Watch Window by extracting the
#	variable name from an entry widget.
#
# Arguments:
#	ent	The entry widget to get the var name from.
#
# Results:
#	None.

proc watch::addVarFromEntry {ent} {
    set newVar [$ent get]
    $ent delete 0 end
    watch::addVar $newVar
}

# watch::removeAll --
#
#	Remove all of the Watched variables.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc watch::removeAll {} {
    watch::setVarList {}
    return
}

# watch::removeSelected --
#
#	Remove all of the highlighted variables.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc watch::removeSelected {} {
    variable nameText
    variable valuText
    variable varList
    
    set yview [lindex [$nameText yview] 0]

    set selectedLines [sel::getSelectedLines $nameText]
    set selectCursor  [sel::getCursor $nameText]

    if {$selectedLines != {}} {
	# Create a new varList containing only the unselected 
	# variables.  Then call updateWindow to display the
	# updated varList.
	
	set tempList {}
	for {set i 0; set j 0} {$i < [llength $varList]} {incr i} {
	    if {($i + 1) == [lindex $selectedLines $j]} {
		# This is a selected var, do not add to tempList.
		incr j
	    } else {
		# This is an unselected var, add this to our new varList.
		lappend tempList [lindex $varList $i]
	    }
	}
	watch::setVarList $tempList
	watch::selectLine $nameText "$selectCursor.0"
    }
    watch::checkState
    
    $valuText yview moveto $yview
    $nameText yview moveto $yview
}

# watch::checkState --
#
#	If one or more selected variable has a value for
#	the variable, then enable the "Data Display"
#	and "Remove" buttons.  If there are values being
#	watched then enable the "Remove All" button.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc watch::checkState {} {
    variable valuText
    variable varList

    set cursor [sel::getCursor $valuText]
    set lines  [sel::getSelectedLines $valuText]

    if {([watch::varDataGet $valuText $cursor.0 "exist"] == 1) \
	    && ([lsearch $lines $cursor] >= 0)} {
	$watch::inspectBut configure -state normal
    } else {
	$watch::inspectBut configure -state disabled
    }
    if {$lines == {}} {
	$watch::remBut configure -state disabled
    } else {
	$watch::remBut configure -state normal
    }	
    if {$watch::varList == {}} {
	$watch::allBut configure -state disabled
    } else {
	$watch::allBut configure -state normal
    }
    if {[focus] == $valuText} {
	watch::changeFocus $valuText in
    }
}

# watch::getVarList --
#
#	Return the current list variables being displayed 
#	in the Watch Window.
#
# Arguments:
#	None.
#
# Results:
#	Returns a list of variable names.

proc watch::getVarList {} {
    return $watch::varList
}

#  watch::setVarList --
#
#	Set the list of Vars to watch.
#
# Arguments:
#	vars	The list of vars to watch.
#	dirty	Boolean, indicating if the dirty bit should be set.  
#		Can be null.
#
# Results:
#	None.

proc watch::setVarList {vars {dirty 1}} {
    # If the level is empty, then a remote app has connected
    # but has not initialized the GUIs state.

    set watch::varList $vars
    if {$dirty} {
	pref::groupSetDirty Project 1
    }
    if {[winfo exists $gui::gui(watchDbgWin)]} {
	watch::updateWindow
    }
    return
}

#-----------------------------------------------------------------------------
# The routines below are written so that both the Var Window and the 
# Watch Window can use them.
#-----------------------------------------------------------------------------

# watch::internalBindings --
#
#	Set bindings on Var and Watch Window nameText and valuText
#	that are common between the two windows.
#
# Arguments:
#	ns		The namespace (either "var" or "watch")
#	nameText	The nameText window for the Var or Watch Window.
#	valeText	The valuText window for the Var or Watch Window.
#	sb		The scrollbar for the valuText Window.
#
# Results:
#	None.

proc watch::internalBindings {nameText valuText vbpText sb} {
    gui::setDbgTextBindings $nameText
    gui::setDbgTextBindings $valuText
    gui::setDbgTextBindings $vbpText

    if {![winfo exists $valuText]} {
	return
    }

    $nameText configure -padx 0
    $valuText configure -padx 0
    $vbpText  configure -padx 2

    $valuText configure -yscroll [list gui::scrollDbgText $valuText $sb \
	    [list grid $sb -sticky nse -row 0 -column 1]]
    
    # Special bindings on the nameText widget; toggling
    # VBPs on/off/enabled/disabled.

    bind $vbpText <1> {
	watch::toggleVBP %W @0,%y onoff
    }
    bind $vbpText <Control-1> {
        watch::toggleVBP %W @0,%y enabledisable
    }

    bind $valuText <FocusIn> {
	watch::changeFocus %W in
	break
    }
    bind $valuText <FocusOut> {
	watch::changeFocus %W out
	break
    }

    # Special bindings on the valuText widget; expanding
    # or flattening arrays.

    $valuText tag bind expander <1> {
        watch::expandOrFlattenArray %W current
    }
    $valuText tag bind expander <Enter> {
	%W configure -cursor hand2
    }
    $valuText tag bind expander <Leave> {
	%W configure -cursor [system::getArrow]
    }
    return
}

# watch::varDataGet --
#
#	Get the value for the key associated to an index 
#	in a text widget.
#
# Arguments:
#	text	The text widget that stores the keys.
#	index	The index to search for the keys.
#	key	The key to get.
#
# Results:
#	Return the value of the key, or {} if the key does 
#	not exist.

proc watch::varDataGet {text index key} {
    upvar 1 value value

    set tags  [$text tag names $index]
    set index [lsearch -glob $tags ${key}:*]

    if {$index >= 0} {
	set word  [lindex $tags $index]
	set start [string length "${key}:"]
	return [string range $word $start end]
    } else {
	return {}
    }
}

# watch::varDataSet --
#
#	Set the value for the key associated to an index 
#	in a text widget.
#
# Arguments:
#	text	The text widget that stores the keys.
#	index	The index where the keys and values are stored.
#	pairs	A list of key/value pairs to set.
#
# Results:
#	None.

proc watch::varDataSet {text index pairs} {
    foreach {key value} $pairs {
	# Remove any old tags that may have been previopusly set.

	set oldValue [watch::varDataGet $text $index $key]
	if {$oldValue != {}} {
	    $text tag remove "${key}:{oldValue}" $index
	}
	$text tag add "${key}:${value}" $index
    }
    return
}

# watch::varDataGetValue --
#
#	Get the value for a scalar or array variable.
#	Arrays are assumed to exists in the database.
#
# Arguments:
#	oname	The original, unmangled, variable name.
#	level	The level to get variables from.
#	type	The type of variable (s or a)
#
# Results:
#	Returns the value of the variable.

proc watch::varDataGetValue {oname level type} {
    if {$type == "a"} {
	return [VarDataGetArrayValue $oname $level]
    } else {
	return [VarDataGetScalarValue $oname $level]
    }
}

# watch::VarDataGetScalarValue --
#
#	Get the scalar value for a variable.  If the
#	variable does not exist at this level, then
#	it has not been fetched.  Set the value to
#	<No Value>.
#
# Arguments:
#	oname		The original, unmangled, variable name.
#	level		The level to get variables from.
#	existVar	Optional var name that will contain a 
#			boolean indicating if the var exists.
#
# Results:
#	Returns the value of the variable.

proc watch::VarDataGetScalarValue {oname level {existVar {}}} {
    variable scalarVarData

    if {$existVar != {}} {
	upvar 1 $existVar exists
    }
    if {[info exists scalarVarData($oname,$level)]} {
	set exists 1
	return $scalarVarData($oname,$level)
    } else {
	set exists 0
	return $watch::noValue
    }
}

# watch::VarDataGetArrayValue --
#
#	Get an array element/value ordered list for an array.
#	May need to fetch the value if this is the first 
#	time an array is expanded.  Note: The array must 
#	exist!  Otherwise watch::varDataFetched wont work.
#
# Arguments:
#	oname	The original, unmangled, array name.
#	level	The level to get variables from.
#
# Results:
#	Returns an ordered list of element/value pairs.

proc watch::VarDataGetArrayValue {oname level} {
    variable arrayVarData

    if {![varDataFetched $oname $level "a"]} {
	set value [lindex [lindex \
		[dbg::getVar $level [font::get -maxchars] $oname] 0] 2]
	set arrayVarData($oname,$level) $value
    }
    return $arrayVarData($oname,$level)
}

# watch::varDataFetched --
#
#	Determine if the variable's value has been
#	fetched at this level.
#
# Arguments:
#	oname	The original, unmangled, array name.
#	level	The level to get variables from.
#	type	The type of variable (a or s)
#
# Results:
#	Returns 1 if the var exists, 0 if it does not.

proc watch::varDataFetched {oname level type} {
    if {$type == "a"} {
	return [info exists ::watch::arrayVarData($oname,$level)]
    } else {
	watch::VarDataGetScalarValue $oname $level exists
	return $exists
    }
}

# watch::setArrayExpanded --
#
#	Set the expanded value for an array.
#
# Arguments:
#	text	The text widget where the array is displayed.
#	oname	The original, unmangled, array name.
#	level	The level to get variables from.
#	expand	Boolean, 1 means the array is expanded.
#
# Results:
#	Returns 1 if the array is expanded.

proc watch::setArrayExpanded {text level oname expand} {
    set ::watch::expanded($text,$level,$oname) $expand
    return
}

# watch::isArrayExpanded --
#
#	Check to see if an array is fully expanded.
#
# Arguments:
#	text	The text widget where the array is displayed.
#	oname	The original, unmangled, array name.
#	level	The level to get variables from.
#
# Results:
#	Returns 1 if the array is expanded.

proc watch::isArrayExpanded {text level oname} {
    variable expanded

    if {[info exists expanded($text,$level,$oname)] \
	    && ($expanded($text,$level,$oname))} {
	return 1
    } else {
	return 0
    }
}

# watch::varDataReset --
#
#	Clear the scalarVarData and arrayVarData arrays.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc watch::varDataReset {} {
    if {[info exists ::watch::scalarVarData]} {
	unset ::watch::scalarVarData
    }
    if {[info exists ::watch::arrayVarData]} {
	unset ::watch::arrayVarData
    }
    return
}

# watch::varDataAddVars --
#
#	Add data to the varData array from a list of variables or the
#	locals for the specified level.  Note this routine should only
#	be called while the debugger is stopped.
#
# Arguments:
#	window		The watch or var window.
#	level		The level to get variables from.
#	vars		Optional.  A list of variable names to add.
#
# Results:
#	Return an ordered list foreach ver of the following format:
#	{mname oname type exist}

proc watch::varDataAddVars {text level {vars {}}} {
    variable scalarVarData
    variable arrayVarData

    # Foreach var in the vars, compute the list {mname oname type exist}
    # and set the value in the database.
    
    set infoVars  {}
    set foundVars {}
    set foundList {}
    set realVars  [dbg::getVariables $level $vars]

    # First, determine which variables values have already
    # been from the Nub or do not need to be fetched.

    foreach pair $realVars {
	set oname [lindex $pair 0]
	set type  [lindex $pair 1]

	# If the value has already been fetched or is an unexpanded
	# array, create the list and continue.  Otherwise append
	# the var name to the list of variables whose values need
	# to be fetched.

	if {([watch::varDataFetched $oname $level $type]) \
		|| (($type == "a") \
		&& (![watch::isArrayExpanded $text $level $oname]))} {
	    set mname [code::mangle $oname]
	    lappend foundList [list $mname $oname $type 1]
	    lappend foundVars $oname
	} else {
	    lappend infoVars $oname
	}
    }

    # Next, fetch the values for the variables in the infoVars
    # list, add the list to the result and set the database.  

    if {$infoVars != ""} {
	foreach info [dbg::getVar $level [font::get -maxchars] $infoVars] {
	    set oname [lindex $info 0]
	    set type  [lindex $info 1]
	    set value [lindex $info 2]
	    set mname [code::mangle $oname]
	    
	    if {$type == "a"} {
		set arrayVarData($oname,$level) $value
	    } else {
		set scalarVarData($oname,$level) $value
	    }
	    lappend foundList [list $mname $oname $type 1]
	    lappend foundVars $oname
	}
    }

    # Finally, determine which varaibles do not exist.  If the 
    # variable is in the realVars list and is not in the foundVars
    # list, then the variable does not exist.  Create the list, but
    # do not set the value in the database.

    set result    {}
    foreach pair $realVars {
	set oname [lindex $pair 0]
	if {[set index [lsearch -exact $foundVars $oname]] >= 0} {
	    lappend result [lindex $foundList $index]
	} else {
	    set type  [lindex $pair 1]
	    set mname [code::mangle $oname]
	    lappend result [list $mname $oname $type 0]
	}
    }
    return $result
}

# watch::updateInternal --
#
#	Update routine that is common between the Watch Window and
#	the Var Window.
#
# Arguments:
#	nameText	The nameText window for the Var or Watch Window.
#	valuText	The valuText window for the Var or Watch Window.
#	vbpText		The vbpText window for the Var or Watch Window.
#	varList		The list of vars to add to the window.  The 
#			insertion is done in order, so this list needs
#			to have been pre-sorted.  Any variables that
#			do not exist in this scope are assumed to have
#			been detected and replaced with <No Value>.
#			varList is an ordered list with the following
#			structure: {mname oname type exist}
#	level		The level of the variables being displayed.  Used
#			to determine which arrays are expanded or compressed.
#
# Results:
#	None.

proc watch::updateInternal {nameText valuText vbpText varList level} {
    variable expanded

    dbg::Log timing {updateInternal $nameText}

    # Cleanup the previous state and start fresh.  Cache the 
    # yview of the scrollbar so it can be "seemlessly" restored.

    set yview [lindex [$valuText yview] 0]

    gui::unsetFormatData $nameText
    gui::unsetFormatData $valuText
    $nameText delete 0.0 end
    $valuText delete 0.0 end
    $vbpText  delete 0.0 end

    set line  1
    foreach var $varList {
	set mname [lindex $var 0]
	set oname [lindex $var 1]
	set type  [lindex $var 2]
	set exist [lindex $var 3]

	# Insert the variable name and value.  If the variable
	# is an array,  display "..." to indicate this can be 
	# expanded.
	#
	# Add the tag "leftIndent" to all on the entries in nameText.
	# This will cause the left side of the text box to indent a few 
	# pixels.  This is done instead of configuring w/ "padx" so 
	# the highlight bar will connect entirely between the nameText
	# and valuText windows.

	if {$level != {}} {
	    icon::drawVBP $vbpText $line.0 [icon::getVBPState $level $oname]
	}
	$nameText insert $line.0 "$mname" [list varEntry leftIndent]

	switch -- $type {
	    "s" {
		# Replace the newlines in the value with a char representation
		# so the value fits on one line. 

		set mvalue [code::mangle \
			[watch::varDataGetValue $oname $level $type]]
		$valuText insert end $mvalue [list varEntry leftIndent]
	    }
	    "a" {
		$valuText insert end {(...)} [list \
			varEntry expander handle leftIndent]
	    }
	    "n" {
		$valuText insert end $watch::noValue [list varEntry leftIndent]
	    }
	}

	$nameText insert end "\n"
	$valuText insert end "\n"
	$vbpText  insert end " \n"

	# Insert the keys AFTER the newlines have been added.  This will
	# insure there is at least one char on the line to add the tags 
	# to.  Otherwise, if the string is null, no tag will be added.

	watch::varDataSet $valuText $line.0 \
		[list oname $oname type $type exist $exist]

	# Expand the array after the keys have been inserted because
	# the expand array APIs rely on these keys.

	if {$type == "a" && $level != {}} {
	    if {[watch::isArrayExpanded $valuText $level $oname]} {
		incr line [watch::ExpandArray $valuText $line.0]
	    }
	}
	incr line
    }

    # Restore the previous yview before everything was deleted.

    $nameText yview moveto $yview
    $valuText yview moveto $yview
    $vbpText  yview moveto $yview
    gui::formatText $valuText right
    gui::formatText $nameText right
}

# watch::configure --
#
#	Format the text widgets.
#
# Arguments:
#	text	The text widget being configured.
#
# Results:
#	None.

proc watch::configure {text} {
    set nameText $watch::text(name,$text)
    set valuText $watch::text(valu,$text)

    set lines [sel::getSelectedLines $nameText]
    $nameText tag remove highlight 0.0 end
    $valuText tag remove highlight 0.0 end

    gui::formatText $text right

    foreach line $lines {
	$nameText tag add highlight $line.0 "$line.0 lineend + 1c"
	$valuText tag add highlight $line.0 "$line.0 lineend + 1c"
    }
    if {$lines != {}} {
	watch::cleanupSelection $nameText
    }
}

# watch::scrollWindow --
#
#	Scroll all of the var window's text widgets in parallel.
#
# Arguments:
#	args	Args passed from the scroll callback.
#
# Results:
#	None.

proc watch::scrollWindow {text args} {
    set nameText $watch::text(name,$text)
    set valuText $watch::text(valu,$text)
    set vbpText  $watch::text(vbp,$text)

    eval {$text yview} $args
    set yview [lindex [$text yview] 0] 
    $nameText yview moveto $yview 
    $valuText yview moveto $yview 
    $vbpText  yview moveto $yview 
 
    # Make sure all of the visible lines are formatted correctly. 
    gui::formatText $valuText right
    gui::formatText $nameText right 
}

# watch::tkTextAutoScan --
#
#	Override the default auto scan functionality so it
#	updates all related windows too.
#
# Arguments:
#	w	The name of the window being updated.
#
# Results:
#	None.

proc watch::tkTextAutoScan {text} {
    variable priv

    set nameText $watch::text(name,$text)
    set valuText $watch::text(valu,$text)
    set vbpText  $watch::text(vbp,$text)
    set update 1

    if {![winfo exists $text]} {
	return
    }
    if {$priv(y,$text) >= [winfo height $text]} {
	$valuText yview scroll 2 units
	watch::selectLineRange $valuText \
		[expr {[sel::getCursor $valuText] + 2}].0
    } elseif {$priv(y,$text) < 0} {
	$valuText yview scroll -2 units
	watch::selectLineRange $valuText \
		[expr {[sel::getCursor $valuText] - 2}].0
    } elseif {$priv(x,$text) >= [winfo width $text]} {
	set update 0
    } elseif {$priv(x,$text) < 0} {
	set update 0
    } else {
	return
    }

    if {$update} {
	set yview [lindex [$valuText yview] 0]
	$nameText yview moveto $yview
	$vbpText  yview moveto $yview
    }

    set watch::priv(afterId,$text) [after 50 watch::tkTextAutoScan $text]
}

# watch::tkCancelRepeat --
#
#	Override the default cancel event so it correctly 
#	cancels the after event.
#
# Arguments:
#	text	The text widget asking to cancel the after event.
#
# Results:
#	None

proc watch::tkCancelRepeat {text} {
    variable priv

    if {[info exists priv(afterId,$text)]} {
	after cancel $priv(afterId,$text)
	set priv(afterId,$text) {}
    }
}

# watch::showInspector --
#
#	Show the Inspector Window for the selected variable.
#
# Arguments:
#	ns	The namespace of the calling proc (watch or var).
#
# Results:
#	None.

proc watch::showInspector {text} {
    set valuText $watch::text(valu,$text)

    set line  [sel::getCursor $valuText]
    set oname [watch::varDataGet $valuText $line.0 "oname"]
    inspector::showVariable $oname [gui::getCurrentLevel]
    
    return
}

# watch::showInspectorFromIndex --
#
#	Show the Inspector Window for a variable pointed to by index.
#	This proc is used by the <Double-1> binding on the Var/Watch
#	text widgets.
#
# Arguments:
#	text	The text widget where the event occured.
#	index	The location in the text widget.
#
# Results:
#	None.

proc watch::showInspectorFromIndex {text index} {
    if {[lsearch [$text tag names $index] expander] >= 0} {
	return
    }
    if {[sel::indexPastEnd $text $index]} {
	return
    }

    # HACK:  I don't know why, but the "current" index always
    # reports tabs to be over one char too far...
    set thisLine [lindex [split [$text index $index] .] 0]
    set prevLine [lindex [split [$text index "$index - 1 chars"] .] 0]
    if {$prevLine == $thisLine} {
	set index "$index - 1 chars"
    }

    if {[lsearch [$text tag names $index] setBreak] >= 0} {
	return
    }
    watch::showInspector $text
}

# watch::toggleVBP --
#
#	Toggle a VBP between on/off enabled/disabled.
#
# Arguments:
#	text		The nameText widget where the VBP is drawn.
#	index		Where to draw the VBP.
#	toggleType	How to toggle ("onoff" or "enabledisable")
#
# Results:
#	None.

proc watch::toggleVBP {text index toggleType} {
    set valuText $watch::text(valu,$text)
    set vbpText  $watch::text(vbp,$text)

    # Dont allow user to toggle VBP state when the GUI's
    # state is not stopped.

    if {[gui::getCurrentState] != "stopped"} {
	return
    }
    
    # Don't allow user to toggle in the Var/Watch Window
    # if the var frame is hidden.

    if {[stack::isVarFrameHidden]} {
	return
    }

    set line  [lindex [split [$vbpText index $index] .] 0]
    set level [gui::getCurrentLevel]
    set oname [watch::varDataGet $valuText $line.0 "oname"]
    set state [icon::getVBPState $level $oname]

    # If the current line is not highlighted, only toggle the 
    # VBP at the current line.  Otherwise, toggle all of the
    # selected variables to the new state of the current line.

    if {![sel::isTagInLine $valuText $index highlight]} {
	if {[watch::varDataGet $valuText $line.0 "exist"] == 1} {
	    if {$toggleType == "onoff"} {
		icon::toggleVBPOnOff $vbpText $line.0 $level $oname $state
	    } else {
		icon::toggleVBPEnableDisable $vbpText $line.0 $level $oname \
			$state
	    }
	}
    } else {
	# Get the list of selected variables, and toggle each
	# to the new state of the selected line.

	set selLines [sel::getSelectedLines $valuText]
	for {set i 0} {$i < [llength $selLines]} {incr i} {
	    set line  [lindex $selLines $i]
	    set oname [watch::varDataGet $valuText $line.0 "oname"]
	    if {[watch::varDataGet $valuText $line.0 "exist"] != 1} {
		continue
	    }
	    if {$toggleType == "onoff"} {
		icon::toggleVBPOnOff $vbpText $line.0 $level $oname $state
	    } else {
		icon::toggleVBPEnableDisable $vbpText $line.0 $level $oname \
		    $state
	    }
	}
    }

    # Depending on what window was updated, tell related windows
    # to update themselves, so all windows have identical state.

    if {$valuText == $var::valuText} {
	watch::updateWindow
	watch::cleanupSelection $var::valuText
    } elseif {$valuText == $watch::valuText} {
	var::updateWindow
	watch::cleanupSelection $watch::valuText
    } else {
	watch::updateWindow
	var::updateWindow
    }
    bp::updateWindow
}

# watch::expandOrFlattenArray --
#
#	Expand or flatten the array handle if the selectCursor
#	is pointing to an array handle.
#
# Arguments:
#	text	The valuText widget where the event originated from.
#	index	The index into the text widget where the array
#		handle (i.e.  "(...)" ) is located.
#	type	Request to expand or flatten only.  Possibly null.
#
# Results:
#	None.

proc watch::expandOrFlattenArray {text index {type {}}} {
    set nameText $watch::text(name,$text)
    set valuText $watch::text(valu,$text)

    if {[watch::varDataGet $valuText "$index linestart" "type"] != "a"} {
	return
    }
    set arrayName [watch::varDataGet $valuText "$index linestart" "oname"]
    set level     [gui::getCurrentLevel]
    set expanded  [watch::isArrayExpanded $valuText $level $arrayName]

    if {($expanded) && ($type != "expand")} {
	watch::FlattenArray $valuText $index
    } elseif {(!$expanded) && ($type != "flatten")} {
	watch::ExpandArray $valuText $index
    }
    return
}

# watch::ExpandArray --
#
#	Expand the array entry to show all of the elements 
#	in the array.  Re-bind the array indicator to 
#	flatten the array if selected again.
#
# Arguments:
#	text	The valuText widget where the event originated from.
#	index	The index into the text widget where the array
#		handle (i.e.  "(...)" ) is located.
#
# Results:
#	The number of lines added.

proc watch::ExpandArray {text index} {
    set nameText $watch::text(name,$text)
    set valuText $watch::text(valu,$text)
    set vbpText  $watch::text(vbp,$text)

    if {[watch::varDataGet $valuText "$index linestart" "type"] != "a"} {
	return
    }

    # Make sure all of the lines are reinstated before deleting.

    gui::unformatText $valuText
    gui::unformatText $nameText
     
    set level [gui::getCurrentLevel]
    set line  [expr {[lindex [split [$valuText index $index] .] 0] + 1}]
    set arrayName [watch::varDataGet $valuText "$index linestart" "oname"]

    array set unsorted [watch::varDataGetValue $arrayName $level "a"]

    foreach element [lsort -dictionary [array names unsorted]] {
	# Insert the text in backwards so we do not leave
	# an extraneous newline at the end of the list.

	# Insert the VBP icon is one exists.

	set scalarName ${arrayName}($element)
	set state [icon::getVBPState $level $scalarName]
	$vbpText  insert $line.0 "\n"
	icon::drawVBP $vbpText $line.0 $state

	set melement [code::mangle $element]
	$nameText insert "$line.0 linestart" "\n"
	$nameText insert "$line.0 linestart" "  $melement" [list varEntry]

	set mvalue [code::mangle $unsorted($element)]
	$valuText insert "$line.0 linestart" "\n"
	$valuText insert "$line.0 linestart" "  $mvalue" [list varEntry]

	# Add varData to the text widget and add the array values
	# to the database as scalar entries.
	
	watch::varDataSet $valuText $line.0 \
		[list oname $scalarName type "a" exist 1 \
		arrayName $arrayName element $element]
	set watch::scalarVarData($scalarName,$level) $unsorted($element)

	incr line
    }

    # Set the expanded flag so the array will remain expanded
    # after window updates.

    watch::setArrayExpanded $valuText $level $arrayName 1

    # Make sure all of the visible lines are formatted correctly.
    gui::formatText $valuText right
    gui::formatText $nameText right

    return [llength [array names unsorted]]
}

# watch::FlattenArray --
#
#	Flatten the array entry to hide all of the elements 
#	in the array.  Re-bind the array indicator to 
#	expand the array is selected again.
#
# Arguments:
#	text	The valuText widget where the event originated from.
#	index	The index into the text widget where the array
#		handle (i.e.  "(...)" ) is located.
#
# Results:
#	The number of lines removed.

proc watch::FlattenArray {text index} {
    set nameText $watch::text(name,$text)
    set valuText $watch::text(valu,$text)
    set vbpText  $watch::text(vbp,$text)

    if {[watch::varDataGet $valuText "$index linestart" "type"] != "a"} {
	return
    }

    # Make sure all of the lines are reinstated before deleting.
    gui::unformatText $valuText
    gui::unformatText $nameText

    # For every index/entry pair there is a line displayed 
    # in the text widgets that needs to be removed.  Set
    # the start and stop indicies to point at the first lin
    # containing array info and keep deleting this line until
    # all array elements have been removed.

    set level [gui::getCurrentLevel]
    set line  [expr {[lindex [split [$valuText index $index] .] 0] + 1}]
    set arrayName [watch::varDataGet $valuText "$index linestart" "oname"]

    set len [expr {[llength [watch::varDataGetValue $arrayName $level "a"]]/2}]
    set start "$line.0"
    set end   "$line.0 + $len lines"
    $nameText delete $start $end
    $valuText delete $start $end
    $vbpText  delete $start $end

    # Remove the expanded flag so the array will not be expanded
    # on the next window update.

    watch::setArrayExpanded $valuText $level $arrayName 0

    # Make sure all of the visible lines are formatted correctly.
    gui::formatText $valuText right
    gui::formatText $nameText right

    return $len
}

# watch::changeFocus --
#
#	Change the graphical feedback when focus changes.
#
# Arguments:
#	text	The nameText or valuText window changing focus.
#	focus	The type of focus change (in or out.)
#
# Results:
#	None.

proc watch::changeFocus {text focus} {
    set nameText $watch::text(name,$text)
    set valuText $watch::text(valu,$text)

    sel::changeFocus $valuText $focus
    sel::changeFocus $nameText $focus

    if {$focus == "in"} {
	set start "[sel::getCursor $nameText].0"
	set end   "$start lineend + 1c"
	$nameText tag remove focusIn 0.0 end
	$nameText tag add focusIn $start $end
    }

}

# watch::initSelection --
#
#	Initialize the anchor and cursor for the window.
#
# Arguments:
#	text	The text widget where the event occured.
#	index 	Location where the selection is to begin.
#
# Results:
#	None.

proc watch::initSelection {text index} {
    set nameText $watch::text(name,$text)
    set valuText $watch::text(valu,$text)

    set index [$text index $index]
    set sel::selectAnchor($valuText) [lindex [split $index .] 0]
    set sel::selectAnchor($nameText) [lindex [split $index .] 0]
    set sel::selectStart($valuText)  [$valuText index "$index linestart"]
}

# watch::selectAllLines --
#
#	Select all of the lines in the Var or Watch Window.
#
# Arguments:
#	nameText	The nameText window for the Var or Watch Window.
#	valuText	The valuText window for the Var or Watch Window.
#
# Results:
#	None.

proc watch::selectAllLines {text} {
    set nameText $watch::text(name,$text)
    set valuText $watch::text(valu,$text)

    sel::selectAllLines $nameText
    sel::selectAllLines $valuText
}

# watch::selectLine --
#
#	Select a new line in the nametext and valuText Windows,
#	removing any prevuious selected lines. 
#
# Arguments:
#	text		The text widget recieving the action.
#	nameText	The nameText window for the Var or Watch Window.
#	valuText	The valuText window for the Var or Watch Window.
#	y		The y location where the event occured.
#
# Results:
#	None.

proc watch::selectLine {text index} {
    set nameText $watch::text(name,$text)
    set valuText $watch::text(valu,$text)

    if {![sel::indexPastEnd $text $index]} {
	set index [$text index $index]
	if {[sel::isTagInLine $nameText $index varEntry]} {
	    sel::selectLine $nameText $index
	    sel::selectLine $valuText $index
	}
	focus $valuText
    }
}

# watch::selectMultiLine --
#
#	Select or deselect a new line in the nametext and valuText 
#	Windows, without removing existing highlights.
#
# Arguments:
#	text		The text widget recieving the action.
#	nameText	The nameText window for the Var or Watch Window.
#	valuText	The valuText window for the Var or Watch Window.
#	y		The y location where the event occured.
#
# Results:
#	None.

proc watch::selectMultiLine {text index} {
    set nameText $watch::text(name,$text)
    set valuText $watch::text(valu,$text)

    if {[sel::isTagInLine $nameText $index varEntry]} {
	sel::selectMultiLine $nameText $index
	sel::selectMultiLine $valuText $index
    }
    focus $valuText
}

# watch::selectLineRange --
#
#	Select a range of lines.
#
# Arguments:
#	text		The text widget recieving the action.
#	nameText	The nameText window for the Var or Watch Window.
#	valuText	The valuText window for the Var or Watch Window.
#	y		The y location where the event occured.
#
# Results:
#	None.

proc watch::selectLineRange {text index} {
    set nameText $watch::text(name,$text)
    set valuText $watch::text(valu,$text)

    if {![sel::indexPastEnd $text $index]} {
	if {[sel::isTagInLine $nameText $index varEntry]} {
	    sel::selectLineRange $nameText $index
	    sel::selectLineRange $valuText $index
	}
	focus $valuText
    }
}

# watch::moveSelection --
#
#	Move the selection of the nameText and valuText 
#	windows up or down, removing any previous 
#	selection.
#
# Arguments:
#	text		The text widget recieving the action.
#	amount		The number of lines to move from the current
#			selectCursor position.
#
# Results:
#	None.

proc watch::moveSelection {text amount} {
    set nameText $watch::text(name,$text)
    set valuText $watch::text(valu,$text)

    sel::moveSelection $nameText $amount
    sel::moveSelection $valuText $amount
}

# watch::moveSelectionRange --
#
#	Move the range of the current selection.
#
# Arguments:
#	text		The text widget recieving the action.
#	amount		The number of lines to move from the current
#			selectCursor position.
#
# Results:
#	None.

proc watch::moveSelectionRange {text amount} {
    set nameText $watch::text(name,$text)
    set valuText $watch::text(valu,$text)

    sel::moveSelectionRange $nameText $amount
    sel::moveSelectionRange $valuText $amount
}

# watch::moveCursor --
#
#	Move the selectCursor without selecting new lines.
#
# Arguments:
#	text		The text widget recieving the action.
#	amount		The number of lines to move from the current
#			selectCursor position.
#
# Results:
#	None.

proc watch::moveCursor {text amount} {
    set nameText $watch::text(name,$text)
    set valuText $watch::text(valu,$text)

    sel::moveCursor $nameText $amount
    sel::moveCursor $valuText $amount
}

# watch::moveCursorToIndex --
#
#	Move the selectCursor without selecting new lines.
#
# Arguments:
#	text		The text widget recieving the action.
#	index		The new index of the current selectCursor position.
#
# Results:
#	None.

proc watch::moveCursorToIndex {text index} {
    set nameText $watch::text(name,$text)
    set valuText $watch::text(valu,$text)

    sel::moveCursorToIndex $nameText $index
    sel::moveCursorToIndex $valuText $index
}

# watch::selectCursor --
#
#	Select the line indicated by the selectCursor without
#	deleting the previous selection.
#
# Arguments:
#	text		The text widget recieving the action.
#
# Results:
#	None.

proc watch::selectCursor {text} {
    set nameText $watch::text(name,$text)
    set valuText $watch::text(valu,$text)

    sel::selectCursor $nameText
    sel::selectCursor $valuText
}

# watch::selectCursorRange --
#
#	Select all of the lines between the selectAnchor and
#	selectCursor.
#
# Arguments:
#	text		The text widget recieving the action.
#
# Results:
#	None.

proc watch::selectCursorRange {text} {
    set nameText $watch::text(name,$text)
    set valuText $watch::text(valu,$text)

    sel::selectCursorRange $nameText
    sel::selectCursorRange $valuText
}

# watch::toggleCursor --
#
#	Toggle the selection of the line indicated by the 
#	selectCursor without deleting the previous selection.
#
# Arguments:
#	text		The text widget recieving the action.
#
# Results:
#	None.

proc watch::toggleCursor {text} {
    set nameText $watch::text(name,$text)
    set valuText $watch::text(valu,$text)

    sel::toggleCursor $nameText
    sel::toggleCursor $valuText
}

# watch::copy --
#
#	Copy the highlighted text to the Clipboard.
#
# Arguments:
#	text	The text widget receiving the copy request.
#
# Results:
#	None.

proc watch::copy {text} {
    set nameText $watch::text(name,$text)
    set valuText $watch::text(valu,$text)

    # Create a list that collates the highlighted name text
    # with the highlighted value text.  Be careful to trim
    # the newline off of the name text so each name-value
    # pair appears on the same line.

    set nameCopy [sel::copy $nameText]
    set valuCopy [sel::copy $valuText]

    set result {}
    for {set i 0} {$i < [llength $nameCopy]} {incr i} {
	set name [lindex $nameCopy $i]
	set valu [lindex $valuCopy $i]
	
	set name [string range $name 0 [expr {[string length $name] - 2}]]
	lappend result "$name $valu"
    }
    if {$result != {}} {
    	clipboard clear -displayof $text
	clipboard append -displayof $text [join $result {}]
    }
}

# watch::cleanupSelection --
#
#	Remove the first char if highlighting from each selected
#	line in the nameText widget, so the VBP icon is not 
#	included in the selection.
#
# Arguments:
#	text	A text widget of the Var or Watch Window.
#
# Results:
#	None.

proc watch::cleanupSelection {text} {
    set nameText $watch::text(name,$text)
    set valuText $watch::text(valu,$text)
    set vbpText  $watch::text(vbp,$text)

    foreach line [sel::getSelectedLines $nameText] {
	if {![sel::isTagInLine $nameText $line.0 varEntry]} {
	    $nameText tag remove highlight $line.0 "$line.0 lineend + 1 chars"
	    $valuText tag remove highlight $line.0 "$line.0 lineend + 1 chars"
	}	    
    }

    set yview [lindex [$text yview] 0]
    $nameText yview moveto $yview
    $valuText yview moveto $yview
    $vbpText  yview moveto $yview
    
    # Make sure all of the visible lines are formatted correctly. 
    gui::formatText $valuText right
    gui::formatText $nameText right 
    
    return
}

# watch::seeCallback --
#
#	Callback routine from the selection API that will
#	insured all three text widgets are always lined up.
#
# Arguments:
#	text	The text widget that just recieved a "see" request.
#	index 	The index to be seen.
#
# Results:
#	None.

proc watch::seeCallback {text index} {
    set nameText $watch::text(name,$text)
    set valuText $watch::text(valu,$text)
    set vbpText  $watch::text(vbp,$text)

    $nameText see $index
    $valuText see $index
    $vbpText  see $index
    
    return
}

