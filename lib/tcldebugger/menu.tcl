# menu.tcl --
#
#	This file implements the menus for the Debugger.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 

namespace eval menu {
    variable showCmd
    variable maxMenuSize 10

    variable postCmd
    variable invokeCmd

    array set postCmd {
	<<Proj_New>>		menu::filePostCmd
	<<Proj_Open>>		menu::filePostCmd
	<<Proj_Close>>		menu::filePostCmd
	<<Proj_Save>>		menu::filePostCmd
	<<Proj_Settings>>	menu::filePostCmd
	<<Dbg_Open>>		menu::filePostCmd
	<<Dbg_Refresh>>		menu::filePostCmd
	<<Dbg_Exit>>		{}
	<<Cut>>			menu::editPostCmd
	<<Copy>>		menu::editPostCmd
	<<Paste>>		{}
	<<Delete>>		{}
	<<Dbg_Find>>		{}
	<<Dbg_FindNext>>	menu::editPostCmd	
	<<Dbg_Goto>>		{}
	<<Dbg_Break>>		{}
	<<Dbg_Eval>>		{}
	<<Dbg_Proc>>		{}
	<<Dbg_Watch>>		{}
	<<Dbg_DataDisp>>	menu::viewPostCmd
	<<Dbg_Run>>		menu::dbgPostCmd
	<<Dbg_Stop>>		menu::dbgPostCmd
	<<Dbg_Kill>>		menu::dbgPostCmd
	<<Dbg_Restart>>		menu::dbgPostCmd
	<<Dbg_In>>		menu::dbgPostCmd
	<<Dbg_Over>>		menu::dbgPostCmd
	<<Dbg_Out>>		menu::dbgPostCmd
	<<Dbg_To>>		menu::dbgPostCmd
	<<Dbg_CmdResult>>	menu::dbgPostCmd
	<<Dbg_AddWatch>>	menu::dbgPostCmd
	<<Dbg_Help>>		{}
    }

    array set invokeCmd {
	<<Proj_New>>		{$menu(file) invoke {New Project*}}
	<<Proj_Open>>		{$menu(file) invoke {Open Project*}}
	<<Proj_Close>>		{$menu(file) invoke {Close Project*}}
	<<Proj_Save>>		{$menu(file) invoke {Save Project}}
	<<Proj_Settings>>	{$menu(file) invoke {*Project Settings*}}
	<<Dbg_Open>>		{$menu(file) invoke {Open File*}}
	<<Dbg_Refresh>>		{$menu(file) invoke {Refresh File*}}
	<<Dbg_Exit>>		{$menu(file) invoke {Exit}}
	<<Cut>>			{$menu(edit) invoke {Cut}}
	<<Copy>>		{$menu(edit) invoke {Copy}}
	<<Paste>>		{$menu(edit) invoke {Paste}}
	<<Delete>>		{$menu(edit) invoke {Delete}}
	<<Dbg_Find>>		{$menu(edit) invoke {Find...}}
	<<Dbg_FindNext>>	{$menu(edit) invoke {Find Next}}
	<<Dbg_Goto>>		{$menu(edit) invoke {Goto Line*}}
	<<Dbg_Break>>		{$menu(view) invoke {Breakpoints*}}
	<<Dbg_Eval>>		{$menu(view) invoke {Eval Console*}}
	<<Dbg_Proc>>		{$menu(view) invoke {Procedures*}}
	<<Dbg_Watch>>		{$menu(view) invoke {Watch Variables*}}
	<<Dbg_DataDisp>>	{$menu(view) invoke {Data Display*}}
	<<Dbg_Run>>		{$menu(dbg)  invoke {Run}}
	<<Dbg_Stop>>		{$menu(dbg)  invoke {Stop}}
	<<Dbg_Kill>>		{$menu(dbg)  invoke {Kill}}
	<<Dbg_Restart>>		{$menu(dbg) invoke {Restart}}
	<<Dbg_In>>		{$menu(dbg)  invoke {Step In}}
	<<Dbg_Over>>		{$menu(dbg)  invoke {Step Over}}
	<<Dbg_Out>>		{$menu(dbg)  invoke {Step Out}}
	<<Dbg_To>>		{$menu(dbg)  invoke {Run To Cursor}}
	<<Dbg_CmdResult>>	{$menu(dbg)  invoke {Step To Result}}
	<<Dbg_AddWatch>>	{$menu(dbg)  invoke {Add Var To Watch*}}
    }
    if {[string equal $::tcl_platform(platform) "windows"]} {
	# On non-windows, remove the Tcl/Tk help menu item
	set postCmd(<<Dbg_TclHelp>>) {}
	set invokeCmd(<<Dbg_TclHelp>>) {$menu(help) invoke {View Tcl/Tk Help}}
    }
    set invokeCmd(<<Dbg_Help>>) \
	    {$menu(help) invoke "View $::projectInfo::productName Help"}
}

