# projWin.tcl --
#
#	This file implements the Project Windows for the file based 
#	projects system.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 

namespace eval projWin {
    # The focusOrder variable is an array with one entry for
    # each tabbed window.  The value is a list of widget handles,
    # which is the order for the tab focus traversial of the 
    # window. 

    variable focusOrder

    # The command to eval when the Project Settings window is 
    # applied or destroyed.

    variable applyCmd {}
    variable destroyCmd {}

    # Modal buttons for the Prefs Window.

    variable okBut
    variable canBut
    variable appBut

    # Widget handles for the Font selection window.
    # 
    # noInstText	The text widget that lists the glob patterns for
    #			files that are not to be instrumented.
    # doInstText	The text widget that lists the glob patterns for
    #			files that are to be instrumented.
    # addNoBut		Button used to add a glob pattern to noInst list.
    # addDoBut		Button used to add a glob pattern to doInst list.
    # remNoBut		Button used to remove a pattern from noInst list.
    # remDoBut		Button used to remove a pattern from doInst list.
    # globList		The internal list of glob patterns.

    variable noInstText
    variable doInstText
    variable addNoBut
    variable addDoBut
    variable remNoBut
    variable remDoBut

    # Widget handles for the Application Arguments window.
    #    
    # scriptCombo  The combobox for the script arg.
    # argCombo     The combobox for the arg arg.
    # dirCombo     The combobox for the dir arg.
    # interpCombo  The combobox for the interp arg.
 
    variable localFrm    {}
    variable scriptCombo {}
    variable argCombo    {}
    variable dirCombo    {}
    variable interpCombo {}

    variable remoteFrm   {}
    variable portEnt     {}
    variable portLbl     {}  
    variable localRad    {}
    variable remoteRad   {}
}

# projWin::showWindow --
#
#	Show the Project Prefs Window.  If the window exists then just
#	raise it to the foreground.  Otherwise, create the window.
#
# Arguments:
#	title	The title of the window.
#	aCmd	Callback to eval when the window is applied.  Can be null
#	dCmd	Callback to eval when the window is destroyed.  Can be null
#			
#
# Results:
#	None.

proc projWin::showWindow {title {aCmd {}} {dCmd {}}} {
    variable applyCmd
    variable destroyCmd

    if {[info command $gui::gui(projSettingWin)] == {}} {
	projWin::createWindow
	focus $gui::gui(projSettingWin)
    } else {
	projWin::DestroyWindow	
	projWin::createWindow
	focus $gui::gui(projSettingWin)
    }

    set applyCmd   $aCmd
    set destroyCmd $dCmd

    projWin::updateWindow $title
    return
}

# projWin::createWindow --
#
#	Create the Prefs Window and all of the sub elements.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc projWin::createWindow {} {
    variable focusOrder
    variable okBut
    variable canBut
    variable appBut

    set bd   0
    set pad  6
    set pad2 2
    
    if {[info exists focusOrder]} {
	unset focusOrder
    }

    set top [toplevel $gui::gui(projSettingWin)]
    wm minsize   $top 100 100
    wm transient $top $gui::gui(mainDbgWin)
    ::guiUtil::positionWindow $top

    pref::groupNew  TempProj
    pref::groupCopy Project TempProj

    set tabWin  [tabnotebook $top.tabWin -pady 2 -browsecmd projWin::NewFocus]
    set scptFrm [frame $tabWin.scptFrm -bd $bd -relief raised]
    set instFrm [frame $tabWin.instFrm -bd $bd -relief raised]
    set errFrm  [frame $tabWin.errFrm  -bd $bd -relief raised]

    $tabWin add "Application" 	  -window $scptFrm
    $tabWin add "Instrumentation" -window $instFrm
    $tabWin add "Errors"          -window $errFrm
    
    # Application Info
    set scriptWin [projWin::CreateScriptWindow $scptFrm]
    pack $scriptWin -fill x -anchor n -padx $pad

    # Instrumentation
    set instFileWin [projWin::CreateNoInstruFilesWindow $instFrm]
    set instOptsWin [projWin::CreateInstruOptionsWindow $instFrm]
    pack $instFileWin -fill both -expand true -anchor n -padx $pad -pady $pad2 
    pack $instOptsWin -fill x -anchor n -padx $pad

    # Errors
    set errorWin [projWin::CreateErrorWindow $errFrm]
    pack $errorWin -fill x -anchor n -padx $pad -pady $pad2 

    # Create the modal buttons.
    set butFrm [frame $top.butFrm]
    set okBut [button $butFrm.okBut -text "OK" -width 10 \
	    -default active -command {projWin::ApplyProjSettings 1}]
    set canBut [button $butFrm.canBut -text "Cancel" -width 10 \
	    -default normal -command {projWin::CancelProjSettings}]
    set appBut [button $butFrm.appBut -text "Apply" -width 10 \
	    -default normal -command {projWin::ApplyProjSettings 0}]

    bind $top <Return> "$okBut invoke"
    bind $top <Escape> "$canBut invoke"
    
    pack $appBut -side right -padx $pad -pady $pad
    pack $canBut -side right -pady $pad
    pack $okBut  -side right -padx $pad -pady $pad

    pack $butFrm -side bottom -fill x 
    pack $tabWin -side bottom -fill both -expand true -padx $pad -pady $pad

    # Add default bindings.
    projWin::SetBindings $scptFrm Application
    projWin::SetBindings $instFrm Instrumentation
    projWin::SetBindings $errFrm  Error

    $tabWin activate 1
    return
}

