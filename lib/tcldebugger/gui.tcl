# gui.tcl --
#
#	This is the main interface for the Debugger.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
#

package require parser
package provide gui 1.0
namespace eval gui {

    # The gui::gui array stores; information on the current state of
    # GUI; handles to Tk widgets created in this namespace, and to
    # text variables of the status window.
    #
    #
    # Toplevel window names.
    #
    #
    # gui(breakDbgWin)		The toplevel window used to display and
    # 				set breakpoints.
    # gui(dataDbgWin)		The toplevel window used for the Data
    # 				Display Window.
    # gui(errorDbgWin)		The toplevel window used to display and
    # 				manage Errors..
    # gui(evalDbgWin)		The toplevel window used to evaluate
    # 				scripts during runtime.
    # gui(loadDbgWin)		The toplevel window used to load scripts
    # 				into the debugger.
    # gui(mainDbgWin)		Toplevel window for the debugger.
    # gui(parseDbgWin)		The toplevel window used to display and
    # 				manage parse errors.
    # gui(prefDbgWin)		The toplevel window used to display
    # 				and set debugger preferences.
    # gui(procDbgWin)		The toplevel window used to display procs
    # 				currently loaded in the debugger.
    # gui(watchDbgWin)		The toplevel window used to display and
    # 				set variable watches.
    # gui(projSettingWin)	The toplevel window that displays project
    #				settings.
    # gui(projMissingWin)	The toplevel window that displays a dialog
    #				when the project file is missing.
    # gui(errorPortWin)		The toplevel window to handle errors in
    #				start-up realted to the server socket port.
    #
    # State of the Debugger.
    #
    #
    # gui(currentArgs)		The cached value of the args, updated on
    #				every call to var::updateWindow.
    # gui(currentBlock) 	The current block being displayed in the
    #				code window.  Updated on calls to
    #				code::updateWindow.
    # gui(currentBreak) 	The current type break (LBP vs. VBP)
    #				Updated on breakpoint event handlers.
    # gui(currentFile)	 	The current file being displayed in the
    #				code window.  Updated on calls to
    #				code::updateWindow.
    # gui(currentLevel)		The cached value of the level, updated on
    #				every call to  var::updateWindow and
    #				gui::changeState.
    # gui(currentLine)	 	The current line being displayed in the
    #				code window.  Updated on calls to
    #				code::updateWindow.
    # gui(currentProc)		The cached value of the proc name, updated
    #				on every call to stack::updateWindow.
    # gui(currentScope)		The cached value of the proc name, or type
    #				on every call to stack::updateWindow.
    # gui(currentState)		The cached value of the GUI state.
    #				Either new, running, stopped or dead. Updated
    #				on every call to gui::changeState.
    # gui(currentType)		The cached value of the stack type, updated
    #				on every call to var::updateWindow.
    # gui(currentVer)		The cached value of the block version, updated
    #				on every call to code::updateWindow.
    # gui(uncaughtError)	The current error will not be caught by the
    #				application.
    #
    # Widgets in the Debugger.
    #
    #
    # gui(dbgFrm)		Frame that contains the stack, var and
    # 				code windows.
    # gui(resultFrm)		Frame that contains the result window.
    # gui(statusFrm)		Frame that contains the status window.
    # gui(toolbarFrm)		Frame that contains the toolbar window.
    #
    #
    # Checkbox variables.
    #
    #
    # gui(showToolbar)		Checkbutton var that indicates if the
    #				toolbar is currently being displayed.
    #				1 if it is diaplayed and 0 if not.
    # gui(showStatus)		Checkbutton var that indicates if the
    #				status is currently being displayed.
    #				1 if it is diaplayed and 0 if not.
    #
    # Other...
    #
    # gui(dbgText)		A list of registered text widgets.  When
    #				the a dbg text is updated via the prefs
    #				window, we need to get a list of widgets
    #				that are using the same bindings.

    variable gui

    # Set all the names of the toplevel windows.

    set gui(breakDbgWin)  .breakDbgWin
    set gui(dataDbgWin)   .dataDbgWin
    set gui(errorDbgWin)  .errorDbgWin
    set gui(evalDbgWin)   .evalDbgWin
    set gui(fileDbgWin)   .fileDbgWin
    set gui(findDbgWin)   .findDbgWin
    set gui(gotoDbgWin)   .gotoDbgWin
    set gui(loadDbgWin)   .loadDbgWin
    set gui(mainDbgWin)   .mainDbgWin
    set gui(newPrjDbgWin) .newPrjDbgWin
    set gui(parseDbgWin)  .parseDbgWin
    set gui(procDbgWin)   .procDbgWin
    set gui(prefDbgWin)   .prefDbgWin
    set gui(watchDbgWin)  .watchDbgWin
    set gui(errorPortWin) .errorPortWin
    set gui(projSettingWin) .projSetWin
    set gui(projMissingWin) .projMisWin

    # Initialize all of the state variables to null.

    set gui(currentArgs)    {}
    set gui(currentBreak)   {}
    set gui(currentBlock)   {}
    set gui(currentFile)    {}
    set gui(currentLevel)   {}
    set gui(currentLine)    {}
    set gui(currentPC)      {}
    set gui(currentProc)    {}
    set gui(currentScope)   {}
    set gui(currentState)   {}
    set gui(currentType)    {}
    set gui(currentVer)     {}

    set gui(dbgText) {}
    set gui(statusStateMsg)    "new session"

    # When the GUI state goes to running, clear out the Stack, Var,
    # Watch, and PC icon.  To reduce flickering, only do this after
    # <after Time>.  The afterID is the handle to the after event
    # so it can be canceled if the GUIs state changes before it fires.

    variable afterID
    variable afterTime 500

    variable msgAfterID
    variable instMsg
    variable counter 0

    # Array that holds the text that has been stripped for each window.

    variable format

    # Stores the command to execute when the debugger attaches.

    variable attachCmd {}
}

#-----------------------------------------------------------------------------
# Main Debugger Window Functions
#-----------------------------------------------------------------------------

# gui::showMainWindow
#
#	Displays the Main Debugger window.  If it has already been created
#	it deiconifies, and raises the window to the foreground.  Otherwise
#	it creates the toplevel window and all of it's components.
#
# Arguments:
#	None.

# Results:
#	The handle to the toplevel window of the debugger.

proc gui::showMainWindow {} {
    variable gui

    if {[info command $gui(mainDbgWin)] == $gui(mainDbgWin)} {
	wm deiconify $gui(mainDbgWin)
	raise $gui(mainDbgWin)
	return $gui(mainDbgWin)
    }

    set mainDbgWin [toplevel $gui(mainDbgWin)]
    wm protocol $mainDbgWin WM_DELETE_WINDOW {ExitDebugger}
    wm minsize  $mainDbgWin 350 300
    wm withdraw $mainDbgWin

    update

    gui::setDebuggerTitle ""
    system::bindToAppIcon $mainDbgWin
    ::guiUtil::positionWindow $mainDbgWin 500x500
    pack propagate $mainDbgWin off

    # Create the Menus and bind the functionality.

    menu::create $mainDbgWin

    # Create the debugger window, which consists of the
    # stack, var and code window with sliding panels.
    # Insert it into the grid and ensure that it expands to fill
    # all available space.

    set gui(dbgFrm) [gui::createDbgWindow $mainDbgWin]

    grid $gui(dbgFrm) -row 1 -sticky nsew -padx 2 -pady 1
    grid rowconfigure $mainDbgWin 1 -weight 1
    grid columnconfigure $mainDbgWin 0 -weight 1

    # Create the Toolbar, Status and Result windows.

    set gui(toolbarFrm) [tool::createWindow $mainDbgWin]
    set gui(statusFrm) [gui::createStatusWindow $mainDbgWin]
    set gui(resultFrm) [result::createWindow $mainDbgWin]

    # Add global keybindings

    bind::addBindTags $mainDbgWin mainDbgWin

    # Initialize the coverage gui.
    
    coverage::init

    # Invoke the appropriate menu times to ensure that the display
    # reflects the user's preferences.

    eval [$menu::menu(view) entrycget Toolbar -command]
    eval [$menu::menu(view) entrycget Status -command]
    eval [$menu::menu(view) entrycget Result -command]
    eval [$menu::menu(view) entrycget {Line Numbers} -command]

    gui::changeState new
    focus -force $stack::stackText

    return $gui(mainDbgWin)
}

# gui::setDebuggerTitle --
#
#	Set the title of the Debugger based on the prj name.
#
# Arguments:
#	proj	The name of the project currently loadded.  Use empty
#		if no project is currently loaded.
#
# Results:
#	None.  Change the title of the main toplevel window.

proc gui::setDebuggerTitle {proj} {
    variable gui

    if {$proj == ""} {
	set proj "<no project loaded>"
    }
    wm title $gui(mainDbgWin) "$::debugger::parameters(productName): $proj"
    return
}

