# dbg.tcl
#
#	This file implements the debugger API.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
#

package require parser

namespace eval dbg {

    # debugging options --
    #
    # Fields:
    #   debug		Set to 1 to enable debugging output.
    #	logFile		File handle where logging messages should be written.
    #	logFilter	If non-null, contains a regular expression that will
    #			be compared with the message type.  If the message
    #			type does not match, it is not logged.

    variable debug 0
    variable logFile stderr
    variable logFilter {}

    # startup options --
    #
    # Fields:
    #   libDir		The directory that contains the debugger scripts.

    variable libDir {}
    
    # nub communication data structure --
    #
    #	Communication with the nub is performed using a socket.  The
    #	debugger creates a server socket that a nub will connect to
    #	when starting.  If the nub is started by the debugger, then 
    #	the process id is also recorded.
    #
    # Fields:
    #	nubSocket	Socket to use to communicate with the
    #			currently connected nub.  Set to -1 if no
    #			nub is currently connected. 
    #	serverSocket	Socket listening for nub connect requests.
    #	serverPort	Port that the server is listening on.
    #	appPid		Process ID for application started by the debugger.
    #	appHost		Name of host that nub is running on.
    #   appVersion 	The tcl_version of the running app.

    variable nubSocket -1
    variable serverSocket -1
    variable serverPort -1
    variable appPid
    variable appHost    {}
    variable appVersion {}

    # application state data structure --
    #
    #	appState	One of running, stopped, or dead.
    #	currentPC	Location information for statement where the app
    #			last stopped.
    #   currentLevel	Current scope level for use in uplevel and upvar.
    #	stack		Current virtual stack.

    variable appState "dead"
    variable currentPC {}
    variable currentLevel 0
    variable stack {}

    # debugger events --
    #
    #	Asynchronous changes in debugger state will be reported to the GUI
    #	via event callbacks.  The set of event types includes:
    #
    #	any		Any of the following events fire.
    #   attach		A new client application has just attached to the
    #			debugger but has not stopped yet.
    #	linebreak 	The client application hit a line breakpoint.
    #	varbreak	The client application hit a variable breakpoint.
    #	userbreak	The client application hit a debugger_break command.
    #	exit		The application has terminated.
    #	result		An async eval completed.  The result string
    #			is appended to the callback script.
    #	error		An error occurred in the script.  The error message,
    #			error info, and error code are appended to the script.
    #   cmdresult	The client application completed the current command
    #			and is stopped waiting to display the result.  The
    #			result string is appended to the callback script.
    #
    #   All of the handlers for an event are stored as a list in the
    #   registeredEvent array indexed by event type.

    variable registeredEvent
    variable validEvents {
	any attach instrument linebreak varbreak userbreak
	error exit result cmdresult
    }

    # evaluate id generation --
    #
    #   evalId		A unique number used as the return ID for
    #			a call to dbg::evaluate.

    variable evalId 0

    # temporary breakpoint --
    #
    #   tempBreakpoint	The current run-to-line breakpoint.

    variable tempBreakpoint {}
}
# end namespace dbg

# dbg::start --
#
#	Starts the application.  Generates an error is one is already running.
#
# Arguments:
#	application	The shell in which to run the script.
#	startDir	the directory where the client program should be
#			started. 
#	script		The script to run in the application.
#	argList		A list of commandline arguments to pass to the script.
#	clientData	An opaque piece of data that will be passed through
#			to the nub and returned on the Attach event.
#
# Results:
#	None.

proc dbg::start {application startDir script argList clientData} {
    variable appState
    variable libDir
    variable serverPort

    if {$appState != "dead"} {
	error "dbg::start called with an app that is already started."
    }

    set oldDir [pwd]

    # Determine the start directory.  Relative paths are computed from the
    # debugger startup directory.

    if {[catch {
	# If the start directory is blank, use the debugger startup directory,
	# otherwise use the specified directory.

	if { $startDir != "" } {
	    cd $startDir
	}
	
	# start up the application

	if {$::tcl_platform(platform) == "windows"} {
	    set args ""
	    foreach arg [list \
		    [file nativename [file join $libDir appLaunch.tcl]] \
		    127.0.0.1 \
		    $serverPort \
		    [file nativename $script] \
		    $clientData] {
		if {([string length $arg] == 0) \
			|| ([string first " " $arg] != -1)} {
		    set quote 1
		} else {
		    set quote 0
		}
		regsub -all {(\\)*"} $arg {\1\1\\"} arg
		if {$quote} {
		    lappend args "\"$arg\""
		} else {
		    lappend args $arg
		}
	    }
	    exec {*}[auto_execok start] [file nativename $application] {*}$args {*}$argList \
		    [file nativename $startDir] &
	} else {
	    set args ""
	    # Ensure that the argument string is a valid Tcl list so we can
	    # safely pass it through eval.

	    if {[catch {
		foreach arg $argList {
		    lappend args $arg
		}
	    }]} {
		# The list wasn't valid so fall back to splitting on
		# spaces and ignoring null values.

		foreach arg [split [string trim $argList]] {
		    if {$arg != ""} {
			lappend args $arg
		    }
		}
	    }

        set _argv [list 127.0.0.1 $serverPort $script $clientData {*}$args]
        set _argc [llength $_argv]
        lappend _input variable argc $_argc argv $_argv
        set f [open [file join $libDir appLaunch.tcl]]
        exec $application <<$_input\n[read $f] &
        close $f
	}
    } msg]} {
	# Make sure to restore the original directory before throwing 
	# the error.

	cd $oldDir
	error $msg $::errorInfo $::errorCode
    }
    cd $oldDir
    return
}

