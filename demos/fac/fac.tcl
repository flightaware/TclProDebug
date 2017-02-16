# fac.tcl --
#
#    This program takes a command line argument and prints the
#    factorial of each integer between 1 and itself.
#
# Copyright (c) 1998 Scriptics Corporation
# See the file "license.terms" for information on usage and redistribution of this file.
#
# RCS: @(#) $Id: fac.tcl,v 1.2 2000/10/31 23:31:08 welch Exp $

# factorial --
#
#    Tail-recursive implementation of the factorial function.
#    As a side-effect, the global value of "n" is decremented.
#

proc factorial {result} {
    global n
    if {$n <= 1} {
	return $result
    }
    set result [expr {$n * $result}]
    incr n -1
    return [factorial $result]
}

# 
# Set max to the value of the command line argument.
#

if {$argc != 1} {
    error "this program requires 1 integer as a command line arg"
}
set max [lindex $argv 0]

# 
# Call the factorial procedure for each integer from max down to 1.
# Store each result in the fact array.
#

for {set i $max} {$i >= 1} {incr i -1} {

    set n $i

    set fact($i) [factorial 1]
}

# 
# Print the index and value of each entry in the fact array.
#

foreach index [lsort -integer [array names fact]] {
    puts "fact($index) = $fact($index)"
}
