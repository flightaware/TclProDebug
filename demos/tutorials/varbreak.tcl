# varbreak.tcl --
#
#    This program increments a variable "x".  It was designed to 
#    illustrate variable breakpoints in TclPro Debugger.
#
# Copyright (c) 1999 Scriptics Corporation
# See the file "license.terms" for information on usage and redistribution of this file.
#

set x 0

label .x -textvariable x
pack .x -padx 6 -pady 4
button .incr -text "Increment" -command {Increment x}
pack .incr -side left -expand yes -padx 4 -pady 4
button .decr -text "Decrement" -command {Decrement x}
pack .decr -side left -expand yes -padx 4 -pady 4

# 
# Increment - Increases the value of the variable whose name is 
#   "varName" by one.
#

proc Increment {varName} {
    global $varName
    incr $varName
}

# 
# Decrement - Reduces the value of the variable "varName" by one.
#

proc Decrement {varName} {
    global $varName
    incr $varName -1
}