# dbg::kill --
#
#	Kills the current application.  Generates an error if the application
#	is already dead.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc dbg::kill {} {
    variable appState
    variable nubSocket
    variable appHost
    variable appPid
    variable tempBreakpoint

    if {$appState == "dead"} {
	error "dbg::kill called with an app that is already dead."
    }

    # Try to kill the application process.
    if {[dbg::isLocalhost]} {
	catch {::kill $appPid}
    }

    HandleClientExit
    return
}

# dbg::step --
#
#	Runs the currently stopped application to the next instrumented
#	statement (at the level specified, if one is specified).
#	Generates an error if an application is currently running.
#
# Arguments:
#	level	The stack level at which to stop in the next instrumented
#		statement.
#
# Results:
#	None.

proc dbg::step {{level any}} {
    variable appState

    if {$appState != "stopped"} {
	error "dbg::step called with an app that is not stopped."
    }
    set appState "running"		

    Log timing {DbgNub_Run $level}
    SendAsync DbgNub_Run $level
    return
}

# dbg::evaluate --
#
#	This command causes the application to evaluate the given script
#	at the specified level.  When the script completes, a result
#	event is generated.
#	Generates an error if the application is not currently stopped.
#
# Arguments:
#	level	The stack level at which to evaluate the script.
#	script	The script to be evaluated by the application.
#
# Results:
#	Returns a unqiue id for this avaluate.  The id can be used
#	to match up the returned result.

proc dbg::evaluate {level script} {
    variable appState
    variable currentLevel
    variable evalId
    
    if {$appState != "stopped"} {
	error "dbg::evaluate called with an app that is not stopped."
    }

    if {$currentLevel < $level} {
	error "dbg::evaluate called with invalid level \"$level\""
    }

    incr evalId
    SendAsync DbgNub_Evaluate $evalId $level $script
    set appState "running"

    return $evalId
}

# dbg::run --
#
#	Runs the currently stopped application to either completion or the 
#	next breakpoint.  Generates an error if an application is not
#	currently stopped.
#
# Arguments:
#	location	Optional.  Specifies the location for a temporary
#			breakpoint that will be cleared the next time the
#			application stops.
#
# Results:
#	None.

proc dbg::run {{location {}}} {
    variable appState
    variable tempBreakpoint 

    if {$appState != "stopped"} {
	error "dbg::run called with an app that is not stopped."
    }

    # If requested, set a temporary breakpoint at the specified location.
    
    if {$location != ""} {
	 set tempBreakpoint [dbg::addLineBreakpoint $location]
    }
    
    # Run until the next breakpoint
    set appState "running"	
    SendAsync DbgNub_Run

    return
}

# dbg::interrupt --
#
#	Interrupts the currently running application by stopping at the next
#	instrumented statement or breaking into the event loop.
#	Generates an error if no application is currently running.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc dbg::interrupt {} {
    variable appState

    if {$appState != "running"} {
	error "dbg::interrupt called with an app that is not running."
    }

    # Stop at the next instrumented statement

    SendAsync DbgNub_Interrupt

    return
}

# dbg::register --
#
#	Adds a callback for the specified event type.  If the event is
#	not a valid event, an error is generated.
#
# Arguments:
#	event	Type of event on which to make the callback.
#	script	Code to execute when a callback is made.
#
# Results:
#	None.

proc dbg::register {event script} {
    variable registeredEvent
    variable validEvents

    if {[lsearch $validEvents $event] == -1} {
	error "dbg::register called with invalid event \"$event\""
    }
    lappend registeredEvent($event) $script
    return
}

# dbg::unregister --
#
#	Removes the callback specified by the event and script.  If the
#	specified script is not already registered with the given event,
#	an error is generated.
#
# Arguments:
#	event	Type of event whose callback to remove.
#	script	The script that was registered with the given event type.
#
# Results:
#	None.

proc dbg::unregister {event script} {
    variable registeredEvent

    if {[info exists registeredEvent($event)]} {

	set i [lsearch $registeredEvent($event) $script]

	if {$i == -1} {
	    error "dbg::unregister called with non-registered script \"$script\"."
	}
	set registeredEvent($event) [lreplace $registeredEvent($event) $i $i]
	return
    }
    error "dbg::unregister called with non-registered event \"$event\"."
}

# dbg::DeliverEvent --
#
#	Deliver an event to any scripts that have registered
#	interest in the event.
#
# Arguments:
#	event	The event to deliver.
#	args	Any arguments that should be passed to the script.
#		Note that we need to be careful here since the data
#		may be coming from untrusted code and may be dangerous.
#
# Results:
#	None.

proc dbg::DeliverEvent {event args} {
    variable registeredEvent

    # Break up args and reform it as a valid list so we can safely pass it
    # through uplevel.

    set newList {}
    foreach arg $args {
	lappend newList $arg
    }

    if {[info exists registeredEvent($event)]} {
	foreach script $registeredEvent($event) {
	    uplevel #0 $script $newList
	}
    }
    if {[info exists registeredEvent(any)]} {
	foreach script $registeredEvent(any) {
	    uplevel #0 $script $event $newList
	}
    }

    return
}

# dbg::getLevel --
#
#	Returns the stack level at which the application is currently
#	running.
#	Generates an error if the application is not currently stopped.
#
# Arguments:
#	None.
#
# Results:
#	Returns the stack level at which the application is currently
#	running.

