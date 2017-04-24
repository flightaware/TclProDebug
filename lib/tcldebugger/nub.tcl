# nub.tcl --
#
#	This file contains the debugger nub implementation used
#	in the client application.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
#

# This file is transmitted to the client application when debugger_init
# connects to the debugger process.  It is evaluated in the debugger_Init
# procedure scope.  The local variable "socket" contains the file handle for
# the debugger socket.

global DbgNub
global tcl_version
set DbgNub(socket) $socket

# Before we go any further, make sure the socket is in the right encoding.

if {$tcl_version >= 8.1} {
    fconfigure $socket -encoding utf-8
}

# debug flag --
#
#   The debug flag can be any OR'ed combination of these flags:
#
#	0 - no debug output
#	1 - statement logging
#	2 - socket protocol logging

if {![info exists DbgNub(debug)]} {
    set DbgNub(debug) 0
}
if {![info exists DbgNub(logFile)]} {
    set DbgNub(logFile) stderr
}

# error action flag --
#   
#   This flag controls the action taken when an error result code is detected.
#   If this flag is set to 0, errors will be allowed to propagate normally.  If
#   the flag is 1, errors that would cause the program to exit will be caught
#   at the nearest instrumented statement on the stack and an error break will
#   be generated.  If the flag is 2, then all errors will generate an error
#   break.

set DbgNub(errorAction) 1

# catch flag --
#
#   If this flag is set, then the current error should be caught by the
#   debugger because it is not handled by the application.

set DbgNub(catch) 1

# handled error flag --
#
#   If this flag is set, the current error has already been reported so it
#   should be propagated without generating further breakpoints.

set DbgNub(errorHandled) 0

# exclude commands list --
# 
# This is a list of all commands, used in the nub, that will cause
# the debugger to crash if they are renamed.  In the wrapped rename
# procedure, the command being renamed is compared to this list.  If
# the command is on this list, then an error is generated stating 
# that renaming the command will crash the debugger.

set DbgNub(excludeRename) [list append array break cd close concat continue \
	eof error eval expr fconfigure file fileevent flush for foreach gets \
	global if incr info lappend lindex linsert list llength lrange \
	lreplace lsearch namespace open puts pwd read regexp regsub rename \
	return set string switch trace unset uplevel upvar variable \
	vwait while]

# wrapped commands list --
#
#  This is a list of commands that the nub has wrapped.  The names may
#  change during runtime due to the "rename" command.  However, the nub
#  filters for "info proc" will always treat these as "commands".

set DbgNub(wrappedCommandList) [list catch source update uplevel \
	vwait info package proc rename]

# instruction nesting count --
#
#   Records the number of nested instrumented instructions on the
#   stack. This count is reset whenever a new event loop frame is pushed.
#   It is used for determining when an error has propagated to the global
#   scope.

set DbgNub(nestCount) 0

# subcommand nesting count --
#
#   Records the number of nested command substitutions in progress.  This count
#   is used to determine where step-over operations should break.  The
#   currentCmdLevel records the nesting level of the currently executing
#   statement.  The stepCmdLevel records the nesting level of the last step
#   command. 

set DbgNub(currentCmdLevel) 0
set DbgNub(stepCmdLevel) 0

# step context level --
#
#   Records the level at which the current "step over" or "step out" operation
#   was initiated.

set DbgNub(stepLevel) 0
set DbgNub(stepOutLevel) {}

# break next flag --
#
#   If this flag is set, the next instrumented statement will trigger a
#   breakpoint.  This flag is set when single-stepping or when an inc interrupt
#   has been received.

set DbgNub(breakNext) 1

# breakpoint check list --
#
#   Contains a list of commands to invoke when testing whether to break on a
#   given statement.  Each command is passed a location and the current level.
#   The breakPreChecks list is invoked before a statement executes.

set DbgNub(breakPreChecks) {}
set DbgNub(breakPostChecks) {}

# breakpoint location tests --
#
#   For each location that contains a breakpoint, there is an entry in the
#   DbgNub array that contains a list of test scripts that will be evaluated at
#   the statement scope.  If the test script returns 1, a break will be
#   triggered.  The format of a breakpoint record is DbgNub(<block>:<line>).
#   The numBreaks field records the number of active breakpoints.

set DbgNub(numBreaks) 0

# variable trace counter --
#
#   Each variable trace is referred to by a unique identifier.  The varHandle
#   counter contains the last trace handle that was allocated.  For each trace
#   there is a list of active variable breakpoints stored as a list in
#   DbgNub(var:<handle>).  For each variable breakpoint created in the
#   debugger, the reference count in dbgNub(varRefs:<handle>) is incremented.

set DbgNub(varHandle) 0

# instruction stack --
#
#   Records the location information associated with each instrumented
#   statement currently being executed.  The current context is a list of
#   the form {level type ?arg1 ... argn?}.  The level indicates
#   the scope in which the statement is executing.  The type is one of
#   "proc", "source", or "global" and indicates where the statement came
#   from.  For "proc" frames, the args contain the name of the
#   procedure and its declared arguments.  For "source" frames, the args
#   contain the name of the file being sourced.   The locations field
#   contains a list of statement locations indicating nested calls to
#   Tcl_Eval at the same scope (e.g. while).  Whenever a new context is
#   created, the previous context and location list are pushed onto the
#   contextStack.  New frames are added to the end of the list.

set DbgNub(contextStack) {}
set DbgNub(context) {0 global}
set DbgNub(locations) {}

# call stack --
#
#   Records the Tcl call stack as reported by info level.  The stack is a
#   list of context records as described for instruction stack entries.

set DbgNub(stack) {{0 global}}

# instrumentation flags --
#
#   The first three flags are set by user preferences:
#	dynProc		- if true, dynamic procs should be instrumented
#	autoLoad	- if false, all files sourced during an auto_load,
#			  auto_import, or package require operation should not
#			  be instrumented.  Dynamic procedures will not be
#			  defined, either.
#	includeFiles	- contains a list of string match patterns that
#			  must be matched in order for sourced files to be
#			  instrumented.  Only the specific file matched
#			  and any procedures it defines will be included, not
#			  files that it sources.  Exclusion (below) takes
#			  precedence over inclusion.
#	excludeFiles	- contains a list of string match patterns that
#			  will be used to exclude some sourced files from
#			  instrumentation.  Only the specific file matched
#			  and any procedures it defines will be excluded, not
#			  files that it sources.  Exclusion takes precedence
#			  over inclusion (above).
#
#   The next three flags are used to keep track of any autoloads, package
#   requires or excluded files that are in progress.

set DbgNub(dynProc)      0
set DbgNub(autoLoad)   1
set DbgNub(excludeFiles) {}
set DbgNub(includeFiles) {*}

set DbgNub(inAutoLoad) 0
set DbgNub(inExclude) 0
set DbgNub(inRequire) 0

# code coverage variables --
#
#     DbgNub(cover:*)  - hash table of covered locations
#     DbgNub(cover)    - if true, store coverage info for each call to
#                        DbgNub_Do, and send coverage info to debugger
#                        on each break.

set DbgNub(cover) 0

# info script:  We need to keep track of the current script being
# sourced so that "info script" can return the current result.  The
# following variable is a stack of all sourced files.  The initial value must
# be set for the remote debugging case, as the script is not neccessarily
# sourced.  For the local debugging case, the initial value is temporarily
# appLaunch.tcl, which is not correct, but this value will never be accessed
# because the "initial" script will be sourced, thereby pushing the correct
# script name on the stack.

set DbgNub(script) [list [info script]]

# Tcl 8.0 & namespace command
#
#   This variable tells the various Nub functions whether to deal
#   with namespace issues that are part of Tcl 8.0.  The namespace
#   issues may also be present in version less than Tcl 8.0 that
#   have itcl - this is a very different type of namespace, however.
#   We also set a scope prefix that will be used on every command that
#   we invoke in an uplevel context to ensure that we get the global version of
#   the command instead of a namespace local version.

if {[info tclversion] >= 8.0} {
    set DbgNub(namespace) 1
    set DbgNub(itcl76) 0
    set DbgNub(scope) ::
} else {
    set DbgNub(namespace) 0
    if {[info commands "namespace"] == "namespace"} {
	set DbgNub(itcl76) 1
    } else {
	set DbgNub(itcl76) 0
    }
    set DbgNub(scope) {}
}

# cached result values --
#
#   After every instrumented statement, the nub stores the current return code
#   and result value.

set DbgNub(lastCode)	0
set DbgNub(lastResult)	{}

##############################################################################


# DbgNub_Startup --
#
#	Initialize the nub state by wrapping commands and creating the
#	socket event handler.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc DbgNub_Startup {} {
    global DbgNub errorInfo errorCode

    DbgNub_WrapCommands

    if {![DbgNub_infoCmd exists errorInfo]} {
	set errorInfo {}
    }
    if {![DbgNub_infoCmd exists errorCode]} {
	set errorCode {}
    }
    fileevent $DbgNub(socket) readable DbgNub_SocketEvent
    DbgNub_ProcessMessages 1
    return
}

# DbgNub_Shutdown --
#
#	Terminate communication with the debugger.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc DbgNub_Shutdown {} {
    global DbgNub
    if {$DbgNub(socket) != -1} {
	close $DbgNub(socket)
	set DbgNub(socket) -1
    }
}

# DbgNub_SendMessage --
#
#	Send the given script to be evaluated in the server.
#
# Arguments:
#	script	The script to be evaluated.
#
# Results:
#	None.

proc DbgNub_SendMessage {args} {
    global DbgNub
    if {$DbgNub(socket) == -1} {
	return
    }
    puts $DbgNub(socket) [string length $args]
    puts -nonewline $DbgNub(socket) $args
    
    if {$DbgNub(debug) & 2} {
	DbgNub_Log "sending [string length $args] bytes: '$args'"
    }
    if {[DbgNub_catchCmd {flush $DbgNub(socket)}]} {
	if {$DbgNub(debug) & 2} {
	    DbgNub_Log "SendMessage detected closed socket"
	}
	DbgNub_Shutdown
    }
    return
}

# DbgNub_GetMessage --
#
#	Get the next message from the debugger. 
#
# Arguments:
#	blocking	If 1, wait until a message is detected (or eof), 
#			otherwise check without blocking, 
#
# Results:
#	Returns the message that was received, or {} no message was
#	present.

proc DbgNub_GetMessage {blocking} {
    global DbgNub

    if {$DbgNub(socket) == -1} {
	return ""
    }

    # Put the socket into non-blocking mode long enough to poll if
    # we aren't doing a blocking read.

    fconfigure $DbgNub(socket) -blocking $blocking
    set result [gets $DbgNub(socket) bytes]
    fconfigure $DbgNub(socket) -blocking 1
    if {$result == -1} {
	return ""
    }

    set msg [read $DbgNub(socket) $bytes]
    if {$DbgNub(debug) & 2} {
	DbgNub_Log "got: '$msg'"
    }
    return $msg
}

# DbgNub_SocketEvent --
#
#	This function is called when a message arrives from the debugger during
#	an event loop.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc DbgNub_SocketEvent {} {
    global DbgNub
    
    DbgNub_ProcessMessages 0
    if {$DbgNub(breakNext)} {
	DbgNub_Break 0 linebreak
    }
}

# DbgNub_Do --
#
#	Execute an instrumented statement.  This command is used to
#	prefix all instrumented statements.  It will detect any
#	uncaught errors and ask the debugger how to handle them.
#	All other errors will be propagated.
#
# Arguments:
#	subcommand	1 if this statement is part of a command substitution,
#			0 if this statement is a body statement.
#	location	Location in original code block that
#			corresponds to the current statement.
#	args		The script that should be executed.
#
# Results:
#	Returns the result of executing the script.