# projWin::updateWindow --
#
#	Update the project settings window when the state changes.
#
# Arguments:
#	title	The title of the window.  If this is an empty string, then
#		the title is not modified.
#
# Results:
#	None.

proc projWin::updateWindow {{title {}}} {
    variable portEnt
    variable portLbl     
    variable localRad
    variable remoteRad

    if {[info command $gui::gui(projSettingWin)] == {}} {
	return
    }

    if {$title != {}} {
	wm title $gui::gui(projSettingWin) $title
    }

    set state [gui::getCurrentState]
    array set color [system::getColor]

    if {[winfo exists $localRad]} {
	if {$state == "dead" || $state == "new"} {
	    $localRad configure -fg [lindex [$localRad configure -fg] 3]
	    $localRad configure -state normal
	} else {
	    $localRad configure -fg $color(darkInside)
	    $localRad configure -state disabled
	}
    }
    if {[winfo exists $remoteRad]} {
	if {$state == "dead" || $state == "new"} {
	    $remoteRad configure -fg [lindex [$remoteRad configure -fg] 3]
	    $remoteRad configure -state normal
	} else {
	    $remoteRad configure -fg $color(darkInside)
	    $remoteRad configure -state disabled
	}
    }
    if {[winfo exists $portEnt]} {
	if {$state == "dead" || $state == "new"} {
	    $portLbl configure -fg [lindex [$portLbl configure -fg] 3]
	    $portEnt configure -fg [lindex [$portLbl configure -fg] 3]
	    $portEnt configure -state normal
	} else {
	    $portLbl configure -fg $color(darkInside)
	    $portEnt configure -fg $color(darkInside)
	    $portEnt configure -state disabled
	}
    }
    return
}

# projWin::isOpen --
#
#	Determine if the Project Settings Window is currently opened.
#
# Arguments:
#	None.
#
# Results:
#	Return a boolean, 1 if the window is open.

proc projWin::isOpen {} {
    return [expr {[info command $gui::gui(projSettingWin)] != {}}]
}

# projWin::ApplyProjSettings --
#
#	Map the local data to the persistent data.
#
# Arguments:
#	destroy	  Boolean, if true then destroy the toplevel window.
#
# Results:
#	None.  The project setting vwait variable is set to 0
#	indicating the window was canceled.

proc projWin::ApplyProjSettings {destroy} {
    variable applyCmd

    # Save the implicit prefs to the registry, or UNIX resource.  This is
    # done now to prevent preferences from being lost if the debugger
    # crashes or is terminated.

    system::saveDefaultPrefs 0
    
    # Apply the project preferences.  If the applyCmd pointer is not 
    # empty, evaluate the command at the global scope. Delete the 
    # window if the destroy bit is true.

    pref::groupApply TempProj Project
    if {$applyCmd != {}} {
	uplevel #0 $applyCmd $destroy
    }
    if {$destroy} {
	projWin::CancelProjSettings
    }

    return
}

# projWin::CancelProjSettings --
#
#	Destroy the Project Settings Window, do not set any
#	preferences, and set the project setting vwait var.
#
# Arguments:
#	None.
#
# Results:
#	None.  The project setting vwait variable is set to 0
#	indicating the window was canceled.

proc projWin::CancelProjSettings {} {
    variable destroyCmd

    if {$destroyCmd != {}} {
	uplevel #0 $destroyCmd 1
    }
    projWin::DestroyWindow
    focus -force $gui::gui(mainDbgWin)
    return
}

# projWin::DestroyWindow --
#
#	Destroy the window and remove the TempProj group.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc projWin::DestroyWindow {} {
    if {[pref::groupExists TempProj]} {
	pref::groupDelete TempProj
    }
    if {[info command $gui::gui(projSettingWin)] != {}} {
	destroy $gui::gui(projSettingWin)
    }
    return
}

# projWin::SetBindings --
#
#	Set the tab order and default bindings on the 
#	active children of all sub windows.
#
# Arguments:
#	mainFrm 	The name of the containing frame.
#	name		The name to use for the bindtag.
#
# Results:
#	None.

