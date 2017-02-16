# debugger.tcl --
#
#	This file is the first file loaded by the Tcl debugger.  It
#	is responsible for loacating and loading the rest of the Tcl
#	source.  It will also set other global platform or localization
#	state that the rest of the application will use.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.

# Source in other Tcl files.  These files should only define procs.
# No other Tcl code should run during the load process.  There should be no
# implied loading order here.

package require Tk
package require projectInfo
package require cmdline
if {$::tcl_platform(platform) == "windows"} {
    package require registry
}

namespace eval debugger {
    if {[catch {package require tbcload}] == 1} {
	variable ::hasLoader 0
    } else {
	variable ::hasLoader 1
    }
    variable libdir [file dirname [info script]]

    # Debugger settable parameters --
    #
    # The parameters array contains values that are needed by various procs
    # in the debugger, but that must be supplied by the application that uses
    # the debugger library.  The list below defines the available parameters
    # and their default values.  The application can override these values when
    # it calls debugger::init.
    #
    # Parameters:
    #	aboutImage	The image to display in the splash screen and about
    #			box.
    #	aboutCopyright	The copyright string to display in the splash screen
    #			and about box.
    #	appType		Either "local" or "remote" to indicate the initial
    #			value of the app type default for new projects.
    #   iconImage	The image file (Unix) or winico image handle (Windows)
    #			to use for the window manager application icon.
    #	productName	The name of the debugger product.

    variable parameters
    array set parameters [list \
	    aboutImage $libdir/images/about.gif \
	    aboutCopyright "$::projectInfo::copyright\nVersion $::projectInfo::patchLevel" \
	    appType local \
	    iconImage $libdir/images/debugUnixIcon.gif \
	    productName "$::projectInfo::productName Debugger" \
	    ]

    wm withdraw .
}
	

proc ::Source { path } {
    variable ::hasLoader

    set stem [file rootname $path]
    set loadTcl 1
    if {($hasLoader == 1) && ([file exists $stem.tbc] == 1)} {
	set loadTcl [catch {uplevel 1 [list source $stem.tbc]}]
    }
    
    if {$loadTcl == 1} {
	uplevel 1 [list source $stem.tcl]
    }
}

Source [file join $::debugger::libdir pref.tcl]
Source [file join $::debugger::libdir image.tcl]
Source [file join $::debugger::libdir system.tcl]
Source [file join $::debugger::libdir font.tcl]

Source [file join $::debugger::libdir dbg.tcl]
Source [file join $::debugger::libdir break.tcl]
Source [file join $::debugger::libdir block.tcl]
Source [file join $::debugger::libdir instrument.tcl]

Source [file join $::debugger::libdir gui.tcl]
Source [file join $::debugger::libdir guiUtil.tcl]
Source [file join $::debugger::libdir widget.tcl]
Source [file join $::debugger::libdir bindings.tcl]
Source [file join $::debugger::libdir icon.tcl]
Source [file join $::debugger::libdir selection.tcl]
Source [file join $::debugger::libdir tabnotebook.tcl]
Source [file join $::debugger::libdir tkcon.tcl]

Source [file join $::debugger::libdir breakWin.tcl]
Source [file join $::debugger::libdir codeWin.tcl]
Source [file join $::debugger::libdir coverage.tcl]
Source [file join $::debugger::libdir evalWin.tcl]
Source [file join $::debugger::libdir file.tcl]
Source [file join $::debugger::libdir find.tcl]
Source [file join $::debugger::libdir inspectorWin.tcl]
Source [file join $::debugger::libdir menu.tcl]
Source [file join $::debugger::libdir portWin.tcl]
Source [file join $::debugger::libdir prefWin.tcl]
Source [file join $::debugger::libdir procWin.tcl]
Source [file join $::debugger::libdir proj.tcl]
Source [file join $::debugger::libdir projWin.tcl]
Source [file join $::debugger::libdir result.tcl]
Source [file join $::debugger::libdir stackWin.tcl]
Source [file join $::debugger::libdir toolbar.tcl]
Source [file join $::debugger::libdir varWin.tcl]
Source [file join $::debugger::libdir watchWin.tcl]