# menu::create --
#
#	Create all of the menus for the main debugger window.
#
# Arguments:
#	mainDbgWin	The toplevel window for the main debugger.
#
# Results:
#	The namespace variables gui(showToolbar) and gui(showStatus)
#	are set to true, indicating that the toolbar and status window
#	should be displayed.

proc menu::create {mainDbgWin} {
    variable show
    variable menu

    set menubar [menu $mainDbgWin.menubar -tearoff 0]
    $mainDbgWin configure -menu $menubar

    array set menuKeys [system::getKeyBindings]

    # New File menu.
    set file [menu $menubar.file -tearoff 0 \
	    -postcommand "menu::filePostCmd"]
    $menubar add cascade -label "File" -menu $file -underline 0
    $file add command -label "Open File..." \
	    -command {menu::openDialog} -underline 5 \
	    -acc $menuKeys(Dbg_Open)
    $file add command -label "Refresh File..." \
	    -command {menu::refreshFile} -underline 6 \
	    -acc $menuKeys(Dbg_Refresh)
    $file add separator
    $file add command -label "New Project..." \
	    -command {proj::showNewProjWindow} -underline 0 \
	    -acc $menuKeys(Proj_New)
    $file add command -label "Open Project..." \
	    -command {proj::openProjCmd} -underline 0 \
	    -acc $menuKeys(Proj_Open)
    $file add command -label "Close Project..." \
	    -command {proj::closeProjCmd} -underline 0 \
	    -acc $menuKeys(Proj_Close)
    $file add separator
    $file add command -label "Save Project" \
	    -command {proj::saveProjCmd} -underline 0 \
	    -acc $menuKeys(Proj_Save)
    $file add command -label "Save Project As..."  -underline 13 \
	-command {proj::saveAsProjCmd}
    $file add separator
    $file add command -label "Project Settings..." \
	    -command {proj::showThisProjWindow} -underline 0 \
	    -acc $menuKeys(Proj_Settings)
    $file add cascade -label "Recent Projects" \
	    -menu $file.runPrj -underline 0
    $file add separator
    $file add command -label "Exit" \
	    -command {ExitDebugger} -underline 1 \
	    -acc $menuKeys(Dbg_Exit)
    
    # New/Edit Project Cascade
    set recent [menu $file.runPrj -tearoff 0 \
	    -postcommand "menu::recentProjPostCmd"]
    
    # Edit menu.
    set edit [menu $menubar.edit -tearoff 0 \
	    -postcommand "menu::editPostCmd"]
    $menubar add cascade -label "Edit" -menu $edit -underline 0

    $edit add command -label "Cut"  -underline 2 \
	    -command {tk_textCopy $code::codeWin} -state disabled \
	    -acc $menuKeys(Cut)
    $edit add command -label "Copy"  -underline 0 \
	    -command {tk_textCopy $code::codeWin} -state disabled \
	    -acc $menuKeys(Copy)
    $edit add command -label "Paste"  -underline 0 \
	    -state disabled -acc $menuKeys(Paste)
    $edit add command -label "Delete"  -underline 0 \
	    -state disabled -acc $menuKeys(Delete)
    $edit add separator
    $edit add command -label "Find..." -acc $menuKeys(Dbg_Find) \
	    -command {find::showWindow} -underline 0
    $edit add command -label "Find Next" -acc $menuKeys(Dbg_FindNext) \
	    -command {find::next} -underline 5
    $edit add command -label "Goto Line..." -acc $menuKeys(Dbg_Goto) \
	    -command {goto::showWindow} -underline 0
    $edit add separator
    $edit add command -label "Preferences..."  -command {prefWin::showWindow} \
	    -underline 0
    # View menu.
    set view [menu $menubar.view -tearoff 0 \
	    -postcommand "menu::viewPostCmd"]
    $menubar add cascade -label "View" -menu $view -underline 0

    $view add command -label "Breakpoints..." -command {bp::showWindow} \
	    -acc $menuKeys(Dbg_Break) -underline 0
    $view add command -label "Eval Console..."  \
	    -command {evalWin::showWindow} \
	    -acc $menuKeys(Dbg_Eval) -underline 0
    $view add command -label "Procedures..." -command {procWin::showWindow} \
	    -acc $menuKeys(Dbg_Proc) -underline 0
    $view add command -label "Watch Variables..." \
	    -command {watch::showWindow} \
	    -acc $menuKeys(Dbg_Watch) -underline 0
    $view add command -label "Connection status..." \
	    -command {gui::showConnectStatus} -underline 0
    $view add command -label "Data Display..." \
	    -command {watch::showInspector $var::nameText} -state disabled \
	    -acc $menuKeys(Dbg_DataDisp) -underline 0
    $view add separator
    $view add checkbutton -label "Toolbar"  -underline 0 \
	    -variable [pref::prefVar showToolbar] \
	    -command {menu::showOrHideDbgWindow \
	        [pref::prefGet showToolbar] \
		[list grid $gui::gui(toolbarFrm) -row 0 -sticky we]}
    $view add checkbutton -label "Result"  -underline 0 \
	    -variable [pref::prefVar showResult] \
	    -command {menu::showOrHideDbgWindow \
	    [pref::prefGet showResult] \
	    [list grid $gui::gui(resultFrm) -row 2 -sticky we]}
    $view add checkbutton -label "Status"  -underline 0 \
	    -variable [pref::prefVar showStatusBar] \
	    -command {menu::showOrHideDbgWindow \
	    [pref::prefGet showStatusBar] \
	    [list grid $gui::gui(statusFrm) -row 3 -sticky we]}
    $view add checkbutton -label "Line Numbers"  -underline 0 \
	    -variable [pref::prefVar showCodeLines] \
	    -command {menu::showOrHideDbgWindow \
	    [pref::prefGet showCodeLines] \
	    [list grid $::code::lineBar -row 0 -column 1 -sticky ns]}

    # Debug menu.
    set dbg [menu $menubar.dbg -tearoff 0 \
	    -postcommand "menu::dbgPostCmd"]
    $menubar add cascade -label "Debug" -menu $dbg -underline 0
    $dbg add command -label "Run" -command {gui::run dbg::run} \
	    -acc $menuKeys(Dbg_Run) -underline 0
    $dbg add command -label "Stop" -command {gui::interrupt} \
	    -acc $menuKeys(Dbg_Stop) -underline 0
    $dbg add command -label "Kill" -command {gui::kill} \
	    -acc $menuKeys(Dbg_Kill) -underline 0
    $dbg add command -label "Restart" \
	    -command {proj::restartProj} -underline 1 \
	    -acc $menuKeys(Dbg_Restart)
    $dbg add separator
    $dbg add command -label "Step In" -command {gui::run dbg::step} \
	    -acc $menuKeys(Dbg_In) -underline 5
    $dbg add command -label "Step Over" -command {gui::run {dbg::step over}} \
	    -acc $menuKeys(Dbg_Over) -underline 5
    $dbg add command -label "Step Out" -command {gui::run {dbg::step out}} \
	    -acc $menuKeys(Dbg_Out) -underline 7
    $dbg add command -label "Run To Cursor" -command {gui::runTo} \
	    -acc $menuKeys(Dbg_To) -underline 7
    $dbg add command -label "Step To Result" -underline 11\
	    -command {gui::run {dbg::step cmdresult}} \
	    -acc $menuKeys(Dbg_CmdResult)
    $dbg add separator
    $dbg add command -label "Add Var To Watch" \
	    -command {var::addToWatch} -state disabled \
	    -acc $menuKeys(Dbg_AddWatch) -underline 11
    $dbg add separator
    $dbg add cascade -label Breakpoints -menu $dbg.bps -underline 0

    # Breakpoint Cascade.
    set bps [menu $dbg.bps -tearoff 0 \
	    -postcommand "menu::bpsPostCmd"]
    $bps add command -label "Add Line Breakpoint" -underline 0 \
	    -acc "Return" -state disabled \
	    -command {code::toggleLBP $code::codeBar \
	    [$code::codeWin index insert] onoff}
    $bps add command -label "Disable Line Breakpoint" -underline 0 \
	    -acc "Ctrl-Return" -state disabled \
	    -command {code::toggleLBP $code::codeBar \
	    [$code::codeWin index insert] enabledisable}
    $bps add separator
    $bps add command -label "Add Variable Breakpoint" -underline 4 \
	    -acc "Return" -state disabled \
	    -command {watch::toggleVBP $var::valuText \
	    [sel::getCursor $var::valuText].0 onoff}
    $bps add command -label "Disable Variable Breakpoint" -underline 1 \
	    -acc "Ctrl-Return" -state disabled \
	    -command {watch::toggleVBP $var::valuText \
	    [sel::getCursor $var::valuText].0 enabledisable}

    # Windows menu.
    set win [menu $menubar.window -tearoff 0 \
	    -postcommand "menu::winPostCmd"]
    $menubar add cascade -label "Window" -menu $win -underline 0

    # Help menu.
    set help [menu $menubar.help -tearoff 0]
    $menubar add cascade -label "Help" -menu $help -underline 0
    $help add command -label "View $::projectInfo::productName Help" \
	    -command [list \
		system::openURL $::projectInfo::helpFile(thisProduct)] \
	    -acc $menuKeys(Dbg_Help) -underline 5
    if { 1 || [string equal $::tcl_platform(platform) "windows"] \
	    && ($::projectInfo::helpFile(tcl) != "")} {
	# On windows, show the Tcl/Tk help menu item
	$help add command -label "View Tcl/Tk Help" \
		-command [list system::openURL $::projectInfo::helpFile(tcl)] \
		-acc $menuKeys(Dbg_TclHelp) -underline 5
    }
    $help add separator
    $help add command -label "About $::projectInfo::productName" \
	    -command {gui::showAboutWindow} -underline 0

    # Enable the debug menu.  This is controlled by the debugMenu
    # preference.  This code is for internal use only.
    # To cause the menu to appear menually add a prefence called 
    # debugMenu and set the value to "1".

    if {[pref::prefExists debugMenu] && [pref::prefGet debugMenu]} {
	set debug [menu $menubar.debug -tearoff 0]
	$menubar add cascade -label "SuperBurrito" -menu $debug -underline 0
	$debug add command -label "Console show"  -underline 8 \
		-command {console show; console eval {raise .}}
	$debug add command -label "Console hide"  -underline 8 \
		-command {console hide}
	$debug add command -label "Show instrumented"  -underline 0 \
		-command {
	    global errorInfo
	    catch {destroy .t}
	    set t [toplevel .instrumented]
	    text $t.t
	    set b [gui::getCurrentBlock]
	    set r [catch {set icode [blk::Instrument $b [blk::getSource $b]]}]
	    if {$r} {
		$t.t insert 0.0 $errorInfo
	    } else {
		$t.t insert 0.0 $icode
	    }
	    pack $t.t -expand 1 -fill both
	}
	$debug add checkbutton -label "Logging output" \
		-variable dbg::debug -command {
	    if {$dbg::debug} {
		set dbg::logFilter message
	    } else {
		set dbg::logFilter {}
	    }
	}
	$debug add command -label "Remove All Prefs & Exit"  \
		-command {CleanExit}
    }

    set menu(file)    $file
    set menu(recent)  $recent
    set menu(edit)    $edit
    set menu(view)    $view
    set menu(dbg)     $dbg
    set menu(bps)     $bps
    set menu(win)     $win
    set menu(help)    $help
}