proc projWin::SetBindings {mainFrm name} {
    variable focusOrder
    variable okBut
    variable canBut
    variable appBut

    # Add the modal buttons to the list of active widgets
    # when specifing tab order.  When the tab window is
    # raised, the projWin::NewFocus proc is called and
    # that will add the appropriate bindtags so the tab
    # order is maintained.

    foreach win $focusOrder($mainFrm) {
	bind::addBindTags $win pref${name}Tab
    }
    lappend focusOrder($mainFrm) $okBut $canBut $appBut
    bind::commonBindings pref${name}Tab $focusOrder($mainFrm)    
    
    return
}

# projWin::NewFocus --
#
#	Re-bind the modal buttons so the correct tab order 
#	is maintained.
#
# Arguments:
#	old	The name of the window loosing focus.
#	new	The name of the window gaining focus.
#
# Results:
#	None.

proc projWin::NewFocus {old new} {
    variable okBut
    variable canBut
    variable appBut

    set tag pref${old}Tag
    bind::removeBindTag $okBut  $tag
    bind::removeBindTag $canBut $tag
    bind::removeBindTag $appBut $tag

    set tag pref${new}Tag
    bind::addBindTags $okBut  $tag
    bind::addBindTags $canBut $tag
    bind::addBindTags $appBut $tag

    return
}

# projWin::AddToCombo --
#
#	Preserve the entry of the combobox so it can be reloaded
#	each new session.
#
# Arguments:
#	combo		The handle to the combo box.
#	value		The contents of the entry box.
#
# Results:
#	Return the list of elements in the combobox's drop down list.

proc projWin::AddToCombo {combo value} {
    # Store the contents of the listbox in the prefs::data array.
    # This will be used to restore the lisbox between sessions.

    set result [$combo add $value]

    # Empty strings are not stored in the ComboBox listbox.  To
    # preserve this state, append the empty string to the 
    # beginning of the data list so it can be placed in the 
    # ComboBox entry widget on the next display request.

    set size [pref::prefGet comboListSize]
    if {$value == {}} {
	set result [linsert $result 0 {}]
	incr size
    }

    # Only store the most recent <historySize> entries.

    if {[llength $result] > $size} {
	set end [expr {$size - 1}]
	set result [lrange $result 0 $end]
    }
    return $result
}

# projWin::CreateScriptWindow --
#
#	Create the interface for setting script options.
#
# Arguments:
#	mainFrm		The containing frame.
#
# Results:
#	A handle to the frame containing the Error interface.

