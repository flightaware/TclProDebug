# toolbar.tcl --
#
#	This file implements the Tcl Debugger toolbar.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 

namespace eval tool {
    # Array used to store handles to all of the toolbar buttons.

    variable tool

    # Store the top frame of the toolbar.

    variable toolbarFrm
}

# tool::createWindow --
#
#	Load the button images, create the buttons and add the callbacks.
#
# Arguments:
#	mainDbgWin	The toplevel window for the main debugger.
#
# Results:
#	The handle to the frame that contains all of the toolbar buttons. 

proc tool::createWindow {mainDbgWin} {
    variable tool
    variable toolbarFrm

    set toolbarFrm [frame $mainDbgWin.tool -bd 2 -relief groove]

    set tool(run) [tool::createButton $toolbarFrm.runButt $image::image(run)  \
	    {Run until break or EOF.} \
	    {gui::run dbg::run}]
    set tool(into) [tool::createButton $toolbarFrm.intoButt $image::image(into) \
	    {Step into the next procedure.} \
	    {gui::run dbg::step}]
    set tool(over) [tool::createButton $toolbarFrm.overButt $image::image(over) \
	    {Step over the next procedure.} \
	    {gui::run {dbg::step over}}]
    set tool(out) [tool::createButton $toolbarFrm.outButt $image::image(out)  \
	    {Step out of the current procedure.} \
	    {gui::run {dbg::step out}}]
    set tool(to) [tool::createButton $toolbarFrm.toButt $image::image(to)  \
	    {Run to cursor.} \
	    {gui::runTo}]
    set tool(cmdresult) [tool::createButton $toolbarFrm.cmdresultButt \
	    $image::image(cmdresult)  \
	    {Step to result of current command.} \
	    {gui::run {dbg::step cmdresult}}]
    pack [frame $toolbarFrm.sep1 -bd 4 -relief groove -width 2] \
	    -pady 2 -fill y -side left
    set tool(stop) [tool::createButton $toolbarFrm.stopButt $image::image(stop) \
	    {Stop at the next instrumented statement.} \
	    {gui::interrupt}]
    set tool(kill) [tool::createButton $toolbarFrm.killButt $image::image(kill) \
	    {Kill the current application.} \
	    {gui::kill}]
    set tool(restart) [tool::createButton $toolbarFrm.restartButt \
	    $image::image(restart) \
	    {Restart the application.} \
            {proj::restartProj}]
    pack [frame $toolbarFrm.sep2 -bd 4 -relief groove -width 2] \
	    -pady 2 -fill y -side left
    set tool(refreshFile) [tool::createButton $toolbarFrm.refreshFileButt \
	    $image::image(refreshFile) \
	    {Refresh the current file.} \
            {menu::refreshFile}]

    pack [frame $toolbarFrm.sep3 -bd 4 -relief groove -width 2] \
	    -pady 2 -fill y -side left
    set tool(win_break) [tool::createButton $toolbarFrm.win_breakButt \
	    $image::image(win_break) \
	    {Display the Breakpoint Window.} \
	    {bp::showWindow}]
    set tool(win_eval) [tool::createButton $toolbarFrm.win_evalButt \
	    $image::image(win_eval) \
	    {Display the Eval Console Window.} \
	    {evalWin::showWindow}]
    set tool(win_proc) [tool::createButton $toolbarFrm.win_procButt \
	    $image::image(win_proc) \
	    {Display the Procedure Window.} \
	    {procWin::showWindow}]
    set tool(win_watch) [tool::createButton $toolbarFrm.win_watchButt \
	    $image::image(win_watch) \
	    {Display the Watch Variables Window.} \
	    {watch::showWindow}]

    return $toolbarFrm
}

# tool::addButton --
#
#	Append a new button at the end of the toolbar.
#
# Arguments:
#	name	The name of the button to create.
#	img	An image that has already beeen created.
#	txt 	Text to display in the help window.
#	cmd 	Command to execute when pressed.
#
# Results:
#	Returns the widget name for the button.

proc tool::addButton {name img txt cmd} {
    variable tool
    variable toolbarFrm
    
    set tool($name) [tool::createButton $toolbarFrm.$name $img \
	    $txt $cmd]
    return $tool($name)
}

