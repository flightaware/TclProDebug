# prefWin.tcl --
#
#	This file implements the Preferences Window that manages
#	Tcl Pro Debugger preferences.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 

namespace eval prefWin {
    # The focusOrder variable is an array with one entry for
    # each tabbed window.  The value is a list of widget handles,
    # which is the order for the tab focus traversial of the 
    # window. 

    variable focusOrder

    # Modal buttons for the Prefs Window.

    variable okBut
    variable canBut
    variable appBut

    # Widget handles and data for the Font selection window.
    # 
    # typeBox	 The combobox that lists available fixed fonts.
    # sizeBox	 The combobox that lists sizes for available fixed fonts.
    # fontSizes	 The default font sizes to choose from.

    variable typeBox
    variable sizeBox
    variable fontSizes [list 8 9 10 12 14 16 18 20 22 24 26 28]

    # Widget handles for the Color selection window.
    #
    # highBut	The button whose foreground color is the same color
    #		used for highlighting in the debugger.
    # errorBut	The button whose foreground color is the same color
    #		used for highlighting errors in the debugger.

    variable highBut
    variable errorBut

}

# prefWin::showWindow --
#
#	Show the Prefs Window.  If the window exists then just
#	raise it to the foreground.  Otherwise, create the window.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc prefWin::showWindow {} {
    # If the window already exists, show it, otherwise
    # create it from scratch.

    if {[info command $gui::gui(prefDbgWin)] == $gui::gui(prefDbgWin)} {
	wm deiconify $gui::gui(prefDbgWin)
	focus $gui::gui(prefDbgWin)
	return $gui::gui(prefDbgWin)
    } else {
	prefWin::createWindow
	focus $gui::gui(prefDbgWin)
	return $gui::gui(prefDbgWin)
    }    
}

# prefWin::createWindow --
#
#	Create the Prefs Window and all of the sub elements.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc prefWin::createWindow {} {
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

    set top [toplevel $gui::gui(prefDbgWin)]
    wm minsize  $top 100 100
    wm title $top "Preferences"
    wm transient $top $gui::gui(mainDbgWin)
    ::guiUtil::positionWindow $top

    pref::groupNew  TempPref
    pref::groupCopy GlobalDefault TempPref

    set tabWin  [tabnotebook $top.tabWin -pady 2 \
	    -browsecmd prefWin::NewFocus]
    set appFrm  [frame $tabWin.appFrm  -bd $bd -relief raised]
    set winFrm  [frame $tabWin.winFrm  -bd $bd -relief raised]
    set instFrm [frame $tabWin.instFrm -bd $bd -relief raised]
    set errFrm  [frame $tabWin.errFrm  -bd $bd -relief raised]
    set otherFrm [frame $tabWin.otherFrm -bd $bd -relief raised]
    set portFrm [frame $tabWin.portFrm -bd $bd -relief raised]

    $tabWin add "Appearance"      -window $appFrm
    $tabWin add "Windows" 	  -window $winFrm
    $tabWin add "Startup & Exit"  -window $errFrm
    $tabWin add "Other"		  -window $otherFrm
    
    # Appearance
    set fontWin  [prefWin::createFontWindow  $appFrm]
    set colorWin [prefWin::createColorWindow $appFrm]
    pack $fontWin  -fill x -anchor n -padx $pad -pady $pad2 
    pack $colorWin -fill x -anchor n -padx $pad    

    # Window
    set evalWin  [prefWin::createEvalWindow $winFrm]
    set codeWin  [prefWin::createCodeWindow $winFrm]
    pack $evalWin -fill x -anchor n -padx $pad -pady $pad2 
    pack $codeWin -fill x -anchor n -padx $pad

    # Startup & Exit
    set startWin [prefWin::createStartWindow  $errFrm]
    pack $startWin  -fill x -anchor n -padx $pad
    set exitWin  [prefWin::createExitWindow  $errFrm]
    pack $exitWin  -fill x -anchor n -padx $pad

    # Other
    set browserWin  [prefWin::createBrowserWindow $otherFrm]
    pack $browserWin  -fill x -anchor n -padx $pad
    set warnWin  [prefWin::createWarnWindow $otherFrm]
    pack $warnWin  -fill x -anchor n -padx $pad

    # Create the modal buttons.
    set butFrm [frame $top.butFrm]
    set okBut [button $butFrm.okBut -text "OK" -width 10 \
	    -default active -command {prefWin::Apply 1}]
    set canBut [button $butFrm.canBut -text "Cancel" -width 10 \
	    -default normal -command [list destroy $top]]
    set appBut [button $butFrm.appBut -text "Apply" -width 10 \
	    -default normal -command {prefWin::Apply 0}]

    bind $top <Return> "$okBut invoke; break"
    bind $top <Escape> "$canBut invoke; break"

    pack $appBut -side right -padx $pad -pady $pad
    pack $canBut -side right -pady $pad
    pack $okBut  -side right -padx $pad -pady $pad

    pack $butFrm -side bottom -fill x 
    pack $tabWin -side bottom -fill both -expand true -padx $pad -pady $pad

    # Add default bindings.
    prefWin::SetBindings $appFrm  Appearance  
    prefWin::SetBindings $winFrm  Windows  
    prefWin::SetBindings $errFrm  Startup
    prefWin::SetBindings $otherFrm Other  

    $tabWin activate 1
}