proc projWin::CreateScriptWindow {mainFrm} {
    variable localFrm    
    variable localRad
    variable remoteRad
    variable scriptCombo 
    variable argCombo    
    variable dirCombo    
    variable interpCombo 
    variable remoteFrm   
    variable portEnt     
    variable portLbl     
    variable focusOrder

    set pad  6
    set pad2 10

    # Toggle frame that switches between the local and remote 
    # preference windows.

    set cntrFrm [frame $mainFrm.cntrFrm]
    set appFrm  [prefWin::createSubFrm $cntrFrm appFrm "Debugging Type"]
    set localRad [radiobutton $appFrm.localRad \
	    -text "Local Debugging" \
	    -command [list projWin::ShowDebuggingType $mainFrm local] \
	    -variable [pref::prefVar appType TempProj] \
	    -value local]
    set remoteRad [radiobutton $appFrm.remoteRad \
	    -text "Remote Debugging" \
	    -command [list projWin::ShowDebuggingType $mainFrm remote] \
	    -variable [pref::prefVar appType TempProj] \
	    -value remote]
    
    # Local Debugging Window -
    # Create the interface for entering basic info about the
    # script to be debugged; script name, arguments, working
    # directory and interpreter.

    set localFrm [prefWin::createSubFrm $cntrFrm localFrm "Local Debugging"]
    set scriptLbl [label $localFrm.scriptLbl -text "Script:" \
	    -width 40 -anchor w]
    set scriptCombo [guiUtil::ComboBox $localFrm.scriptCombo \
	    -textvariable [pref::prefVar appScript TempProj] \
	    -listheight 1]
    set scriptBut [button $localFrm.scriptBut -text "Browse" \
	    -command [list proj::openComboFileWindow $scriptCombo \
	    [list {{Tcl Scripts} {.tcl .tk}} {{Test Scripts} .test} \
	    {{All files} *}]]]
    
    set argLbl [label $localFrm.argLbl -text "Script Arguments:"]
    set argCombo [guiUtil::ComboBox $localFrm.argCombo \
	    -textvariable [pref::prefVar appArg TempProj] \
	    -listheight 1]
    
    set dirLbl [label $localFrm.dirLbl -text "Working Directory:"]
    set dirCombo [guiUtil::ComboBox $localFrm.dirCombo \
	    -textvariable [pref::prefVar appDir TempProj] \
	    -listheight 1]
    
    set interpLbl [label $localFrm.interpLbl -text "Interpreter:"]
    set interpCombo [guiUtil::ComboBox $localFrm.interpCombo \
	    -textvariable [pref::prefVar appInterp TempProj] \
	    -listheight 1]
    set interpBut [button $localFrm.interpBut -text "Browse" \
	    -command [list proj::openComboFileWindow $interpCombo \
	    [system::getExeFiles]]]

    # Load the combo boxes with the Project's history.

    set s [pref::prefGet appScriptList TempProj]
    set a [pref::prefGet appArgList    TempProj]
    set d [pref::prefGet appDirList    TempProj]
    set i [pref::prefGet appInterpList TempProj]

    # If the interp list is empty, or just contains white space, fill it with
    # the default values.  This code was added to make up for prior 
    # releases that left the interp list empty on Windows.

    if {[llength $i] < 2} {
	if {[string length [string trim [lindex $i 0]]] == 0} {
	    set i {}
	}
	foreach interp [system::getInterps] {
	    lappend i $interp
	}
	pref::prefSet Project appInterpList $i
	pref::prefSet TempProj appInterpList $i

	# Give the interp the value of the 1st elt of the interp list.  This
	# causes users never to have to add the interp themselves.

	set firstInterp [lindex $i 0]
	pref::prefSet Project appInterp $firstInterp
	pref::prefSet TempProj appInterp $firstInterp	
    }

    eval {$scriptCombo add} $s
    eval {$argCombo    add} $a
    eval {$dirCombo    add} $d
    eval {$interpCombo add} $i

    $scriptCombo set [lindex $s 0]
    $argCombo    set [lindex $a 0]
    $dirCombo    set [lindex $d 0]
    $interpCombo set [lindex $i 0]

    # Remote Debugging Window -
    # Create the window for setting preferences on remote applications.
    # Simply ask for the port they want to connect on.

    set remoteFrm [prefWin::createSubFrm $cntrFrm remoteFrm "Port"]
    set portLbl [label $remoteFrm.screenLbl \
	    -text "Listen for remote connection on port number:"]
    set portEnt [entry $remoteFrm.screenEnt -justify right -width 6 \
	    -textvariable [pref::prefVar portRemote TempProj]]

    grid $localRad  -row 0 -column 0 -sticky w -padx $pad
    grid $remoteRad -row 0 -column 1 -sticky w -padx $pad
    grid columnconfigure $appFrm 1 -weight 1 -minsize 20
    grid columnconfigure $appFrm 2 -weight 1 -minsize 20

    grid $scriptLbl   -sticky nw -padx $pad
    grid $scriptCombo $scriptBut -padx $pad -sticky ne
    grid $argLbl      -sticky nw -padx $pad -columnspan 2
    grid $argCombo    -sticky nwe -padx $pad
    grid [frame $localFrm.frmSep1 -height 5]

    grid $dirLbl      -sticky nw -padx $pad -columnspan 2
    grid $dirCombo    -padx $pad -sticky nwe
    grid [frame $localFrm.frmSep2 -height 5]

    grid $interpLbl   -sticky nw -padx $pad -columnspan 2
    grid $interpCombo $interpBut -padx $pad -sticky ne
    grid [frame $localFrm.frmSep3 -height $pad] -sticky we

    grid configure $scriptCombo -sticky nwe
    grid configure $interpCombo -sticky nwe
    grid columnconfigure $localFrm 0 -weight 1

    grid $portLbl -row 0 -column 0 -sticky w -padx $pad -pady $pad
    grid $portEnt -row 0 -column 1 -sticky w -pady $pad
    grid columnconfigure $remoteFrm 3 -weight 1

    pack $appFrm -fill x -expand true -padx $pad -pady $pad2
    pack $localFrm -fill both -expand true -padx $pad -pady $pad2
    pack $remoteFrm -fill both -expand true -padx $pad -pady $pad2
    pack $cntrFrm.appFrm -fill x -expand true

    lappend focusOrder($mainFrm) $localRad $remoteRad
    if {[proj::isRemoteProj]} {
	pack $cntrFrm.remoteFrm -fill both -expand true

	lappend focusOrder($mainFrm) $portEnt
    } else {
	pack $cntrFrm.localFrm -fill both -expand true
	
	lappend focusOrder($mainFrm) $scriptCombo $argCombo \
		$dirCombo $interpCombo
    }

    # Set the namespace variables to the outter frames.

    set localFrm  $cntrFrm.localFrm
    set remoteFrm $cntrFrm.remoteFrm

    return $cntrFrm
}

# projWin::ShowDebuggingType --
#
#	Used by the Application window, toggle between the Remote
#	interface and the loacl interface.
#
# Arguments:
#	type	Indicates which type is being toggled to. (local or remote)
#
# Results:
#	None.