# gui::resetWindow --
#
#	Reset the Debugger to it's start-up state.  Clear all of
#	the sub-windows and unset the local cache of the current
#	debugger state.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc gui::resetWindow {{msg {}}} {
    gui::setCurrentArgs  {}
    gui::setCurrentBreak {}
    gui::setCurrentLevel {}
    gui::setCurrentPC    {}
    gui::setCurrentProc  {}
    gui::setCurrentScope {}
    gui::setCurrentType  {}

    # If the error window is present, remove it.

    if {[winfo exists $gui::gui(errorDbgWin)]} {
	destroy $gui::gui(errorDbgWin)
    }

    stack::resetWindow $msg
    var::resetWindow $msg
    result::resetWindow

    # Check to see if the current block has been deleted
    # (i.e. a dynamic block)

    if {![blk::exists [gui::getCurrentBlock]]} {
	code::resetWindow " "
	gui::setCurrentBlock {}
	gui::setCurrentFile  {}
	gui::setCurrentLine  {}
	gui::updateStatusFile
    } else {
	code::resetWindow {}
    }
    # Remove cached blocks
    file::update 1

    focus $stack::stackText
    return
}

# gui::createDbgWindow --
#
#	Create the Stack, Var and CodeView Windows, placing
#	scrolling panes between the Stack and Var Window, and
#	another between the Stack/Var windows and the CodeView
#	window.
#
# Arguments:
#	mainDbgWin	The toplevel window for the main debugger.
#
# Results:
#	The handle to the frame that contains all of the sub windows.

proc gui::createDbgWindow {mainDbgWin} {
    set dbgFrm  [frame $mainDbgWin.dbg]
    set dataFrm [frame $dbgFrm.data]
    pack propagate $dbgFrm  off
    pack propagate $dataFrm off

    # Create the Stack Window.  The return of this call is the
    # handle to the frame of the Stack Window.

    set stackFrm [stack::createWindow $dataFrm]

    # Create the Var Window.  The return of this call is the
    # handle to the frame of the Var Window.

    set varFrm [var::createWindow $dataFrm]

    # Create the CodeView Window.  The return of this call is the
    # handle to the frame of the CodeView Window.

    set codeFrm [code::createWindow $dbgFrm]

    # Make Pane frame of stack & var frames.

    guiUtil::paneCreate $stackFrm $varFrm \
	    -in $dataFrm -orient horz -percent 0.3

    # Make Pane frame of top & code frames.

    guiUtil::paneCreate $dataFrm $codeFrm \
	    -in $dbgFrm -orient vertical -percent 0.3

    bind::addBindTags $stack::stackText mainDbgWin
    bind::addBindTags $var::valuText    mainDbgWin
    bind::addBindTags $code::codeWin    mainDbgWin
    bind::commonBindings mainDbgWin [list \
	    $stack::stackText $var::valuText $code::codeWin]
    return $dbgFrm
}

# gui::showCode --
#
#	Update the Code Window, CodeBar and Status message
#	without affecting the other windows.
#
# Arguments:
#	loc	The location opaque type that contains the
#		block of code to view and the line number
#		within the body to see.
#
# Results:
#	None.

proc gui::showCode {loc} {
    code::updateWindow $loc
    code::updateCodeBar
    gui::updateStatusFile
    file::pushBlock [loc::getBlock $loc]
    return
}

# gui::resultHandler --
#
#	Callback executed when the nub sends a result message.
#	Notify the Eval Window of the result and update the
#	variable windows in case the eval changed the var frames.
#
# Arguments:
#	code		A standard Tcl result code for the evaled cmd.
#	result		A value od the result for the evaled cmd.
#	errCode		A standard Tcl errorCode for the evaled cmd.
#	errInfo		A standard Tcl errorInfo for the evaled cmd.
#
# Results:
#	None.

proc gui::resultHandler {id code result errCode errInfo} {
    if {[info exists gui::afterID]} {
	after cancel $gui::afterID
    }
    evalWin::evalResult $id $code $result $errCode $errInfo

    file::update
    gui::setCurrentBreak result
    gui::changeState stopped

    gui::updateStatusMessage -state 1 -msg "eval result"
    set gui::msgAfterID [after $gui::afterTime {
	gui::updateStatusMessage -state 1 -msg [gui::getCurrentState]
    }]
    return
}

# gui::varbreakHandler --
#
#	Update the debugger when a VBP is fired.  Store in the
#	GUI that the break occured because of a VBP so the
#	codeBar will draw the correct icon.
#
# Arguments:
#	var	The var that cused the break.
#	type	The type of operation performed in the var (w,u,r)
#
# Results:
#	None.

proc gui::varbreakHandler {var type} {
    gui::stoppedHandler var
    gui::updateStatusMessage -state 1 -msg "variable breakpoint"
    code::focusCodeWin
    return
}

# gui::linebreakHandler --
#
#	Update the debugger when a LBP is fired.  Store in the
#	GUI that the break occured because of a LBP so the
#	codeBar will draw the correct icon.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc gui::linebreakHandler {args} {
    gui::stoppedHandler line
    gui::updateStatusMessage -state 1 -msg [gui::getCurrentState]
    code::focusCodeWin
    return
}

# gui::cmdresultHandler --
#
#	Update the display when the debugger stops at the end of a
#	command with the result.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc gui::cmdresultHandler {args} {
    gui::stoppedHandler cmdresult
    gui::updateStatusMessage -state 1 -msg [gui::getCurrentState]
    code::focusCodeWin
    return
}

# gui::userbreakHandler --
#
#	This handles a users call to "debugger_break" it is
#	handled just like a line breakpoint - except that we
#	also post a dialog box that denotes this type of break.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc gui::userbreakHandler {args} {
    eval gui::linebreakHandler $args

    set str [lindex $args 0]
    if {$str == ""} {
	set msg "Script called debugger_break"
    } else {
	set msg $str
    }

    tk_messageBox -type ok -title "User Break" -message $msg -icon warning \
	    -parent $::gui::gui(mainDbgWin) 
    return
}

# gui::stoppedHandler --
#
#	Update the debugger when the app stops.
#
# Arguments:
#	breakType	Store the reason for the break (result, line, var...)
#
# Results:
#	None.

proc gui::stoppedHandler {breakType} {
    if {[info exists gui::afterID]} {
	after cancel $gui::afterID
    }
    if {[info exists gui::msgAfterID]} {
	after cancel $gui::msgAfterID
    }
    file::update
    gui::setCurrentBreak $breakType
    gui::changeState stopped
    gui::showCode [dbg::getPC]
    result::updateWindow
    bp::updateWindow
    gui::showMainWindow
    dbg::Log timing {gui::stoppedHandler $breakType}
    return
}

# gui::exitHandler --
#
#	Callback executed when the nub sends an exit message.
#	Re-initialize the state of the Debugger and clear all
#	sub-windows.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc gui::exitHandler {} {
    if {[info exists gui::afterID]} {
	after cancel $gui::afterID
    }
    if {[info exists gui::msgAfterID]} {
	after cancel $gui::msgAfterID
    }

    # Remote projects stay alive for further connections.
    if {[proj::isRemoteProj]} {
	projWin::updatePort

	# HACK:  This is a big hairy work around due to the fact that
	# Windows does not recycle it's ports immediately.  If this
	# is not done, it will appear as though another app is using 
	# our port.

	if {$::tcl_platform(platform) == "windows"} {
	    after 300
	}
	proj::initPort
    }
    gui::changeState dead
    code::updateCodeBar
    gui::resetWindow "end of script..."
    gui::updateStatusMessage -state 1 -msg "end of script..."
    gui::updateStatusFile
    gui::showMainWindow
    return
}

# gui::errorHandler --
#
#	Show the error message in the error window.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc gui::errorHandler {errMsg errStk errCode uncaught} {
    variable uncaughtError

    gui::stoppedHandler error
    gui::updateStatusMessage -state 1 -msg "error"

    set uncaughtError $uncaught
    gui::showErrorWindow [dbg::getLevel] [dbg::getPC] \
	    $errMsg $errStk $errCode
    return
}

# gui::instrumentHandler --
#
#	Update Status Bar and Code Window before and after
#	a file is instrumented.
#
# Arguments:
#	status		Specifies if the file is starting to be instrumented
#			or finshed being instrumented ("start" or "end".)
#	blk		The block being instrumented.
#
# Results:
#	None.

proc gui::instrumentHandler {status block} {
    # Cancel any after events relating to message updates.
    # This is to prevent flicker or clobbering of more
    # current messages.

    if {[info exists gui::msgAfterID]} {
	after cancel $gui::msgAfterID
    }

    if {$status == "start"} {
	gui::updateStatusMessage -state 1 -msg \
		"instrumenting [blk::getFile $block]"
    } else {
	# We run the following code in an after event to avoid
	# unnecessary updates in the case of queued events.  The
	# following script will update the status bar and the
	# code window if the file being instrument was the one
	# we are currently displaying.

	set gui::msgAfterID [after $gui::afterTime {
	    gui::updateStatusMessage -state 1 -msg [gui::getCurrentState]
	}]
	if {[gui::getCurrentBlock] == $block} {
	    code::updateCodeBar
	}
    }
    return
}