proc dbg::getLevel {} {
    variable appState
    variable currentLevel
    
    if {$appState != "stopped"} {
	error "dbg::getLevel called with an app that is not stopped."
    }

    return $currentLevel
}

# dbg::getPC --
#
#	Returns the location which the application is currently
#	executing.
#	Generates an error if the application is not currently stopped.
#
# Arguments:
#	None.
#
# Results:
#	Returns the location which the application is currently
#	executing.

proc dbg::getPC {} {
    variable appState
    variable currentPC
    
    if {$appState != "stopped"} {
	error "dbg::getPC called with an app that is not stopped."
    }

    return $currentPC
}

# dbg::getStack --
#
#	Returns information about each frame on the current Tcl stack
#	up to the most closely nested global scope.  The format of the
#	stack information is a list of elements that have the
#	following form:
#		{level location type args ...}
# 	The level indicates the Tcl scope level, as used by uplevel.
#	The location refers to the location of the statement that is
#	currently executing (or about to be executed in the current
#	frame).  The type determines how the remainder of the
#	arguments are to be interpreted and should be one of the
#	following values:
#		global	The stack frame is outside of any procedure
#			scope.  There are no additonal arguments.
#		proc	The statement is inside a procedure.  The
#			first argument is the procedure name and the
#			remaining arguments are the names of the
#			procedure arguments.
#		source	This entry in the stack is a virtual frame
#			that corresponds to a change in block due to a
#			source command.  There are no arguments.
#	Eventually we will want to provide support for other virtual
#	stack frames so we can handle other forms of dynamic code that
#	are executed in the current stack scope (e.g. eval).  For now
#	we will only handle "source", since it is a critical case.
#
#	Generates an error if the application is not currently stopped.
#
# Arguments:
#	None.
#
# Results:
#	Returns a list of stack locations of the following form:
#		{level location type args ...}

proc dbg::getStack {} {
    variable appState
    variable stack

    if {$appState != "stopped"} {
	error "dbg::getStack called with an app that is not stopped."
    }

    return $stack
}

# dbg::getProcs --
#
#	Returns a list of all procedures in the application, excluding
#	those added by the debugger itself.  The list consists of
#	elements of the form {<procname> <location>}, where the
#	location refers to the entire procedure definition.  If the
#	procedure is uninstrumented, the location is null.
#	Generates an error if the application is not currently stopped.
#
# Arguments:
#	None.
#
# Results:
#	Returns a list of all procedures in the application, excluding
#	those added by the debugger itself.  The list consists of
#	elements of the form {<procname> <location>}.

proc dbg::getProcs {} {
    variable appState

    if {$appState != "stopped"} {
	error "dbg::getProcs called with an app that is not stopped."
    }

    return [Send DbgNub_GetProcs]
}

# dbg::getProcLocation --
#
#	Get a location that refers to the specified procedure.  This
#	function only works on uninstrumented procedures because the
#	location will refer to an uninstrumented procedure block.
#
# Arguments:
#	name	The name of the procedure.
#
# Results:
#	Returns a location that can be used to get the procedure
#	definition.

proc dbg::getProcLocation {name} {
    variable appState
    if {$appState != "stopped"} {
	error "dbg::getProcLocation called with an app that is not stopped."
    }
    blk::SetSource Temp [Send DbgNub_GetProcDef $name]
    return [loc::makeLocation Temp 1]
}

# dbg::getProcBody --
#
#	Given the location for an instrumented procedure we extract
#	the body of the procedure from the origional source and return
#	the uninstrumented body.  This is used, for example, by the
#	info body command to return the origional body of code.
#
# Arguments:
#	loc	The location of the procedure we want the body for.
#
# Results:
#	The uninstrumented body of the procedure.

proc dbg::getProcBody {loc} {
    # This function is more complicated that it would seem at first.  The
    # literal value from the script is an unsubstituted value, but we need the
    # substituted value that the proc command would see.  So, we need to parse
    # the commaand as a list, extract the body argument and then create a new
    # command to evaluate that will compute the resulting substituted body.
    # If we don't do all of this, any backslash continuation characters won't
    # get substituted and we'll end up with a subtly different body.

    set script [blk::getSource [loc::getBlock $loc]]
    set args [parse list $script [loc::getRange $loc]]
    eval set body [parse getstring $script [lindex $args 3]]
    return $body
}

# dbg::uninstrumentProc --
#
#	Given a fully qualified procedure name that is currently 
#	instrumented this procedure will insteract with the 
#	application to redefine the procedure as un uninstrumented
#	procedure.
#
# Arguments:
#	procName	A fully qualified procedure name.
#	loc		This is the location tag for the procedure
#			passing this makes the implementation go
#			much faster.
#
# Results:
#	None.

proc dbg::uninstrumentProc {procName loc} {
    set body [dbg::getProcBody $loc]
    SendAsync DbgNub_UninstrumentProc $procName $body
    return
}

# dbg::instrumentProc --
#
#	Given a fully qualified procedure name this function will
#	instrument the procedure body and redefine the proc to use
#	the new procedure body.
#
# Arguments:
#	procName	A fully qualified procedure name.
#	loc		The tmp loc for this procedure.
#
# Results:
#	None.

proc dbg::instrumentProc {procName loc} {
    set block [loc::getBlock $loc]
    set iscript [Instrument {} [blk::getSource $block]]
    SendAsync DbgNub_InstrumentProc $procName $iscript
    return
}