proc projWin::ShowDebuggingType {mainFrm type} {
    variable localFrm    
    variable scriptCombo 
    variable argCombo    
    variable dirCombo    
    variable interpCombo 
    variable remoteFrm   
    variable portEnt     
    variable focusOrder

    wm geometry $gui::gui(projSettingWin) \
	    [winfo geometry $gui::gui(projSettingWin)]

    if {$type == "local"} {
	pack forget $remoteFrm
	pack $localFrm -fill both -expand true

	set focusOrder($mainFrm) [lreplace $focusOrder($mainFrm) 2 2 \
		$scriptCombo $argCombo $dirCombo $interpCombo]
	bind::commonBindings prefApplicationTab $focusOrder($mainFrm)    
    } else {
	pack forget $localFrm
	pack $remoteFrm -fill both -expand true

	set focusOrder($mainFrm) [lreplace $focusOrder($mainFrm) 2 5 \
		$portEnt]
	bind::commonBindings prefApplicationTab $focusOrder($mainFrm)
    }

    projWin::updateWindow
    return
}

# projWin::CreateErrorWindow --
#
#	Create the interface for setting Error options.
#
# Arguments:
#	mainFrm		The containing frame.
#
# Results:
#	A handle to the frame containing the Error interface.

proc projWin::CreateErrorWindow {mainFrm} {
    variable focusOrder

    set pad  6
    set pad2 10

    set subFrm [prefWin::createSubFrm $mainFrm errorFrm "Errors"]
    set errRad1 [radiobutton $subFrm.errRad1 \
	    -text "Always stop on errors." \
	    -variable [pref::prefVar errorAction TempProj] \
	    -value 2]
    set errRad2 [radiobutton $subFrm.errRad2 \
	    -text "Only stop on uncaught errors." \
	    -variable [pref::prefVar errorAction TempProj] \
	    -value 1]
    set errRad3 [radiobutton $subFrm.errRad3 \
	    -text "Never stop on errors." \
	    -variable [pref::prefVar errorAction TempProj] \
	    -value 0]
    
    grid $errRad1 -row 0 -column 0 -sticky w -padx $pad
    grid $errRad2   -row 1 -column 0 -sticky w -padx $pad
    grid $errRad3   -row 2 -column 0 -sticky w -padx $pad
    grid columnconfigure $subFrm 0 -weight 1

    pack $subFrm -fill both -expand true -padx $pad -pady $pad2

    lappend focusOrder($mainFrm) $errRad1 $errRad2 $errRad3
    return $mainFrm.errorFrm
}

# projWin::CreateInstruWindow --
#
#	Create the interface for specifying which files
#	not to instrument.
#
# Arguments:
#	mainFrm		The containing frame.
#
# Results:
#	A handle to the frame containing the Instrumentation interface.