# gui::instrumentErrorHandler --
#
#	An error occured during Instrumentation.  Show the error
#	and display the error message.  The user can choose from
#	one of three options:
#	  1) Instrument as much of the file as possible.
#	  2) Do not instrument the file
#	  3) Kill the running application.
#
# Arguments:
#	loc	The location of the error.
#
# Results:
#	Return 1 if the file should be instrumented as much as
#	possible, or 0 if the file should not be instrumented.

proc gui::instrumentErrorHandler {loc} {
    variable parseErrorVar

    set errorMsg [lindex $::errorCode end]
    if {[info exists gui::afterID]} {
	after cancel $gui::afterID
    }
    gui::resetWindow

    gui::setCurrentBreak error
    gui::changeState parseError
    gui::showCode $loc
    gui::updateStatusMessage -state 1 -msg "parse error"
    gui::showParseErrorWindow $errorMsg

    vwait gui::parseErrorVar
    switch $parseErrorVar {
	cont {
	    return 1
	}
	dont {
	    return 0
	}
	kill {
	    after 1 {catch dbg::kill}
	    return 0
	}
    }
}

# gui::attachHandler --
#
#	An application has attached itself to the debugger.
#	This event occurs if the application was started
#	from the GUI or attached remotely.
#
# Arguments:
#	projName	The name of the project.
#
# Results:
#	None.

proc gui::attachHandler {projName} {
    # Update the state in an after event, because there
    # may be events that will "immediately" cancel this
    # event.

    gui::changeState running
    set gui::afterID [after $gui::afterTime {
	if {[proj::isRemoteProj]} {
	    gui::run "dbg::step any"
	} else {
	    gui::run $gui::attachCmd
	}
	set gui::attachCmd {}
    }]
    set gui::msgAfterID [after $gui::afterTime "
	gui::updateStatusMessage -state 1 -msg \
		[list [list $projName] application attached]
    "]

    return
}

# gui::quit --
#
#	Wrapper around the dbg::quit command that removes the file caching
#	since the dbg::quit command destroys all blocks.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc gui::quit {} {
    dbg::quit
    file::update 1
    return
}

# gui::start --
#
#	This routine verifies the project arguments, initializes the port,
#	starts the application, and then sets the command to call when the
#	nub attaches to the debugger.
#
#
# Arguments:
#	cmd	The actual command that will cause the engine
#		to start running again.
#
# Results:
#	Return a boolean, 1 means that the start was successful, 0 means
#	the application could not be started.

proc gui::start {cmd} {
    if {[proj::isRemoteProj]} {
	set gui::attachCmd "dbg::step any"
	set result 1
    } else {
	if {![proj::checkProj]} {
	    return 0
	}

	set interp [lindex [pref::prefGet appInterpList] 0]
	set dir    [lindex [pref::prefGet appDirList]    0]
	set script [lindex [pref::prefGet appScriptList] 0]
	set arg    [lindex [pref::prefGet appArgList]    0]
	set proj   [file tail [proj::getProjectPath]]

	# Make the starting directory relative to the path of the project
	# file. If the script path is absolute, then the join does nothing.
	# Otherwise, the starting dir is relative from the project directory.
	
	if {![proj::projectNeverSaved]} {
	    set dir [file join [file dirname [proj::getProjectPath]] $dir]
	}

	# Make sure the script path is absolute so we can source 
	# relative paths.  File joining the dir with the script 
	# will give us an abs path.

	set script [file join $dir $script]

	if {![dbg::setServerPort random]} {
	    # The following error should never occur.  It would mean that
	    # the "random" option of setServerPort was somehow broken or
	    # there were real network problems (like no socket support?).

	    tk_messageBox -icon error -type ok \
		-title "Network error" \
		-parent [gui::getParent] -message \
		"Could not find valid port."
	    return 0
	}

	# If there is an error loading the script, display the
	# error message in a tk_message box and return.

	if {[catch {dbg::start $interp $dir $script $arg $proj} msg]} {
	    tk_messageBox -icon error -type ok \
		-title "Application Initialization Error" \
		-parent [gui::getParent] -message $msg
	    set result 0
	} else {
	    # Set the attach command that gets called when the nub signals
	    # that it has attached.  Convert the "run" or "step" requests
	    # to commands that do not require a location.

	    if {$cmd == "dbg::run"} {
		set cmd "dbg::step run"
	    } elseif {$cmd == "dbg::step"} {
		set cmd "dbg::step any"
	    }
	    set gui::attachCmd $cmd

	    set result 1
	}
    }
    return $result
}

# gui::run --
#
#	Wrapper function around any command that changes the engine
#	to "running", (e.g. dbg::run and dbg::step).  The GUI needs
#	to update itself so it is in sync with the engine.
#
# Arguments:
#	cmd	The actual command that will cause the engine
#		to start running again.
#
# Results:
#	The result of evaluating the cmd.

proc gui::run {cmd} {
    dbg::Log timing {gui::run $cmd}

    # Dismiss the error dialog and take the default action

    if {[winfo exists $gui::gui(errorDbgWin)]} {
	gui::handleError
    }

    # If the current state is dead, we need to verify the app arguments
    # are valid, and start the application.  If any of these steps fail,
    # simply return.  If all steps succeed, set the gui state to running
    # and return.  When the nub connects, the step will be evaluated.

    if {[getCurrentState] == "dead"} {
	gui::start $cmd
	return
    }

    gui::setCurrentBreak {}
    gui::changeState running
    set gui::afterID [after $gui::afterTime {
	stack::resetWindow {}
	var::resetWindow   {}
	code::resetWindow  {}
	evalWin::resetWindow {}
    }]
    set gui::msgAfterID [after $gui::afterTime {
	gui::updateStatusMessage -state 1 -msg "running"
    }]

    return [eval $cmd]
}

# gui::runTo --
#
#	Instruct the debugger to run to the current insert point.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc gui::runTo {} {
    set loc [code::makeCodeLocation $code::codeWin [code::getInsertLine].0]
    gui::run [list dbg::run $loc]
    return
}

# gui::kill --
#
#	Update the Debugger when the debugged app is killed.
#
# Arguments:
#	None.
#
# Results:
#	Returns 0 if we actually killed the application,
#	returns 1 if the user canceled this action.

proc gui::kill {} {
    if {[info exists gui::afterID]} {
	after cancel $gui::afterID
    }
    set state [getCurrentState]

    # We don't need to kill it if it isn't running.  Also, we
    # need to check with the user to see if we want to kill.

    if {($state == "dead") || ($state == "new")} {
	return 0
    }
    if {[gui::askToKill]} {
	return 1
    }

    # Kill the debugger engine and update various GUI state
    # to reflect the change.

    dbg::kill
    gui::setCurrentBreak {}
    file::update 1
    if {[proj::isRemoteProj]} {
	proj::initPort
    }
    gui::changeState dead
    gui::resetWindow "script killed..."
    gui::updateStatusMessage -state 1 -msg "script killed"

    return 0
}

# gui::interrupt --
#
#	Update the Debugger when an interrupt is requested.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc gui::interrupt {} {
    if {[gui::getCurrentState] == "running"} {
	gui::updateStatusMessage -state 1 -msg "interrupt pending"
	dbg::interrupt
    }
    return
}

# gui::changeState --
#
#	This is the state management routine.  Whenever there is
# 	a change of state (new, running, stopped or dead) this
#	routine updates the menu , toolbar and any bindings.
#
# Arguments:
#	state	The new state of the GUI.
#
# Results:
#	None.