# dbg::getVariables --
#
#	Returns the list of variables that are visible at the specified
#	level.
#	Generates an error if the application is not currently stopped.
#
# Arguments:
#	level	The stack level whose variables are returned.
#	vars	List of variable names to fetch type info for.
#
# Results:
#	Returns the list of variables that are visible at the specified
#	level.

proc dbg::getVariables {level {vars {}}} {
    variable appState
    variable currentLevel

    if {$appState != "stopped"} {
	error "dbg::getVariables called with an app that is not stopped."
    }

    if {$currentLevel < $level} {
	error "dbg::getVar called with invalid level \"$level\""
    }

    return [Send DbgNub_GetVariables $level $vars]
}

# dbg::getVar --
#
#	Returns a list containing information about each of the
#	variables specified in varList.  The returned list consists of
#	elements of the form {<name> <type> <value>}.  Type indicates
#	if the variable is scalar or an array and is either "s" or
#	"a".  If the variable is an array, the result of an array get
#	is returned for the value, otherwise it is the scalar value.
#	Any names that were specified in varList but are not valid
#	variables will be omitted from the returned list.
#	Generates an error if the application is not currently stopped.
#
# Arguments:
#	level		The stack level of the variables in varList.
#	maxlen		The maximum length of any data element to fetch, may
#			be -1 to fetch everything.
#	varList		A list of variables whose information is returned.
#
# Results:
#	Returns a list containing information about each of the
#	variables specified in varList.  The returned list consists of
#	elements of the form {<name> <type> <value>}.

proc dbg::getVar {level maxlen varList} {
    variable appState
    variable currentLevel

    if {$appState != "stopped"} {
	error "dbg::getVar called with an app that is not stopped."
    }

    if {$currentLevel < $level} {
	error "dbg::getVar called with invalid level \"$level\""
    }

    return [Send DbgNub_GetVar $level $maxlen $varList]
}

# dbg::setVar --
#
#	Sets the value of a variable.  If the variable is an array,
#	the value must be suitable for array set, or an error is
#	generated.  If no such variable exists, an error is generated.
#	Generates an error if the application is not currently stopped.
#
# Arguments:
#	level	The stack level of the variable to set.
#	var	The name of the variable to set.
#	value	The new value of var.
#
# Results:
#	None.

proc dbg::setVar {level var value} {
    variable appState
    variable currentLevel

    if {$appState != "stopped"} {
	error "dbg::setVar called with an app that is not stopped."
    }

    if {$currentLevel < $level} {
	error "dbg::setVar called with invalid level \"$level\""
    }

    SendAsync DbgNub_SetVar $level $var $value
    return
}

# dbg::getResult --
#
#	Fetch the result and return code of the last instrumented statement
#	that executed.
#
# Arguments:
#	maxlen	Truncate long values after maxlen characters.
#
# Results:
#	Returns the list of {code result}.

proc dbg::getResult {maxlen} {
    variable appState
    if {$appState != "stopped"} {
	error "dbg::getVar called with an app that is not stopped."
    }

    return [Send DbgNub_GetResult $maxlen]
}


# dbg::addLineBreakpoint --
#
#	Set a breakpoint at the given location.  If no such location
#	exists, an error is generated.
#	Generates an error if an application is currently running.
#
# Arguments:
#	location	The location of the breakpoint to add.
#
# Results:
#	Returns a breakpoint identifier.

proc dbg::addLineBreakpoint {location} {
    variable appState
    
    if {$appState != "dead"} {
	SendAsync DbgNub_AddBreakpoint line $location
    }
    return [break::MakeBreakpoint line $location]
}

# dbg::getLineBreakpoints --
#
#	Get the breakpoints that are set on a given line, or all
#	line breakpoints.
#
# Arguments:
#	location	Optional. The location of the breakpoint to get.
#
# Results:
#	Returns a list of line-based breakpoint indentifiers.

proc dbg::getLineBreakpoints {{location {}}} {
    variable tempBreakpoint
    
    set bps [break::GetLineBreakpoints $location]
    if {$tempBreakpoint != ""} {
	set index [lsearch -exact $bps $tempBreakpoint]
	if {$index != -1} {
	    set bps [lreplace $bps $index $index]
	}
    }
    return $bps
}

# dbg::validateBreakpoints --
#
#	Get the list of prior bpts and valid bpts for the block.
#	Move invalid bpts that to nearest valid location.
#
# Arguments:
#	file	The name of the file for this block.
#	blk	Block for which to validate bpts.
#
# Results:
#	None.

proc dbg::validateBreakpoints {file blk} {

    set validLines [blk::getLines $blk]
    set bpLoc [loc::makeLocation $blk {}]
    set bpList [dbg::getLineBreakpoints $bpLoc]

    set warning 0
    foreach bp $bpList {
	set line [loc::getLine [break::getLocation $bp]]
	set newLine [dbg::binarySearch $validLines $line]
	if {$newLine != $line} {
	    set newLoc [loc::makeLocation $blk $newLine]
	    set newBp [dbg::moveLineBreakpoint $bp $newLoc]
	    set warning 1
	}
    }

    if {$warning && [pref::prefGet warnInvalidBp]} {
	set msg "invalid breakpoints found in $file have been moved to valid lines."

	tk_messageBox -icon warning -type ok -title "Warning" \
		-parent [gui::getParent] -message "Warning:  $msg"
    }
    return
}

