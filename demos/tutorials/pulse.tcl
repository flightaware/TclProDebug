# pulse.tcl --
#
#
# Copyright (c) 1999 Scriptics Corporation
# See the file "license.terms" for information on usage and redistribution of this file.
#

set beats 0
set pending ""

label .title -text "Total Heartbeats"
label .beats -textvariable beats

label .scaleTitle -text "Heart Rate"
scale .rate -orient horizontal -from 60 -to 180 -variable rate

frame .controls
button .controls.start -text "Start" -command {start}
button .controls.stop -text "Stop" -command {stop}
button .controls.clear -text "Clear" -command {clear}

pack .title -pady 4 -padx 6
pack .beats 
pack .scaleTitle -pady 4 -padx 2
pack .rate -padx 2 -fill x
pack .controls -fill x -pady 4

pack .controls.start -padx 4 -side left -expand yes
pack .controls.stop -padx 4 -side left -expand yes
pack .controls.clear -padx 4 -side left -expand yes

proc start {} {
    global pending 

    if {$pending == ""} {
	set pending [after idle animate]
    }
}

proc animate {} {
    global rate pending beats

    incr beats
    set delay [expr {int(60.0/$rate*1000)}]
    set pending [after $delay animate]
}
    

proc stop {} {
    global pending

    if {$pending != ""} {
	after cancel $pending
	set pending ""
    }
}

proc clear {} {
    global beats

    set beats 0
}
	
