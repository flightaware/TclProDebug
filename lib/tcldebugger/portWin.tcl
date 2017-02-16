# portWin.tcl --
#
#	This file defines the APIs needed to display the bad port dialog
#	when a user enters an invalid or taken port.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 

namespace eval portWin {
    # Widgets that are used througout this module for updating
    # messages and for setting and retrieving port values.

    variable msgLbl
    variable portEnt

    # Vwait variable used to indicate when a valid port has been 
    # entered.

    variable newPortVar
}

# portWin::showWindow --
#
#	Show the window.  If it does not exist, create it.  If it does 
#	exist, bring it to focus.
#
# Arguments:
#	port	The invalid port.
#
# Results:
#	The next OK port to use.

proc portWin::showWindow {port} {
    if {[info command $gui::gui(errorPortWin)] == $gui::gui(errorPortWin)} {
	wm deiconify $gui::gui(errorPortWin)
    } else {
	portWin::CreateWindow
    }

    portWin::UpdateWindow $port
    focus -force $portWin::portEnt
    grab $gui::gui(errorPortWin)

    vwait portWin::newPortVar
    return $portWin::newPortVar
}

# portWin::CreateWindow --
#
#	Create the window from scratch.  It is assumed that the window 
#	currently does not exist.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc portWin::CreateWindow {} {
    variable msgLbl
    variable portEnt

    set bd       2
    set pad      6
    set pad2     3
    set width  350
    set height  50

    set top [toplevel $gui::gui(errorPortWin)]
    wm title     $top "Error Opening Port"
    wm minsize   $top 100 100
    wm transient $top $gui::gui(mainDbgWin)

    # Center window on the screen.

    set w [winfo screenwidth .]
    set h [winfo screenheight .]
    wm geometry $gui::gui(errorPortWin) \
	    +[expr {($w/2) - ($width/2)}]+[expr {($h/2) - ($height/2)}]

    set mainFrm  [frame $top.mainFrm -bd $bd -relief raised]
    set imageLbl [label $mainFrm.imageLbl -bitmap error]
    set msgLbl   [label $mainFrm.msgLbl -wraplength $width -justify left]

    set portFrm   [frame $mainFrm.portFrm]
    set portLabel [label $portFrm.portLabel -text "Next available port:"]
    set portEnt   [entry $portFrm.portEnt -width 6 -exportselection 0]

    set butFrm  [frame $top.butFrm]
    set okBut [button $butFrm.okBut  -text "OK"  -default active \
	    -command {portWin::ApplyWindow} -width 12]
    set cancelBut [button $butFrm.cancelBut  -text "Cancel"  -default normal \
	    -command [list destroy $top] -width 12]

    pack $portEnt  -side right
    pack $portLabel -side right

    grid $imageLbl  -row 0 -column 0 -sticky w -padx $pad -pady $pad
    grid $msgLbl    -row 0 -column 1 -sticky w -padx $pad -pady $pad
    grid $portFrm   -row 2 -column 1 -sticky w -padx $pad -pady $pad
    grid columnconfigure $mainFrm 1 -weight 1
    grid rowconfigure $mainFrm 1 -weight 1

    pack $cancelBut -side right -padx $pad
    pack $okBut     -side right -padx $pad
    pack $butFrm    -side bottom -fill x -pady $pad2
    pack $mainFrm   -side bottom -fill both -expand true -padx $pad -pady $pad

    bind $portEnt  <Return> "$okBut invoke; break"
    bind $okBut    <Return> {%W invoke; break}
    bind $top      <Return> "$okBut invoke; break"
    bind $top      <Escape> "$cancelBut invoke; break"

    return
}

# portWin::UpdateWindow --
#
#	Show the error message and prompt the user for a new port.
#
# Arguments:
#	port	The invalid port.
#
# Results:
#	None.

proc portWin::UpdateWindow {port} {
    variable msgLbl
    variable portEnt

    # Insert the message stating that the port was taken or is invalid.

    append msg "Port \"$port\" is invalid or in use.  "
    append msg "Please specify another port to use for this project.  "
    append msg "This will automatically modify your project settings."
    $msgLbl configure -text $msg

    # Find the next open port.  Loop while the port is in use.
    # Make sure the port entered is a valid integer.  If it is not, use
    # the initial factory default setting as a starting point for locating
    # the next available port.

    if {[catch {incr port}]} {
	set port [pref::prefGet portRemote ProjectFactory]
    }
    while {![portWin::isPortValid $port]} {
	incr port
    }

    # Insert the new suggested port to be used.

    $portEnt delete 0 end
    $portEnt insert 0 $port
    $portEnt selection range 0 end

    return
}

# portWin::ApplyWindow --
#
#	Verify the new port is valid.  If the nerw port is valid then 
#	destroy the window and set the vwait var to the value of the 
#	port.  Otherwise beep and update the error message.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc portWin::ApplyWindow {} {
    variable portEnt

    set port [$portEnt get]
    if {[portWin::isPortValid $port]} {
	grab release $gui::gui(errorPortWin)
	destroy $gui::gui(errorPortWin)
	set ::portWin::newPortVar $port
    } else {
	bell
	portWin::UpdateWindow $port
    }
    return
}

# portWin::isPortValid --
#
#	Test to see if the port is valid.
#
# Arguments:
#	port	The port to test.
#
# Results:
#	Return a boolean, 1 means the port is OK.

proc portWin::isPortValid {port} {
    global errorCode

    # First test to see that the port is a valid integer.

    if {[catch {incr port 0}]} {
	return 0
    }
  
    # If the errorCode is not EADDRINUSE nor EACCES then an error occured
    # that was not a taken port.  Make sure to close the port when one
    # is found, so the correct routine can be called to re-open
    # the same port.

    if {([catch {set sock [socket -server dummy $port]}] != 0) \
	    && ([lsearch -exact \
	    [list "EADDRINUSE" "EACCES"] \
	    [lindex $errorCode 1]] != -1)} {
	return 0
    }
    close $sock
    return 1
}

