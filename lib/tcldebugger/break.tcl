# break.tcl --
#
#	This file implements the breakpoint object API.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 

package provide break 1.0
namespace eval break {
    # breakpoint data type --
    #
    #   A breakpoint object encapsulates the state associated with a
    #	breakpoint.  Each breakpoint is represented by a Tcl array
    #   whose name is of the form break<type><num> where <type> is
    #	L for line-based breakpoints and V for variable breakpoints.
    #	Each array contains the following elements:
    #		state		Either enabled or disabled.
    #		test		The script in conditional breakpoints.
    #		location	The location or trace handle for the
    #				breakpoint.
    #		data		This field holds arbitrary data associated
    #				with the breakpoint for use by the GUI.
    #
    # Fields:
    #	counter		This counter is used to generate breakpoint names.

    variable counter 0
}
# end namespace break

# break::MakeBreakpoint --
#
#	Create a new breakpoint.
#
# Arguments:
#	type		One of "line" or "var"
#	where		Location for line breakpoints; trace handle for
#			variable breakpoints.
#	test		Optional.  Script to use for conditional breakpoint.
#
# Results:
#	Returns a breakpoint identifier.

proc break::MakeBreakpoint {type location {test {}}} {
    variable counter
    
    if {$type == "line"} {
	set type L
    } else {
	set type V
    }

    # find an unallocated breakpointer number and create the array

    incr counter
    while {[info exists ::break::break$type$counter]} {
	incr counter
    }
    set name $type$counter
    array set ::break::break$name \
	    [list data {} location $location state enabled test $test]
    return $name
}

# break::Release --
#
#	Release the storage associated with one or more breakpoints.
#
# Arguments:
#	breakList	The breakpoints to release, or "all".
#
# Results:
#	None.

proc break::Release {breakList} {
    if {$breakList == "all"} {
	# Release all breakpoints
	set all [info vars ::break::break*]
	if {$all != ""} {
	    eval unset $all
	}
    } else {
	foreach breakpoint $breakList {
	    if {[info exist ::break::break$breakpoint]} {
		unset ::break::break$breakpoint
	    }
	}
    }
    return
}

# break::getState --
#
#	Return the breakpoint state.
#
# Arguments:
#	breakpoint	The breakpoint identifier.
#
# Results:
#	Returns one of enabled or disabled.

proc break::getState {breakpoint} {
    return [set ::break::break${breakpoint}(state)]
}

# break::getLocation --
#
#	Return the breakpoint location.
#
# Arguments:
#	breakpoint	The breakpoint identifier.
#
# Results:
#	Returns the breakpoint location.

proc break::getLocation {breakpoint} {
    return [set ::break::break${breakpoint}(location)]
}


# break::getTest --
#
#	Return the breakpoint test.
#
# Arguments:
#	breakpoint	The breakpoint identifier.
#
# Results:
#	Returns the breakpoint test.

proc break::getTest {breakpoint} {
    return [set ::break::break${breakpoint}(test)]
}

# break::getType --
#
#	Return the type of the breakpoint.
#
# Arguments:
#	breakpoint	The breakpoint identifier.
#
# Results:
#	Returns the breakpoint type; one of "line" or "var".

proc break::getType {breakpoint} {
    switch [string index $breakpoint 0] {
	V {
	    return "var"
	}
	L {
	    return "line"
	}
    }
    error "Invalid breakpoint type"
}


# break::SetState --
#
#	Change the breakpoint state.
#
# Arguments:
#	breakpoint	The breakpoint identifier.
#	state		One of enabled or disabled.
#
# Results:
#	None.

proc break::SetState {breakpoint state} {
    set ::break::break${breakpoint}(state) $state
    return
}

# break::getData --
#
#	Retrieve the client data field.
#
# Arguments:
#	breakpoint	The breakpoint identifier.
#
# Results:
#	Returns the data field.

proc break::getData {breakpoint} {
    return [set ::break::break${breakpoint}(data)]
}

# break::setData --
#
#	Set the client data field.
#
# Arguments:
#	breakpoint	The breakpoint identifier.
#
# Results:
#	None.

proc break::setData {breakpoint data} {
    set ::break::break${breakpoint}(data) $data
    return
}

# break::GetLineBreakpoints --
#
#	Returns a list of all line-based breakpoint indentifiers.  If the
#	optional location is specified, only breakpoints set at that
#	location are returned.
#
# Arguments:
#	location	Optional. The location of the breakpoint to get.
#
# Results:
#	Returns a list of all line-based breakpoint indentifiers.

proc break::GetLineBreakpoints {{location {}}} {
    set result {}
    foreach breakpoint [info vars ::break::breakL*] {
	if {($location == "") \
		|| [loc::match $location [set ${breakpoint}(location)]]} {
	    lappend result $breakpoint
	}
    }

    regsub -all {::break::break} $result {} result
    return $result
}

# break::GetVarBreakpoints --
#
#	Returns a list of all variable-based breakpoint indentifiers
#	for a specified variable trace.
#
# Arguments:
#	handle		The trace handle.
#
# Results:
#	A list of breakpoint identifiers.

proc break::GetVarBreakpoints {{handle {}}} {
    set result {}
    foreach breakpoint [info vars ::break::breakV*] {
	if {($handle == "") \
		|| ([set ${breakpoint}(location)] == $handle)} {
	    lappend result $breakpoint
	}
    }
    regsub -all {::break::break} $result {} result
    return $result
}

# break::preserveBreakpoints --
#
#	Generate a persistent representation for all line-based
#	breakpoints so they can be stored in the user preferences.
#
# Arguments:
#	varName		Name of variable where breakpoint info should
#			be stored.
#
# Results:
#	None.

proc break::preserveBreakpoints {varName} {
    upvar $varName data
    set data {}
    foreach bp [GetLineBreakpoints] {
	set location [getLocation $bp]
	set file [blk::getFile [loc::getBlock $location]]
	set line [loc::getLine $location]
	if {$file != ""} {
	    lappend data [list $file $line [getState $bp] \
		    [getTest $bp]]
	}
    }		
    return
}

# break::restoreBreakpoints --
#
#	Recreate a set of breakpoints from a previously preserved list.
#
# Arguments:
#	data		The data generated by a previous call to
#			preserveBreakpoints.
#
# Results:
#	None.

proc break::restoreBreakpoints {data} {
    foreach bp $data {
	set block [blk::makeBlock [lindex $bp 0]]
	set location [loc::makeLocation $block [lindex $bp 1]]
	SetState [MakeBreakpoint "line" $location [lindex $bp 3]] \
		[lindex $bp 2]
    }
    return
}