# prefWin::SetBindings --
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

proc prefWin::SetBindings {mainFrm name} {
    variable focusOrder
    variable okBut
    variable canBut
    variable appBut

    # Add the modal buttons to the list of active widgets
    # when specifing tab order.  When the tab window is
    # raised, the prefWin::NewFocus proc is called and
    # that will add the appropriate bindtags so the tab
    # order is maintained.

    foreach win $focusOrder($mainFrm) {
	bind::addBindTags $win pref${name}Tab
    }
    lappend focusOrder($mainFrm) $okBut $canBut $appBut
    bind::commonBindings pref${name}Tab $focusOrder($mainFrm)
}

# prefWin::NewFocus --
#
#	Re-bind the modal buttons so the correct tab order 
#	is maintained.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc prefWin::NewFocus {old new} {
    variable okBut
    variable canBut
    variable appBut
 
    # The implementation of the tab window gives us the name of the 
    # tab window displayed.  The name is used for tag bindings.  Having
    # complex list is complicated, so use the first simple index of the
    # tab window name.

    set old [lindex $old 0]
    set new [lindex $new 0]

    set tag pref${old}Tab
    bind::removeBindTag $okBut  $tag
    bind::removeBindTag $canBut $tag
    bind::removeBindTag $appBut $tag

    set tag pref${new}Tab
    bind::addBindTags $okBut  $tag
    bind::addBindTags $canBut $tag
    bind::addBindTags $appBut $tag

    return
}

# prefWin::Apply --
#
#	Map the local data to the persistent data.
#
# Arguments:
#	destroy	  Boolean, if true then destroy the 
#		  toplevel window.
#
# Results:
#	None.

proc prefWin::Apply {destroy} {
    pref::groupApply TempPref GlobalDefault

    # Save the implicit prefs to the registry, or UNIX resource.  This is
    # done now to prevent preferences from being lost if the debugger
    # crashes or is terminated.

    system::saveDefaultPrefs 0

    if {$destroy} {
	destroy $gui::gui(prefDbgWin)
    }
    return
}

# prefWin::createSubFrm --
#
#	Create a new sub-frame.  Any preference that needs
#	an outline and title should call this routine, so
#	all sub-frames look the same.
#
# Arguments:
#	mainFrm		The containing frame.
#	winName		The name of the new sub-frame.
#	title		The title to place in the frame.
#
# Results:
#	A nested frame in the win-frame to place the widgets.