# menu::filePostCmd --
#
#	Post command for the File menu.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc menu::filePostCmd {} {
    variable menu

    menu::changeState {newProj openProj projSettings} normal
    
    if {[llength [pref::prefGet projectList]] == 0} {
	menu::changeState recentProj disabled
    } else {
	menu::changeState recentProj normal
    }
    
    if {[proj::isProjectOpen]} {
	menu::changeState {closeProj saveProj saveAsProj openFile} normal
	
	# If  (1) the project has been previously saved
	# And (2) the project file exists 
	# And (3) the project preferences are all up to date
	# Set the "Save Project" menu entry to be disabled.

	if {![proj::projectNeverSaved] \
		&& [file exists [proj::getProjectPath]] \
		&& (![pref::groupIsDirty Project])} {
	    menu::changeState {saveProj} disabled
	}
    } else {
	menu::changeState {closeProj saveProj saveAsProj openFile} disabled
    }
    
    # Enable the refresh button if the current block is associated
    # with a file that is currently instrumented.

    if {([gui::getCurrentFile] == {}) \
	    || ([blk::isInstrumented [gui::getCurrentBlock]])} {
	menu::changeState {refreshFile} disabled
    } else {
	menu::changeState {refreshFile} normal
    }

    set state [gui::getCurrentState]
    if {$state == "new"} {
	$menu(file) entryconfigure {*Project Settings*} \
		-label "Default Project Settings..."
    } else {
	$menu(file) entryconfigure {*Project Settings*} \
		-label "Project Settings..."
	menu::changeState openFile normal
    }

    return
}

