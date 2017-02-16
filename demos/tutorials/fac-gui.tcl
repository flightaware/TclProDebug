#!/bin/sh
# the next line restarts using prowish82 \
exec prowish82 "$0" "$@"

# fac.tcl --
#
# This program creates a simple Tk graphical user interface to
# compute factorials.  It is intended as a demo application for
# TclPro.

# This procedure computes the factorial of its argument using a
# recursive approach and returns the factorial as result.

proc fac x {
    if {$x <= 1} {
	return 1
    }
    set next [expr {$x - 1}]
    return [expr {$x * [fac $next]}]
}

# Create the three widgets that make up the GUI for the application
# and arrange them in a gridded pattern.

label .label1 -text "Enter number:"
entry .entry
label .label2 -textvariable answer
grid .label1 .entry
grid .label2 -columnspan 2

# Arrange for the fac procedure to be invoked whenever Return is typed
# in the entry widget.  The result is stored in variable "answer"; the
# widget .label2 always displays the value of this variable.

bind .entry <Return> {
    set answer "Answer is [fac [.entry get]]"
}