proc prefWin::createSubFrm {mainFrm winName title} {
    set winFrm   [frame $mainFrm.$winName]
    set titleLbl [label $winFrm.titleLbl -text $title]
    set titleFrm [frame $winFrm.titleFrm -bd 2 -relief groove]
    set subFrm   [frame $titleFrm.subFrm]

    array set fontMetric [font metrics [$titleLbl cget -font]]
    set pad [expr {($fontMetric(-linespace) / 2) + 2}]

    pack  $titleFrm -fill both -expand true -pady $pad
    place $titleLbl -anchor nw -x $pad -y 0
    raise $titleLbl

    return $subFrm
}

# prefWin::createFontWindow --
#
#	Create the interface for setting fonts.
#
# Arguments:
#	mainFrm		The containing frame.
#
# Results:
#	A handle to the frame containing the Font interface.

proc prefWin::createFontWindow {mainFrm} {
    variable focusOrder
    variable typeBox
    variable sizeBox
    variable fontSizes

    set pad  6
    set pad2 10

    set subFrm [prefWin::createSubFrm $mainFrm fontFrm Font]
    set typeLbl [label $subFrm.typeLbl -text Type]
    set typeBox [guiUtil::ComboBox $subFrm.typeBox -ewidth 1 -listheight 1 \
		     -textvariable [pref::prefVar fontType TempPref]]
    set sizeLbl [label $subFrm.sizeLbl -text Size]
    set sizeBox [guiUtil::ComboBox $subFrm.sizeBox -ewidth 6 \
		     -listwidth 6 -listheight 1 \
		     -textvariable [pref::prefVar fontSize TempPref]]

    grid $typeLbl -row 0 -column 0 -sticky w  -padx $pad -pady $pad
    grid $typeBox -row 0 -column 1 -sticky we -pady $pad
    grid $sizeLbl -row 0 -column 3 -sticky w  -padx $pad -pady $pad
    grid $sizeBox -row 0 -column 4 -sticky we -pady $pad
    grid columnconfigure $subFrm 1 -weight 1
    grid columnconfigure $subFrm 2 -minsize 20
    grid columnconfigure $subFrm 5 -weight 1

    pack $subFrm -fill both -expand true -padx $pad -pady $pad

    eval {$typeBox add} [font::getFonts]
    $typeBox set [font::get -family]
    eval {$sizeBox add} $fontSizes
    $sizeBox set [font::get -size]

    lappend focusOrder($mainFrm) $typeBox.e $sizeBox.e
    return $mainFrm.fontFrm
}

# prefWin::createColorWindow --
#
#	Create the interface for setting colors.
#
# Arguments:
#	mainFrm		The containing frame.
#
# Results:
#	A handle to the frame containing the Color interface.

proc prefWin::createColorWindow {mainFrm} {
    variable focusOrder
    variable highBut
    variable errorBut

    set pad  6
    set pad2 10

    set subFrm   [prefWin::createSubFrm $mainFrm colorFrm Colors]
    set highLbl  [label $subFrm.highLbl -text "Highlight"]
    set highFrm  [frame  $subFrm.highFrm -width 40 -height 20]
    set highBut  [button $highFrm.highBut -bg [pref::prefGet highlight] \
	     -bd 4 -command [list prefWin::chooseColor $highFrm.highBut \
				highlight]]
    pack propagate $highFrm 0
    pack $highBut -fill both

    set errorLbl [label $subFrm.errorLbl -text "Highlight On Error"]
    set errorFrm [frame  $subFrm.errorFrm -width 40 -height 20]
    set errorBut [button $errorFrm.errorBut -bd 4 \
		      -bg [pref::prefGet highlight_error] \
		      -command [list prefWin::chooseColor $errorFrm.errorBut \
				   highlight_error]]
    pack propagate $errorFrm 0
    pack $errorBut -fill both

    set cmdresultLbl [label $subFrm.cmdresultLbl -text "Highlight On Result"]
    set cmdresultFrm [frame  $subFrm.cmdresultFrm -width 40 -height 20]
    set cmdresultBut [button $cmdresultFrm.cmdresultBut -bd 4 \
		      -bg [pref::prefGet highlight_cmdresult] \
		      -command [list prefWin::chooseColor \
		      $cmdresultFrm.cmdresultBut highlight_cmdresult]]
    pack propagate $cmdresultFrm 0
    pack $cmdresultBut -fill both

    grid $highLbl  -row 0 -column 0 -sticky w -padx $pad -pady $pad
    grid $highFrm  -row 0 -column 1 -sticky w -pady $pad 
    grid $errorLbl -row 0 -column 3 -sticky w -padx $pad -pady $pad
    grid $errorFrm -row 0 -column 4 -sticky w -pady $pad
    grid $cmdresultLbl -row 0 -column 6 -sticky w -padx $pad -pady $pad
    grid $cmdresultFrm -row 0 -column 7 -sticky w -pady $pad
    grid columnconfigure $subFrm 2 -minsize 20
    grid columnconfigure $subFrm 5 -minsize 20
    grid columnconfigure $subFrm 8 -weight 1

    pack $subFrm -fill both -expand true -padx $pad -pady $pad2

    lappend focusOrder($mainFrm) $highBut $errorBut $cmdresultBut
    return $mainFrm.colorFrm
}