# menu::recentProjPostCmd --
#
#	Post command for the "Recent Projects" cascade.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc menu::recentProjPostCmd {} {
    set m $menu::menu(recent)
    $m delete 0 end
    
    set i   1
    set end [pref::prefGet comboListSize]

    foreach path [pref::prefGet projectList] {
	if {$i >= $end} {
	    break
	}
	$m add command -label "$i $path" \
		-underline 0 \
		-command [list proj::openProjCmd $path]
	incr i
    }
    return
}

# menu::editPostCmd --
#
#	Post command for the Edit menu.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc menu::editPostCmd {} {
    menu::changeState {cut copy findNext} disabled
    set focusWin [focus]
    if {$focusWin == $code::codeWin} {
        if {[$focusWin tag ranges sel] != {}} {
	    menu::changeState {cut copy} normal
	}
    } elseif {$focusWin == $var::valuText || $focusWin == $stack::stackText} {
        if {[$focusWin tag ranges highlight] != {}} {
	    menu::changeState {cut copy} normal
	}
    }
    if {[find::nextOK]} {
	menu::changeState {findNext} normal
    }
    return
}

# menu::viewPostCmd --
#
#	Post command for the View menu.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc menu::viewPostCmd {} {
    menu::changeState {inspector} disabled
    set focusWin [focus]
    if {$focusWin == $var::valuText} {
        if {[$focusWin tag ranges highlight] != {}} {
	    menu::changeState {inspector} normal
	}
    }
}