proc gui::changeState {state} {

    gui::setCurrentState $state

    switch -exact -- $state {
	new {
	    tool::changeState {
		run stepIn stepOut stepOver stepTo stepResult stop kill restart
	    } disabled

	    if {![bind::tagExists $stack::stackText disableButtons]} {
		bind::addBindTags $stack::stackText \
			{mainDbgWin disableKeys disableButtons}
		bind::addBindTags $var::valuText \
			{mainDbgWin disableKeys disableButtons}
		bind::addBindTags $var::nameText \
			{mainDbgWin disableKeys disableButtons}
	    }
	}
	parseError {
	    tool::changeState {
		run stepIn stepOut stepOver stepTo stepResult stop kill restart
	    } disabled
	    if {![bind::tagExists $stack::stackText disableButtons]} {
		bind::addBindTags $stack::stackText \
			{mainDbgWin disableKeys disableButtons}
		bind::addBindTags $var::valuText \
			{mainDbgWin disableKeys disableButtons}
		bind::addBindTags $var::nameText \
			{mainDbgWin disableKeys disableButtons}
	    }
	}
	stopped {
	    tool::changeState {stop} disabled
	    tool::changeState {
		run stepIn stepOut stepOver stepTo stepResult kill restart
	    } normal

	    gui::setCurrentPC    [dbg::getPC]
	    gui::setCurrentLevel [dbg::getLevel]

	    # If the app is connected remotely, disable the restart
	    # button because it will restart the wrong project.

	    if {[proj::isRemoteProj]} {
		tool::changeState restart disabled
	    }

	    if {[bind::tagExists $stack::stackText disableButtons]} {
		bind::removeBindTag $stack::stackText mainDbgWin
		bind::removeBindTag $stack::stackText disableKeys
		bind::removeBindTag $stack::stackText disableButtons
		bind::removeBindTag $var::valuText    mainDbgWin
		bind::removeBindTag $var::valuText    disableKeys
		bind::removeBindTag $var::valuText    disableButtons
		bind::removeBindTag $var::nameText    mainDbgWin
		bind::removeBindTag $var::nameText    disableKeys
		bind::removeBindTag $var::nameText    disableButtons
	    }
	    watch::varDataReset
	    stack::updateWindow [dbg::getLevel]
	    var::updateWindow
	}
    	running {
	    gui::setCurrentPC {}

	    tool::changeState {
		run stepIn stepOut stepOver stepTo stepResult
	    } disabled
	    tool::changeState {stop kill restart} normal

	    # If the app is connected remotely, disable the restart
	    # button because it will restart the wrong project.

	    if {[proj::isRemoteProj]} {
		tool::changeState restart disabled
	    }

	    if {![bind::tagExists $stack::stackText disableButtons]} {
		bind::addBindTags $stack::stackText \
			{mainDbgWin disableKeys disableButtons}
		bind::addBindTags $var::valuText \
			{mainDbgWin disableKeys disableButtons}
		bind::addBindTags $var::nameText \
			{mainDbgWin disableKeys disableButtons}
	    }
	}
	dead {
	    gui::setCurrentPC {}
	    bp::updateWindow

	    if {[proj::isRemoteProj]} {
		tool::changeState {run stepIn} disabled
	    } else {
		tool::changeState {run stepIn} normal
	    }
	    tool::changeState {
		stepOut stepOver stepTo stepResult stop kill restart
	    } disabled

	    if {![bind::tagExists $stack::stackText disableButtons]} {
		bind::addBindTags $stack::stackText \
			{mainDbgWin disableKeys disableButtons}
		bind::addBindTags $var::valuText \
			{mainDbgWin disableKeys disableButtons}
		bind::addBindTags $var::nameText \
			{mainDbgWin disableKeys disableButtons}
	    }
	}
	default {
	    error "Unknown state \"$state\": in gui::changeState proc"
	}
    }

    # Enable the refresh button if the current block is associated
    # with a file that is currently instrumented.

    if {([gui::getCurrentFile] == {}) \
	    || ([blk::isInstrumented [gui::getCurrentBlock]])} {
	tool::changeState {refreshFile} disabled
    } else {
	tool::changeState {refreshFile} normal
    }

    tool::updateMessage $state
    watch::updateWindow
    evalWin::updateWindow
    procWin::updateWindow

    # If coverage is on, update the coverage window

    if {$::coverage::coverageEnabled} {
	coverage::updateWindow
    }

    inspector::updateWindow
    projWin::updateWindow
    gui::showConnectStatus update
}

# gui::askToKill --
#
#	Popup a dialog box that warns the user that their requested
#	action is destructive.  If the current GUI state is "running"
#	or "stopped", then certain actions will terminate the debugged
#	application (e.g. kill, restart, etc.)
#
# Arguments:
#	None.
#
# Results:
#	Returns 0 if it is OK to continue or 1 if the action
#	should be terminated.

proc gui::askToKill {} {
    if {[pref::prefGet warnOnKill] == 0} {
	return 0
    }
    set state [gui::getCurrentState]
    if {($state == "stopped") || ($state == "running")} {
	set but [tk_messageBox -icon warning -type okcancel \
		-title "Warning" -parent [gui::getParent] \
		-message "This command will kill the running application."]
	if {$but == "cancel"} {
	    return 1
	}
    }
    return 0
}

# gui::getParent --
#
#	Return the parent window that a tk_messageBox should use.
#
# Arguments:
#	None.
#
# Results:
#	A window name.

proc gui::getParent {} {
    if {[set parent [focus]] == {}} {
	return "."
    }
    return [winfo toplevel $parent]
}


#-----------------------------------------------------------------------------
# Default setting and helper routines.
#-----------------------------------------------------------------------------

# gui::setDbgTextBindings --
#
#	There are common bindings in debugger text windows that
# 	should shared between the code window, stack window, var
#	window etc.  These are:
#		1) Set the state to disabled -- readonly.
#		2) Specify the font to override any global settings
#		3) Set the wrap option to none.
#
# Arguments:
#	w	A text widget.
#	sb	If not null, then this is a scrollbar that needs
#		to be attached to the text widget.
#
# Results:
#	None.

proc gui::setDbgTextBindings {w {sb {}}} {
    variable gui

    # Add to the list of registered text widgets.
    lappend gui(dbgText) $w

    #
    # Configure the text widget to have common default settings.
    #

    # All text widgets share the same configuration for wrapping,
    # font displayed and padding .

    $w configure -wrap none -padx 4 -pady 1 \
	-font dbgFixedFont  -highlightthickness 0 \
	-insertwidth 0 -cursor [system::getArrow]

    # If there is a value for a scrollbar, set the yscroll callback
    # to display the scrollbar only when needed.

    if {$sb != {}} {
	$w configure -yscroll [list gui::scrollDbgText $w $sb \
	    [list place $sb -in $w -anchor ne -relx 1.0 -rely 0.0 \
	    -relheight 1.0]]
	$sb configure -cursor [system::getArrow]
    }
    bind::removeBindTag $w Text

    #
    # Tag Attributes.
    #

    # Define the look for a region of disabled text.
    # Set off array names in the var window.
    # Define what highlighted lext looks like (e.g. indicating the
    # current stack level)

    $w tag configure disable -bg gray12 -borderwidth 0 -bgstipple gray12
    $w tag configure handle -foreground blue
    $w tag configure message -font $font::metrics(-fontItalic)
    $w tag configure left -justify right
    $w tag configure center -justify center
    $w tag configure right -justify right
    $w tag configure leftIndent -lmargin1 4 -lmargin2 4
    $w tag configure underline -underline on
    $w tag configure focusIn -relief groove -borderwidth 2
    $w tag configure highlight -background [pref::prefGet highlight]
    $w tag configure highlight_error -background \
	    [pref::prefGet highlight_error]
    $w tag configure highlight_cmdresult -background \
	    [pref::prefGet highlight_cmdresult]

    # Define the status window messages.

    $w tag bind stackLevel <Enter> {
	set gui::gui(statusMsgVar) \
		"Stack level as used by upvar."
    }
    $w tag bind stackType <Enter> {
	set gui::gui(statusMsgVar) \
		"Scope of the stack frame."
    }
    $w tag bind stackProc <Enter> {
	set gui::gui(statusMsgVar) \
		"Name of the procedure called."
    }
    $w tag bind stackArg <Enter> {
	set gui::gui(statusMsgVar) \
		"Argument passed to the procedure of this stack."
    }
    $w tag bind varName <Enter> {
	set gui::gui(statusMsgVar) \
		"The name of the variable"
    }
    $w tag bind varValu <Enter> {
	set gui::gui(statusMsgVar) \
		"The value of the variable."
    }
}

# gui::scrollDbgText --
#
#	Scrollbar command that displays the vertical scrollbar if it
#	is needed and removes it if there is nothing to to scroll.
#
# Arguments:
#	scrollbar	The scrollbar widget.
#	geoCmd		The command used to re-manage the scrollbar.
#	offset		Beginning location of scrollbar slider.
#	size		Size of the scrollbar slider.
#
# Results:
#	None.

proc gui::scrollDbgText {text scrollbar geoCmd offset size} {
    if {$offset == 0.0 && $size == 1.0} {
	set manager [lindex $geoCmd 0]
	$manager forget $scrollbar
    } else {
	# HACK: Try to minimize the occurance of an infinite
	# loop by counting the number of lines in the text
	# widget.  I am assuming that a scrollbar need at least
	# three lines of text in the text window otherwise it is
	# too big.  This will NOT work on all systems.

	# TODO: This hack needs to be cleaned up!!! - ray

	set line [expr {[lindex [split [$text index end] .] 0] - 1}]
	if {$line == 1} {
	    return
	} elseif {($line > 1) && ($line < 4)} {
	    set script [$text cget -yscroll]
	    $text configure -yscroll {}
	    $text configure -height $line
	    after 100 "catch {$text configure -yscroll \[list $script\]}"
	    return
	}
	if {![winfo ismapped $scrollbar]} {
	    eval $geoCmd
	}
	$scrollbar set $offset $size
    }
    return
}

# gui::scrollDbgTextX --
#
#	Scrollbar command that displays the horizontal scrollbar if
#	it is needed.
#
# Arguments:
#	scrollbar	The scrollbar widget.
#	geoCmd		The command used to re-manage the scrollbar.
#	offset		Beginning location of scrollbar slider.
#	size		Size of the scrollbar slider.
#
# Results:
#	None.

proc gui::scrollDbgTextX {scrollbar geoCmd offset size} {

    if {$offset != 0.0 || $size != 1.0} {
	eval $geoCmd
    }
    $scrollbar set $offset $size
    return
}

#-----------------------------------------------------------------------------
# APIs for formatting text and adding elipses.
#-----------------------------------------------------------------------------