# dbg::binarySearch --
#
#	Find the nearest matching line on which to move an invalid bpt.
#	Find the nearest matching value to elt in ls.
#
# Arguments:
#	ls	Sorted list of ints >= 0.
#	elt	Integer to match.
#
# Results:
#	Returns the closest match or -1 if ls is empty.

proc dbg::binarySearch {ls elt} {
    set len [llength $ls]
    if {$len == 0} {
	return -1
    }
    if {$len == 1} {
	return [lindex $ls 0]
    }
    if {$len == 2} {
	set e0 [lindex $ls 0]
	set e1 [lindex $ls 1]
	if {$elt <= $e0} {
	    return $e0
	} elseif {$elt < $e1} {
	    if {($elt - $e0) <= ($e1 - $elt)} {
		return $e0
	    } else {
		return $e1
	    }
	} else {
	    return $e1
	}
    }
    set middle [expr {$len / 2}]
    set result [lindex $ls $middle]
    if {$result == $elt} {
	return $result
    }
    if {$result < $elt} {
	return [dbg::binarySearch [lrange $ls $middle $len] $elt]
    } else {
	return [dbg::binarySearch [lrange $ls 0 $middle] $elt]
    }
}

# dbg::addVarBreakpoint --
#
#	Set a breakpoint on the given variable.
#
# Arguments:
#	level		The level at which the variable is accessible.
#	name		The name of the variable.
#
# Results:
#	Returns a new breakpoint handle.

proc dbg::addVarBreakpoint {level name} {
    variable appState

    if {$appState != "stopped"} {
	error "dbg::addVarBreakpoint called with an app that is not stopped."
    }

    set handle [Send DbgNub_AddVarTrace $level $name]
    SendAsync DbgNub_AddBreakpoint var $handle
    return [break::MakeBreakpoint var $handle]
}

# dbg::getVarBreakpoints --
#
#	Get the variable breakpoints that are set on a given variable.
#	If both level and name are null, then all variable breakpoints
#	are returned.
#
# Arguments:
#	level		The level at which the variable is accessible.
#	name		The name of the variable.
#
# Results:
#	The list of breakpoint handles.

proc dbg::getVarBreakpoints {{level {}} {name {}}} {
    variable appState

    if {$appState != "stopped"} {
	error "dbg::getVarBreakpoints called with an app that is not stopped."
    }
    if {$level == ""} {
	return [break::GetVarBreakpoints]
    }
    set handle [Send DbgNub_GetVarTrace $level $name]
    if {$handle != ""} {
	return [break::GetVarBreakpoints $handle]
    }
    return ""
}

# dbg::removeBreakpoint --
#
#	Remove the specified breakpoint.  If no such breakpoint
#	exists, an error is generated.
#	Generates an error if an application is currently running.
#
# Arguments:
#	breakpoint	The identifier of the breakpoint to remove.
#
# Results:
#	None.

proc dbg::removeBreakpoint {breakpoint} {
    variable appState
    
    if {$appState != "dead"} {
	SendAsync DbgNub_RemoveBreakpoint [break::getType $breakpoint] \
		[break::getLocation $breakpoint] [break::getTest $breakpoint]
	if {[break::getType $breakpoint] == "var"} {
	    SendAsync DbgNub_RemoveVarTrace [break::getLocation $breakpoint]
	}
    }

    break::Release $breakpoint
    return
}

# dbg::moveLineBreakpoint --
#
#	Remove the specified breakpoint.  If no such breakpoint
#	exists, an error is generated.  Add a new breakpoint on the
#	specified line.
#	Generates an error if an application is currently running.
#
# Arguments:
#	breakpoint	The identifier of the breakpoint to move.
#	newLoc		The new location for the breakpoint.
#
# Results:
#	Returnes the new breakpoint or "" if none was added.

proc dbg::moveLineBreakpoint {breakpoint newLoc} {
    variable appState
    
    set removedBpState [break::getState $breakpoint]
    dbg::removeBreakpoint $breakpoint

    # If there's already a bpt on "line"
    #    and it's enabled, then do nothing.
    #    and we removed a disabled one, then do nothing.
    # Otherwise, remove any pre-existing bpts, and add "breakpoint"
    # to its new line.

    set priorBpts [break::GetLineBreakpoints $newLoc]
    if {[llength $priorBpts] > 0} {
	if {$removedBpState == "disabled"} {
	    return ""
	}
	foreach priorBpt $priorBpts {
	    if {[break::getState $priorBpt] != "disabled"} {
		return ""
	    }
	}
	foreach priorBpt $priorBpts {
	    dbg::removeBreakpoint $priorBpt	    
	}
    }
    return [dbg::addLineBreakpoint $newLoc]
}

# dbg::disableBreakpoint --
#
#	Disable (without removing) the specified breakpoint.  If no such
#	breakpoint exists or if the breakpoint is already disabled, an
#	error is generated.
#	Generates an error if an application is currently running.
#
# Arguments:
#	breakpoint	The identifier of the breakpoint to disable.
#
# Results:
#	None.

proc dbg::disableBreakpoint {breakpoint} {
    variable appState
    
    if {$appState != "dead"} {
	SendAsync DbgNub_RemoveBreakpoint [break::getType $breakpoint] \
		[break::getLocation $breakpoint] [break::getTest $breakpoint]
    }

    break::SetState $breakpoint disabled
    return
}