# menu::dbgPostCmd --
#
#	Post command for the Debug menu.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc menu::dbgPostCmd {} {
    variable focusWin
    set focusWin [focus]

    # Copy the current state into a more easily tested array form.
    array set state {
	new 0
	dead 0
	stopped 0
	running 0
    }
    set state([gui::getCurrentState]) 1

    set remote [proj::isRemoteProj]
    
    # The following expressions determine the conditions under which
    # the given menu item will be enabled.

    set conditions {
	breakpoints {($focusWin != $stack::stackText) && [proj::isProjectOpen]}
	addToWatch {$focusWin == $var::valuText}
	restart {!$remote && ($state(stopped) || $state(running))}
	run {(!$remote && $state(dead)) || $state(stopped)}
	stepIn {(!$remote && $state(dead)) || $state(stopped)}
	stepOut {$state(stopped)}
	stepOver {$state(stopped)}
	stepTo {$state(stopped)}
	stepResult {$state(stopped)}
	stop {$state(running)}
	kill {$state(running) || $state(stopped)}
    }

    foreach {item cond} $conditions {
	if $cond {
	    menu::changeState $item normal
	} else {
	    menu::changeState $item disabled
	}
    }

    return
}

# menu::bpsPostCmd --
#
#	Post command for the Breakpoints cascade menu.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc menu::bpsPostCmd {} {
    variable focusWin
    variable menu

    if {$focusWin == $var::valuText} {
	menu::changeState {addVBP disableVBP} normal
	menu::changeState {addLBP disableLBP} disabled
	set breakState [icon::getState $var::vbpText \
		[sel::getCursor $var::valuText]]
	switch $breakState {
	    noBreak {
		$menu(bps) entryconfigure 3 -label "Add Var Breakpoint"
		$menu(bps) entryconfigure 4 -label "Disable Var Breakpoint"
		menu::changeState {disableVBP} disabled
	    }
	    mixedBreak -
	    enabledBreak {
		$menu(bps) entryconfigure 3 -label "Remove Var Breakpoint"
		$menu(bps) entryconfigure 4 -label "Disable Var Breakpoint"
	    }
	    disabledBreak {
		$menu(bps) entryconfigure 3 -label "Add Var Breakpoint"
		$menu(bps) entryconfigure 4 -label "Enable Var Breakpoint"
	    }
	}
    } elseif {$focusWin == $code::codeWin} {
	menu::changeState {addLBP disableLBP} normal
	menu::changeState {addVBP disableVBP} disabled
	set breakState [icon::getState $code::codeBar \
		[lindex [split [$code::codeWin index insert] .] 0]]
	switch $breakState {
	    noBreak {
		$menu(bps) entryconfigure 0 -label "Add Line Breakpoint"
		$menu(bps) entryconfigure 1 -label "Disable Line Breakpoint"
		menu::changeState {disableLBP} disabled
	    }
	    mixedBreak -
	    enabledBreak {
		$menu(bps) entryconfigure 0 -label "Remove Line Breakpoint"
		$menu(bps) entryconfigure 1 -label "Disable Line Breakpoint"
	    }
	    disabledBreak {
		$menu(bps) entryconfigure 0 -label "Add Line Breakpoint"
		$menu(bps) entryconfigure 1 -label "Enable Line Breakpoint"
	    }
	}
    } else {
	menu::changeState {addVBP disableVBP addLBP disableLBP} disabled
    }
}