# gui::getDbgText --
#
#	Get a list of registered text widgets.  Whenever a text
#	widget uses the gui::setDbgTextBindings proc, that
#	widget becomes registered.  Whenever the prefs updates
#	the configuration, all registered text widgets are
#	updated.
#
# Arguments:
#	None.
#
# Results:
#	Return a list of registered text widgets.  When windows
#	are destroied they are not removed from this list, so it
#	is still necessary to check for window existence.

proc gui::getDbgText {} {
    return $gui::gui(dbgText)
}

# gui::updateDbgText --
#
#	Update all of the registered Dbg text widgets to
#	a current preferences.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc gui::updateDbgText {} {

    # Update the font family used by all dbg text widgets.

    font::configure [pref::prefGet fontType] [pref::prefGet fontSize]

    # Foreach formatted text widget, redo the formatting so it
    # is consistent with any new preferences.

    foreach {win side} [gui::getFormattedTextWidgets] {
	if {[winfo exists $win]} {
	    gui::formatText $win $side
	}
    }
    return
}

# gui::updateTextHighlights --
#
#	Update all of the registered Dbg text widgets to
#	a current highlight preferences.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc gui::updateDbgHighlights {} {
    # Reset the tag configurations for all dbg text widgets.

    foreach win [gui::getDbgText] {
	if {[winfo exists $win]} {
	    $win tag configure highlight \
		    -background [pref::prefGet highlight]
	    $win tag configure highlight_error \
		    -background [pref::prefGet highlight_error]
	    $win tag configure highlight_cmdresult \
		    -background [pref::prefGet highlight_cmdresult]
	}
    }
    return
}

# gui::formatText --
#
#	This command will trim, if nexessary, the display of every
#	viewable line in the text widget and append an elipse to
#	provide feedback that the line was trimmed.
#
#	Any highlighiting on strings that are formatted will be
#	destroied.  The caller of this function must maintain
#	their own highlighting.
#
# Arguments:
#	text	The text widget to format.
#	side	The side to place the elipse if necessary (left or right.)
#
# Results:
#	None.

proc gui::formatText {text side} {
    variable format

    # Restore the text to it previous glory.  The tear it apart
    # all over again.  Do this because it makes it easier to
    # restore text that might have previously been formatted.

    gui::unformatText $text

    if {$side == "left"} {
	$gui::fileText xview moveto 1
    }

    # Get a list of all the viewable lines and cache the
    # index as well as the result of calling dlineinfo.

    set end [$text index end]
    set viewable {}
    for {set i 1} {$i < $end} {incr i} {
	if {[set info [$text dlineinfo $i.0]] != {}} {
	    lappend viewable [list $i.0 $info]
	}
    }

    foreach view $viewable {
	set index [lindex $view 0]
	set info  [lindex $view 1]
	set delta 0
	switch $side {
	    right {
		set textWidth [winfo width $text]
		set lineWidth [expr {[lindex $info 2] + \
			(2 * [$text cget -padx]) + 4}]
		if {$lineWidth > $textWidth} {
		    # If the trimStart is < the linestart then the
		    # viewable region is less then three chars.  Set
		    # the trimStart to the beginning of the line.

		    set y [expr {[lindex $info 1] + 4}]
		    set trimStart [$text index "@$textWidth,$y - 3c"]
		    if {[$text compare $trimStart < "$index linestart"]} {
			set trimStart "$index linestart"
		    }
		    set trimEnd     [$text index "$index lineend"]
		    set trimIndex   $trimStart
		    set elipseStart $trimStart
		    set elipseEnd   [$text index "$trimStart + 3c"]

		    set delta 1
		}
	    }
	    left {
		if {[lindex $info 0] < 0} {
		    set x [lindex $info 0]
		    set y [expr {[lindex $info 1] + 4}]
		    set trimStart   [$text index "$index linestart"]
		    set trimEnd     [$text index "@$x,$y + 3c"]
		    set trimIndex   $trimEnd
		    set elipseStart [$text index "$index linestart"]
		    set elipseEnd   [$text index "$elipseStart + 3c"]

		    set delta 1
		}
	    }
	    default {
		error "unknown format side \"$side\""
	    }
	}
	if {$delta} {
	    # Extract the text that we are about to delete and
	    # cache it so it can be restored later.

	    set str  [$text get $trimStart $trimEnd]
	    set tags [$text tag names $trimIndex]

	    $text delete $trimStart $trimEnd
	    $text insert $elipseStart "..." $tags
	    set format($text,$index) [list $trimStart $trimEnd \
		    $elipseStart $elipseEnd $trimIndex $side $str]
	    unset str tags
	}
    }
}

# gui::unformatText --
#
# 	Restore any previously trimmed strings to their
# 	original value.  This is necessary when the
# 	viewable region changes (scrolling) and we do not
# 	have line info for lines out of the viewavle region.
#
# Arguments:
#	text	The text widget to format.
#
# Results:
#	None.

proc gui::unformatText {text} {
    variable format

    foreach name [array names format $text,*] {
	set trimStart   [lindex $format($name) 0]
	set trimEnd     [lindex $format($name) 1]
	set elipseStart [lindex $format($name) 2]
	set elipseEnd   [lindex $format($name) 3]
	set trimIndex   [lindex $format($name) 4]
	set side        [lindex $format($name) 5]
	set str         [lindex $format($name) 6]

	set tags [$text tag names $trimIndex]
	$text delete $elipseStart $elipseEnd
	$text insert $elipseStart $str $tags
	unset format($name)
    }
}

# gui::unsetFormatData --
#
#	Delete all format data.  This proc should be called
#	prior to the contents of a text widget being deleted.
#
# Arguments:
#	text	The formatted text widget.
#
# Results:
#	None.

proc gui::unsetFormatData {text} {
    variable format
    foreach name [array names format $text,*] {
	unset format($name)
    }
}

# gui::getUnformatted --
#
#	Return the unformatted line at index.
#
# Arguments:
#	text	The formatted text widget.
#	index	The line to unformat and return.
#
# Results:
#	A string representing the unformatted line.

proc gui::getUnformatted {text index} {
    variable format

    if {[info exists format($text,$index)]} {
	set side      [lindex $format($text,$index) 5]
	set str       [lindex $format($text,$index) 6]
	switch $side {
	    right {
		set trimStart [lindex $format($text,$index) 0]
		set prefix [$text get "$index linestart" $trimStart]
		set result $prefix$str
	    }
	    left {
		set elipseEnd [lindex $format($text,$index) 3]
		set suffix [$text get $elipseEnd "$index lineend"]
		set result $str$suffix
	    }
	    default {
		error "unknown side \"$side\""
	    }
	}
    } else {
	set result [$text get "$index linestart" "$index lineend"]
    }
    return $result
}

# gui::getFormattedTextWidgets --
#
#	Get a list of the current text widgets that have formatting.
#
# Arguments:
#	None.
#
# Results:
#	Returns a list of formatetd text widgets and the side
#	they are formatted on.

proc gui::getFormattedTextWidgets {} {
    variable format

    # The array name is composed of <windowName>,<index>.
    # Strip off the index and use only the window name.
    # Set the value of the entry to the side the text
    # widget was formatted on.

    foreach name [array names format] {
	set win([lindex [split $name ","] 0]) [lindex $format($name) 5]
    }
    return [array get win]
}

#-----------------------------------------------------------------------------
# APIs for manipulating GUI state data.
#-----------------------------------------------------------------------------

# gui::getCurrentBreak --
#
#	Set or return the break type.
#
# Arguments:
#	type	The type of break that just occured.
#
# Results:
# 	Either line, var, error or cmdresult.

proc gui::getCurrentBreak {} {
    return $gui::gui(currentBreak)
}

proc gui::setCurrentBreak {type} {
    set gui::gui(currentBreak) $type
}

# gui::getCurrentArgs --
#
#	Set or return any args passed to the proc at
#	the current stack.
#
# Arguments:
#	argList		The list of args passed to the proc.
#
# Results:
#	The current args or empty string if none exists.

proc gui::getCurrentArgs {} {
    return $gui::gui(currentArgs)
}

proc gui::setCurrentArgs {argList} {
    set gui::gui(currentArgs) $argList
}

# gui::getCurrentBlock --
#
#	Set or return any args passed to the proc at
#	the current stack.
#
# Arguments:
#	blk	The new block being displayed.
#
# Results:
#	The current args or empty string if none exists.

proc gui::getCurrentBlock {} {
    return $gui::gui(currentBlock)
}

proc gui::setCurrentBlock {blk} {
    set gui::gui(currentBlock) $blk
}

# gui::getCurrentFile --
#
#	Set or return any args passed to the proc
#	at the current stack.
#
# Arguments:
#	file 	The name of the file being displayed.
#
# Results:
#	The current args or empty string if none exists.

proc gui::getCurrentFile {} {
    return $gui::gui(currentFile)
}

proc gui::setCurrentFile {file} {
    set gui::gui(currentFile) $file
}

