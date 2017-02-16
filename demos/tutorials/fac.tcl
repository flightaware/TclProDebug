#!/bin/sh
# the next line restarts using protclsh82 \
exec protclsh82 "$0" "$@"

# fac.tcl --
#
# This program computes factorials.  It is intended as a 
# simple demo application for TclPro.

# This procedure computes the factorial of its argument using a
# recursive approach and returns the factorial as a result.

proc fac x {
    if {$x <= 1} {
	return 1
    }
    set next [expr {$x - 1}]
    return [expr {$x * [fac $next]}]
}

set iter 1

while {$iter == 1} {

    # Prompt for a value

    puts -nonewline "Enter a number: "
    flush stdout
    set value [gets stdin]

    # Output the factorial

    puts "${value}! is [fac $value]"
    
    # Do it again?
    
    puts -nonewline "Calculate another factorial? (y/n) "
    flush stdout
    set iter [regexp {^[yY]} [gets stdin]]
}
