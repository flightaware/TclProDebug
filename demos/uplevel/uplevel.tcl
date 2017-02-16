# uplevel.tcl --
#
#    This program demonstrates the debugger's display of stack data when
#    an application stops in a script invoked via the "uplevel" command.
#
# Copyright (c) 1998 Scriptics Corporation
# See the file "license.terms" for information on usage and redistribution of this file.
#
# RCS: @(#) $Id: uplevel.tcl,v 1.2 2000/10/31 23:31:13 welch Exp $

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

# populate_fact_array --
#
#    Call the factorial procedure for each integer from 1 to global max.
#    Store each result in the global fact array.
#

proc populate_fact_array {} {

    uplevel \#0 {

	# 
	# Call the factorial procedure for each integer from 1 to max.
	# Store each result in the global fact array.
	#

	for {set i 1} {$i <= $max} {incr i 1} {

	    set n $i

	    set fact($i) [factorial 1]
	}
    }
}

set max 5
populate_fact_array

# 
# Print the index and value of each entry in the fact array.
#

foreach index [lsort [array names fact]] {
    puts "fact($index) = $fact($index)"
}