proc projWin::CreateNoInstruFilesWindow {mainFrm} {
    variable focusOrder
    variable noInstText
    variable doInstText
    variable addNoBut
    variable addDoBut
    variable remNoBut
    variable remDoBut

    set pad  6
    set pad2 10

    set subFrm [prefWin::createSubFrm $mainFrm instFrm \
	    "Choose which files to instrument"]

    set entFrm [frame $subFrm.entFrm]
    set instLbl  [label $entFrm.instLbl -text "String Match Pattern:"]
    set instEnt  [entry $entFrm.instEnt]

    set instDoLbl  [label $subFrm.instDoLbl \
	    -text "Instrument all files with paths matching these patterns:"]
    set instNoLbl  [label $subFrm.instNoLbl \
	    -text "Except for files with paths matching these patterns:"]
    set noInstText [text $subFrm.noInstText -height 3 -width 3 \
	    -yscroll [list $subFrm.noScroll set]]
    set doInstText [text $subFrm.doInstText -height 3 -width 3 \
	    -yscroll [list $subFrm.doScroll set]]
    set sbNoInst [scrollbar $subFrm.noScroll \
	    -command [list $noInstText yview]]
    set sbDoInst [scrollbar $subFrm.doScroll \
	    -command [list $doInstText yview]]

    set noButFrm [frame $subFrm.noButFrm]
    set addNoBut [button $noButFrm.addNoBut -text "Add" \
	    -command [list projWin::AddInstruGlobFromEntry $instEnt 0]]
    set remNoBut [button $noButFrm.delNoBut -text "Remove" \
	    -command {projWin::RemoveSelectedInstru 0} -state disabled]

    set doButFrm [frame $subFrm.doButFrm]
    set addDoBut [button $doButFrm.addDoBut -text "Add" \
	    -command [list projWin::AddInstruGlobFromEntry $instEnt 1]]
    set remDoBut [button $doButFrm.delDoBut -text "Remove" \
	    -command {projWin::RemoveSelectedInstru 1} -state disabled]

    pack $addDoBut -fill both
    pack $remDoBut -fill both
    pack $addNoBut -fill both
    pack $remNoBut -fill both

    pack $instLbl -side left -anchor nw
    pack $instEnt -side left -anchor ne -fill x -expand true
    grid $entFrm -row 0 -column 0 -columnspan 3 -sticky new -padx $pad -pady $pad

    grid $instDoLbl  -row 1 -column 0 -columnspan 3 -sticky nsw -padx $pad 
    grid $doInstText -row 2 -column 0 -sticky nswe
    grid $sbDoInst   -row 2 -column 1 -sticky nsw
    grid $doButFrm   -row 2 -column 2 -sticky new -padx $pad
    
    grid $instNoLbl  -row 3 -column 0 -columnspan 3 -sticky nsw -padx $pad 
    grid $noInstText -row 4 -column 0 -sticky nswe
    grid $sbNoInst   -row 4 -column 1 -sticky nsw
    grid $noButFrm   -row 4 -column 2 -sticky new -padx $pad

    grid columnconfigure $subFrm 0 -weight 1 -minsize $pad
    grid rowconfigure $subFrm [list 2 4] -weight 1 -minsize $pad
    pack $subFrm -fill both -expand true -padx $pad -pady $pad 

    set font [$noInstText cget -font]
    bind::removeBindTag $noInstText Text
    bind::removeBindTag $doInstText Text
    $noInstText configure -cursor [system::getArrow] -insertwidth 0 -wrap none
    $doInstText configure -cursor [system::getArrow] -insertwidth 0 -wrap none
    $noInstText tag configure highlight -background [pref::prefGet highlight]
    $doInstText tag configure highlight -background [pref::prefGet highlight]
    $noInstText tag configure focusIn -relief groove -borderwidth 2
    $doInstText tag configure focusIn -relief groove -borderwidth 2

    bind::addBindTags $noInstText [list prefNoInstText scrollText selectFocus \
	    selectLine selectRange selectCopy moveCursor]
    bind::addBindTags $doInstText [list prefDoInstText scrollText selectFocus \
	    selectLine selectRange selectCopy moveCursor]
    sel::setWidgetCmd $noInstText all {
	projWin::CheckInstruFilesState 
    }
    sel::setWidgetCmd $doInstText all {
	projWin::CheckInstruFilesState 
    }
    bind prefNoInstText <1> {
	focus %W
    }
    bind prefDoInstText <1> {
	focus %W
    }
    bind $noInstText <<Dbg_RemSel>> {
	projWin::RemoveSelectedNoInstru 0
	break
    }
    bind $doInstText <<Dbg_RemSel>> {
	projWin::RemoveSelectedDoInstru 1
	break
    }
    bind $instEnt <Return> {break}
    bind $instEnt <<Paste>> {
	global tcl_platform
	catch {
	    if {[string compare $tcl_platform(platform) "unix"]} {
		catch {
		    %W delete sel.first sel.last
		}
	    }
	    set line [selection get -displayof %W -selection CLIPBOARD]
	    set trim [string range $line 0 [expr {[string length $line] - 2}]]
	    %W insert insert $trim
	    ::tk::EntrySeeInsert %W
	}
	break
    }

    # Insert the glob lists and update the remove buttons.

    projWin::UpdateNoInstruFilesWindow
    projWin::UpdateDoInstruFilesWindow
    projWin::CheckInstruFilesState

    lappend focusOrder($mainFrm) $instEnt $doInstText $noInstText \
	    $addNoBut $addDoBut $remNoBut $remDoBut
    return $mainFrm.instFrm
}

# proc::CreateInstruOptionsWindow --
#
#	Create the interface for setting Instrumentation options.
#
# Arguments:
#	mainFrm		The containing frame.
#
# Results:
#	A handle to the frame containing the Instrumentation interface.

proc projWin::CreateInstruOptionsWindow {mainFrm} {
    variable focusOrder

    set pad  6
    set pad2 10

    set subFrm [prefWin::createSubFrm $mainFrm optFrm "Options"]
    set dynChk [checkbutton $subFrm.dynChk -pady 0 \
	    -text "Instrument dynamic procs." \
	    -variable [pref::prefVar instrumentDynamic TempProj]]
    set autoChk [checkbutton $subFrm.autoChk -pady 0 \
	    -text "Instrument auto loaded scripts." \
	    -variable [pref::prefVar autoLoad TempProj]]
    set incrChk [checkbutton $subFrm.incrChk -pady 0 \
	    -text "Instrument Incr Tcl." \
	    -variable [pref::prefVar instrumentIncrTcl TempProj]]
    set tclxChk [checkbutton $subFrm.tclxChk -pady 0 \
	    -text "Instrument TclX." \
	    -variable [pref::prefVar instrumentTclx]]
    set expectChk [checkbutton $subFrm.expectChk -pady 0 \
	    -text "Instrument Expect." \
	    -variable [pref::prefVar instrumentExpect]]

    grid $dynChk  -row 0 -column 0 -sticky w -padx $pad
    grid $autoChk -row 1 -column 0 -sticky w -padx $pad
    grid $incrChk  -row 0 -column 1 -sticky w -padx $pad
    grid $tclxChk  -row 1 -column 1 -sticky w -padx $pad
    grid $expectChk  -row 2 -column 1 -sticky w -padx $pad
    grid columnconfigure $subFrm 1 -minsize 20
    grid columnconfigure $subFrm 3 -weight 1

    pack $subFrm -fill x -padx $pad -pady $pad

    lappend focusOrder($mainFrm) $dynChk $autoChk $incrChk $tclxChk $expectChk
    return $mainFrm.optFrm
}