# gui::getCurrentLevel --
#
#	Set or return the currently displayed stack level.
#
# Arguments:
#	level	The new stack level.
#
# Results:
#	The current stack level or empty string if none exists.

proc gui::getCurrentLevel {} {
    return $gui::gui(currentLevel)
}

proc gui::setCurrentLevel {level} {
    set gui::gui(currentLevel) $level
}

# gui::getCurrentLine --
#
#	Set or return the current line in the displayed body of code
#
# Arguments:
#	line	The new line number in the block being displayed.
#
# Results:
#	The current line or empty string if none exists.

proc gui::getCurrentLine {} {
    return $gui::gui(currentLine)
}

proc gui::setCurrentLine {line} {
    set gui::gui(currentLine) $line
}

# gui::getCurrentPC --
#
#	Set or return the current PC of the engine.
#
# Arguments:
#	pc	The new engine PC.
#
# Results:
#	The current PC location.

proc gui::getCurrentPC {} {
    return $gui::gui(currentPC)
}

proc gui::setCurrentPC {pc} {
    set gui::gui(currentPC) $pc
}

# gui::getCurrentProc --
#
#	Set or return the current proc name.  If the current
#	type is "proc" then this will contain the proc name
#	of the currently displayed stack.
#
# Arguments:
#	procName 	The new proc name.
#
# Results:
#	The current proc name or empty string if none exists.

proc gui::getCurrentProc {} {
    return $gui::gui(currentProc)
}

proc gui::setCurrentProc {procName} {
    set gui::gui(currentProc) $procName
}

# gui::getCurrentScope --
#
#	Set or return the current scope of the level.  If we
#	are in a proc this will return the proc name, otherwise
#	it returns the type (e.g.. global, source etc.)
#
# Arguments:
#	scope	The new GUI scope.
#
# Results:
#	The current scope.

proc gui::getCurrentScope {} {
    return $gui::gui(currentScope)
}

proc gui::setCurrentScope {scope} {
    set gui::gui(currentScope) $scope
}

# gui::getCurrentState --
#
#	Set or return the current state of the GUI.
#
# Arguments:
#	state	The new GUI state.
#
# Results:
#	The current state.

proc gui::getCurrentState {} {
    return $gui::gui(currentState)
}

proc gui::setCurrentState {state} {
    set gui::gui(currentState) $state
}

# gui::getCurrentType --
#
# 	Set or return the currently displayed stack type;
#	either the string "global" if the scope is global
#	or the the string "proc" if the stack is in a procedure.
#
# Arguments:
#	type	The new Stack type (proc, global, etc.)
#
# Results:
#	The current stack type or empty string if none exists.

proc gui::getCurrentType {} {
    return $gui::gui(currentType)
}

proc gui::setCurrentType {type} {
    set gui::gui(currentType) $type
}

# gui::getCurrentVer --
#
#	Set or return the current version of the
#	block being displayed.
#
# Arguments:
#	ver	The new block version.
#
# Results:
#	The current block version.

proc gui::getCurrentVer {} {
    return $gui::gui(currentVer)
}

proc gui::setCurrentVer {ver} {
    set gui::gui(currentVer) $ver
}

#-----------------------------------------------------------------------------
# Status Window Functions
#-----------------------------------------------------------------------------

# gui::createStatusWindow --
#
#	Create the status bar and initialize the status label.
#
# Arguments:
#	mainDbgWin	The toplevel window for the main debugger.
#
# Results:
#	The frame that contains the status window.

proc gui::createStatusWindow {mainDbgWin} {
    variable infoText
    variable instLbl
    variable fileText

    set bg     [$mainDbgWin cget -bg]
    set cursor [system::getArrow]

    set statusFrm [frame $mainDbgWin.status -borderwidth 0]
    set subFrm    [frame $statusFrm.subFrm]
    set infoFrm   [frame $subFrm.infoFrm]
    set infoText  [text $infoFrm.infoText -relief sunken -bd 2 \
	    -width 1 -height 1 -bg $bg -padx 2 \
	    -wrap none -cursor $cursor]
    set fillFrm   [frame $infoFrm.fillFrm -width 1]
    set fileFrm [frame $subFrm.fileFrm -width 0 -cursor $cursor]
    set instLbl [label $fileFrm.instLbl -relief sunken -bd 2 -bg $bg]
    set fileText  [text $fileFrm.fileText -relief sunken -bd 2 \
	    -width 0 -height 1 -bg $bg -padx 2 \
	    -wrap none -cursor $cursor]

    set width [expr {([font measure [$instLbl cget -font] "*"] * 2) + 4}]

    pack $infoText -side left -fill x -expand 1
    pack $fillFrm  -side left -fill x
    grid $instLbl  -row 0 -column 0 -sticky we
    grid $fileText -row 0 -column 1 -sticky we -padx 2
    grid columnconfigure $fileFrm 1 -weight 1
    grid columnconfigure $fileFrm 0 -minsize $width

    $subFrm configure -height [winfo reqheight $infoText]
    pack $subFrm -fill both -expand true
    guiUtil::paneCreate $infoFrm $fileFrm \
	    -in $subFrm -orient horz -percent 0.7

    $fileText tag configure right -justify right -rmargin 4
    bind::removeBindTag $infoText Text
    bind::removeBindTag $fileText Text
    bind $fileText <Configure> {
	gui::updateStatusFileFormat
    }
    $fileText tag bind lineStatus <Double-1> {
	goto::showWindow
    }
    gui::updateStatusMessage
    return $statusFrm
}

# gui::updateStatusMessage --
#
#	Set messages in the Status window.
#
# Arguments:
#	args	Ordered list of flag and value, used to set the
#		portions of the Status message.  Currently supported
#		flags are: -msg and -state
#
# Results:
#	None.

proc gui::updateStatusMessage {args} {
    variable infoText

    set a(-state) 0
    set a(-msg)  {}
    array set a $args

    # If the message is an empty string, display the current
    # GUI state information.  If the message type is 'state'
    # then we have a new GUI state, cache the message in the
    # gui array.

    if {$a(-msg) == {}} {
	set a(-msg) $gui::gui(statusStateMsg)
    }
    if {$a(-state)} {
	set gui::gui(statusStateMsg) $a(-msg)
    }
    $infoText delete 0.0 end
    $infoText insert 0.0 $a(-msg)
    return
}

# gui::updateStatusFile --
#
#	Set file and line info in the Status window.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc gui::updateStatusFile {} {
    variable fileText
    variable instLbl

    # Remove the existing text and any data stored
    # in the format database.

    gui::unformatText $fileText
    $fileText delete 0.0 end
    $instLbl configure -text " "

    if {[gui::getCurrentState] == "new"} {
	return
    }

    # Insert a "*" into the status if the block
    # is instrumented.

    set block [gui::getCurrentBlock]
    if {($block != {}) && ([blk::exists $block])} {
	set inst [blk::isInstrumented $block]
    } else {
	set inst 0
    }
    if {$inst} {
	$instLbl configure -text " "
    } else {
	$instLbl configure -text "*"
    }

    # Enable the refresh button if the current block is associated
    # with a file that is currently instrumented.

    set file [gui::getCurrentFile]
    if {($file == {}) || $inst} {
	tool::changeState {refreshFile} disabled
    } else {
	tool::changeState {refreshFile} normal
    }

    # Insert the name of the block being shown.

    if {$file == {}} {
	set file "<Dynamic Block>"
    }
    $fileText insert 0.0 "$file" right

    # Insert the line number that the cursor is on.

    set line [code::getInsertLine]
    if {$line != {}} {
	$fileText insert end " : $line" [list right lineStatus]
    }
    gui::updateStatusFileFormat
}

# gui::updateStatusLine --
#
#	Update the status line number.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc gui::updateStatusLine {} {
    variable fileText

    set update 0
    set line  [code::getInsertLine]
    set range [$fileText tag range lineStatus]
    if {$range == {}} {
	set update 1
    } else {
	foreach {start end} $range {
	    $fileText delete $start $end
	}

	set start [lindex [split [lindex $range 0] .] 1]
	set end   [lindex [split [lindex $range 1] .] 1]
	set oldLen [expr {$end - $start}]
	set newLen [string length $line]
	if {$oldLen != $newLen} {
	    set update 1
	}
    }
    $fileText insert end " : $line" [list right lineStatus]
    if {$update} {
	gui::formatText $fileText left
    }
}


# gui::updateStatusFileFormat --
#
#	Make sure that the rhs of the filename is
#	always viewable.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc gui::updateStatusFileFormat {} {
    variable afterStatus
    variable fileText

    if {[info exists afterStatus($fileText)]} {
	after cancel $afterStatus($fileText)
	unset afterStatus($fileText)
    }
    set afterStatus($fileText) [after 50 {
	gui::formatText $gui::fileText left
    }]
}

# gui::registerStatusMessage --
#
#	Add the <Enter> and <Leave> bindings to a widget
#	that displays the message after the mouse has
#	been in the widget for more then N seconds.
#
# Arguments:
#	win	The widget to add bindings to.
#	msg	The message to display.
#	delay	The number of ms. to wait before displaying the msg.
#
# Results:
#	None.

