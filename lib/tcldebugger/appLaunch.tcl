# appLaunch.tcl --
#
#	This script takes care of initializing the nub and invoking the
#	client application script when an application is being launched
#	from the debugger.
#
#	NOTE: This file is for internal use only and may change without
#	notice.  The contents should not be modified in any way.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 

# DbgNub_Main --
#
#	Initializes the nub and invokes the client script.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc DbgNub_Main {} {
    global argc argv0 argv errorCode errorInfo tcl_version

    if {$argc < 4} {
	error "$argv0 needs cmd line args:  hostname port scriptName data ?args?"
    }

    # Parse command line arguments

    set libDir [file dirname $argv0]
    set host [lindex $argv 0]
    set port [lindex $argv 1]
    set script [lindex $argv 2]
    set data [lindex $argv 3]
    set argList [lrange $argv 4 end]

    # Set up replacement arguments so the client script doesn't see the
    # appLaunch arguments.

    set argv0 $script
    set argv $argList
    set argc [llength $argList]

    if {[info commands tk] == "tk"} {
	set appName [lindex [file split $argv0] end]
	tk appname $appName
    }

    # The following code needs to be kept in sync with initdebug.tcl

    if {[catch {set socket [socket $host $port]}] != 0} {
	exit 1
    }
    fconfigure $socket -blocking 1 -translation binary

    # On 8.1 and later versions we should ensure the socket is not doing
    # any encoding translations.

    if {$tcl_version >= 8.1} {
	fconfigure $socket -encoding utf-8
    }

    # Attach to the debugger as a local app.

    set msg [list HELLO 1.0 $tcl_version $data]
    puts $socket [string length $msg]
    puts -nonewline $socket $msg
    flush $socket

    # Get the rest of the nub library and evaluate it in the current scope.
    # Note that the nub code assumes there will be a "socket" variable that
    # contains the debugger socket channel.

    if {[gets $socket bytes] == -1} {
	exit 1
    }
    set msg [read $socket $bytes]
    eval [lindex $msg 1]
    return
}

DbgNub_Main
source $argv0