# projWin::UpdateNoInstruFilesWindow --
#
#	Update the glob list by displaying the contents
#	of dontInstrument flag in noInstText.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc projWin::UpdateNoInstruFilesWindow {} {
    variable noInstText

    $noInstText delete 0.0 end

    foreach globPat [pref::prefGet dontInstrument TempProj] {
	$noInstText insert end "$globPat\n" globPat
    }
    return
}

# projWin::UpdateDoInstruFilesWindow --
#
#	Update the glob list by displaying the contents
#	of doInstrument flag in doInstText.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc projWin::UpdateDoInstruFilesWindow {} {
    variable doInstText

    $doInstText delete 0.0 end

    foreach globPat [pref::prefGet doInstrument TempProj] {
	$doInstText insert end "$globPat\n" globPat
    }
    return
}

# projWin::AddInstruGlob --
#
#	Add a new glob pattern to the list of uninstrumented 
#	files as long as the glob pattern is not a duplicate
#	or an empty string.
#
# Arguments:
#	globPat   The new variable to add to the Watch window.
#	doInst	  true if adding to doInstText list, else adding to
#		  noInstText list.
#
# Results:
#	None.

proc projWin::AddInstruGlob {globPat doInst} {
    
    if {$doInst} {
	set instPref doInstrument
	set updateCmd projWin::UpdateDoInstruFilesWindow
    } else {
	set instPref dontInstrument
	set updateCmd projWin::UpdateNoInstruFilesWindow
    }

    set globList [pref::prefGet $instPref TempProj]
    if {($globPat != {}) && ([lsearch -exact $globList $globPat] < 0)} {
	lappend globList $globPat
	pref::prefSet TempProj $instPref $globList
    }
    $updateCmd
    projWin::CheckInstruFilesState 
}

# projWin::AddInstruGlobFromEntry --
#
#	Add a glob pattern to the Inst. text by extracting the
#	pattern name from an entry widget.
#
# Arguments:
#	ent	The entry widget to get the pattern from.
#	doInst	true if adding to doInstText list, else adding to
#		noInstText list.
#
# Results:
#	None.

proc projWin::AddInstruGlobFromEntry {ent doInst} {
    set globPat [$ent get]
    $ent delete 0 end
    projWin::AddInstruGlob $globPat $doInst
}

# projWin::nonEmptyInstruText --
#
#	If the doInstrument list is empty, then add the "*" pattern to it.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc projWin::nonEmptyInstruText {} {
    if {[llength [pref::prefGet doInstrument TempProj]] == 0} {
	pref::prefSet Project doInstrument {*}
	projWin::AddInstruGlob {*} 1
    }
}

# projWin::RemoveSelectedInstru --
#
#	Remove all of the highlighted glob patterns.
#
# Arguments:
#	doInst	true if removing a pattern from doInstText list, else
#		removing from noInstText list.
#
# Results:
#	None.

proc projWin::RemoveSelectedInstru {doInst} {
    variable noInstText
    variable doInstText
    
    if {$doInst} {
	set selectedLines [sel::getSelectedLines $doInstText]
	set selectCursor  [sel::getCursor $doInstText]
	set instPref doInstrument
	set updateCmd projWin::UpdateDoInstruFilesWindow
    } else {
	set selectedLines [sel::getSelectedLines $noInstText]
	set selectCursor  [sel::getCursor $noInstText]
	set instPref dontInstrument
	set updateCmd projWin::UpdateNoInstruFilesWindow
    }

    # Create a new globList containing only the unselected 
    # glob patterns.  Then call updateWindow to display the
    # updated globList.

    if {$selectedLines != {}} {
	set globList [pref::prefGet $instPref TempProj]
	set newGlobList {}
	for {set i 0; set j 0} {$i < [llength $globList]} {incr i} {
	    if {($i + 1) == [lindex $selectedLines $j]} {
		# This is a selected glob, do not add to TempProjList.
		incr j
	    } else {
		# This is an unselected glob, add this to our new globList.
		lappend newGlobList [lindex $globList $i]
	    }
	}
	pref::prefSet TempProj $instPref $newGlobList
	$updateCmd
	if {$doInst} {
	    sel::selectLine $doInstText "$selectCursor.0"
	} else {
	    sel::selectLine $noInstText "$selectCursor.0"
	}
    }
    projWin::CheckInstruFilesState
}