# dbg::enableBreakpoint --
#
#	Enable the specified breakpoint.  If no such breakoint exists
#	or if the breakpoint is already enabled, an error is generated.
#	Generates an error if an application is currently running.
#
# Arguments:
#	breakpoint	The identifier of the breakpoint to enable.
#
# Results:
#	None.

proc dbg::enableBreakpoint {breakpoint} {
    variable appState
    
    if {$appState != "dead"} {
	SendAsync DbgNub_AddBreakpoint [break::getType $breakpoint] \
		[break::getLocation $breakpoint] [break::getTest $breakpoint]
    }
    
    break::SetState $breakpoint enabled
    return
}

# dbg::initialize --
#
#	Initialize the debugger engine.  Intializes the library
#	directory for the debugger.
#
# Arguments:
#	dir		Optional.  The directory containing the debugger
#			scripts.
#
# Results:
#	None.

proc dbg::initialize {{dir {}}} {
    variable libDir

    # Find the library directory for the debugger.  If one is not specified
    # look in the directory containing the startup script.

    if {$dir == {}} {
	set libDir [file dir [info nameofexecutable]]
    } else {
	set libDir $dir
    }

    set oldcwd [pwd]
    cd $libDir
    set libDir [pwd]
    cd $oldcwd

    return
}

# dbg::setServerPort --
#
#	This function sets the server port that the debugger listens on.
#	If another port is opened for listening, it is closed before the
#	new port is opened.
#
# Arguments:
#	port		The new port number the users wants.  If the
#			port arg is set to "random" then we find a
#			suitable port in a standard range.
#
# Results:
#	Return 1 if the new port was available and is now being used, 
#	returns 0 if we couldn't open the new port for some reason.
#	The old port will still work if we fail.

proc dbg::setServerPort {port} {
    variable serverSocket
    variable serverPort

    # If the current port and the requested port are identical, just
    # return 1, indicating the port is available.

    if {($serverSocket != -1) && ($serverPort == $port)} {
	return 1
    }
    
    # Close the port if it has been opened.

    dbg::closeServerSocket

    if {$port == "random"} {
	set result 1
	set port 16999
	while {$result != 0} {
	    incr port
	    set result [catch \
		    {socket -server ::dbg::HandleConnect $port} socket]
	}
    } else {
	set result [catch \
		{socket -server ::dbg::HandleConnect $port} socket]
    }

    if {$result == 0} {
	set serverPort $port
	set serverSocket $socket
    }
    return [expr {!$result}]
}

# dbg::getServerPortStatus --
#
#	This function returns status information about the connection
#	betwen the debugger and the debugged app.  The return is a
#	list of appState & serverPort.
#
# Arguments:
#	None.
#
# Results:
#	A Tcl list

proc dbg::getServerPortStatus {} {
    variable serverPort
    variable serverSocket
    variable nubSocket
    variable appHost

    if {$serverSocket == -1} {
	set status "Not connected"
	set listenPort "n/a"
    } else {
	set status "Listening"
	set listenPort "$serverPort (on [info hostname])"
    }

    if {$nubSocket != -1} {
	set status "Connected"
	set sockname [fconfigure $nubSocket -sockname]
	set peername [fconfigure $nubSocket -peername]
    } else {
	set sockname "n/a"
	set peername "n/a"
    }

    return [list $status $listenPort $sockname $peername]
}

# dbg::closeServerSocket --
#
#	Close the server socket so the debugger is no longer listening
#	on the open port.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc dbg::closeServerSocket {} {
    variable serverSocket
    if {$serverSocket != -1} {
	close $serverSocket
	set serverSocket -1
    }
    return
}

# dbg::quit --
#
#	Clean up the debugger engine.  Kills the background app if it
#	is still running and shuts down the server socket.  It also
#	cleans up all of the debugger state.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc dbg::quit {} {
    variable appState
    variable tempBreakpoint

    if {$appState != "dead"} {
	catch {dbg::kill}
    }
    dbg::closeServerSocket
    break::Release all
    set tempBreakpoint {}
    blk::release all
    return
}

# dbg::HandleClientExit --
#
#	This function is called when the nub terminates in order to clean up
#	various aspects of the debugger state.
#
# Arguments:
#	None.
#
# Results:
#	None.  Removes any variable traces, changes the state to dead,
#	and generates an "exit" event.

proc dbg::HandleClientExit {} {
    variable nubSocket
    variable appState
    variable appPid
    variable tempBreakpoint
    
    # Release all of the variable breakpoints.

    break::Release [break::GetVarBreakpoints]


    # Release all of the dynamic blocks and breakpoints.  We
    # also need to mark all instrumented blocks as uninstrumented.

    if {$tempBreakpoint != ""} {
	break::Release $tempBreakpoint
	set tempBreakpoint {}
    }
    foreach bp [break::GetLineBreakpoints] {
	set block [loc::getBlock [break::getLocation $bp]]
	if {[blk::isDynamic $block]} {
	    break::Release $bp
	}
    }
    
    set tempBreakpoint {}

    blk::release dynamic
    blk::unmarkInstrumented

    # Close the connection to the client.
    
    close $nubSocket
    set nubSocket -1
    set appState "dead"
    set appPid -1

    DeliverEvent exit
    return
}

# dbg::HandleConnect --
#
#	Handle incoming connect requests from the nub.  If there is no
#	other nub currently connected, creates a file event handler
#	to watch for events generated by the nub.
#
# Arguments:
#	sock	Incoming connection socket.
#	host	Name of nub host.
#	port    Incoming connection port.
#
# Results:
#	None.