# prefWin::chooseColor --
#
#	Popup a color picker, and set the button's bg to the
#	result.
#
# Arguments:
#	but	The button to set.
#	pref	The preference to request the new color to.
#
# Results:
#	None.

proc prefWin::chooseColor {but pref} {
    set w $gui::gui(prefDbgWin)
    grab $w

    set initialColor [$but cget -bg]
    set color [tk_chooseColor -title "Choose a color" -parent $w \
	-initialcolor $initialColor]

    # If the color is not an empty string, then set the preference value 
    # to the newly selected color.

    if {$color != ""} {
	$but configure -bg $color
	pref::prefSet TempPref $pref $color
    }

    grab release $w
}

# prefWin::createEvalWindow --
#
#	Create the interface for setting Eval Console options.
#
# Arguments:
#	mainFrm		The containing frame.
#
# Results:
#	A handle to the frame containing the Eval Console interface.

proc prefWin::createEvalWindow {mainFrm} {
    variable focusOrder

    set pad  6
    set pad2 10

    set subFrm    [prefWin::createSubFrm $mainFrm evalFrm "Eval Console"]
    set screenLbl [label $subFrm.screenLbl -text "Screen Buffer Size"]
    set screenEnt [entry $subFrm.screenEnt -justify right -width 6 \
		       -textvariable [pref::prefVar screenSize TempPref]]
    set histryLbl [label $subFrm.histryLbl -text "History Buffer Size"]
    set histryEnt [entry $subFrm.histryEnt -justify right -width 6 \
		       -textvariable [pref::prefVar historySize TempPref]]

    grid $screenLbl -row 0 -column 0 -sticky w -padx $pad -pady $pad
    grid $screenEnt -row 0 -column 1 -sticky w -pady $pad
    grid $histryLbl -row 0 -column 3 -sticky w -padx $pad -pady $pad
    grid $histryEnt -row 0 -column 4 -sticky w -pady $pad
    grid columnconfigure $subFrm 2 -minsize 20
    grid columnconfigure $subFrm 5 -weight 1

    pack $subFrm -fill both -expand true -padx $pad -pady $pad2

    lappend focusOrder($mainFrm) $screenEnt $histryEnt
    return $mainFrm.evalFrm
}

# prefWin::createCodeWindow --
#
#	Create the interface for setting Eval Console options.
#
# Arguments:
#	mainFrm		The containing frame.
#
# Results:
#	A handle to the frame containing the Eval Console interface.

