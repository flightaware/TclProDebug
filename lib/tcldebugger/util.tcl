# util.tcl --
#
#	This file contains miscellaneous utilities.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 

# lassign --
#
#	This function emulates the TclX lassign command.
#
# Arguments:
#	valueList	A list containing the values to be assigned.
#	args		The list of variables to be assigned.
#
# Results:
#	Returns any values that were not assigned to variables.

if {[info commands lassign] eq {}} {

# start lassign proc
proc lassign {valueList args} {
  if {[llength $args] == 0} {
      error "wrong # args: lassign list varname ?varname..?"
  }

  uplevel [list foreach $args $valueList {break}]
  return [lrange $valueList [llength $args] end]
}
# end lassign proc

}

# matchKeyword --
#
#	Find the unique match for a string in a keyword table and return
#	the associated value.
#
# Arguments:
#	table	A list of keyword/value pairs.
#	str	The string to match.
#	exact	If 1, only exact matches are allowed, otherwise unique
#		abbreviations are considered valid matches.
#	varName	The name of a variable that will hold the resulting value.
#
# Results:
#	Returns 1 on a successful match, else 0.

proc matchKeyword {table str exact varName} {
    upvar $varName result
    if {$str == ""} {
	foreach pair $table {
	    set key [lindex $pair 0]
	    if {$key == ""} {
		set result [lindex $pair 1]
		return 1
	    }
	}
	return 0
    }
    if {$exact} {
	set end end
    } else {
	set end [expr {[string length $str] - 1}]
    }
    set found ""
    foreach pair $table {
	set key [lindex $pair 0]
	if {[string compare $str [string range $key 0 $end]] == 0} {
	    # If the string matches exactly, return immediately.

	    if {$exact || ($end == ([string length $key]-1))} {
		set result [lindex $pair 1]
		return 1
	    } else {
		lappend found [lindex $pair 1]
	    }
	}
    }
    if {[llength $found] == 1} {
	set result [lindex $found 0]
	return 1
    } else {
	return 0
    }
}