proc dbg::HandleConnect {sock host port} {
    variable nubSocket
    variable appState

    if {$nubSocket != -1} {
	close $sock
    } else {
	set nubSocket $sock
	set appState running
	fconfigure $sock -translation binary -encoding utf-8
	fileevent $sock readable ::dbg::HandleNubEvent

	# Close the server socket
	dbg::closeServerSocket 
    }
    return
}

# dbg::SendMessage --
#
#	Transmit a list of strings to the nub.
#
# Arguments:
#	args	Strings that will be turned into a list to send.
#
# Results:
#	None.

proc dbg::SendMessage {args} {
    variable nubSocket

    puts $nubSocket [string length $args]
    puts -nonewline $nubSocket $args
    flush $nubSocket
    Log message {sent: len=[string length $args] '$args'}
    return
}

# dbg::GetMessage --
#
#	Wait until a message is received from the nub.
#
# Arguments:
#	None.
#
# Results:
#	Returns the message that was received, or {} if the connection
#	was closed.

proc dbg::GetMessage {} {
    variable nubSocket

    set bytes [gets $nubSocket]
    Log message {reading $bytes bytes}
    if { $bytes == "" } {
	return ""
    }
    set msg [read $nubSocket $bytes]
    Log message {got: '$msg'}
    return $msg
}

# dbg::SendAsync --
#
#	Send the given script to be evaluated in the nub without
#	waiting for a result.
#
# Arguments:
#	args	The script to be evaluated.
#
# Results:
#	None.

proc dbg::SendAsync {args} {
    SendMessage "SEND" 0 $args
    return
}

# dbg::Send --
#
#	Send the given script to be evaluated in the nub.  The 
#	debugger enters a limited event loop until the result of
#	the evaluation is received.  This call should only be used
#	for scripts that are expected to return quickly and cannot
#	be done in a more asynchronous fashion.
#
# Arguments:
#	args	The script to be evaluated.
#
# Results:
#	Returns the result of evaluating the script in the nub, 
#	including any errors that may result.

proc dbg::Send {args} {
    SendMessage "SEND" 1 $args
    while {1} {
	set msg [GetMessage]
	if {$msg == ""} {
	    return
	}
	switch -- [lindex $msg 0] {
	    RESULT {		# Result of SEND message
		return [lindex $msg 1]
	    }
	    ERROR {		# Error generated by SEND
		return -code [lindex $msg 2] -errorcode [lindex $msg 3] \
			-errorinfo [lindex $msg 4] [lindex $msg 1]
	    }
	    default {		# Looks like a bug to me
		error "Unexpected message waiting for reply: $msg"
	    }
	}
    }
}

# dbg::HandleNubEvent --
#
#	This function is called whenever the nub generates an event on
#	the nub socket.  It will invoke HandleEvent to actually 
#	process the event.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc dbg::HandleNubEvent {} {
    variable nubSocket
    variable currentPC
    variable appState
    variable stack
    variable currentLevel
    variable tempBreakpoint 


    set result [catch {

	# Get the next message from the nub

	set msg [GetMessage]

	# If the nub closed the connection, generate an "exit" event.

	if {[eof $nubSocket]} {
	    HandleClientExit
	    return
	}

	switch -- [lindex $msg 0] {
	    HELLO {
		if {[llength $msg] == 3} {
		    set project REMOTE
		} else {
		    set project [lindex $msg 3]
		}
		InitializeNub [lindex $msg 1] [lindex $msg 2] $project
	    }
	    ERROR {
		error "Got an ERROR from an asyncronous SEND: $msg"
	    }
	    RESULT {		# Result of SEND message, should not happen
		error "Got SEND result outside of call to dbg::Send; $msg"
	    }
	    BREAK {
		Log timing {HandleNubEvent BREAK}
		set appState "stopped"
		set stack [lindex $msg 1]
		set frame [lindex $stack end]
		set currentPC [lindex $frame 1]
		set currentLevel [lindex $frame 0]

		# Remove any current temporary breakpoint

		if {$tempBreakpoint != ""} {
		    dbg::removeBreakpoint $tempBreakpoint
		    set tempBreakpoint {}
		}

		# If coverage is on, retrieve and store coverage data

		if {$::coverage::coverageEnabled} {
		    coverage::tabulateCoverage [lindex $msg 2]
		}

		# Break up args and reform it as a valid list so we can safely
		# pass it through eval.

		set newList {}
		foreach arg [lindex $msg 4] {
		    lappend newList $arg
		}

		eval {DeliverEvent [lindex $msg 3]} $newList
	    }
	    INSTRUMENT {
		SendAsync DbgNub_InstrumentReply [Instrument [lindex $msg 1] \
			[lindex $msg 2]]
	    }
	    PROCBODY {
		set body [dbg::getProcBody [lindex $msg 1]]
		SendAsync array set DbgNub [list body $body state running]
	    }
	    UNSET {		# A variable was unset so clean up the trace
		set handle [lindex $msg 1]
		break::Release [break::GetVarBreakpoints $handle]
	    }
	    default {		# Looks like a bug to me
		Log error {Unexpected message: $msg}
	    }
	}
    } msg]
    if {$result == 1} {
	Log error {Caught error in dbg::HandleNubEvent: $msg at \n$::errorInfo}
    }
    return
}