proc gui::registerStatusMessage {win msg {delay 1000}} {
    bind $win <Enter> "
	if \{\[%W cget -state\] == \"normal\"\} \{
	    set gui::afterStatus(%W) \[after $delay \\
		    \{gui::updateStatusMessage -msg \[list $msg\]\}\]
	\}
    "
    bind $win <Leave> "
	if \{\[info exists gui::afterStatus(%W)\]\} \{
	    after cancel \$gui::afterStatus(%W)
	    unset gui::afterStatus(%W)
	    gui::updateStatusMessage -msg {}
	\}
    "
}

#-----------------------------------------------------------------------------
# Error Window Functions
#-----------------------------------------------------------------------------

# gui::showErrorWindow --
#
#	Popup a dialog box that shows the error and asks how
#	to handle the error.
#
# Arguments:
#	level		The level the error occured in.
#	loc 		The <loc> opaque type where the error occured.
#	errMsg		The message from errorInfo.
#	errStack	The stack trace.
#	errCode		The errorCode of the error.
#
# Results:
#	The name of the toplevel window.

proc gui::showErrorWindow {level loc errMsg errStack errCode} {
    if {[info command $gui::gui(errorDbgWin)] == $gui::gui(errorDbgWin)} {
	gui::updateErrorWindow $level $loc $errMsg $errStack $errCode
	wm deiconify $gui::gui(errorDbgWin)
	focus -force $gui::gui(errorDbgWin)
	return $gui::gui(errorDbgWin)
    } else {
	gui::createErrorWindow
	gui::updateErrorWindow $level $loc $errMsg $errStack $errCode
	focus -force $gui::gui(errorDbgWin)
	return $gui::gui(errorDbgWin)
    }
}

# gui::createErrorWindow --
#
#	Create the Error Window.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc gui::createErrorWindow {} {
    variable errorInfoText
    variable errorInfoLabel
    variable errorInfoSuppress
    variable errorInfoDeliver

    set top [toplevel $gui::gui(errorDbgWin)]
    wm title $top "Tcl Error"
    wm minsize  $top 100 100
    wm transient $top $gui::gui(mainDbgWin)

    set bd 2
    set pad  6
    set pad2 [expr {$pad / 2}]

    set mainFrm  [frame $top.mainFrm -bd $bd -relief raised]
    set titleFrm [frame $mainFrm.titleFrm]
    set imageLbl [label $titleFrm.imageLbl -bitmap error]
    set errorInfoLabel   [message $titleFrm.msgLbl -aspect 500 -text \
	    "An error occured while executing the script:"]
    pack $imageLbl -side left
    pack $errorInfoLabel -side left
    set infoFrm [frame $mainFrm.infoFrm]
    set errorInfoText [text $infoFrm.errorInfoText -width 40 -height 10 \
	    -takefocus 0]
    set sb      [scrollbar $mainFrm.sb -command [list $errorInfoText yview]]
    pack $errorInfoText -side left -fill both -expand true
    pack $titleFrm -fill x -padx $pad -pady $pad
    pack $infoFrm -fill both -expand true -padx $pad -pady $pad

    set butWidth [string length {Suppress and Continue}]

    set butFrm  [frame $top.butFrm]
    set errorInfoSuppress  [button $butFrm.suppressBut \
	    -text "Suppress Error" -default normal \
	    -command {gui::handleError suppress} -width $butWidth]
    set errorInfoDeliver [button $butFrm.deliverBut \
	    -text "Deliver Error" -default normal \
	    -command {gui::handleError deliver} -width $butWidth]
    pack $errorInfoSuppress $errorInfoDeliver -side right -padx $pad
    bind $top <Return> {gui::handleError}
    pack $butFrm -side bottom -fill x -pady $pad2
    pack $mainFrm -side bottom -fill both -expand true -padx $pad -pady $pad

    gui::setDbgTextBindings $errorInfoText $sb
    bind::addBindTags $errorInfoText noEdit
    $errorInfoText configure -wrap word
}

# gui::updateErrorWindow --
#
#	Update the message in the Error Window.
#
# Arguments:
#	level		The level the error occured in.
#	loc 		The <loc> opaque type where the error occured.
#	errMsg		The message from errorInfo.
#	errStack	The stack trace.
#	errCode		The errorCode of the error.
#
# Results:
#	None.

proc gui::updateErrorWindow {level loc errMsg errStack errCode} {
    variable errorInfoLabel
    variable errorInfoSuppress
    variable errorInfoDeliver
    variable uncaughtError

    if {$uncaughtError} {
	$errorInfoLabel configure -text "An error occurred while \
running the script.\nThis error may not be caught by the application \
and will probably terminate the script unless it is suppressed."
	$errorInfoSuppress configure -default active
	$errorInfoDeliver configure -default normal
	focus $errorInfoSuppress
    } else {
	$errorInfoLabel configure -text "An error occurred while \
running the script.\nThis error will be caught by the application."
	$errorInfoSuppress configure -default normal
	$errorInfoDeliver configure -default active
	focus $errorInfoDeliver
    }
    $gui::errorInfoText insert 0.0 "$errStack"
}

# gui::handleError --
#
#	Determine whether the error should be suppressed, then destroy
#	the error window.
#
# Arguments:
#	option		"suppress" or "deliver", or "" to get default action
#
# Results:
#	None.

proc gui::handleError {{option {}}} {
    variable uncaughtError
    switch $option {
	deliver {
	    # Let the error propagate
	}
	suppress {
	    dbg::ignoreError
	}
	default {
	    # Take the default action for the dialog.

	    if {$uncaughtError} {
		dbg::ignoreError
	    }
	}
    }
    destroy $gui::gui(errorDbgWin)
    return
}

# gui::showParseErrorWindow --
#
#	Display a dialog reporting the parse error that
#	occured during instrumentation.  Provide the
#	user with three choices:
#	  1) Attempt the instrument as much as possible.
#	  2) Don't instrument this file.
#	  3) Kill the application.
#
# Arguments:
#	msg	The error message.
#
# Results:
#	The name of the top level window.

proc gui::showParseErrorWindow {msg} {
    if {[info command $gui::gui(parseDbgWin)] == $gui::gui(parseDbgWin)} {
	gui::updateParseErrorWindow $msg
	wm deiconify $gui::gui(parseDbgWin)
	focus -force $gui::gui(parseDbgWin)
	return $gui::gui(parseDbgWin)
    } else {
	gui::createParseErrorWindow
	gui::updateParseErrorWindow $msg
	focus -force $gui::gui(parseDbgWin)
	return $gui::gui(parseDbgWin)
    }
}

# gui::createParseErrorWindow --
#
#	Create the Parse Error Window.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc gui::createParseErrorWindow {} {
    variable parseInfoText

    set top [toplevel $gui::gui(parseDbgWin)]
    wm title $top "Parse Error"
    wm minsize  $top 100 100
    wm transient $top $gui::gui(mainDbgWin)
    wm protocol $top WM_DELETE_WINDOW { }

    set bd 2
    set pad  6
    set pad2 [expr {$pad / 2}]

    set mainFrm  [frame $top.mainFrm -bd $bd -relief raised]
    set titleFrm [frame $mainFrm.titleFrm]
    set imageLbl [label $titleFrm.imageLbl -bitmap error]
    set msgLbl   [label $titleFrm.msgLbl -text \
	    "The following error occured while instrumenting the script:"]
    pack $imageLbl -side left
    pack $msgLbl -side left
    set infoFrm [frame $mainFrm.infoFrm]
    set parseInfoText [text $infoFrm.parseInfoText -width 1 -height 3]
    set sb      [scrollbar $mainFrm.sb -command [list $parseInfoText yview]]
    pack $parseInfoText -side left -fill both -expand true
    pack $titleFrm -fill x -padx $pad -pady $pad
    pack $infoFrm -fill both -expand true -padx $pad -pady $pad

    set butWidth [string length {Continue Instrumenting}]

    set butFrm  [frame $top.butFrm]
    set contBut [button $butFrm.contBut -text "Continue Instrumenting" \
	    -command {gui::handleParseError cont} -width $butWidth]
    set dontBut [button $butFrm.dontBut -text "Do Not Instrument" \
	    -command {gui::handleParseError dont} -width $butWidth]
    set killBut [button $butFrm.killBut -text "Kill The Application" \
	    -command {gui::handleParseError kill} -width $butWidth]
    pack $killBut $dontBut $contBut -side right -padx $pad

    pack $butFrm -side bottom -fill x -pady $pad2
    pack $mainFrm -side bottom -fill both -expand true -padx $pad -pady $pad

    gui::setDbgTextBindings $parseInfoText $sb
    bind::addBindTags $parseInfoText noEdit
    $parseInfoText configure -wrap word
    focus $butFrm.killBut
    grab $top
    return
}

# gui::updateParseErrorWindow --
#
#	Update the display of the Parse Error Window to show
#	the parse error message and provide options.
#
# Arguments:
#	msg	The error msg.
#
# Results:
#	None.

proc gui::updateParseErrorWindow {msg} {
    variable parseInfoText

    $parseInfoText delete 0.0 end
    $parseInfoText insert 0.0 $msg
    return
}