Source [file join $::debugger::libdir location.tcl]
Source [file join $::debugger::libdir util.tcl]

source [file join $::debugger::libdir uplevel.pdx]
source [file join $::debugger::libdir tcltest.pdx]
#source [file join $::debugger::libdir blend.pdx]
source [file join $::debugger::libdir oratcl.pdx]
source [file join $::debugger::libdir tclCom.pdx]
source [file join $::debugger::libdir xmlGen.pdx]

# LicenseExit --
#
#	Exit the debugger and release shared network license.
#	This routine must be defined before the following namespace
#	eval because it may be called in some error cases.
#
# Arguments:
#	None.
#
# Side Effects:
#	Releases shared network license and exits the process.

proc LicenseExit {{status 0}} {
    catch {$::projectInfo::licenseReleaseProc}
    exit $status
}

# debugger::init --
#
#	Start the debugger and show the main GUI.
#
# Arguments:
#	argv		The command line arguments.
#	newParameters	Additional debugger parameters specified as a
#			list of keys and values.  These parameters are
#			saved for later use by other modules in the
#			debugger.  See above for a list of the possible
#			values.
#
# Results:
#	None.

proc debugger::init {argv newParameters} {
    variable parameters
    variable libdir

    # Merge in application specific parameters.

    array set parameters $newParameters

    # Note: the wrapper target for this application must contain a -code
    # fragment that moves the -display switch to the beginning and
    # then inserts a -- switch to bypass the normal wish argument
    # parsing.  If we don't do this, then switches like -help will be
    # intercepted by wish before we get to handle them.

    append usageStr "Usage: [cmdline::getArgv0] ?options? projectFile\n" \
	    "  -help                   print this help message\n" \
	    "  -version                display version information\n"
    if {$::tcl_platform(platform) == "unix"} {
	append usageStr "  -display <displayname>  X display for interface\n"
    }
    set optionList {? h help v version coverage}

    # Parse the command lines:
    while {[set err [cmdline::getopt argv $optionList opt arg]]} {
	if { $err < 0 } {
	    append badArgMsg "error: [cmdline::getArgv0]: " \
		    "$arg (use \"-help\" for legal options)"
	    set errorBadArg 1
	    break
	} else {
	    switch -exact -- $opt {
		? -
		h -
		prohelp -
		help {
		    set projectInfo::printCopyright 0
		    set showHelp 1
		    set dontStart 1
		}
		v -
		version {
		    set projectInfo::printCopyright 1
		    set dontStart 1
		}
		coverage {
		    set ::coverage::coverageEnabled 1
		}
	    }
	}
    }

    # If showing help information - do so then exit.  However, on windows
    # there is not stdout so we display the message to a message box.

    if {[info exists showHelp]} {
	if {$::tcl_platform(platform) == "windows"} {
	    tk_messageBox -message $usageStr -title Help
	} else {
	    puts $usageStr
	}
    }
    if {[info exists dontStart]} {
	exit 0
    }
    if {[info exists errorBadArg]} {
	puts $badArgMsg
	if {$::tcl_platform(platform) == "windows"} {
	    tk_messageBox -message $badArgMsg -title Help
	}
	exit 1
    }
    
    # WARNING. These routines need to be called in this order!
    # After calling verifyLicenseProc, you should use LicenseExit
    # to terminate the process and release the license.

    TestForSockets
    system::init
    if {[info exists ::projectInfo::verifyLicenseProc]} {
        $::projectInfo::verifyLicenseProc
    }
    
    # Display the splash screen and set a timer to remove it.

    set about [gui::showAboutWindow]
    after 2500 [list destroy $about]

    # Remove the send command.  This will keep other applications
    # from being able to poke into our interp via the send command.
    if {[info commands send] == "send"} {
	rename send ""
    }
    
    # Calculate the font data for the current font.

    font::configure [pref::prefGet fontType] [pref::prefGet fontSize]

    # Restore the settings for any paned or tabled window.

    guiUtil::restorePaneGeometry

    # Restore instrumentation preferences.

    instrument::extension incrTcl [pref::prefGet instrumentIncrTcl]
    instrument::extension tclx   [pref::prefGet instrumentTclx]
    instrument::extension expect [pref::prefGet instrumentExpect]

    # Register events sent from the engine to the GUI.

    dbg::register linebreak  {gui::linebreakHandler}
    dbg::register varbreak   {gui::varbreakHandler}
    dbg::register userbreak  {gui::userbreakHandler}
    dbg::register cmdresult  {gui::cmdresultHandler}
    dbg::register exit       {gui::exitHandler}
    dbg::register error      {gui::errorHandler}
    dbg::register result     {gui::resultHandler}
    dbg::register attach     {gui::attachHandler}
    dbg::register instrument {gui::instrumentHandler}

    # Register the error handler for errors during instrumentation.

    set instrument::errorHandler gui::instrumentErrorHandler

    # Initialize the debugger.

    dbg::initialize $libdir

    # Draw the GUI.  We need to ensure that the gui is created before loading
    # any extensions in case they need to modify the gui.

    gui::showMainWindow

    # Load any external extensions from <ProRoot>/lib and
    # from env(TCLPRO_LOCAL).
    
    namespace eval :: {namespace import -force ::instrument::*}
    set files [glob -nocomplain \
	    [file join [file dir [info nameofexecutable]] ../../lib/*.pdx]]
    if {[info exists ::env(TCLPRO_LOCAL)]} {
	set files [concat $files [glob -nocomplain \
		[file join $::env(TCLPRO_LOCAL) *.pdx]]]
    }
    foreach file $files {
	if {[catch {uplevel \#0 [list source $file]} err]} {
	    bgerror "Error loading $file:\n$err"
	}
    }
    
    # Hide the main window until the splash screen is gone.

    if {[winfo exists $about]} {
	bind $about <Destroy> { wm deiconify $gui::gui(mainDbgWin) }
    } else {
	wm deiconify $gui::gui(mainDbgWin)
    }

    # Defer the update until after we've sourced any extensions to avoid
    # annoying refreshes.
 
    update
    
    # If there are more than one arguments left on the command line
    # dump the usage string and exit.  However, on windows
    # there is not stdout so we display the message to a message box.

    if {[llength $argv] > 1} {
	if {$::tcl_platform(platform) == "windows"} {
	    tk_messageBox -message $usageStr -title "Wrong Number of Arguments"
	} else {
	    puts $usageStr
	}
	LicenseExit 1
    }

    # Now try to figure out which project to load.

    if {[llength $argv] == 1} {
	set projPath [file join [pwd] [lindex $argv 0]]
    } elseif {[pref::prefGet projectReload]} {
	set projPath [pref::prefGet projectPrev]
    } else {
	set projPath {}
    }

    if {$projPath != {}} {
	proj::openProjCmd $projPath
    }

    return
}

# ExitDebugger --
#
#	Call this function to gracefully exit the debugger.  It will
#	save preferences and do other important cleanup.
#
# Arguments:
#	None.
#
# Results:
#	This function will not return.  The debugger will die.

proc ExitDebugger {} {
    # Save the implicit prefs to the registry, or UNIX resource.  Implicit
    # prefs are prefs that are set by the debugger and do not belong in a
    # project file (i.e., window sizes.)

    if {![system::saveDefaultPrefs 1]} {
	LicenseExit
    }
    return
}

# CleanExit --
#
#	Before exiting the debugger, clear all of the
#	pref data so the next session starts fresh.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc CleanExit {} {
    global tcl_platform

    proc ExitDebugger {} {}
    if {$tcl_platform(platform) == "windows"} {
	registry delete [pref::prefGet key]
    } else {
	file delete [pref::prefGet fileName]
    }
    LicenseExit
}

# TestForSockets --
#
#	The debugger requires sockets to work.  This routine
#	tests to ensure we have sockets.  If we don't have 
#	sockets we gen an error message and exit.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc TestForSockets {} {
    proc dummy {args} {error dummy}
    if {[catch {set socket [socket -server dummy 0]} msg]} {
	tk_dialog .error "Fatal error" \
	    "$::debugger::parameters(productName) requires sockets to work." \
	    error 0 Ok
	exit
    }
    close $socket
    rename dummy ""
}

package provide debugger 2.0