# menu::winPostCmd --
#
#	This command is a "post command" for the Windows menu item.
#	We use this command to see if we need to update our list of 
#	files in the menu list.  We also do all the work of adding them
#	if the files need to be updated.
#
# Arguments:
#	m		This is the menu the post command is called for.
#
# Results:
#	None.

proc menu::winPostCmd {} {
    variable menu

    # Update all the menus.  We give a different value
    # for the check based on if it is instrumented.  The command
    # will view the file when selected.

    $menu(win) delete 0 end
    set showList {}

    set font [$menu(win) cget -font]
    set family [font actual $font -family]
    set size   [font actual $font -size]
    set italic [list $family $size italic]
 
    set line 0
    foreach {file block} [file::getUniqueFiles] {
	set code  [list gui::showCode [loc::makeLocation $block {}]]
	set inst  [blk::isInstrumented $block]

	if {$line < $menu::maxMenuSize} {
	    if {$inst} {
		$menu(win) add command -label "  $file" -command $code
	    } else {
		$menu(win) add command -label "* $file" -command $code
	    }
	}
	incr line
	lappend showList $block $code $inst
    }
    $menu(win) add separator
    $menu(win) add command -label "Windows..." -underline 0 \
	    -command [list menu::showFileWindow $showList]
}

# menu::openDialog --
#
#	Displays the open file dialog so the user can select a
#	a Tcl file to view and set break points on.  If the task
#	succeds a block is retreived for the file and it is displayed.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc menu::openDialog {} {
    set types {
	{"Tcl Scripts"		{.tcl .tk}}
	{"All files"		*}
    }

    set file [proj::openFileWindow $gui::gui(mainDbgWin) \
	    [pref::prefGet fileOpenDir] $types]

    if {[string compare $file ""]} {
	set oldwd [pwd]
	set dir   [file dirname $file]
	cd  $dir
	set absfile [file join [pwd] [file tail $file]]
	cd  $oldwd

	pref::prefSet GlobalDefault fileOpenDir $dir

	set block [blk::makeBlock $absfile]
	set loc [loc::makeLocation $block {}]
	gui::showCode $loc
    }
    return
}

# menu::refreshFile --
#
#	Displays the open file dialog so the user can select a
#	a Tcl file to view and set break points on.  If the task
#	succeds a block is retreived for the file and it is displayed.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc menu::refreshFile {} {
    global ::gui::fileText

    set file [gui::getCurrentFile]
    if {$file == {}} {
	return
    }

    set oldwd [pwd]
    set dir   [file dirname $file]
    cd  $dir
    set absfile [file join [pwd] [file tail $file]]
    cd  $oldwd
    
    pref::prefSet GlobalDefault fileOpenDir $dir
    
    set block [blk::makeBlock $absfile]
    set loc [loc::makeLocation $block {}]
    gui::showCode $loc
    
    return
}

# menu::showOrHideDbgWindow --
#
#	Display or remove the current frame from the window. It is
#	assumed that the window has already been created and just 
#	needs additional management by the packer.
#
# Arguments:
#	showFrm	  Boolean that indicates if the window should
#		  be shown or hidden.
#	frm 	  The name of the frame to show or hide.
#	args	  Extra args passed to pack.
#
# Results:
#	None.

proc menu::showOrHideDbgWindow {showFrm geomCmd} {
    if {$showFrm} {
	eval $geomCmd
    } else {
	set manager [lindex $geomCmd 0]
	set window  [lindex $geomCmd 1]
	$manager forget $window
    }
}