proc DbgNub_Do {subcommand location cmd} {
    global DbgNub errorInfo errorCode

    if {$DbgNub(socket) == -1} {
	set code [DbgNub_catchCmd {DbgNub_uplevelCmd 1 $cmd} result]
	return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
    }

    set level [expr {[DbgNub_infoCmd level] - 1}]

    # Push a new virtual stack frame so we know where we are
    
    lappend DbgNub(locations) $location
    incr DbgNub(nestCount)

    # If this command is part of a command substitution, increment the
    # subcommand level.

    if {$subcommand} {
	incr DbgNub(currentCmdLevel)
    }

    if {$DbgNub(debug) & 1} {
	DbgNub_Log "[list DbgNub_Do $subcommand $location $cmd]"
    }
    
    # Process any queued messages without blocking

    DbgNub_ProcessMessages 0

    # Check to see if we need to stop on this statement

    if {! $DbgNub(breakNext)} {
	foreach check $DbgNub(breakPreChecks) {
	    if {[$check $location $level]} {
		set DbgNub(breakNext) 1
		break
	    }
	}
    }
    if {$DbgNub(breakNext)} {
	DbgNub_Break $level linebreak
    }

    # Execute the statement and return the result

    set DbgNub(lastCode) [DbgNub_catchCmd {DbgNub_uplevelCmd 1 $cmd} \
	    DbgNub(lastResult)]

    # Store the current location in DbgNub array, so we can calculate which
    # locations have not yet been covered.
    
    if {$DbgNub(cover)} {
	set index "cover:$location"
	if {[info exists DbgNub($index)]} {
	    incr DbgNub($index)
	} else {
	    set DbgNub($index) 1
	}
    }

    if {$DbgNub(debug) & 1} {
	DbgNub_Log "[list DbgNub_Do $subcommand $location $cmd completed \
		with code == $DbgNub(lastCode)]"
    }
    if {$DbgNub(lastCode) == 1} {
	# Clean up the errorInfo stack to remove our tracks.
	DbgNub_cleanErrorInfo
	DbgNub_cleanWrappers

	# This error could end the application. Let's check
	# to see if we want to stop and maybe break now.
	if {! $DbgNub(errorHandled) && (($DbgNub(errorAction) == 2) \
		|| (($DbgNub(errorAction) == 1) && $DbgNub(catch)))} {
	    if {[DbgNub_HandleError $DbgNub(lastResult) $level]} {
		set DbgNub(lastCode) 0
		set DbgNub(lastResult) {}
		set errorCode NONE
		set errorInfo {}
		set DbgNub(errorHandled) 0
		if {[DbgNub_infoCmd exists DbgNub(returnState)]} {
		    unset DbgNub(returnState)
		}
	    } else {
		set DbgNub(errorHandled) 1
	    }
	}
    }
    # Check to see if we need to stop and display the command result.
    set breakAfter 0
    foreach check $DbgNub(breakPostChecks) {
	if {[$check $location $level]} {
	    set breakAfter 1
	    break
	}
    }
    if {$breakAfter} {
	DbgNub_Break $level cmdresult
    }

    # Pop the current location from the location stack
    set DbgNub(locations) [lreplace $DbgNub(locations) end end]

    incr DbgNub(nestCount) -1
    if {$DbgNub(nestCount) == 0} {
	set DbgNub(errorHandled) 0
    }

    # Pop the subcommand frame, if necessary.

    if {$subcommand} {
	incr DbgNub(currentCmdLevel) -1
    }

    return -code $DbgNub(lastCode) -errorcode $errorCode \
	    -errorinfo $errorInfo $DbgNub(lastResult)
}

# DbgNub_Break --
#
#	Generate a breakpoint notification and wait for the debugger
#	to tell us to continue.
#
# Arguments:
#	level	The level of the program counter.
#	type	The type of breakpoint being generated.
#	args	Additonal type specific arguments.
#
# Results:
#	None.

proc DbgNub_Break {level type args} {
    set marker [DbgNub_PushStack $level]
    DbgNub_SendMessage BREAK [DbgNub_CollateStacks] [DbgNub_GetCoverage] \
	    $type $args
    DbgNub_ProcessMessages 1
    DbgNub_PopStack $marker
}

# DbgNub_Run --
#
#	Configure the nub to start running again.  The given operation
#	will determine how far the debugger will run.
#
# Arguments:
#	op	The type of step operation to do.
#
# Results:
#	None.  However, the application will start running again.

proc DbgNub_Run {{op run}} {
    global DbgNub

    # Remove any stale check procedures

    set index [lsearch -exact $DbgNub(breakPreChecks) DbgNub_CheckOver]
    if {$index != -1} {
	set DbgNub(breakPreChecks) \
		[lreplace $DbgNub(breakPreChecks) $index $index]
    }
    set index [lsearch -exact $DbgNub(breakPostChecks) DbgNub_CheckOver]
    if {$index != -1} {
	set DbgNub(breakPostChecks) \
		[lreplace $DbgNub(breakPostChecks) $index $index]
    }
    set DbgNub(stepOutLevel) {}

    switch $op {
	any {
	    set DbgNub(breakNext) 1
	}
	over {
	    lappend DbgNub(breakPreChecks) DbgNub_CheckOver
	    set DbgNub(stepLevel) [llength $DbgNub(contextStack)]
	    set DbgNub(stepCmdLevel) $DbgNub(currentCmdLevel)
	    set DbgNub(breakNext) 0
	}
	out {
	    set DbgNub(stepOutLevel) [llength $DbgNub(contextStack)]
	    set DbgNub(breakNext) 0
	}
	cmdresult {
	    lappend DbgNub(breakPostChecks) DbgNub_CheckOver
	    set DbgNub(stepLevel) [llength $DbgNub(contextStack)]
	    set DbgNub(stepCmdLevel) $DbgNub(currentCmdLevel)
	    set DbgNub(breakNext) 0
	}
	default {
	    set DbgNub(breakNext) 0
	}
    }
    set DbgNub(state) running
}

# DbgNub_CheckOver --
#
#	Checks to see if we should break the debugger based on what
#	level we are located in.
#
# Arguments:
#	location	Current location.
#	level		Stack level of current statement.
#
# Results:
#	Returns 1 if we should break at this statement.

proc DbgNub_CheckOver {location level} {
    global DbgNub

    set curLevel [llength $DbgNub(contextStack)]

    if {($curLevel < $DbgNub(stepLevel)) \
	    || ($DbgNub(currentCmdLevel) < $DbgNub(stepCmdLevel)) \
	    || (($curLevel == $DbgNub(stepLevel)) \
	    && ($DbgNub(currentCmdLevel) == $DbgNub(stepCmdLevel)))} {
	set index [lsearch -exact $DbgNub(breakPreChecks) DbgNub_CheckOver]
	if {$index != -1} {
	    set DbgNub(breakPreChecks) \
		    [lreplace $DbgNub(breakPreChecks) $index $index]
	}
	return 1
    }
    return 0
}

# DbgNub_HandleError --
#
#	Notify the debugger that an uncaught error has occurred and
#	wait for it to tell us what to do.
#
# Arguments:
#	message		Error message reported by statement.
#	level		Level at which the error occurred.
#
# Results:
#	Returns 1 if the error should be ignored, otherwise
#	returns 0.

proc DbgNub_HandleError {message level} {
    global DbgNub errorInfo errorCode
    set DbgNub(ignoreError) 0
    DbgNub_Break $level error $message $errorInfo $errorCode $DbgNub(catch)
    return $DbgNub(ignoreError)
}

# DbgNub_Instrument --
#
#	Pass a block of code to the debugger to be instrumented.
#	Generates an INSTRUMENT message that will eventually be
#	answered with a call to DbgNub_InstrumentReply.
#
# Arguments:
#	file		Absolute path to file being instrumented.
#	script		Script being instrumented.
#
# Results:
#	Returns the instrumented form of the script, or "" if the
#	script was not instrumentable.

proc DbgNub_Instrument {file script} {
    global DbgNub

    # Send the code to the debugger and process events until we are
    # told to continue execution.  The instrumented code should be
    # contained in the global DbgNub array.

    set DbgNub(iscript) ""
    DbgNub_SendMessage INSTRUMENT $file $script
    DbgNub_ProcessMessages 1
    return $DbgNub(iscript)
}

# DbgNub_InstrumentReply --
#
#	Invoked when the debugger completes instrumentation of
#	code sent in a previous INSTRUMENT message.
#
# Arguments:
#	script		The instrumented script.
#
# Results:
#	None.  Stores the instrumented script in DbgNub(iscript) and
#	sets the DbgNub(state) back to running so we break out of the
#	processing loop.

proc DbgNub_InstrumentReply {script} {
    global DbgNub
    set DbgNub(iscript) $script
    set DbgNub(state) running
}

# DbgNub_UninstrumentProc --
#
#	Give a fully qualified procedure name and the orginal proc
#	body (before it was instrumented) this procedure will recreate
#	the procedure to effectively unimplement the procedure.
#
# Arguments:
#	procName	A fully qualified procedure name.
#	body		The uninstrumented version of the body.
#
# Results:
#	None - various global state about the proc is changed.

proc DbgNub_UninstrumentProc {procName body} {
    global DbgNub

    set current [DbgNub_GetProcDef $procName]
    set new [lreplace $current 0 0 DbgNub_procCmd]
    set new [lreplace $new 3 3 $body]
    eval $new
    unset DbgNub(proc=$procName)
}

# DbgNub_InstrumentProc --
#
#	Given a fully qualified procedure name this command will
#	instrument the procedure.  This should not be called on
#	procedures that have already been instrumented.
#
# Arguments:
#	procName	A fully qualified procedure name.
#
# Results:
#	None - various global state about the proc is changed.