# tool::createButton --
#
#	Create uniform toolbar buttons and add bindings.
#
# Arguments:
#	but	The name of the button to create.
#	img	An image that has already beeen created.
#	txt 	Text to display in the help window.
#	cmd 	Command to execute when pressed.
#	side 	The default is to add the on the left side of the
#		toolbar - you may pass right to pack from the other
#		side.
#
# Results:
#	The name of the button being created.

proc tool::createButton {but img txt cmd {side left}} {
    variable gui

    set but [button $but -image $img -command $cmd -relief flat \
	    -bd 1 -height [image height $img] -width [image width $img]]
    pack $but -side $side -pady 2

    gui::registerStatusMessage $but $txt 5
    tool::addButtonBindings $but

    return $but
}

# tool::addButtonBindings --
#
#	Add <Enter> and <Leave> bindings to the buttons so they raise and
#	lower as the mouse goes in and out of the button.  This routine
#	should be called after the gui::registerStatusMessage to assure 
#	the bindings are added in order.
#
# Arguments:
#	but	The button to add the bindings to.
#
# Results:
#	None.

proc tool::addButtonBindings {but} {
    bind $but <Enter> {+ 
        if {[%W cget -state] == "normal"} {
	    %W config -relief raised
	}
    }
    bind $but <Leave> {+
        %W config -relief flat
    }
}

# tool::updateMessage --
#
#	Update the status message displayed based on the state of the debugger.
#
# Arguments:
#	state	The new state of the debugger.
#
# Results:
#	None.

proc tool::updateMessage {state} {
    variable tool

    # Override all of the <Enter> and <Leave> bindings and add the new
    # message to display for the help message.

    switch -exact -- $state {
	new -
	parseError -
	stopped -
    	running {
	    gui::registerStatusMessage $tool(run) \
		    {Run until break or EOF.} 5
	    gui::registerStatusMessage $tool(into) \
		    {Step into the next procedure.} 5
	}
	dead {
	    gui::registerStatusMessage $tool(run) \
		    {Start app and run until break or EOF.} 5
	    gui::registerStatusMessage $tool(into) \
		    {Start app and step to first command.} 5
	}
	default {
	    error "Unknown state \"$state\": in tool::updateMessage"
	}
    }

    # Now add the bindings that raise and lower the toolbar buttons.

    tool::addButtonBindings $tool(run)
    tool::addButtonBindings $tool(into)

    return
}

# tool::changeState --
#
#	Update the state of the Toolbar buttons.
#
# Arguments:
#	buttonList	Names of the buttons to re-configure.
#	state 		The state all buttons in buttonList
#			will be configure to.
#
# Results:
#	None.

proc tool::changeState {buttonList state} {
    variable tool

    foreach button $buttonList {
	switch $button {
	    refreshFile -
	    restart -
	    run -
	    stop -
	    kill -
	    inspector {
		$tool($button) configure -state $state
		tool::changeButtonState $button $state
	    }
	    stepIn {
		$tool(into) configure -state $state
		tool::changeButtonState into $state
	    }
	    stepOut {
		$tool(out) configure -state $state
		tool::changeButtonState out $state
	    }
	    stepOver {
		$tool(over) configure -state $state
		tool::changeButtonState over $state
	    }
	    stepTo {
		$tool(to) configure -state $state
		tool::changeButtonState to $state
	    }
	    stepResult {
		$tool(cmdresult) configure -state $state
		tool::changeButtonState cmdresult $state
	    }
	    showStack {
		$tool(stack) configure -state $state
		tool::changeButtonState stack $state
	    }
	    default {
		error "Unknown toolbar item \"$button\": in tool::changeState"
	    }
	}
    }
}

# tool::changeButtonState --
#
#	Change the state of the button.
#
# Arguments:
#	but	Name of the button.
#	state	New state.
#
# Results:
#	None.

proc tool::changeButtonState {but state} {
    variable tool

    if {$state == "disabled"} {
	$tool($but) configure -image $image::image(${but}_disable)
    } else {
	$tool($but) configure -image $image::image($but)
    }		    
}