# menu::changeState --
#
#	Change the state of menu items.  There is a limited number
#	of menu items whose state will change over the course of the 
#	debug session.  Given the name of the menu item, this routine
#	locates the handle to the menu item and updates the state.
#
# Arguments:
#	menuList	List of menu item names that should be updated.
#	state		The new state of all items in menuList.
#
# Results:
#	None.

proc menu::changeState {menuList state} {
    variable menu

    foreach entry $menuList {
	switch -exact $entry {
	    openFile {
		$menu(file) entryconfigure {Open File*} -state $state
	    }
	    refreshFile {
		$menu(file) entryconfigure {Refresh File*} -state $state
	    }
	    newProj {
		$menu(file) entryconfigure {New Project*} -state $state
	    }
	    openProj {
		$menu(file) entryconfigure {Open Project*} -state $state
	    }
	    closeProj {
		$menu(file) entryconfigure {Close Project*} -state $state
	    }
	    saveProj {
		$menu(file) entryconfigure {Save Project} -state $state
	    }
	    saveAsProj {
		$menu(file) entryconfigure {Save Project As*} -state $state
	    }
	    recentProj {
		$menu(file) entryconfigure {Recent Projects*} -state $state
	    }
	    projSettings {
		$menu(file) entryconfigure {*Project Settings*} -state $state
	    }
	    editProj {
		$menu(file) entryconfigure {Edit Project*} -state $state
	    }
	    runProj {
		$menu(file) entryconfigure {Run Project*} -state $state
	    }
	    cut {
		$menu(edit) entryconfigure Cut -state $state
	    }
	    copy {
		$menu(edit) entryconfigure Copy -state $state
	    }
	    paste {
		$menu(edit) entryconfigure Paste -state $state
	    }
	    delete {
		$menu(edit) entryconfigure Delete -state $state
	    }
	    findNext {
		$menu(edit) entryconfigure {Find Next} -state $state
	    }
	    restart {
		$menu(dbg) entryconfigure Restart -state $state
	    }
	    run {
		$menu(dbg) entryconfigure Run -state $state
	    }
	    stop {
		$menu(dbg) entryconfigure Stop -state $state
	    }
	    kill {
		$menu(dbg) entryconfigure Kill -state $state
	    }
	    stepIn {
		$menu(dbg) entryconfigure {Step In} -state $state
	    }
	    stepOut {
		$menu(dbg) entryconfigure {Step Out} -state $state
	    }
	    stepOver {
		$menu(dbg) entryconfigure {Step Over} -state $state
	    }
	    stepTo {
		$menu(dbg) entryconfigure {Run To Cursor} -state $state
	    }
	    stepResult {
		$menu(dbg) entryconfigure {Step To Result} -state $state
	    }
	    addToWatch {
		$menu(dbg) entryconfigure {Add Var To Watch*} -state $state
	    }
	    breakpoints {
		$menu(dbg) entryconfigure {Breakpoints*} -state $state
	    }
	    addLBP {
		$menu(bps) entryconfigure 0 -state $state
	    }
	    disableLBP {
		$menu(bps) entryconfigure 1 -state $state
	    }
	    addVBP {
		$menu(bps) entryconfigure 3 -state $state
	    }
	    disableVBP {
		$menu(bps) entryconfigure 4 -state $state
	    }
	    inspector {
		$menu(view) entryconfigure {Data Display*} -state $state
	    }
	    default {
		error "Unknown menu item \"$entry\": in menu::changeState"
	    }
	}
    }
}

# menu::showFileWindow --
#
#	Display all of the open files in a list inside
# 	a new toplevel window.
#
# Arguments:
#	showList 	A list of open files.
#
# Results:
#	The toplevel window name of the File Window.

proc menu::showFileWindow {showList} {
    grab $gui::gui(mainDbgWin)

    if {[info command $gui::gui(fileDbgWin)] == $gui::gui(fileDbgWin)} {
	menu::updateFileWindow $showList
	wm deiconify $gui::gui(fileDbgWin)
	focus $menu::selectText
    } else {
	menu::createFileWindow
	menu::updateFileWindow $showList
	focus $menu::selectText
    }    

    grab release $gui::gui(mainDbgWin)

    return $gui::gui(fileDbgWin)
}

