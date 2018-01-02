# startup.tcl --
#
#	This file is the primary entry point for the 
#       TclPro Debugger.
#
# Copyright (c) 1999 by Scriptics Corporation.
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 

# Initialize the debugger library

package require projectInfo

# Specify the additional debugger parameters.

set script_dir [file dirname [file norm [info script]]]
set about_gif $script_dir/images/about.gif
set logo_gif $script_dir/images/logo.gif

set parameters [list \
	aboutCmd "::TclProAboutBox $about_gif $logo_gif" \
	aboutCopyright "$::projectInfo::copyright\nVersion $::projectInfo::patchLevel" \
	appType local \
]

if {0 && $::tcl_platform(platform) == "windows"} {
    package require Winico
    lappend parameters iconImage [winico load dbg scicons.dll]
} else {
    lappend parameters iconImage $script_dir/images/debugUnixIcon.gif
}

# ::TclProAboutBox --
#
#	This procedure displays the TclPro about box or
#	splash screen.
#
# Arguments:
#	image		The main image to display in the about box.
#
# Results:
#	None.

proc ::TclProAboutBox {aboutImage logoImage} {
    catch {destroy .about}

    # Create an undecorated toplevel with a raised bevel
    set top [toplevel .about -bd 4 -relief raised]
    wm overrideredirect .about 1

    # This is a hack to get around a Tk bug.  Once Tk is fixed, we can
    # let the geometry computations happen off-screen
    wm geom .about 1x1
#    wm withdraw .about

    # Create a container frame so we can set the background without
    # affecting the color of the outermost bevel.
    set f1 [frame .about.f -bg white]
    pack $f1 -fill both

    # Create the images
    
    image create photo about -file $aboutImage
    image create photo logo -file $logoImage

    # Compute various metrics
    set logoWidth [image width logo]
    set aboutWidth [image width about]
    set screenWidth [winfo screenwidth .]
    set screenHeight [winfo screenheight .]

    label $f1.about -bd 0 -bg white -padx 0 -pady 0 -highlightthickness 0 \
	    -image about
    pack $f1.about -side top -anchor nw

    set f2 [frame $f1.f2 -bg white -bd 0]
    pack $f2 -padx 6 -pady 6 -side bottom -fill both -expand 1

    label $f2.logo -bd 0 -bg white -padx 0 -pady 0 -highlightthickness 0 \
	    -image logo
    pack $f2.logo -side left -anchor nw -padx 0 -pady 0

if {0} {
    # No room for this
    set okBut [button $f2.ok -text "OK" -width 6 -default active \
	    -command {destroy .about}]
    pack $okBut -side right -anchor se -padx 0 -pady 0
}

    label $f2.version -bd 0 -bg white -padx 10 -pady 0 -highlightthickness 0 \
	    -text $::debugger::parameters(aboutCopyright) -justify left
    pack $f2.version -side top -anchor nw

    label $f2.url -bd 0 -bg white -padx 10 -pady 0 -highlightthickness 0 \
	    -text "http://www.tcl.tk" -fg blue \
	    -cursor hand2
    pack $f2.url -side top -anchor nw

    # Establish dialog bindings

    bind .about <ButtonRelease-1> {
	destroy .about
    }
    bind $f2.url <ButtonRelease-1> {
#	destroy .about
	system::openURL http://www.tcl.tk/software/tclpro/
    }
    bind .about <Return> {destroy .about}

    # Add the Windows-only console hack

    if {$::tcl_platform(platform) == "windows"} {
	bind .about <F12> {
	    console show
	    destroy .about; break
	}
    }

    # Place the window in the center of the screen
    update
    set width [winfo reqwidth .about]
    set height [winfo reqheight .about]
    set x [expr {([winfo screenwidth .]/2) - ($width/2)}]
    set y [expr {([winfo screenheight .]/2) - ($height/2)}]
    wm deiconify .about
    wm geom .about ${width}x${height}+${x}+${y}
    raise .about

    catch {
	focus .about
	grab -global .about
    }

    # Return the about window so we can destroy it from external bindings
    # if necessary.
    return .about
}

if {[catch {

    # This package require loads the debugger and system modules
    package require debugger

    # Set TclPro license hook
#	package require licenseWin
#	licenseWin::verifyLicense
#	set ::projectInfo::licenseReleaseProc lclient::release

    debugger::init $argv $parameters
} err]} {
    set f [toplevel .init_error]
    set l [label $f.label -text "Startup Error"]
    set t [text $f.text -width 50 -height 30]
    $t insert end $errorInfo
    pack $f.text

    if {$::tcl_platform(platform) == "windows"} {
	console show
    }
}

# Add the TclPro debugger extensions

#Source xmlview.tcl

# Enter the event loop.