proc DbgNub_InstrumentProc {procName script} {
    global DbgNub

    # If the proc given has been compiled with TclPro Compiler
    # the we can't instrument the code so we don't allow it to
    # happen.

    set cmpBody {# Compiled -- no source code available}
    append cmpBody \n
    append cmpBody {error "called a copy of a compiled script"}
    if {[DbgNub_infoCmd body $procName] == $cmpBody} {
	return
    }

    # The code we just received starts with a DbgNub_Do which we
    # don't want to run.  Strip out the actual proc command and eval.
    set cmd [lindex $script end]
    eval $cmd
    return
}

# DbgNub_ProcessMessages --
#
#	Read messages from the debugger and handle them until the
#	debugger indicates that the nub should exit the loop by setting
#	the DbgNub(state) variable to something other than "waiting".
#
# Arguments:
#	blocking		Indicates whether we should wait for
#				messages if none are present.
#
# Results:
#	None.  Processing certain message types may have arbitrary
#	side effects which the caller may expect.

proc DbgNub_ProcessMessages {blocking} {
    global DbgNub

    if {$DbgNub(socket) == -1} {
	return
    }

    set DbgNub(state) waiting

    while {$DbgNub(state) == "waiting"} {
	if {[DbgNub_catchCmd {DbgNub_GetMessage $blocking} msg]} {
	    DbgNub_Shutdown
	    return
	} elseif {$msg == ""} {
	    if {[eof $DbgNub(socket)]} {
		DbgNub_Shutdown
	    }
	    return
	}
	switch [lindex $msg 0] {
	    SEND {
		# Evaluate a Send.  Return any result
		# including error information.
		
		set code [DbgNub_catchCmd {eval [lindex $msg 2]} result]
		if {$code != 0} {
		    global errorInfo errorCode
		    DbgNub_SendMessage ERROR $result $code $errorCode \
			    $errorInfo
		} elseif {[lindex $msg 1] == "1"} {
		    DbgNub_SendMessage RESULT $result
		}
	    }
	}
    }
    return
}

# DbgNub_Log --
#
#	Log a debugging message.
#
# Arguments:
#	args	Debugging message to log
#
# Results:
#	None.

proc DbgNub_Log {args} {
    global DbgNub
    puts $DbgNub(logFile) [concat "LOG: " $args]
    flush $DbgNub(logFile)
}

# DbgNub_GetProcs --
#
#	Returns a list of all procedures in the application, excluding
#	those added by the debugger itself.  The list consists of
#	elements of the form {<procname> <location>}, where the
#	location refers to the entire procedure definition.  If the
#	procedure is uninstrumented, the location is null.
#
# Arguments:
#	namespace:	This variable is only used by the implementation
#			of DbgNub_GetProcs itself.  It is used to recurse
#			through the namespaces to find hidden procs.
#
# Results:
#	Returns a list of all procedures in the application, excluding
#	those added by the debugger itself and imported names.  The list
#	consists of elements of the form {<procname> <location>}.

proc DbgNub_GetProcs {{namespace {}}} {
    global DbgNub

    set procList ""
    if {$namespace != ""} {
	set nameProcs ""
	# Be sure to call the "wrapped" version of info to filter DbgNub procs
	foreach x [namespace eval $namespace "$DbgNub(scope)info procs"] {
	    if {[string compare \
		    [namespace eval $namespace \
			[list $DbgNub(scope)namespace origin $x]] \
		    [namespace eval $namespace \
			[list $DbgNub(scope)namespace which $x]]] \
		    == 0} {
		lappend nameProcs ${namespace}::$x
	    }
	}
	foreach n [namespace children $namespace] {
	    set nameProcs [concat $nameProcs [DbgNub_GetProcs $n]]
	}
	return $nameProcs
    } elseif {$DbgNub(namespace)} {
	foreach n [namespace children ::] {
	    set procList [concat $procList [DbgNub_GetProcs $n]]
	}
	# Be sure to call the "wrapped" version of info to filter DbgNub procs
	foreach name [$DbgNub(scope)info procs] {
	    if {[string compare [namespace origin $name] \
		    [namespace which $name]] == 0} {
		lappend procList "::$name"
	    }
	}
    } else {
	# Be sure to call the "wrapped" version of info to filter DbgNub procs
	set procList [$DbgNub(scope)info procs]
    }

    set result {}
    foreach name $procList {
	if {[DbgNub_infoCmd exists DbgNub(proc=$name)]} {
	    lappend result [list $name $DbgNub(proc=$name)]
	} else {
	    lappend result [list $name {}]
	}
    }
    return $result
}

# DbgNub_GetVariables --
#
#	Retrieve the names of the variables that are visible at the
#	specified level, excluding internal Debugger variables.
#
# Arguments:
#	level	Stack level to get variables from.
#	vars	A list of variables to test for existence.  If this list
#		is null, all local and namespace variables will be returned.
#
# Results:
#	Returns a list of variable names.

proc DbgNub_GetVariables {level vars} {
    global DbgNub

    # We call the "wrapped" version of info vars which will weed
    # out any debugger variables that may exist in the var frame.

    if {$vars == ""} {
	set vars [DbgNub_uplevelCmd #$level "$DbgNub(scope)info vars"]
	if {$DbgNub(itcl76)} {
	    if {[DbgNub_uplevelCmd \#$level {info which info}] \
		    == "::itcl::builtin::info"} {
		# We are in a class or instance context
		set name [DbgNub_uplevelCmd \#$level {lindex [info level 0] 0}]
		set mvars [DbgNub_uplevelCmd \#$level {info variable}]
		if {($name != "") && ([DbgNub_uplevelCmd \#$level \
			[list info function $name -type]] == "proc")} {
		    # We are in a class proc, so we need to filter out
		    # all of the instance variables.  Note that we also
		    # need to filter out duplicates because once they have
		    # been accessed once, member variables show up in the
		    # "info vars" list.

		    foreach var $mvars {
			if {([DbgNub_uplevelCmd \#$level \
				[list info variable $var -type]] == "common") \
				&& ([lsearch $vars $var] == -1)} {
			    lappend vars $var
			}
		    }
		} else {
		    # Filter out duplicates.

		    foreach var $mvars {
			if {[lsearch $vars $var] == -1} {
			    lappend vars $var
			}
		    }
		}
	    }
	} elseif {$DbgNub(namespace)} {
	    # Check to see if we are in an object or class context.  In this
	    # case we need to add in the member variables.  Otherwise, check
	    # to see if we are in a non-global namespace context, in which
	    # case we add the namespace variables.

	    if {[DbgNub_uplevelCmd \#$level \
		    [list $DbgNub(scope)namespace origin info]] \
		    == "::itcl::builtin::info"} {
		# If the function name is null, we're in a configure context,
		# otherwise we need to check the function type to determine
		# whether the function is a proc or a method.

		set name [DbgNub_uplevelCmd \#$level {lindex [info level 0] 0}]
		set mvars [DbgNub_uplevelCmd \#$level {info variable}]
		if {($name != "") && ([DbgNub_uplevelCmd \#$level \
			[list info function $name -type]] == "proc")} {
		    # We are in a class proc, so filter out instance variables

		    foreach var $mvars {
			if {[DbgNub_uplevelCmd \#$level \
				[list info variable $var -type]] == "common"} {
			    lappend vars $var
			}
		    }
		} else {
		    set vars [concat $mvars $vars]
		}
	    } else {
		set current [DbgNub_uplevelCmd #$level \
			"$DbgNub(scope)namespace current"]
		if {$current != "::"} {
		    set vars [concat $vars \
			    [DbgNub_uplevelCmd #$level \
			    "$DbgNub(scope)info vars" [list ${current}::*]]]
		}
	    }
	}
    }

    # Construct a list of name/type pairs.

    set result {}
    foreach var $vars {
	# We have to be careful because we cannot call
	# upvar on a qualified namespace variable.  First
	# verify the var exists, then test to see if
	# it is an array.

	if {[DbgNub_uplevelCmd #$level [list info exists $var]]} {
	    upvar #$level $var local
	    if {[array exists local]} {
		lappend result [list $var a]
	    } else {
		lappend result [list $var s]
	    }
	} else {
	    lappend result [list $var s]
	}
    }
    return $result
}

# DbgNub_GetVar --
#
#	Returns a list containing information about each of the
#	variables specified in varList.  The returned list consists of
#	elements of the form {<name> <type> <value>}.  Type indicates
#	if the variable is scalar or an array and is either "s" or
#	"a".  If the variable is an array, the result of an array get
#	is returned for the value, otherwise it is the scalar value.
#	Any names that were specified in varList but are not valid
#	variables will be omitted from the returned list.
#
# Arguments:
#	level		The stack level of the variables in varList.
#	maxlen		The maximum length of data to return for a single
#			element.  If this value is -1, the entire string
#			is returned.
#	varList		A list of variables whose information is returned.
#
# Results:
#	Returns a list containing information about each of the
#	variables specified in varList.  The returned list consists of
#	elements of the form {<name> <type> <value>}. 

proc DbgNub_GetVar {level maxlen varList} {
    global DbgNub
    set result {}
    # Adjust the maxlen to be the last character position
    if {$maxlen > 0} {
	incr maxlen -1
    }
    foreach var $varList {
	upvar #$level $var local

	# Remove all traces before getting the value so we don't enter
	# instrumented code or cause other undesired side effects.  Note
	# that we must do this before calling info exists, since that will
	# also trigger a read trace.  
	#
	# There are two types of traces to look out for: scalar and array.
	# Array elements trigger both scalar and array traces.  The current
	# solution is a hack because we are looking for variables that look
	# like name(element).  This won't catch array elements that have been
	# aliased with upvar to scalar names.  The only way to handle that case
	# is to wrap upvar and track every alias.  This is a lot of work for a
	# very unusual case, so we are punting for now.

	set traces [trace vinfo local]
	foreach trace $traces {
	    eval trace vdelete local $trace
	}
	# We use the odd string range call instead of string index
	# to work on 8.0
	if {[string range $var end end] == ")"} {
	    set avar [lindex [split $var "("] 0]
	    upvar #$level $avar alocal

	    set atraces [trace vinfo alocal]
	    foreach trace $atraces {
		eval trace vdelete alocal $trace
	    }
	} else {
	    set atraces {}
	}

	# Now it is safe to check for existence before we attempt to fetch the
	# value. 
	
	if {[DbgNub_uplevelCmd #$level \
		[list DbgNub_infoCmd exists $var]]} {
	    
	    # Fetch the current value.  Note that we have to be careful
	    # when truncating the value.  If we call string range directly
	    # the object will be converted to a string object, losing any
	    # internal rep.  If we copy it first, we can avoid the problem.
	    # Normally this doesn't matter, but for extensions like TclBlend
	    # that rely on the internal rep to control object lifetime, it
	    # is a critical step.

	    # Also, because of a bug in Windows where null values in the env
	    # array are automatically unset, we need to guard against
	    # non-existent values when iterating over array names. Bug: 4120

	    if {$maxlen == -1} {
		if {[array exists local]} {
		    set value {}
		    foreach name [array names local] {
			if {[DbgNub_infoCmd exists local($name)]} {
			    lappend value $name $local($name)
			} else {
			    lappend value $name {}
			}
		    }
		    lappend result [list $var a $value]
		} else {
		    lappend result [list $var s $local]
		}
	    } else {
		if {[array exists local]} {
		    set value {}
		    foreach name [array names local] {
			set copy {}
			if {[DbgNub_infoCmd exists local($name)]} {
			    append copy $local($name)
			} else {
			    append copy {}
			}
			lappend value $name [string range $copy 0 $maxlen]
		    }
		    lappend result [list $var a $value]
		} else {
		    set copy {}
		    append copy $local
		    lappend result [list $var s [string range $copy 0 $maxlen]]
		}
	    }

	}

	# Restore the traces

	foreach trace $traces {
	    eval trace variable local $trace
	}
	foreach trace $atraces {
	    eval trace variable alocal $trace
	}
    }
    return $result
}

# DbgNub_SetVar --
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
#	Returns an empty string.

proc DbgNub_SetVar {level var value} {
    upvar #$level $var local
    if {![DbgNub_infoCmd exists local]} {
	error "No such variable $var"
    }
    if {[array exists local]} {
	foreach name [array names local] {
	    unset local($name)
	}
	array set local $value
    } else {
	set local $value
    }
    return
}

# DbgNub_GetResult --
#
#	Gets the last reported return code and result value.
#
# Arguments:
#	maxlen		The maximum length of data to return for the 
#			result.  If this value is -1, the entire string
#			is returned, otherwise long values are truncated
#			after maxlen bytes.
#
# Results:
#	Returns a list of the form {code result}.

proc DbgNub_GetResult {maxlen} {
    global DbgNub
    
    if {$maxlen == -1} {
	set maxlen end
    } else {
	incr maxlen -1
    }

    return [list $DbgNub(lastCode) \
	    [string range $DbgNub(lastResult) 0 $maxlen]]
}

# DbgNub_PushContext --
#
#	Push the current context and location stack onto the context
#	stack and set up a new context.
#
# Arguments:
#	level		The new stack level.
#	type		The context type.
#	args		Context type specific state.
#
# Results:
#	None.

proc DbgNub_PushContext {level type args} {
    global DbgNub
    lappend DbgNub(contextStack) [list $DbgNub(context) $DbgNub(locations)]
    set DbgNub(locations) {}
    set DbgNub(context) [concat $level $type $args]
    if {$DbgNub(debug) & 1} {
	DbgNub_Log "PUSH CONTEXT:\ncontext = $DbgNub(context)\n\locations = $DbgNub(locations)\ncontextStack = $DbgNub(contextStack)\nstack=$DbgNub(stack)"
    }
    return
}

# DbgNub_PopContext --
#
#	Restore the previous context from the contextStack.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc DbgNub_PopContext {} {
    global DbgNub
    set last [lindex $DbgNub(contextStack) end]
    set DbgNub(contextStack) [lreplace $DbgNub(contextStack) end end]
    set DbgNub(context) [lindex $last 0]
    set DbgNub(locations) [lindex $last 1]
    if {$DbgNub(debug) & 1} {
	DbgNub_Log "POP CONTEXT:\ncontext = $DbgNub(context)\n\locations = $DbgNub(locations)\ncontextStack = $DbgNub(contextStack)\nstack=$DbgNub(stack)"
    }
    return
}

# DbgNub_PushStack --
#
#	Push info about all of the stack frames that have been
#	added after the last stack checkpoint.
#
# Arguments:
#	current		Stack level of current statement.
#	frame		Optional. New stack frame that will be pushed
#			by current statement.
#
# Results:
#	Returns a marker for the end of the stack before any frames
#	were pushed.

proc DbgNub_PushStack {current {frame {}}} {
    global DbgNub

    set oldTop [lindex [lindex $DbgNub(stack) end] 0]
    set marker [expr {[llength $DbgNub(stack)] - 1}]

    for {set level [expr {$oldTop + 1}]} {$level <= $current} {incr level} {
	set name [lindex [DbgNub_infoCmd level $level] 0]
	if {$name == ""} {
	    # This is a "namespace eval" so compute the name and push
	    # it onto the stack.
	    if {$DbgNub(itcl76)} {
		set name [DbgNub_uplevelCmd \#$level \
			[list $DbgNub(scope)DbgNub_infoCmd context]]
	    } else {
		set name [DbgNub_uplevelCmd \#$level \
			[list $DbgNub(scope)namespace current]]
	    }

	    # Handle the special case of the [incr Tcl] parser namespace
	    # so classes appear as expected.

	    if {$name == "::itcl::parser"} {
		lappend DbgNub(stack) [list $level class]
	    } else {
		lappend DbgNub(stack) [list $level namespace eval $name]
	    }
	    continue
	}

	# Handle [incr Tcl] methods and procedures first. We check to see
	# if we are in an object context by testing to see where "info"
	# is coming from.  If we're in an object context, we can get all
	# the info we need from the "info function" command.

	if {$DbgNub(itcl76)} {
	    if {[DbgNub_uplevelCmd \#$level {info which info}] \
		    == "::itcl::builtin::info"} {
		lappend DbgNub(stack) [concat $level \
			[DbgNub_uplevelCmd \#$level \
			[list info function $name -type -name -args]]]
		continue
	    }
	} elseif {$DbgNub(namespace)} {
	    if {[DbgNub_uplevelCmd \#$level \
		    [list $DbgNub(scope)namespace origin info]] \
		    == "::itcl::builtin::info"} {
		lappend DbgNub(stack) [concat $level \
			[DbgNub_uplevelCmd \#$level \
			[list info function $name -type -name -args]]]
		continue
	    }
	}

	# If we are using namespaces, transform the name to fully qualified
	# form before trying to get the arglist.  Determine whether the
	# name refers to a proc or a command.

	if {$DbgNub(namespace)} {
	    # Check to see if the name exists in the calling context.  If it
	    # isn't present, it must have been deleted while it was on the
	    # stack.  This check must be done before calling namespace origin
	    # below or an error will be generated (Bug: 3613).

	    set infoLevel \#[expr {$level - 1}]
	    if {[DbgNub_uplevelCmd $infoLevel \
		    [list $DbgNub(scope)info commands $name]] == ""} {
		lappend DbgNub(stack) [list $level proc $name (deleted)]
		continue
	    }		

	    # Now determine the fully qualified name.

	    set name [DbgNub_uplevelCmd $infoLevel \
		    [list $DbgNub(scope)namespace origin $name]]

	    # Because of Tcl's namespace design, "info procs" does not
	    # work on qualified names.  The workaround is to invoke the
	    # "info" command inside the namespace.

	    set qual [namespace qualifiers $name]
	    if {$qual == ""} {
		set qual ::
	    }
	    set tail [namespace tail $name]
	    set isProc [namespace eval $qual \
		    [list DbgNub_infoCmd procs $tail]]
	} else {
	    # Check to make sure the command still exists.

	    if {[DbgNub_uplevelCmd \#[expr {$level - 1}] \
		    [list DbgNub_infoCmd commands $name]] == ""} {
		lappend DbgNub(stack) [list $level proc $name (deleted)]
		continue
	    }

	    # Check to see if the command is a proc.

	    set isProc [DbgNub_infoCmd procs $name]
	}

	# Attempt to determine the argument list.

	if {$isProc != ""} {
	    set argList [DbgNub_uplevelCmd \#$level \
		    [list DbgNub_infoCmd args $name]]
	} else {
	    # The command on the stack is not a procedure.
	    # We have to put a special hack in here to work
	    # around a very poor implementation the tk_get*File and
	    # tk_messageBox dialogs on Unix.

	    if {[regexp \
		    {^(::)?tk_(messageBox|getOpenFile|getSaveFile)$} \
		    $name dummy1 dummy2 match]} {
		if {$match == "messageBox"} {
		    set name "tkMessageBox"
		} else {
		    set name "tkFDialog"
		}
		if {$DbgNub(namespace)} {
		    set name "::$name"
		}
		set argList "args"
	    } else {
		set argList ""
	    }
	}
	lappend DbgNub(stack) [list $level "proc" $name $argList]
    }
    if {$frame != {}} {
	lappend DbgNub(stack) $frame
    }
    return $marker
}

# DbgNub_PopStack --
#
#	Pop frames from the stack that were pushed by DbgNub_PushStack.
#
# Arguments:
#	marker		Marker value returned by DbgNub_PushStack
#
# Results:
#	None.

proc DbgNub_PopStack {marker} {
    global DbgNub

    set DbgNub(stack) [lrange $DbgNub(stack) 0 $marker]
    return
}

# DbgNub_CollateStacks --
#
#	Merge the call stack with the instruction stack.  The istack
#	may have more than one frame for any given call stack frame due to
#	virtual frames pushed by commands like "source", but it may also be
#	missing some uninstrumented frames.  Because of this, we have to
#	collate the two stacks to recover the complete stack description.
#
# Arguments:
#	None.
#
# Results:
#	Returns the merged stack.

proc DbgNub_CollateStacks {} {
    global DbgNub

    set result ""

    # Put the current context and location list onto the stack so
    # we can deal with the whole mess at once

    lappend DbgNub(contextStack) [list $DbgNub(context) $DbgNub(locations)]

    if {$DbgNub(debug) & 1} {
	DbgNub_Log "Collate context: $DbgNub(contextStack)\nstack: $DbgNub(stack)"
    }

    set s [expr {[llength $DbgNub(stack)] - 1}]
    set i [expr {[llength $DbgNub(contextStack)] - 1}]

    while {$i >= 0} {
	set iframes {}

	# Look for the next instrumented procedure invocation so we can match
	# it against the call stack. Generate stack information for each
	# instrumented instruction location that is in a new block or a new
	# scope.

	while {$i >= 0} {
	    set frame [lindex $DbgNub(contextStack) $i]
	    incr i -1
	    set locations [lindex $frame 1]
	    set context [lindex $frame 0]
	    set temp {}
	    set block {}
	    for {set l [expr {[llength $locations] - 1}]} {$l >= 0} {incr l -1} {
		set location [lindex $locations $l]
		set newBlock [lindex $location 0]
		if {[string compare $newBlock $block] != 0} {
		    set iframes [linsert $iframes 0 \
			    [linsert $context 1 $location]]
		    set block $newBlock
		}
	    }
	    # Add a dummy frame if we have an empty context.
	    if {$context != "" && $locations == ""} {
		set iframes [linsert $iframes 0 [linsert $context 1 {}]]
	    }
	    set type [lindex $context 1]
	    switch $type {
		configure -
		debugger_eval -
		proc -
		class -
		global -
		event -
		uplevel -
		method -
		source -
		namespace -
		package {
		    break
		}
	    }
	}

	# Find the current instrumented statement on the call stack.  Generate
	# stack information for any uninstrumented frames.

	while {$s >= 0} {
	    set sframe [lindex $DbgNub(stack) $s]
	    incr s -1
	    if {[string compare $context $sframe] == 0} {
		break
	    } elseif {[string match *(deleted) $sframe] \
		    && ([string compare [lrange $context 0 1] \
		    [lrange $sframe 0 1]] == 0)} {
		break
	    }
		
	    set result [linsert $result 0 [linsert $sframe 1 {}]]
	}
	set result [concat $iframes $result]
    }

    # Add any uninstrumented frames that appear before the first instrumented
    # statement.

    while {$s >= 0} {
	set result [linsert $result 0 [linsert [lindex $DbgNub(stack) $s] 1 {}]]
	incr s -1
    }
    set DbgNub(contextStack) [lreplace $DbgNub(contextStack) end end]
    if {$DbgNub(debug) & 1} {
	DbgNub_Log "Collate result: $result"
    }
    return $result
}

# DbgNub_Proc --
#
#	Define a new instrumented procedure.
#
# Arguments:
#	location	Location that contains the entire definition.
#	name		Procedure name.
#	argList		Argument list for procedure.
#	body		Instrumented body of procedure.
#
# Results:
#	None.

proc DbgNub_Proc {location name argList body} {
    global DbgNub
    
    set ns $DbgNub(scope)
    if {$DbgNub(namespace)} {
	# Create an empty procedure first so we can determine the correct
	# absolute name.
	DbgNub_uplevelCmd 1 [list DbgNub_procCmd $name {} {}]
	set fullName [DbgNub_uplevelCmd 1 \
		[list $DbgNub(scope)namespace origin $name]]

	set nameCmd "\[DbgNub_uplevelCmd 1 \[${ns}list ${ns}namespace origin \[${ns}lindex \[${ns}info level 0\] 0\]\]\]"
    } else {
	set fullName $name

	set nameCmd "\[lindex \[info level 0\] 0\]"
    }

    set DbgNub(proc=$fullName) $location

    # Two variables are substituted into the following string.  The
    # fullName variable contains the full name of the procedure at
    # the time the procedure was created.  The body variable contains
    # the actual "user-specified" code for the procedure. 
    # NOTE: There is some very tricky code at the end relating to unsetting
    # some local variables.  We need to unset local variables that have
    # traces before the procedure context goes away so things look
    # rational on the stack.  In addition, we have to watch out for upvar
    # variables because of a bug in Tcl where procedure arguments that are
    # unset and then later reused as upvar variables will show up in the
    # locals list.  If we did an unset on these, we'd blow away the variable
    # in the other scope.  Instead we just upvar the variable to a dummy
    # variable that will get cleaned up locally.

    return [DbgNub_uplevelCmd 1 [list DbgNub_procCmd $name $argList \
	    "#DBG INSTRUMENTED PROC TAG
    ${ns}upvar #0 errorInfo DbgNub_errorInfo errorCode DbgNub_errorCode
    ${ns}set DbgNub_level \[DbgNub_infoCmd level\]
    DbgNub_PushProcContext \$DbgNub_level
    ${ns}set DbgNub_catchCode \[DbgNub_UpdateReturnInfo \[
        [list DbgNub_catchCmd $body DbgNub_result]\]\]
    ${ns}foreach DbgNub_index \[${ns}info locals\] {
	${ns}if {\[${ns}trace vinfo \$DbgNub_index\] != \"\"} {
	    ${ns}if {[${ns}catch {${ns}upvar 0 DbgNub_dummy \$DbgNub_index}]} {
		${ns}catch {${ns}unset \$DbgNub_index}
	    }
	}
    }
    DbgNub_PopContext
    ${ns}return -code \$DbgNub_catchCode -errorinfo \$DbgNub_errorInfo -errorcode \$DbgNub_errorCode \$DbgNub_result"]]
}

# DbgNub_PushProcContext --
#
#	Determine the current procedure context, then push it on the
#	context stack.  This routine handles some of the weird cases
#	like procedures that are being invoked by way of an alias.
#	NOTE: much of this code is identical to that in DbgNub_PushStack.
#
# Arguments:
#	level	The current stack level.
#
# Results:
#	None.

proc DbgNub_PushProcContext {level} {
    global DbgNub
    
    set name [lindex [DbgNub_infoCmd level $level] 0]

    # If we are using namespaces, transform the name to fully qualified
    # form before trying to get the arglist.  Determine whether the
    # name refers to a proc or a command.
    
    if {$DbgNub(namespace)} {
	set qualName [DbgNub_uplevelCmd \#[expr {$level - 1}] \
		[list $DbgNub(scope)namespace origin $name]]

	if {$qualName == ""} {
	    DbgNub_PushContext $level "proc" $name {}
	} else {
	    set name $qualName
	}
    

	# Because of Tcl's namespace design, "info procs" does not
	# work on qualified names.  The workaround is to invoke the
	# "info" command inside the namespace.

	set qual [namespace qualifiers $name]
	if {$qual == ""} {
	    set qual ::
	}
	set tail [namespace tail $name]
	set isProc [namespace eval $qual [list DbgNub_infoCmd procs $tail]]
    } else {
	set isProc [DbgNub_infoCmd procs $name]
    }
	
    if {$isProc != ""} {
	set args [DbgNub_uplevelCmd \#$level [list DbgNub_infoCmd args $name]]
    } else {
	set args ""
    }
    DbgNub_PushContext $level "proc" $name $args
    return
}

# DbgNub_WrapItclBody --
#
#	Define a new instrumented [incr Tcl] function, adding the standard
#	prefix/suffix to the body, if possible.  The last argument is
#	expected to be the body of the function.
#
# Arguments:
#	args		The command and all of its args, the last of which
#			must be the body.
#
# Results:
#	None.

proc DbgNub_WrapItclBody {args} {
    upvar #0 DbgNub(scope) ns
    set body [lindex $args end]
    set args [lrange $args 0 [expr {[llength $args] - 2}]]
    if {[string index $body 0] != "@"} {
	set body "#DBG INSTRUMENTED PROC TAG
    ${ns}upvar #0 errorInfo DbgNub_errorInfo errorCode DbgNub_errorCode
    ${ns}set DbgNub_level \[DbgNub_infoCmd level\]
    ${ns}eval \[${ns}list DbgNub_PushContext \$DbgNub_level\] \[info function \[${ns}lindex \[info level 0\] 0\] -type -name -args\]
    ${ns}set DbgNub_catchCode \[DbgNub_UpdateReturnInfo \[
        [list DbgNub_catchCmd $body DbgNub_result]\]\]
    ${ns}foreach DbgNub_index \[${ns}info locals\] {
	${ns}if {\[${ns}trace vinfo \$DbgNub_index\] != \"\"} {
	    ${ns}if {[${ns}catch {${ns}upvar 0 DbgNub_dummy \$DbgNub_index}]} {
		${ns}catch {${ns}unset \$DbgNub_index}
	    }
	}
    }
    DbgNub_PopContext
    ${ns}return -code \$DbgNub_catchCode -errorinfo \$DbgNub_errorInfo -errorcode \$DbgNub_errorCode \$DbgNub_result"
    }
    return [DbgNub_uplevelCmd 1 $args [list $body]]
}

# DbgNub_WrapItclConfig --
#
#	Define a new [incr Tcl] config body.  These bodies run in a
#	namespace context instead of a procedure context, so we need to
#	call a function instead of putting the code inline.
#
# Arguments:
#	args	The command that defines the config body, the last argument
#		of which contains the body script.
#
# Results:
#	Returns the result of defining the config body.

proc DbgNub_WrapItclConfig {args} {
    set body [lindex $args end]
    set args [lrange $args 0 [expr {[llength $args] - 2}]]
    if {[string index $body 0] != "@"} {
	set body [list DbgNub_ItclConfig $body]
    }
    return [DbgNub_uplevelCmd 1 $args [list $body]]
}

# DbgNub_ItclConfig --
#
#	Perform an [incr Tcl] variable configure operation.  This is
#	basically just a namespace eval, but we want it to behave like
#	a procedure call in the interface.
#
# Arguments:
#	args	The original body.
#
# Results:
#	Returns the result of evaluating the body.

proc DbgNub_ItclConfig {body} {
    global errorInfo errorCode DbgNub

    set level [expr {[DbgNub_infoCmd level]-1}]
    DbgNub_PushContext $level configure

    # Replace the current stack frame with a "configure" frame so we don't
    # end up with a wierd namespace eval on the stack.

    set marker [DbgNub_PushStack [expr {$level-1}] [list $level configure]]
    set code [DbgNub_catchCmd \
	    {DbgNub_uplevelCmd 1 $body} result]
    DbgNub_PopStack $marker

    # Check to see if we are in the middle of a step-out operation and
    # we are unwinding from the initial context.

    if {$DbgNub(stepOutLevel) == [llength $DbgNub(contextStack)]} {
	set DbgNub(stepOutLevel) {}
	set DbgNub(breakNext) 1
    }
    DbgNub_PopContext

    return -code $code -errorinfo $errorInfo -errorcode $errorCode $result
}

# DbgNub_Constructor --
#
#	Define a new instrumented [incr Tcl] constructor.
#
# Arguments:
#	cmd		"constructor"
#	argList		Argument list for method.
#	args		The body arguments
#
# Results:
#	None.

proc DbgNub_Constructor {cmd argList args} {
    if {[llength $args] == 2} {
	# The initializer script isn't a procedure context.  It's more
	# like a namespace eval.  In order to get return code handling to
	# work properly, we need to call a procedure that will push/pop
	# the context and clean up the return code properly.

	set body1 [list [list DbgNub_ConstructorInit [lindex $args 0]]]
    } else {
	# Set the first body to null so it gets thrown away by the concat
	# in the uplevel command.

	set body1 {}
    }
    set body2 [list [lindex $args end]]
    return [DbgNub_uplevelCmd 1 [list DbgNub_WrapItclBody $cmd $argList] \
	    $body1 $body2]
}

# DbgNub_ConstructorInit --
#
#	This function pushes a context for the init block of a constructor.
#
# Arguments:
#	body		The body of code to evaluate.
#
# Results:
#	Returns the result of evaluating the body.

proc DbgNub_ConstructorInit {body} {
    global errorInfo errorCode

    # Determine the calling context.

    set level [expr {[DbgNub_infoCmd level] - 1}]
    eval [list DbgNub_PushContext $level] [DbgNub_uplevelCmd 1 \
	    {info function [lindex [info level 0] 0] -type -name -args}]

    set code [DbgNub_catchCmd {DbgNub_uplevelCmd 1 $body} result]

    DbgNub_PopContext
    return -code $code -errorinfo $errorInfo -errorcode $errorCode $result
}

# DbgNub_Class --
#
#	Push a new context for a class command.  This is really a
#	namespace eval so, it needs to fiddle with the step level.
#
# Arguments:
#	cmd		Should be "class".
#	name		The name of the class being defined.
#	body		The body of the class being defined.
#
# Results:
#	Returns the result of evaluating the class command.

proc DbgNub_Class {cmd name body} {
    global errorInfo errorCode DbgNub

    DbgNub_PushContext [DbgNub_infoCmd level] class

    incr DbgNub(stepLevel)
    if {$DbgNub(stepOutLevel) != {}} {
	incr DbgNub(stepOutLevel)
    }
    set code [DbgNub_catchCmd \
	    {DbgNub_uplevelCmd 1 [list $cmd $name $body]} result]
    if {$DbgNub(stepOutLevel) != {}} {
	incr DbgNub(stepOutLevel) -1
    }
    incr DbgNub(stepLevel) -1
    DbgNub_PopContext

    return -code $code -errorinfo $errorInfo -errorcode $errorCode $result
}

# DbgNub_NamespaceEval --
#
#	Define a new instrumented namespace eval.  Pushes a new context
#	and artificially bumps the step level so step over will treat
#	namespace eval like any other control structure.
#
# Arguments:
#	args	The original namespace command.
#
# Results:
#	None.

proc DbgNub_NamespaceEval {args} {
    global errorInfo errorCode DbgNub
    set level [DbgNub_infoCmd level]

    if {$DbgNub(itcl76)} {
	set name [lindex $args 1]
	set cmd [list $DbgNub(scope)DbgNub_infoCmd context]
    } else {
	set name [lindex $args 2]
	set cmd [list $DbgNub(scope)namespace current]
    }

    if {![string match ::* $name]} {
	set name [DbgNub_uplevelCmd 1 $cmd]::$name
    }
    regsub -all {::+} $name :: name
    DbgNub_PushContext $level "namespace eval $name"
    incr DbgNub(stepLevel)
    if {$DbgNub(stepOutLevel) != {}} {
	incr DbgNub(stepOutLevel)
    }
    set code [DbgNub_catchCmd {
	DbgNub_uplevelCmd 1 $args
    } result]
    if {$DbgNub(stepOutLevel) != {}} {
	incr DbgNub(stepOutLevel) -1
    }
    incr DbgNub(stepLevel) -1
    DbgNub_PopContext

    return -code $code -errorinfo $errorInfo -errorcode $errorCode $result
}

proc DbgNub_Apply {args} {
    global errorInfo errorCode DbgNub
    set level [DbgNub_infoCmd level]

    set argList [lassign $args x func]
    set lfunc [llength $func]

    if {$lfunc < 2 || $lfunc > 3} {
        set msg "can't interpret \"$func\" as a lambda expression"
        set code [DbgNub_catchCmd {
             DbgNub_uplevelCmd 1 [list error $msg]
        } result]
        return -code $code -errorinfo $errorInfo -errorcode $errorCode $result
    }

    lassign $func procArgs body ns
    lassign [concat $ns ::] ns

    set ns [DbgNub_uplevelCmd 1 namespace inscope $ns namespace current]
    set ns [string trimright $ns :]

    set procName ${ns}::<apply>
    proc $procName $procArgs $body

    set code [DbgNub_catchCmd {
    DbgNub_uplevelCmd 1 $procName $argList
    } result]

    rename $procName {}

    return -code $code -errorinfo $errorInfo -errorcode $errorCode $result
}

# DbgNub_WrapCommands --
#
#	This command is invoked at the beginning of every instrumented
#	procedure.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc DbgNub_WrapCommands {} {
    global DbgNub

    foreach cmd $DbgNub(wrappedCommandList) {
	if {$cmd == "rename"} continue

	rename $cmd DbgNub_${cmd}Cmd
	rename DbgNub_${cmd}Wrapper $cmd
    }

    # Need to be a little careful when renaming rename itself...
    rename rename DbgNub_renameCmd
    DbgNub_renameCmd DbgNub_renameWrapper rename
}

# DbgNub_exitWrapper --
#
#     Called whenever the applpication invokes "exit".  Calls the coverage
#     check check command before exitting.
#
# Arguments:
#     args    Arguments passed to original exit call.
#
# Results:
#     Returns the same result that the exit call would have.

if {0} {
proc DbgNub_exitWrapper {args} {
    global DbgNub

    set level [expr {[DbgNub_infoCmd level] - 1}]
    set cmd "DbgNub_Break $level exit $args"
    eval $cmd

    set exitCmd "DbgNub_exitCmd $args"
    eval $exitCmd
}
}

# DbgNub_catchWrapper --
#
#	Called whenever the application invokes "catch".  Changes the error
#	handling so we don't report errors that are going to be caught.
#
# Arguments:
#	args	Arguments passed to original catch call.
#
# Results:
#	Returns the result of evaluating the catch statement.

proc DbgNub_catchWrapper {args} {
    global DbgNub errorCode errorInfo
    set oldCatch $DbgNub(catch)
    set DbgNub(catch) 0
    set code [DbgNub_catchCmd {DbgNub_uplevelCmd DbgNub_catchCmd $args} result]
    if {$code == 1} {
	regsub -- DbgNub_catchCmd $errorInfo catch errorInfo
    }
    set DbgNub(errorHandled) 0
    set DbgNub(catch) $oldCatch
    if {[DbgNub_infoCmd exists DbgNub(returnState)]} {
	unset DbgNub(returnState)
    }
    return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
}

# DbgNub_Return --
#
#	Called whenever the application invokes "return".  We need
#	to manage a little extra state when the user uses the -code
#	option because we can't determine the actual code used at the
#	call site.  All calls to "return" have a result code of 2 and the
#	real value is stored inside the interpreter where we can't get at
#	it.  So we cache the result code in global state and fetch it back
#	at the call site so we can invoke the standard "return" at the
#	proper scope with the proper -code.
#
# Arguments:
#	args	Arguments passed to original return call.
#
# Results:
#	Returns the result of evaluating the return statement.

proc DbgNub_Return {args} {
    global DbgNub errorCode errorInfo

    # Get the value of the -code option if given.  (If it isn't given 
    # then Tcl assumes it is -code OK; we assume the same.

    set realCode "ok"
    set realErrorCode ""
    set realErrorInfo ""
    set argc [llength $args]
    for {set i 0} {$i < $argc} {incr i 2} {
	set arg [lindex $args $i]
	if {$arg == "-code"} {
	    set realCode [lindex $args [expr {$i + 1}]]
	} elseif {$arg == "-errorcode"} {
	    set realErrorCode [lindex $args [expr {$i + 1}]]
	} elseif {$arg == "-errorinfo"} {
	    set realErrorInfo [lindex $args [expr {$i + 1}]]
	} elseif {$arg in {-errorstack -level}} {
        error "argument $arg not supported"
    }
    }
    

    # Invoke the return command so we can see what the result would have been.
    # We need to check to see if the call to return failed so we can clean up
    # the errorInfo.  If the call succeeds, we store the real return code so we
    # can retrieve it later.

    set code [DbgNub_catchCmd {DbgNub_uplevelCmd $DbgNub(scope)return $args} result]
    if {$code == 1} {
	regsub -- DbgNub_Return $errorInfo catch errorInfo
    } else {
	set DbgNub(returnState) [list $realCode $realErrorCode $realErrorInfo]
    }
    return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
}

# DbgNub_UpdateReturnInfo --
#
#	Restore the errorCode and errorInfo that was cached by DbgNub_Return.
#	Test to see if a step out is in progress and convert it to an
#	interrupt if necessary. This routine is called in the procedure and
#	method header code inserted by the instrumenter as well as the
#	wrapper for the "source" command.
#
# Arguments:
#	code	The result code of the last command.
#
# Results:
#	Returns the new result code, modifies errorCode/errorInfo as
#	needed and creates upvar'd versions of errorCode/errorInfo in
#	the caller's context.

proc DbgNub_UpdateReturnInfo {code} {
    global errorInfo errorCode DbgNub
    if {$code == 2 || $code == "return"} {
	if {[DbgNub_infoCmd exists DbgNub(returnState)]} {
	    set code [lindex $DbgNub(returnState) 0]
	    set errorCode [lindex $DbgNub(returnState) 1]
	    set errorInfo [lindex $DbgNub(returnState) 2]
	    unset DbgNub(returnState)
	} else {
	    set code 0
	}
    }
    DbgNub_uplevelCmd 1 "
	$DbgNub(scope)upvar #0 errorInfo DbgNub_errorInfo
	$DbgNub(scope)upvar #0 errorCode DbgNub_errorCode
    "

    # Check to see if we are in the middle of a step-out operation and
    # we are unwinding from the initial context.

    if {$DbgNub(stepOutLevel) == [llength $DbgNub(contextStack)]} {
	set DbgNub(stepOutLevel) {}
	set DbgNub(breakNext) 1
    }
	
    return $code
}

# DbgNub_procWrapper --
#
#	Called whenever the application invokes "proc" on code that has
#	not been instrumented.  This allows for dynamic procedures to
#	be instrumented.  This feature may be turned off by the user.
#	The DbgNub(dynProc) flag can be used to turn this feature on
#	or off.
#
# Arguments:
#	args	Arguments passed to original catch call.
#
# Results:
#	Returns the result of evaluating the catch statement.

proc DbgNub_procWrapper {args} {
    global DbgNub errorInfo errorCode
    set length [llength $args]
    set unset 0
    if {($length == 3) && ($DbgNub(socket) != -1)} {

	# Don't allow redefining of builtin commands that the 
	# debugger relies on.

	set searchName [lindex $args 0]
	set level [expr {[DbgNub_infoCmd level] - 1}]
	if {![DbgNub_okToRename $searchName $level]} {
	    return -code 1 \
		    "cannot overwrite \"[lindex $args 0]\" in the debugger"
	}

	set body [lindex $args end]
	if {[regexp "\n# DBGNUB START: (\[^\n\]*)\n" $body dummy data]} {
	    # This body is already instrumented, so we should not reinstrument
	    # it, but we do want to define it as an instrumented procedure.

	    set icode [linsert $args 0 DbgNub_Proc [lindex $data 0]]
	} elseif {$DbgNub(dynProc) && !$DbgNub(inExclude) \
		&& ($DbgNub(autoLoad) \
		    || (!$DbgNub(inRequire) && !$DbgNub(inAutoLoad)))} {
	    # This is a dynamic procedure, so we need to instrument it first.
	    # The code we get back starts with a DbgNub_Do which we don't want
	    # to run so we have to strip out the actual proc command.

	    set script [linsert $args 0 "proc"]
	    set icode [DbgNub_Instrument "" $script]
	    set loc [lindex $icode 2]
	    set cmd [lindex $icode 3]

	    # Now change things so we are calling DbgNub_Proc instead of
	    # proc so this routine gets created like a normal instrumented
	    # procedure.

	    set icode [lreplace $cmd 0 0 "DbgNub_Proc" $loc]
	} else {
	    # This is a dynamic procedure, but we are ignoring them
	    # right now per user setting.

	    set icode [linsert $args 0 "DbgNub_procCmd"]
	    set unset 1
	}
	set code [DbgNub_catchCmd {DbgNub_uplevelCmd 1 $icode} result]
    } else {
	# This isn't a well formed call to proc, or we aren't connected
	# to the debugger any longer, so let it execute without interference. 

	set icode [linsert $args 0 DbgNub_procCmd]
	set unset 1
    }
    set code [DbgNub_catchCmd {DbgNub_uplevelCmd 1 $icode} result]
    
    if {$unset} {
	# We need to check if we are replacing an already
	# instrumented procedure with an uninstrumented body.
	# If so, we need to clean up some state.

	set name [lindex $args 0]
	if {$DbgNub(namespace)} {
	    set name [DbgNub_uplevelCmd 1 \
		    [list $DbgNub(scope)namespace which $name]]
	}
	if {[DbgNub_infoCmd exists DbgNub(proc=$name)]} {
	    unset DbgNub(proc=$name)
	}
    }
    if {$code == 1} {
	set result [DbgNub_cleanErrorInfo $result DbgNub_procCmd proc]
	set DbgNub(cleanWrapper) {DbgNub_procCmd proc}
	return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
    }
    return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
}

# DbgNub_infoWrapper --
#
#	Called whenever the applpication invokes "info".  Changes the
#	output of some introspection commands to hide the debugger's
#	changes to the environment.
#
# Arguments:
#	args	Arguments passed to original info call.
#
# Results:
#	Returns the result of evaluating the info statement.

proc DbgNub_infoWrapper {args} {
    global DubNub errorCode errorInfo
    set code [DbgNub_catchCmd {DbgNub_uplevelCmd DbgNub_infoCmd $args} result]
    if {$code == 1} {
	set result [DbgNub_cleanErrorInfo $result DbgNub_infoCmd info]
	set DbgNub(cleanWrapper) {DbgNub_infoCmd info}
	return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
    }
    switch -glob -- [lindex $args 0] {
	comm* -
	pr* {
	    set newResult ""
	    foreach x $result {
		if {![regexp DbgNub_* $x]} {
		    # Strip out the commands we wrapped.
		    global DbgNub

		    if {[lsearch $DbgNub(wrappedCommandList) $x] != -1} {
			if {[string match p* [lindex $args 0]]} {
			    continue
			}
		    }
		    lappend newResult $x
		}
	    }
	    set result $newResult
	}
	loc* -
	v* -
	g* {
	    # We string out the DbgNub variable and any variable that
	    # begins with DbgNub_

	    set i [lsearch -exact $result DbgNub]
	    if {$i != -1} {
		set result [lreplace $result $i $i]
	    }
	    set newResult ""
	    foreach x $result {
		if {[regexp DbgNub_* $x]} {
		    continue
		}
		lappend newResult $x
	    }
	    set result $newResult
	}
	b* {
	    if {[string compare "#DBG INSTRUMENTED PROC TAG" $result] == -1} {
		global DbgNub

		set name [lindex $args 1]
		if {$DbgNub(namespace)} {
		    set name [DbgNub_uplevelCmd 1 \
			    [list $DbgNub(scope)namespace origin $name]]
		}
		if {! [DbgNub_infoCmd exists DbgNub(proc=$name)]} {
		    error "debugger in inconsistant state"
		}
		DbgNub_SendMessage PROCBODY $DbgNub(proc=$name)
		DbgNub_ProcessMessages 1
		return $DbgNub(body)
	    }
	}
	sc* {
	    global DbgNub
	    return [lindex $DbgNub(script) end]
	}
    }
    return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
}

# DbgNub_sourceWrapper --
#
#	Called whenever the application tries to source a file.
#	Loads the file and passes the contents to the debugger to
#	be instrumented.
#
# Arguments:
#	file	File name to source.
#
# Results:
#	Returns the result of evaluating the instrumented code.

proc DbgNub_sourceWrapper {args} {
    global DbgNub errorCode errorInfo

    if {[llength $args] == 1} {
	set file [lindex $args 0]
    } else {
	# Let the real source command generate the error for bad args.

	set code [DbgNub_catchCmd {DbgNub_uplevelCmd DbgNub_sourceCmd $args} \
		result]
	set errorInfo ""
	regsub -- "DbgNub_sourceCmd" $result "source" result
	return -code $code -errorcode $errorCode $result
    }

    # Short circuit the procedure if we aren't connected to the debugger.

    if {$DbgNub(socket) == -1} {
	set code [DbgNub_catchCmd {
	    DbgNub_uplevelCmd [list DbgNub_sourceCmd $file]
	} result]
	return -code $code -errorcode $errorCode -errorinfo $errorInfo \
		$result
    }
	
    # If the users preferences indicate that autoloaded scripts 
    # are not to be instrumented, then check to see if this file
    # is being autoloaded.  The test is to look up the stack, if
    # the "auto_load" or "auto_import" procs are on the stack, then we are
    # autoloading.

    if {!$DbgNub(autoLoad)} {
	set DbgNub(inAutoLoad) 0
	foreach stack $DbgNub(stack) {
	    if {([lindex $stack 1] == "proc") \
		    && [regexp {^(::)?auto_(load|import)$} \
			[lindex $stack 2]]} {
		set DbgNub(inAutoLoad) 1
		break
	    }
	}
    }

    # Clear the inExclude flag since we are about to source a new file and
    # any previous exclude flag doesn't apply until we are done.

    set oldExclude $DbgNub(inExclude)
    set DbgNub(inExclude) 0

    if {!$DbgNub(autoLoad) && ($DbgNub(inAutoLoad) || $DbgNub(inRequire))} {
	set dontInstrument 1
    } else {
	# Check to see if this file matches any of the included file
	# patterns.  If not set the dontInstrument flag to true,
	# so the file is not instrumented.  Otherwise, check to see if
	# it matches one of the excluded file patterns.

	set dontInstrument 1
	foreach pattern $DbgNub(includeFiles) {
	    if {[string match $pattern $file]} {
		set dontInstrument 0
		break
	    }
	}	
	if {$dontInstrument} {
	    set DbgNub(inExclude) 1
	} else {
	    # Check to see if this file matches any of the excluded file
	    # patterns.  If it does, set the dontInstrument flag to true,
	    # so the file is not instrumented.

	    foreach pattern $DbgNub(excludeFiles) {
		if {[string match $pattern $file]} {
		    set dontInstrument 1
		    set DbgNub(inExclude) 1
		    break
		}
	    }
	}
    }

    # If the "dontInstrument" flag is true, just source the file 
    # normally, taking care to propagate the error result.
    # NOTE: this will not work on the Macintosh because of it's additional
    # arguments.

    if {$dontInstrument} {
	# Set the global value DbgNub(dynProc) to false so procs 
	# defined in the uninstrumented file will not become 
	# instrumented even if the dynProcs flag was true.  
	# Restore the value to the value when done with the
	# read-only copy of the original dynProc variable.
	
	lappend DbgNub(script) $file

	set code [DbgNub_catchCmd {
	    DbgNub_uplevelCmd [list DbgNub_sourceCmd $file]
	} result]
	
	set DbgNub(script) [lreplace $DbgNub(script) end end]
	set DbgNub(inExclude) $oldExclude

	return -code $code -errorcode $errorCode -errorinfo $errorInfo \
		$result
    }

    lappend DbgNub(script) $file

    # Pass the contents of the file to the debugger for
    # instrumentation.
    
    set result [catch {set f [open $file r]} msg]
    if {$result != 0} {
	# We failed to open the file, so let source take care of generating
	# the error.

	set DbgNub(script) [lreplace $DbgNub(script) end end]
	set DbgNub(inExclude) $oldExclude

	set code [DbgNub_catchCmd {
	    DbgNub_uplevelCmd DbgNub_sourceCmd $args
	} result]
	set errorInfo ""
	regsub -- "DbgNub_sourceCmd" $result "source" result
	return -code $code -errorcode $errorCode $result
    }
    set source [read $f]
    close $f

    # We now need to calculate the absolute path so the
    # engine will be able to point to this file.  We then pass
    # the script to the engine to be processed.

    set oldwd [pwd]
    cd [file dir $file]
    set absfile [file join [pwd] [file tail $file]]
    cd $oldwd

    set icode [DbgNub_Instrument $absfile $source]

    # If the instrumentation failed, we just source the original file

    if {$icode == ""} {
	set icode $source
    }
    
    # Evaluate the instrumented code, propagating
    # errors that might occur during the eval.

    set level [expr {[DbgNub_infoCmd level] - 1}]
    DbgNub_PushContext $level "source" $file
    set marker [DbgNub_PushStack $level [list $level "source" $file]]
    set code [DbgNub_UpdateReturnInfo [DbgNub_catchCmd {
	DbgNub_uplevelCmd 1 $icode
    } result]]
    DbgNub_PopStack $marker
    DbgNub_PopContext

    set DbgNub(script) [lreplace $DbgNub(script) end end]
    set DbgNub(inExclude) $oldExclude

    if {($code == 1)  || ($code == "error")} {
	set result [DbgNub_cleanErrorInfo $result DbgNub_sourceCmd info]
	set DbgNub(cleanWrapper) {DbgNub_sourceCmd source}
	set errorInfo "$result$errorInfo"
	set errorCode NONE
	error $result $errorInfo $errorCode
    }
    return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
}

# DbgNub_vwaitWrapper --
#
#	Called whenever the program enters the event loop. Records a
#	discontinuity in the Tcl stack. 
#
# Arguments:
#	args	Arguments passed to original vwait call.
#
# Results:
#	Returns the result of the vwait statement.

proc DbgNub_vwaitWrapper {args} {
    global DbgNub errorCode errorInfo
    DbgNub_PushContext 0 event
    set marker [DbgNub_PushStack [expr {[DbgNub_infoCmd level] - 1}] "0 event"]
    set oldCatch $DbgNub(catch)
    set DbgNub(catch) 1
    set oldCount $DbgNub(nestCount)
    set DbgNub(nestCount) 0
    set code [DbgNub_catchCmd {
	DbgNub_uplevelCmd DbgNub_vwaitCmd $args
    } result]
    set DbgNub(catch) $oldCatch
    set DbgNub(nestCount) $oldCount
    DbgNub_PopStack $marker
    DbgNub_PopContext
    if {$code == 1} {
	set result [DbgNub_cleanErrorInfo $result DbgNub_vwaitCmd vwait]
	set DbgNub(cleanWrapper) {DbgNub_vwaitCmd vwait}
    }
    return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
}

# DbgNub_updateWrapper --
#
#	Called whenever the program enters the event loop. Records a
#	discontinuity in the Tcl stack. 
#
# Arguments:
#	args	Arguments passed to original update call.
#
# Results:
#	Returns the result of the update statement.

proc DbgNub_updateWrapper {args} {
    global DbgNub errorCode errorInfo
    DbgNub_PushContext 0 event
    set marker [DbgNub_PushStack [expr {[DbgNub_infoCmd level] - 1}] "0 event"]
    set oldCatch $DbgNub(catch)
    set DbgNub(catch) 1
    set oldCount $DbgNub(nestCount)
    set DbgNub(nestCount) 0
    set code [DbgNub_catchCmd {
	DbgNub_uplevelCmd DbgNub_updateCmd $args
    } result]
    set DbgNub(catch) $oldCatch
    set DbgNub(nestCount) $oldCount
    DbgNub_PopStack $marker
    DbgNub_PopContext
    if {$code == 1} {
	set result [DbgNub_cleanErrorInfo $result DbgNub_updateCmd update]
	set DbgNub(cleanWrapper) {DbgNub_updateCmd update}
    }
    return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
}

# DbgNub_uplevelWrapper --
#
#	Called whenever the program calls uplevel. Records a
#	discontinuity in the Tcl stack. 
#
# Arguments:
#	args	Arguments passed to original uplevel call.
#
# Results:
#	Returns the result of the uplevel statement.

proc DbgNub_uplevelWrapper {args} {
    global errorCode errorInfo
    set level [lindex $args 0]
    if {[string index $level 0] == "#"} {
	set level [string range $level 1 end]
	set local 0
    } else {
	set local 1
    }
    if {[DbgNub_catchCmd {incr level 0}]} {
	set level [expr {[DbgNub_infoCmd level] - 2}]
    } elseif {$local} {
	set level [expr {[DbgNub_infoCmd level] - 1 - $level}]
    }
    DbgNub_PushContext $level uplevel
    set marker [DbgNub_PushStack \
	    [expr {[DbgNub_infoCmd level] - 1}] [list $level uplevel]]
    set code [DbgNub_catchCmd {
	DbgNub_uplevelCmd DbgNub_uplevelCmd $args
    } result]
    DbgNub_PopStack $marker
    DbgNub_PopContext
    if {$code == 1} {
	set result [DbgNub_cleanErrorInfo $result DbgNub_uplevelCmd uplevel]
	set DbgNub(cleanWrapper) {DbgNub_uplevelCmd uplevel}
    }
    return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
}

# DbgNub_packageWrapper --
#
#	Called whenever the program calls package. Records a
#	discontinuity in the Tcl stack. 
#
# Arguments:
#	args	Arguments passed to original package call.
#
# Results:
#	Returns the result of the package statement.

proc DbgNub_packageWrapper {args} {
    global errorCode errorInfo DbgNub

    set level [expr {[DbgNub_infoCmd level] - 1}]
    set cmd [lindex $args 0]

    set oldRequire $DbgNub(inRequire)
    set DbgNub(inRequire) 1

    DbgNub_PushContext 0 package $cmd
    set marker [DbgNub_PushStack $level [list 0 "package" $cmd]]
    set code [DbgNub_catchCmd {
	DbgNub_uplevelCmd DbgNub_packageCmd $args
    } result]
    DbgNub_PopStack $marker
    DbgNub_PopContext

    set DbgNub(inRequire) $oldRequire

    if {$code == 1} {
	set result [DbgNub_cleanErrorInfo $result DbgNub_packageCmd package]
	set DbgNub(cleanWrapper) {DbgNub_packageCmd package}
    }

    return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
}

# DbgNub_renameWrapper --
#
#	A replacement for the standard "rename" command.  We need to
#	do a little extra work when renaming instrumented procs.
#
# Arguments:
#	args	Arguments passed to original rename call.
#
# Results:
#	Returns the result of the rename statement.

proc DbgNub_renameWrapper {args} {
    global DbgNub errorCode errorInfo
    
    # Check to see if the name we are about to rename is in a namespace.
    # We need to get the full name for this command before and after
    # it is renamed.

    if {[llength $args] > 0} {
	set level [expr {[DbgNub_infoCmd level] - 1}]

	set name [lindex $args 0]
	if {$DbgNub(namespace)} {
	    set name [DbgNub_uplevelCmd 1 \
		    [list $DbgNub(scope)namespace origin $name]]

	    # Check to see if the command we are about to rename is imported
	    # from a namespace.  If so we need to short circuit out here
	    # because imported procs will choke on the code below.

	    if {$name != [DbgNub_uplevelCmd 1 \
		    [list $DbgNub(scope)namespace which [lindex $args 0]]]} {
		set $name [lindex $args 0]
		set code [DbgNub_catchCmd {
		    DbgNub_uplevelCmd DbgNub_renameCmd $args
		} result]
		if {$code == 1} {
		    set result [DbgNub_cleanErrorInfo $result \
			    DbgNub_renameCmd rename]
		    set DbgNub(cleanWrapper) {DbgNub_renameCmd rename}
		}
		return -code $code -errorcode $errorCode -errorinfo \
			$errorInfo $result
	    }
	}

	# Check to see if the name we are about to rename is in the
	# list of commands that cannot be renamed.  If it is generate
	# an error stating that renaming the command will crash the
	# debugger.

	if {![DbgNub_okToRename $name $level]} {
	    return -code 1 \
		    "cannot rename \"[lindex $args 0]\" in the debugger"
	}
    }

    set code [DbgNub_catchCmd {
	DbgNub_uplevelCmd DbgNub_renameCmd $args
    } result]
    if {$code == 1} {
	set result [DbgNub_cleanErrorInfo $result DbgNub_renameCmd rename]
	set DbgNub(cleanWrapper) {DbgNub_renameCmd rename}
	return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
    }

    # Check to see if the command we just renamed was instrumented.
    # If so, we need to update our info and fix the body of the
    # procedure to add the correct info to the context stack.

    set newName [lindex $args 1]
    if {[info exists DbgNub(proc=$name)]} {
	if {$newName == ""} {
	    unset DbgNub(proc=$name)
	} else {
	    if {$DbgNub(namespace)} {
		if {$DbgNub(namespace)} {
		    set newName [DbgNub_uplevelCmd 1 \
			    [list $DbgNub(scope)namespace origin $newName]]
		}
	    }
	    set DbgNub(proc=$newName) $DbgNub(proc=$name)
	    unset DbgNub(proc=$name)
	}
    }

    # Finally check to see if the command just renamed was one of the
    # builting commands that the nub wrapped.

    set name [string trim $name :]
    set i [lsearch $DbgNub(wrappedCommandList) $name]
    if {$i != -1} {
	set DbgNub(wrappedCommandList) [lreplace $DbgNub(wrappedCommandList) \
		$i $i [string trim $newName :]]
    }

    return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
}

# DbgNub_CheckLineBreakpoints --
#
#	Check the current location against the list of breakpoint
#	locations to determine if we need to stop at the current
#	statement.
#
# Arguments:
#	location	Current location.
#	level		Stack level of current statement.
#
# Results:
#	Returns 1 if we should break at this statement.

proc DbgNub_CheckLineBreakpoints {location level} {
    global DbgNub

    set block [lindex $location 0]
    set line [lindex $location 1]

    if {[DbgNub_infoCmd exists DbgNub($block:$line)]} {
	foreach test $DbgNub($block:$line) {
	    if {($test == "") || ([DbgNub_uplevelCmd #$level $test] == "1")} {
		return 1
	    }
	}
    }
    return 0
}

# DbgNub_GetVarTrace --
#
#	Retrieve the trace handle for the given variable if one exists.
#
# Arguments:
#	level	The scope at which the variable is defined.
#	name	The name of the variable.
#
# Results:
#	Returns the trace handle or {} if none is defined.

proc DbgNub_GetVarTrace {level name} {
    global DbgNub

    if {! [DbgNub_uplevelCmd #$level [list DbgNub_infoCmd exists $name]]} {
	return ""
    }

    upvar #$level $name var
    foreach trace [trace vinfo var] {
	set command [lindex $trace 1]
	if {[string compare [lindex $command 0] "DbgNub_TraceVar"] == 0} {
	    set handle [lindex $command 1]
	    if {[DbgNub_infoCmd exists DbgNub(var:$handle)]} {
		return $handle
	    }
	}
    }

    return ""
}

# DbgNub_AddVarTrace --
#
#	Add a new debugger trace for the given variable.
#
# Arguments:
#	level	The scope at which the variable is defined.
#	name	The name of the variable.
#	handle	The variable handle.
#
# Results:
#	None.  Creates a trace and sets up the state info for the variable.

proc DbgNub_AddVarTrace {level name} {
    global DbgNub
    upvar #$level $name var

    # Check to see if a trace already exists and bump the reference count.

    set handle [DbgNub_GetVarTrace $level $name]
    if {$handle != ""} {
	incr DbgNub(varRefs:$handle)
	return $handle
    }

    if {[array exists var]} {
	set type array
    } else {
	set type scalar
    }

    # Find an unallocated trace handle

    set handle [incr DbgNub(varHandle)]
    while {[DbgNub_infoCmd exists DbgNub(var:$handle)]} {
	set handle [incr DbgNub(varHandle)]
    }

    # Initialize the trace

    set DbgNub(var:$handle) {}
    set DbgNub(varRefs:$handle) 1
    trace variable var wu "DbgNub_TraceVar $handle $type"
    return $handle
}

# DbgNub_RemoveVarTrace --
#
#	Marks a variable trace as being deleted so it will be cleaned up
#	the next time the variable trace fires.
#
# Arguments:
#	handle		The debugger trace handle for this variable.
#
# Results:
#	None.

proc DbgNub_RemoveVarTrace {handle} {
    global DbgNub
    if {[incr DbgNub(varRefs:$handle) -1] == 0} {
	unset DbgNub(var:$handle)
	unset DbgNub(varRefs:$handle)
    }
    return
}

# DbgNub_AddBreakpoint --
#
#	Add a breakpoint.
#
# Arguments:
#	type		One of "line" or "var".
#	where		If the type is "line", then where contains a location.
#			If the type is "var", then where contains a trace
#			handle for the variable break on.
#	test		The test to use to determine whether a breakpoint
#			should be generated when the trace triggers.  This
#			script is evaluated at the scope where the trace
#			triggered.  If the script returns 1, a break is
#			generated. 
#
# Results:
#	None.

proc DbgNub_AddBreakpoint {type where {test {}}} {
    global DbgNub
    switch $type {
	line {
	    # Ensure that we are looking for line breakpoints.

	    if {[lsearch -exact $DbgNub(breakPreChecks) \
		    DbgNub_CheckLineBreakpoints] == -1} {
		lappend DbgNub(breakPreChecks) DbgNub_CheckLineBreakpoints
	    }
	    set block [lindex $where 0]
	    set line [lindex $where 1]
	    lappend DbgNub($block:$line) $test
	    incr DbgNub(numBreaks)
	}
	var {
	    # Add to the list of tests for the trace.

	    if {[DbgNub_infoCmd exists DbgNub(var:$where)]} {
		lappend DbgNub(var:$where) $test
	    }
	}
    }
    return
}

# DbgNub_RemoveBreakpoint --
#
#	Remove the specified breakpoint.
#
# Arguments:
#	type		One of "line" or "var".
#	where		If the type is "line", then where contains a location.
#			If the type is "var", then where contains a trace
#			handle for the variable break on.
#	test		The test to remove.
#
# Results:
#	None.

proc DbgNub_RemoveBreakpoint {type where test} {
    global DbgNub

    switch $type {
	line {
	    set block [lindex $where 0]
	    set line [lindex $where 1]

	    # Remove the breakpoint.

	    if {[DbgNub_infoCmd exists DbgNub($block:$line)]} {
		set index [lsearch -exact $DbgNub($block:$line) $test]
		set tests [lreplace $DbgNub($block:$line) $index $index]
		if {$tests == ""} {
		    unset DbgNub($block:$line)
		} else {
		    set DbgNub($block:$line) $tests
		}
		incr DbgNub(numBreaks) -1
	    }

	    # If this was the last breakpoint, remove the line breakpoint
	    # check routine from the check list.

	    if {$DbgNub(numBreaks) == 0} {
		set index [lsearch -exact $DbgNub(breakPreChecks) \
			DbgNub_CheckLineBreakpoints]
		set DbgNub(breakPreChecks) [lreplace $DbgNub(breakPreChecks) \
			$index $index]
	    }
	}
	var {
	    # Remove the test from the trace.

	    if {[DbgNub_infoCmd exists DbgNub(var:$where)]} {
		set index [lsearch -exact $DbgNub(var:$where) $test]
		set DbgNub(var:$where) [lreplace $DbgNub(var:$where) \
			$index $index]
	    }
	}
    }
    return
}

# DbgNub_TraceVar --
#
#	This procedure is invoked when a traced variable is written to or
#	unset.  It reports the event to the debugger and waits to see if it
#	should generate a breakpoint event.
#
# Arguments:
#	handle		The debugger trace handle for this variable.
#	type		The type of variable trace, either "array" or "scalar".
#	name1		The first part of the variable name.
#	name2		The second part of the variable name.
#	op		The variable operation being performed.
#
# Results:
#	None.

proc DbgNub_TraceVar {handle type name1 name2 op} {
    global DbgNub
    
    if {$DbgNub(socket) == -1} {
	return
    }

    set level [expr {[DbgNub_infoCmd level] - 1}]

    # Process any queued messages without blocking.  This ensures that
    # we have seen any changes in the tracing state before we process
    # this event.

    DbgNub_ProcessMessages 0

    # Compute the complete name and the correct operation to report

    if {$type == "array"} {
	if {$name2 != "" && $op == "u"} {
	    set op "w"
	}
	set name $name1
    } elseif {$name2 == ""} {
	set name $name1
    } else {
	set name ${name1}($name2)
    }

    # Clean up the trace state if the handle is dead.
    
    if {! [DbgNub_infoCmd exists DbgNub(var:$handle)]} {
	trace vdelete $name wu "DbgNub_TraceVar $handle $type"
	return
    }

    # If the variable is being written, check to see if we should generate a
    # breakpoint.  Note that we execute all of the tests in case they have side
    # effects that are desired.
    
    if {$op != "u"} {
	set varBreak 0
	foreach test $DbgNub(var:$handle) {
	    if {($test == "")} {
		set varBreak 1
	    } elseif {([DbgNub_catchCmd {DbgNub_uplevelCmd #$level $test} result] == 0) \
		    && $result} {
		set varBreak 1
	    }
	}
	if {$varBreak} {
	    DbgNub_Break $level varbreak $name $op 
	}
    } else {
	unset DbgNub(var:$handle)
	unset DbgNub(varRefs:$handle)
	DbgNub_SendMessage UNSET $handle
    }
}

# DbgNub_Evaluate --
#
#	Evaluate a user script at the specified level.  The script is
#	treated like an uninstrumented frame on the stack.
#
# Arguments:
#	id		This id should be returned with the result.
#	level		The scope at which the script should be evaluated.
#	script		The script that should be evaluated.
#
# Results:
#	None.

proc DbgNub_Evaluate {id level script} {
    global DbgNub errorInfo errorCode

    # Save the debugger state so we can restore it after the evaluate
    # completes.  Reset the error handling flags so we don't notify the
    # debugger of errors generated by the script until we complete the
    # evaluation.  

    set saveState {}
    foreach element {state catch errorHandled nestCount breakNext} {
	lappend saveState $element $DbgNub($element)
    }
    array set DbgNub {catch 0 errorHandled 0 nestCount 0 breakNext 0}

    DbgNub_PushContext $level "user eval"

    set code [DbgNub_catchCmd {DbgNub_uplevelCmd #$level $script} result]
    if {$code == 1} {
	# Clean up the errorInfo stack to remove our tracks.
	DbgNub_cleanErrorInfo
	DbgNub_cleanWrappers
    }

    # Restore the debugger state.

    DbgNub_PopContext
    array set DbgNub $saveState

    DbgNub_SendMessage BREAK [DbgNub_CollateStacks] [DbgNub_GetCoverage] \
	    result [list $id $code $result $errorInfo $errorCode]
}

# DbgNub_BeginCoverage --
#
#	Set global coverage boolean to true.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc DbgNub_BeginCoverage {} {
    global DbgNub

    set DbgNub(cover) 1
    foreach index [array names DbgNub cover:*] {
	unset DbgNub($index)
    }
    return
}

# DbgNub_EndCoverage --
#
#	Set global coverage boolean to false, and clear all memory of
#	covered locations.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc DbgNub_EndCoverage {} {
    global DbgNub

    set DbgNub(cover) 0
    foreach index [array names DbgNub cover:*] {
	unset DbgNub($index)
    }
    return
}

# DbgNub_GetCoverage --
#
#	Find the list of ranges that have been covered
#	since the last time this command was called; then remove
#	all memory of covered locations.
#
# Arguments:
#	None.
#
# Results:
#	Returns the list of ranges that have been covered
#	since the last time this command was called.

proc DbgNub_GetCoverage {} {
    global DbgNub

    if {$DbgNub(cover)} {
	set coverage [array get DbgNub cover:*]

	foreach index [array names DbgNub cover:*] {
	    unset DbgNub($index)
	}
	return $coverage
    }
    return {}
}

# DbgNub_GetProcDef --
#
#	Reconstruct a procedure definition.
#
# Arguments:
#	name	The name of the procedure to reconstruct.
#
# Results:
#	Returns a script that can be used to recreate a procedure.

proc DbgNub_GetProcDef {name} {
    global DbgNub DbgNubTemp
    set body [DbgNub_uplevelCmd #0 [list DbgNub_infoCmd body $name]]
    set args [DbgNub_uplevelCmd #0 [list DbgNub_infoCmd args $name]]
    set argList {}
    foreach arg $args {
	if {[DbgNub_uplevelCmd #0 [list \
		DbgNub_infoCmd default $name $arg DbgNubTemp]]} {
	    lappend argList [list $arg $DbgNubTemp]
	} else {
	    lappend argList $arg
	}
    }
    return [list proc $name $argList $body]
}

# DbgNub_Interrupt --
#
#	Interrupt the currently running application by stopping at
#	the next instrumented statement.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc DbgNub_Interrupt {} {
    global DbgNub
    set DbgNub(breakNext) 1
    return 
}

# DbgNub_IgnoreError --
#
#	Ignore the current error.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc DbgNub_IgnoreError {} {
    global DbgNub
    set DbgNub(ignoreError) 1
    return
}

# DbgNub_cleanErrorInfo --
#
#	This attepts to remove our tracks from wrapper functions for
#	the Tcl commands like info, source, rename, etc.
#
# Arguments:
#	result		The dirty result.
#	wrapCmd		The wraped command we want to replace.
#	actualCmd	The actualy command errorInfo & result should have.
#
# Results:
#	Returns the cleaned result string.

proc DbgNub_cleanErrorInfo {{result {}} {wrapCmd {}} {actualCmd {}}} {
    global errorInfo
    if {$wrapCmd != {}} {
	if {[string match "wrong # args:*" $result]} {
	    regsub -- $wrapCmd $result $actualCmd result
	    regsub -- $wrapCmd $errorInfo $actualCmd errorInfo
	}
    }

    # Hide shadow procedure invocations.  This is pretty complicated because
    # Tcl doesn't support non-greedy regular expressions.

    while {[regexp -indices "\n    invoked from within\n\"\[^\n\]*__DbgNub__" \
	    $errorInfo range]} {
	set newInfo [string range $errorInfo 0 [lindex $range 0]]
	set substring [string range $errorInfo \
		[expr {[lindex $range 0] + 1}] end]
	regexp -indices "\n\"DbgNub_catchCmd\[^\n\]*\n" $substring range
	append newInfo [string range $substring [expr {[lindex $range 1]+1}] end]
	set errorInfo $newInfo
    }
    while {[regexp -indices "\n    invoked from within\n\"\DbgNub_Do" \
	    $errorInfo range]} {
	set newInfo [string range $errorInfo 0 [lindex $range 0]]
	set substring [string range $errorInfo [lindex $range 1] end]
	regexp -indices "    invoked from within\n" $substring range
	append newInfo [string range $substring [lindex $range 0] end]
	set errorInfo $newInfo
    }

    set pat "\n    \\(\"uplevel\" body line \[^\n\]*\\)\n    invoked from within\n\"DbgNub_uplevelCmd 1 \[^\n\]*\""
    regsub -all -- $pat $errorInfo {} errorInfo 
    
    return $result
}

# DbgNub_cleanWrappers --
#
#	This procedure will clean up some our tracks in the errorInfo
#	variable by hiding the wrapping of certain core commands.  Each
#	wrapper will note that it needs to be cleaned up by setting
#	variableDbgNub(cleanWrappers).  The DbgNub_Do command is what will
#	actually call this procedure.
#
# Arguments:
#	None.
#
# Results:
#	None.  The global errorInfo variable may be modified.

proc DbgNub_cleanWrappers {} {
    global DbgNub errorInfo

    if {[DbgNub_infoCmd exists DbgNub(cleanWrapper)]} {
	set wrap [lindex $DbgNub(cleanWrapper) 0]
	set actu [lindex $DbgNub(cleanWrapper) 1]
	set dbgMsg "\"$wrap.*"
	append dbgMsg \n {    invoked from within}
	append dbgMsg \n "\"$actu"
	regsub -- $dbgMsg $errorInfo "\"$actu" errorInfo
	unset DbgNub(cleanWrapper)
    }
}

# DbgNub_okToRename --
#
#	This procedure checks that it is safe to rename (or redefine) a
#	given command.
#
# Arguments:
#	name	The command name to check.
#	level	Stack level of current statement.
#
# Results:
#	Returns 1 if it is safe to modify the given command name in the
#	current context, else returns 0.
#
# Side effects:
#	None.

proc DbgNub_okToRename {name level} {
    global DbgNub

    if {$DbgNub(namespace)} {
	if {![string match ::* $name]} {
	    set name [DbgNub_uplevelCmd \#$level \
		    [list $DbgNub(scope)namespace current]]::$name
	}
	if {[string length [namespace qualifiers $name]] == 0} {
	    set name [namespace tail $name]
	} else {
	    set name {}
	}
    }
    return [expr [lsearch $DbgNub(excludeRename) $name] < 0]
}


##############################################################################
# Initialize the nub library.  Once this completes successfully, we can
# safely replace the debugger_eval and debugger_init routines.

DbgNub_Startup

# debugger_init --
#
#	This is a replacement for the public debugger_init routine
#	that does nothing.  This version of the function is installed
#	once the debugger is successfully initialized.
#
# Arguments:
#	args	Ignored.
#
# Results:
#	Returns 1.

DbgNub_procCmd debugger_init {args} {
    return [debugger_attached]
}

# debugger_eval --
#
#	Instrument and evaluate the specified script.
#
# Arguments:
#	args		One or more arguments, the last of which must
#			be the script to evaluate.
#
# Results:
#	Returns the result of evaluating the script.

DbgNub_procCmd debugger_eval {args} {
    global DbgNub errorInfo errorCode
    set length [llength $args]
    set blockName ""
    for {set i 0} {$i < $length} {incr i} {
	set arg [lindex $args $i]
	switch -glob -- $arg {
	    -name {
		incr i
		if {$i < $length} {
		    set blockName [lindex $args $i]
		} else {
		    return -code error "missing argument for -name switch" 
		}
	    }
	    -- {
		incr i
		break
	    }
	    -* {
		return -code error "bad switch \"$arg\": must be -block, or --"
	    }
	    default {
		break
	    }
	}
    }
    if {$i != $length-1} {
	return -code error "wrong # args: should be \"debugger_eval ?options? script\""
    }
    
    set script [lindex $args $i]
    
    if {$DbgNub(socket) != -1} {
	set icode [DbgNub_Instrument $blockName $script]

	# If the instrumentation failed, we just eval the original script

	if {$icode == ""} {
	    set icode $script
	}
    } else {
	set icode $script
    }

    set level [expr {[DbgNub_infoCmd level] - 1}]
    DbgNub_PushContext $level "debugger_eval"
    set marker [DbgNub_PushStack $level [list $level "debugger_eval"]]
    set code [DbgNub_catchCmd {
	DbgNub_uplevelCmd 1 $icode
    } result]
    DbgNub_cleanErrorInfo
    DbgNub_PopStack $marker
    DbgNub_PopContext

    return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
}

# debugger_break --
#
#	Cause the debugger to break on this command.
#
# Arguments:
#	str	(Optional) String that displays in debugger.
#
# Results:
#	None.  Will send break message to debugger.

DbgNub_procCmd debugger_break {{str ""}} {
    global DbgNub

    set level [expr {[DbgNub_infoCmd level] - 1}]
    if {$DbgNub(socket) != -1} {
	DbgNub_Break $level userbreak $str
    }

    return
}

# debugger_attached --
#
#	Test whether the debugger socket is still connected to the
#	debugger.
#
# Arguments:
#	None.
#
# Results:
#	Returns 1 if the debugger is still connected.

DbgNub_procCmd debugger_attached {} {
    global DbgNub

    # Process queued messages to ensure that we notice a disconnect.
    DbgNub_ProcessMessages 0
    return [expr {$DbgNub(socket) != -1}]
}

# debugger_setCatchFlag --
#
#	Set the catch flag to indicate if errors should be caught by the
#	debugger.  This flag is normally set to 0 by the "catch" command.
#	This command can be used to reset the flag to allow errors to be
#	reported by the debugger even if they would normally be masked by a
#	enclosing catch command.  Note that the catch flag can be overridden by
#	the errorAction flag controlled by the user's project settings.
#
# Arguments:
#	flag	The new value of the flag.  1 indicates thtat errors should
#		be caught by the debugger.  0 indicates that the debugger
#		should allow errors to propagate.
#
# Results:
#	Returns the previous value of the catch flag.
#
# Side effects:
#	None.

DbgNub_procCmd debugger_setCatchFlag {flag} {
    global DbgNub

    set old $DbgNub(catch)
    set DbgNub(catch) $flag
    return $old
}