# menu::createFileWindow --
#
#	Create the File Window.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc menu::createFileWindow {} {
    variable selectText 

    set bd 2
    set pad 6

    set top [toplevel $gui::gui(fileDbgWin)]
    ::guiUtil::positionWindow $top 400x250
    wm transient $top $gui::gui(mainDbgWin)
    wm title $top "Windows"

    set mainFrm [frame $top.mainFrm -bd 2 -relief raised]
    set selectLbl [label $mainFrm.selectLbl -text "Select Window:"]
    set selectFrm [frame $mainFrm.selectFrm]
    set selectText [text  $selectFrm.selectText -height 10 -width 15]
    set sb [scrollbar $selectFrm.sb -command [list $selectText yview]]
    set instLbl [label $mainFrm.instLbl \
	    -text "* means the file is uninstrumented"]

    set butFrm [frame $mainFrm.butFrm]
    set showBut [button $butFrm.showBut -text "Show Code" -default active \
	    -command [list menu::showFile $selectText]]
    set canBut [button $butFrm.canBut -text "Cancel" -default normal \
	    -command menu::removeFileWindow]

    pack $selectText -side left -fill both -expand true
    pack $showBut $canBut -fill x
    pack $canBut -pady $pad -fill x
    grid $selectLbl -row 0 -column 0 -padx $pad -sticky nw
    grid $selectFrm -row 1 -column 0 -padx $pad -pady $pad -sticky nswe \
	    -rowspan 2
    grid $butFrm  -row 1 -column 1 -padx $pad -pady $pad -sticky nwe
    grid $instLbl -row 3 -column 0 -padx $pad -sticky nw -columnspan 2
    grid columnconfigure $mainFrm 0 -weight 1
    grid rowconfigure $mainFrm 1 -weight 1
    pack $mainFrm -fill both -expand true -padx $pad -pady $pad

    gui::setDbgTextBindings $selectText $sb
    bind::addBindTags $selectText \
	    [list scrollText selectLine selectCopy breakDbgWin]
    bind::addBindTags $showBut    breakDbgWin
    bind::addBindTags $canBut     breakDbgWin
    bind::commonBindings breakDbgWin [list $selectText $showBut $canBut]

    bind $selectText <Double-1> [list \
	    menu::showFile $selectText
    ]
    bind $selectText <<Dbg_ShowCode>> [list \
	    menu::showFile $selectText
    ]
    bind $top <Escape> "$canBut invoke; break"
    bind $top <Return> "$showBut invoke; break"
}

# menu::updateFileWindow --
#
#	Update the contents of the File Window.
#
# Arguments:
#	showList	A list of files to show.  The list is ordered
#			to contain:
#		          block		The block of the file.
#			  code		The code to run to show the file.
#			  instrumented	Boolean, true if the file is 
#					instrumented.
#
# Results:
#	None

proc menu::updateFileWindow {showList} {
    variable showCmd
    variable selectText

    $selectText delete 0.0 end
    if {[info exists showCmd]} {
	unset showCmd
    }

    set line 1
    foreach {block code inst} $showList {
	set file [blk::getFile $block]
	if {$inst} {
	    $selectText insert end "  $file\n" $file
	} else {
	    $selectText insert end "* $file\n" [list $file]
	}
	set showCmd($line) $code
	incr line
    }
    sel::selectLine $selectText 1.0
    # if there are no files, disable the Show Code button
    if {[llength $showList]==0} {
	$::gui::gui(fileDbgWin).mainFrm.butFrm.showBut configure \
		-state disabled
    } else {
	$::gui::gui(fileDbgWin).mainFrm.butFrm.showBut configure \
		-state normal
    }
}

# menu::showFile --
#
#	Show the selected file.
#
# Arguments:
#	text	The text widget containign a list of file names.
#
# Results:
#	None.

proc menu::showFile {text} {
    variable showCmd

    set line [sel::getCursor $text]
    if {[info exists showCmd($line)]} {
	eval $showCmd($line)
    }
    menu::removeFileWindow
}

# menu::removeFileWindow --
#
#	Destroy the "Windows" Window.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc menu::removeFileWindow {} {
    destroy $gui::gui(fileDbgWin)
}

# menu::accKeyPress --
#
#	All key bindings are routed through this routine.  If a 
#	"post command" exists for the event, then it is run to 
#	update the state and determine if the event should be
#	trapped or executed.
#
# Arguments:
#	virtual		The virtual event bound to a key binding.
#
# Results:
#	None.

proc menu::accKeyPress {virtual} {
    variable menu
    variable postCmd
    variable invokeCmd
    
    if {$postCmd($virtual) != {}} {
	eval $postCmd($virtual)
    }
    eval $invokeCmd($virtual)
    return
}