# dbg::ignoreError --
#
#	Indicates that the debugger should suppress the current error
#	being propagated by the nub.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc dbg::ignoreError {} {
    variable appState

    if {$appState != "stopped"} {
	error "dbg::step called with an app that is not stopped."
    }

    SendAsync DbgNub_IgnoreError
    return
}


# dbg::Instrument --
#
#	Instrument a new block of code.  Creates a block to contain the
#	code and returns the newly instrumented script.
#
# Arguments:
#	file		File that contains script if this is being
#			called because of "source", otherwise {}.
#	script		Script to be instrumented.
#
# Results:
#	Returns the instrumented code or "" if the instrumentation failed.

proc dbg::Instrument {file script} {

    # Get a block for the new code.

    set block [blk::makeBlock $file]

    # Send the debugger a message when the instrumentation
    # begins and ends.

    DeliverEvent instrument start $block
    set alreadyInstrumented [blk::isInstrumented $block]

    # Generate the instrumented script.

    set icode [blk::Instrument $block $script]

    # Ensure that all breakpoints are valid.
	
    dbg::validateBreakpoints $file $block

    if {$icode != "" && !$alreadyInstrumented} {
	# If the instrumentation succeeded and the block was not previously
	# instrumented (e.g. re-sourcing), create any enabled breakpoints.

	foreach breakpoint [break::GetLineBreakpoints \
		[loc::makeLocation $block {}]] {
	    if {[break::getState $breakpoint] == "enabled"} {
		SendAsync DbgNub_AddBreakpoint "line" \
			[break::getLocation $breakpoint] \
			[break::getTest $breakpoint]
	    }
	}
    }

    DeliverEvent instrument end $block
    return $icode
}

# dbg::Log --
#
#	Log a debugging message.
#
# Arguments:
#	type		Type of message to log
#	message		Message string.  This string is substituted in
#			the calling context.
#
# Results:
#	None.

proc dbg::Log {type message} {
    variable logFilter
    variable debug

    if {!$debug || [lsearch -exact $logFilter $type] == -1} {
	return
    }
    puts $::dbg::logFile "LOG($type,[clock clicks]): [uplevel 1 [list subst $message]]"
    update idletasks
    return
}

# dbg::InitializeNub --
#
#	Initialize the client process by sending the nub library script
#	to the client process.
#
# Arguments:
#	nubVersion	The nub loader version.
#	tclVersion	The tcl library version.
#	clientData	The clientData passed to debugger_init.
#
# Results:
#	None.

proc dbg::InitializeNub {nubVersion tclVersion clientData} {
    variable appHost
    variable appPid
    variable libDir
    variable appState
    variable appVersion
    variable nubSocket

    # Load the nub into the client application.  Note that we are getting
    # the nub from the current working directory because we assume it is
    # going to be packaged into the debugger executable.

    set fd [open $::debugger::libdir/nub.tcl r]
    set nubScript [read $fd]
    close $fd

    # If we are talking to an older version of Tcl, change the channel
    # encoding to iso8859-1 to avoid sending multibyte characters.

    if {$tclVersion < 8.1} {
	fconfigure $nubSocket -encoding iso8859-1
    }	

    SendMessage NUB $nubScript

    # Fetch some information about the client and set up some 
    # initial state.

    set appPid [Send pid]
    set appState "stopped"
    set appVersion $tclVersion
    set appHost [Send info hostname]
    dbg::initInstrument

    # Begin coverage if it is enabled.

    if {$::coverage::coverageEnabled} {
	SendAsync DbgNub_BeginCoverage
    }

    # Configure the instrumentor to know what version of Tcl
    # we are debugging.

    instrument::initialize $appVersion

    DeliverEvent attach $clientData

    return
}

# dbg::initInstrument --
#
#	This command will communicate with the client application to
#	initialize various preference flags.  The flags being set are:
#
#	DbgNub(dynProc)		If true, then instrument dynamic procs.
#	DbgNub(includeFiles)	A list of files to be instrumented.
#	DbgNub(excludeFiles)	A list of files not to be instrumented.
#				Exclusion takes precedence over inclusion.
#	DbgNub(autoLoad)	If true, instrument scripts sourced
#				during auto_loading or package requires.
#	DbgNub(errorAction)	If 0, propagate errors.  If 1, stop on
#				uncaught errors.  If 2, stop on all errors.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc dbg::initInstrument {} {
    if {$dbg::appState != "dead"} {
	SendAsync set DbgNub(dynProc)      [pref::prefGet instrumentDynamic]
	SendAsync set DbgNub(includeFiles) [pref::prefGet doInstrument]
	SendAsync set DbgNub(excludeFiles) [pref::prefGet dontInstrument]
	SendAsync set DbgNub(autoLoad)   [pref::prefGet autoLoad]
	SendAsync set DbgNub(errorAction)  [pref::prefGet errorAction]
    }
    return
}

# dbg::getAppVersion --
#
#	Return the tcl_version of the running app.
#
# Arguments:
#	None.
#
# Results:
#	Return the tcl_version of the running app.

proc dbg::getAppVersion {} {
    return $dbg::appVersion
}

# dbg::isLocalhost --
#
#	Determine if the nub is running on the same host as the debugger.
#
# Arguments:
#	None.
#
# Results:
#	Boolean, true if the nub and debugger are on the same machine.

proc dbg::isLocalhost {} {
    variable appState
    variable appHost

    if {$appState == "dead"} {
	return 1
    }
    return [expr {[string compare $appHost [info hostname]] == 0}]
}