# gui::handleParseError --
#
#	Notify the engine of the user choice in handling the
#	parse error.
#
# Arguments:
#	option		One of three options for handling
#			parse errors.
#
# Results:
#	No return value, but the parseErrorVar is set to the
#	user's option.

proc gui::handleParseError {option} {
    variable parseErrorVar

    grab release $gui::gui(parseDbgWin)
    destroy $gui::gui(parseDbgWin)
    set parseErrorVar $option
    return
}

#-----------------------------------------------------------------------------
# About Window Functions
#-----------------------------------------------------------------------------

# gui::showAboutWindow --
#
#	Present the About Box for the Debugger.
#
# Arguments:
#	None.
#
# Results:
#	This shows a modal dialog.  The window is destroyed and the
#	grab released when the user dismisses the window.  The window
#	name is returned immediately.

proc gui::showAboutWindow {} {
    if {[info exists debugger::parameters(aboutCmd)]} {
	return [eval $debugger::parameters(aboutCmd)]
    }

    catch {destroy .about}

    # Compute the screen size so we can constrain the size of the about box
    set w [winfo screenwidth .]
    set h [winfo screenheight .]

    # Create and measure the three images
    set img [image create photo -file $::debugger::parameters(aboutImage)]
    set img2 [image create photo -file $::debugger::libdir/images/logo.gif]
    set logoWidth [image width $img2]
    set imageHeight [image height $img]
    set imageWidth  [image width $img]

    # Inflate the values a little bit so we have some whitespace
    incr imageHeight 6
    incr imageWidth 6
    incr logoWidth 6

    # Create an undecorated toplevel
    set top [toplevel .about -bd 4 -relief raised]
    wm overrideredirect .about 1

    # This is a hack to get around a Tk bug.  Once Tk is fixed, we can
    # let the geometry computations happen off-screen
    wm geom .about 1x1
#    wm withdraw .about

    set f1 [frame .about.f -bg white]
    set f2 [frame $f1.f -bg white]
    set c [canvas $f2.c -bd 0 -bg white -highlightthickness 0]
    set t1 [$c create text 0 0 -anchor nw -text \
	    $::debugger::parameters(aboutCopyright)]
    set bbox [$c bbox $t1]

    # Make sure the registered name doesn't make us go off the screen
    set t1Width [expr {[lindex $bbox 2] - [lindex $bbox 0]}]
    if {$t1Width + $logoWidth + 50> $w} {
	set t1Width [expr {$w -$logoWidth - 50}]
    }

    set t1Height [expr {[lindex $bbox 3] - [lindex $bbox 1]}]

    # Align the text to the bottom of the splash gif and the right
    # edge of the logo gif
    $c coords $t1 $logoWidth $imageHeight

    # Align the url to the bottom left edge of the copyright
    set height [expr {$imageHeight + $t1Height}]
    set t2 [$c create text $logoWidth $height -anchor nw -tag url \
	    -fill blue -text "http://www.ajubasolutions.com"]

    set width [expr {$logoWidth + $t1Width}]

    if {$width < $imageWidth} {
	set width $imageWidth
    }

    # Center the image over the width of the canvas widget
    $c lower [$c create image [expr {$width/2}] 0 -image $img -anchor n]

    # Create the logo image, and put it a little above the text
    $c create image 0 [expr {$imageHeight-15}] -image $img2 -anchor nw

#    $::projectInfo::setupExtrasProc $c $width $height

    # Align the button to the bottom right corner of the copyright text
    set okBut [button $c.okBut -text "OK" \
	    -cursor [system::getArrow] -width 6 -default active \
	    -command {destroy .about}]
    set b1 [$c create window $width $height -anchor ne -window $okBut]

    set height [expr {[lindex [$c bbox $b1] 3]}]

    # Add a little space in the lower right corner
    incr width 4
    incr height 4
    $c conf -width $width -height $height

    pack $c  -fill both -expand 1
    pack $f1 -fill both
    pack $f2 -fill both -padx 6 -pady 6

    # To get rid of the flicker, first fix Tk so this works, then uncomment
    # the following line:

    update
    set width [winfo reqwidth .about]
    set height [winfo reqheight .about]
    set x [expr {($w/2) - ($width/2)}]
    set y [expr {($h/2) - ($height/2)}]

    wm deiconify .about
    wm geometry .about ${width}x${height}+${x}+${y}

    bind .about <1> {
	raise .about
    }
    $c bind url <Enter> " \
	    $c configure -cursor hand2
    "
    $c bind url <Leave> " \
	    $c configure -cursor [system::getArrow]
    "
    $c bind url <ButtonRelease-1> " \
	    destroy .about
	    system::openURL http://www.ajubasolutions.com
    "
    bind .about <Return> "
	$okBut invoke
    "

    # TODO: this easter egg should go away before we ship
    # Maybe we could have it add back our hack menu?
    bind $okBut <F12> {
	console show
	destroy .about; break
    }

    update
    focus $okBut
    grab -global .about

    # Return the about window so we can destroy it from external bindings
    # if necessary.
    return .about
}

# gui::showConnectStatus --
#
#	This command creates a new window that shows the status of
#	connection to the debugged application.
#
# Arguments:
#	update	(Optional) Use this when you want to update values
#		(it will only update the window if the window has
#		been created).  If the update argument is not given
#		then we create the connection status window.
#
# Results:
#	None.  A new window will be created (or updated).

proc gui::showConnectStatus {{update {}}} {
    set w .connectStatus
    set m $w.mainFrm
    set createWindow 1

    if {[winfo exists $w]} {
	set createWindow 0
    }
    if {$update != ""} {
	# Update case: Don't update values if window doesn't exist
	if {$createWindow} {
	    return
	}
    } else {
	# Create case: if window exists raise it to the top
	if {! $createWindow} {
	    raise $w
	}
    }

    if {$createWindow} {
	# Registering for "any" may be too aggressive.  However,
	# it ensures that we don't miss any state changes.
	dbg::register any gui::connectStatusHandler

	toplevel $w
	wm title $w "Connection Status"
	::guiUtil::positionWindow $w 
	wm minsize  $w 100 100
	wm transient $w $gui::gui(mainDbgWin)
	
	set m [frame $w.mainFrm -bd 2 -relief raised]
	pack $m -fill both -expand true -padx 6 -pady 6

	label $m.title -text "Status of connection to debugged application."
	text $m.t
	label $m.l1 -text "Project type:"
	label $m.r1
	label $m.l2 -text "Connect status:"
	label $m.r2
	label $m.l3 -text "Listening port:"
	label $m.r3
	label $m.l4 -text "Local socket info:"
	label $m.r4
	label $m.l5 -text "Peer socket info:"
	label $m.r5
	button $m.b -text "Close" -command "destroy $w" -default active
	bind $w <Return> "$m.b invoke; break"
	bind $w <Escape> "$m.b invoke; break"

	grid $m.title -columnspan 2 -pady 10
	#grid $m.t -columnspan 2
	grid $m.l1 -row 1 -column 0 -sticky e
	grid $m.r1 -row 1 -column 1 -sticky w
	grid $m.l2 -row 2 -column 0 -sticky e
	grid $m.r2 -row 2 -column 1 -sticky w
	grid $m.l3 -row 3 -column 0 -sticky e
	grid $m.r3 -row 3 -column 1 -sticky w
	grid $m.l4 -row 4 -column 0 -sticky e
	grid $m.r4 -row 4 -column 1 -sticky w
	grid $m.l5 -row 5 -column 0 -sticky e
	grid $m.r5 -row 5 -column 1 -sticky w
	grid $m.b -columnspan 2 -pady 10
    }

    # Update window with current values.
    set msg "Project type:\t"
    if {! [proj::isProjectOpen]} {
	append msg "No project open"
	$m.r1 configure -text "No project open"
    } elseif {[proj::isRemoteProj]} {
	$m.r1 configure -text "Remote"
	append msg "Remote"
    } else {
	$m.r1 configure -text "Local"
	append msg "Local"
    }
    append msg "\n"
    set statusList [dbg::getServerPortStatus]
    $m.r2 configure -text [lindex $statusList 0]
    $m.r3 configure -text [lindex $statusList 1]
    $m.r4 configure -text [lindex $statusList 2]
    $m.r5 configure -text [lindex $statusList 3]
    append msg "Connect status:\t[lindex $statusList 0]\n"
    append msg "Listening port:\t[lindex $statusList 1]\n"
    append msg "Sockname:\t[lindex $statusList 2]\n"
    append msg "Peername:\t[lindex $statusList 3]\n"
    $m.t delete 0.0 end
    $m.t insert 0.0 $msg

    update
    focus -force $m.b
}

# gui::connectStatusHandler --
#
#	This command is registered with the nub so we get
#	feedback on debugger state and can update the
#	connection status window if it is open.
#
# Arguments:
#	The first arg is type, the rest depend on the type.
#
# Results:
#	None.  May cause connection window to update.

proc gui::connectStatusHandler {args} {
    gui::showConnectStatus update
}