proc prefWin::createCodeWindow {mainFrm} {
    variable focusOrder

    set pad  6
    set pad2 10

    set subFrm [prefWin::createSubFrm $mainFrm codeFrm "Code Window"]
    set tabLbl [label $subFrm.screenLbl -text "Tab Size"]
    set tabEnt [entry $subFrm.screenEnt -justify right -width 6 \
		    -textvariable [pref::prefVar tabSize TempPref]]

    grid $tabLbl -row 0 -column 0 -sticky w -padx $pad -pady $pad
    grid $tabEnt -row 0 -column 1 -sticky w -pady $pad
    grid columnconfigure $subFrm 3 -weight 1

    pack $subFrm -fill both -expand true -padx $pad -pady $pad2

    lappend focusOrder($mainFrm) $tabEnt
    return $mainFrm.codeFrm
}

proc prefWin::createStartWindow {mainFrm} {
    variable focusOrder

    set pad  6
    set pad2 10

    set subFrm [prefWin::createSubFrm $mainFrm startFrm "Startup"]
    set reloadChk [checkbutton $subFrm.reloadChk \
		     -text "Reload the previous project on startup." \
		     -variable [pref::prefVar projectReload TempPref]]
    grid $reloadChk -row 0 -column 0 -sticky w -padx $pad
    grid columnconfigure $subFrm 1 -weight 1

    pack $subFrm -fill both -expand true -padx $pad -pady $pad2

    lappend focusOrder($mainFrm) $reloadChk
    return $mainFrm.startFrm
}

proc prefWin::createExitWindow {mainFrm} {
    variable focusOrder

    set pad  6
    set pad2 10

    set subFrm [prefWin::createSubFrm $mainFrm exitFrm "Exit"]
    set askRad [radiobutton $subFrm.askRad \
		    -text "On exit, ask if the application should be killed." \
		    -variable [pref::prefVar exitPrompt TempPref] \
		    -value ask]
    set killRad [radiobutton $subFrm.killRad \
		     -text "On exit, always kill the application." \
		     -variable [pref::prefVar exitPrompt TempPref] \
		     -value kill]
    set runRad [radiobutton $subFrm.runRad \
		    -text "On exit, always leave the application running." \
		    -variable [pref::prefVar exitPrompt TempPref] \
		    -value run]
    set warnChk [checkbutton $subFrm.warnChk \
		     -text "Warn before killing the application." \
		     -variable [pref::prefVar warnOnKill TempPref]]
    
    grid $askRad  -row 0 -column 0 -sticky w -padx $pad
    grid $killRad -row 1 -column 0 -sticky w -padx $pad
    grid $runRad  -row 2 -column 0 -sticky w -padx $pad
    grid $warnChk -row 0 -column 2 -sticky w -padx $pad
    grid columnconfigure $subFrm 1 -minsize 20
    grid columnconfigure $subFrm 3 -weight 1

    pack $subFrm -fill both -expand true -padx $pad -pady $pad2

    lappend focusOrder($mainFrm) $askRad $killRad $runRad $warnChk
    return $mainFrm.exitFrm
}

# prefWin::createBrowserWindow --
#
#	Create the interface for setting Browser options.
#
# Arguments:
#	mainFrm		The containing frame.
#
# Results:
#	A handle to the frame containing the Browser interface.

proc prefWin::createBrowserWindow {mainFrm} {
    return [system::createBrowserWindow $mainFrm]
}

proc prefWin::createWarnWindow {mainFrm} {
    variable focusOrder

    set pad  6
    set pad2 10

    set subFrm [prefWin::createSubFrm $mainFrm otherFrm "Warnings"]
    set mvBpChk [checkbutton $subFrm.mvBpChk \
		     -text "Warn when moving invalid breakpoints." \
		     -variable [pref::prefVar warnInvalidBp TempPref]]
    grid $mvBpChk -row 0 -column 0 -sticky w -padx $pad
    grid columnconfigure $subFrm 1 -weight 1

    pack $subFrm -fill both -expand true -padx $pad -pady $pad2

    lappend focusOrder($mainFrm) $mvBpChk
    return $mainFrm.otherFrm
}