# projWin::CheckInstruFilesState --
#
#	If one or more glob patterns is selected then 
#	enable the "Remove" button.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc projWin::CheckInstruFilesState {} {
    variable noInstText
    variable doInstText
    variable remNoBut
    variable remDoBut

    set state disabled
    set lines [sel::getSelectedLines $noInstText]
    foreach line $lines {
	if {[sel::isTagInLine $noInstText $line.0 globPat]} {
	    set state normal
	    break
	}
    }
    $projWin::remNoBut configure -state $state

    set state disabled
    set lines [sel::getSelectedLines $doInstText]
    foreach line $lines {
	if {[sel::isTagInLine $doInstText $line.0 globPat]} {
	    set state normal
	    break
	}
    }
    $projWin::remDoBut configure -state $state

    if {[focus] == $noInstText} {
	sel::changeFocus $noInstText in
    }
    if {[focus] == $doInstText} {
	sel::changeFocus $doInstText in
    }
}

# projWin::updateScriptList --
#
#	Update command for the project script preference.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc projWin::updateScriptList {} {
    variable scriptCombo

    if {[pref::groupExists TempProj] && \
	    [pref::prefGet appType TempProj] == "local"} {
	# Add the current combo entry to the combo's drop down 
	# list.  The result of the command is the ordered list
	# of elements in the combo's drop down list.
	
	set script [pref::prefGet appScript TempProj]
	set sList  [projWin::AddToCombo $scriptCombo $script]
	
	if {$sList != [pref::prefGet appScriptList Project]} {
	    pref::prefSet Project  appScriptList $sList
	    pref::prefSet TempProj appScriptList $sList
	}
    }
    return
}

# proj::updateInterpList --
#
#	Update command for the project script preference.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc projWin::updateInterpList {} {
    variable interpCombo

    if {[pref::groupExists TempProj] && \
	    [pref::prefGet appType TempProj] == "local"} {
	# Add the current combo entry to the combo's drop down 
	# list.  The result of the command is the ordered list
	# of elements in the combo's drop down list.
	
	set interp [pref::prefGet appInterp TempProj]
	set iList  [projWin::AddToCombo $interpCombo $interp]

	if {$iList != [pref::prefGet appInterpList Project]} {
	    pref::prefSet Project  appInterpList $iList
	    pref::prefSet TempProj appInterpList $iList
	}
    }
    return
}

# projWin::updateArgList --
#
#	Update command for the project script preference.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc projWin::updateArgList {} {
    variable argCombo

    if {[pref::groupExists TempProj] && \
	    [pref::prefGet appType TempProj] == "local"} {
	# Add the current combo entry to the combo's drop down 
	# list.  The result of the command is the ordered list
	# of elements in the combo's drop down list.
	
	set arg   [pref::prefGet appArg TempProj]
	set aList [projWin::AddToCombo $argCombo $arg]

	if {$aList != [pref::prefGet appArgList Project]} {
	    pref::prefSet Project  appArgList $aList
	    pref::prefSet TempProj appArgList $aList
	}
    }
    return
}

# projWin::updateDirList --
#
#	Update command for the project script preference.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc projWin::updateDirList {} {
    variable dirCombo

    if {[pref::groupExists TempProj] && \
	    [pref::prefGet appType TempProj] == "local"} {
	# Add the current combo entry to the combo's drop down 
	# list.  The result of the command is the ordered list
	# of elements in the combo's drop down list.
	
	set dir   [pref::prefGet appDir TempProj]
	set dList [projWin::AddToCombo $dirCombo $dir]

	if {$dList != [pref::prefGet appDirList Project]} {
	    pref::prefSet Project  appDirList $dList
	    pref::prefSet TempProj appDirList $dList
	}
    }
    return
}

# projWin::updateIncrTcl --
#
#	Update command for the project script preference.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc projWin::updateIncrTcl {} {
    instrument::extension incrTcl [pref::prefGet instrumentIncrTcl]
    return
}

# projWin::updateExpect --
#
#	Update command for the project script preference.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc projWin::updateExpect {} {
    instrument::extension expect [pref::prefGet instrumentExpect]
    return
}

# projWin::updateTclX --
#
#	Update command for the project script preference.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc projWin::updateTclX {} {
    instrument::extension tclx [pref::prefGet instrumentTclx]
    return
}

# projWin::updatePort --
#
#	Update command for the project script preference.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc projWin::updatePort {} {
    return
}

