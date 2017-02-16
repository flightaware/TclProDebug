# icon.tcl --
#
#	This file manages all of the icon drawing as well as 
#	setting the correct state in the nub based on the type
#	of icon drawn.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 

namespace eval icon {
    # Do Nothing...
}

# icon::getState --
#
#	Get the state of the BP based on the icon in the code bar.
#
# Arguments:
#	text 	The Code Bar text widget.
#	line	The line number in the text widget to check.
#
# Results:
#	The state of the BP based on the icon

proc icon::getState {text line} {
    foreach tag [$text tag names $line.0] {
	switch $tag {
	    enabledBreak -
	    disabledBreak -
	    mixedBreak {
		return $tag
	    }
	}
    }
    return noBreak
}

# icon::getLBPState --
#
#	Return the state of the breakpoint for a <loc> type.
#	The CodeBar only displays one icon per line, so the 
#	breakpoint state is a combination of all breakpoints
#	that exist on this line.  A breakpoint's state is 
#	"mixed" if there are one or more enabled AND disabled
#	breakpoints for the same line.
#
# Arguments:
#	loc	A <loc> opaque type that contains the location 
#		of the breakpoint in a script.
#
# Results:
#	The state of the breakpoint at <loc>.  Either: enabledBreak,
#	disabledBreak, mixedBreak or noBreak.

proc icon::getLBPState {loc} {
    set state noBreak
    set bps [dbg::getLineBreakpoints $loc]
    foreach bp $bps {
	if {[break::getState $bp] == "enabled"} {
	    if {$state == "disabled"} {
		return mixedBreak
	    } 
	    set state enabledBreak
	} else {
	    if {$state == "enabled"} {
		return mixedBreak
	    } 
	    set state disabledBreak
	}
    }
    return $state
}

# icon::toggleLBPOnOff --
#
#	Toggle the breakpoint on and off.  Based on the current
#	state of the breakpoint, determine the next valid state,
#	delete any existing icon and draw a new icon if necessary.
#
# Arguments:
#	text		Text widget that contains breakpoint icons.
#	index		Location to delete and insert icons.
#	loc		The <loc> type needed set breakpoints.
#	breakState	The current state of the breakpoint.
#	pcType  	String, used to indicate if the "current"
#			icon is also at this index and what type
#			the icon is (current or history.)
#
# Results:
#	None.

proc icon::toggleLBPOnOff {text index loc breakState {pcType {}}} {
    switch -exact $breakState {
	noBreak {
	    # If the "current" icon is on the current line,
	    # delete it, then set the state to "enabled".
	    if {$pcType != {}} {
		$text delete $index
	    }

	    dbg::addLineBreakpoint $loc
	    pref::groupSetDirty Project 1
	    icon::drawLBP $text $index enabledBreak $pcType
	}
	enabledBreak {
	    # Delete "enabled" icon and set the state to "no break".
	    $text delete $index

	    icon::setLBP noBreak $loc 
	    icon::drawLBP $text $index noBreak $pcType
	}
	disabledBreak -
	mixedBreak {
	    # Delete the icon and set the state back to "enabled".
	    $text delete $index

	    icon::setLBP enabledBreak $loc 
	    icon::drawLBP $text $index enabledBreak $pcType
	}
	default {
	    error "unknown line breakpoint state: $breakState"
	}
    }
}

# icon::toggleLBPEnableDisable --
#
#	Toggle the breakpoint to enabled and disabled.  Based on the 
#	current state of the breakpoint, determine the next valid 
#	state, delete any existing icon, and draw a new icon if 
# 	necessary.
#
# Arguments:
#	text		Text widget that contains breakpoint icons.
#	index		Location to delete and insert icons.
#	loc		The <loc> type needed set breakpoints.
#	breakState	The current state of the breakpoint.
#	pcType  	String, used to indicate if the "current"
#			icon is also at this index and what type
#			the icon is (current or history.)
#
# Results:
#	None.

proc icon::toggleLBPEnableDisable {text index loc breakState {pcType {}}} {
    switch -exact $breakState {
	noBreak {
	    return
	}
	enabledBreak -
	mixedBreak {
	    # Delete the icon and set the state to "disabled".
	    $text delete $index

	    icon::setLBP disabledBreak $loc 
	    icon::drawLBP $text $index disabledBreak $pcType
	}
	disabledBreak {
	    # Delete the disabled icon and set the state back to "enabled".
	    $text delete $index

	    icon::setLBP enabledBreak $loc 
	    icon::drawLBP $text $index enabledBreak $pcType
	}
	default {
	    error "unknown line breakpoint state: $breakState"
	}
    }
}

# icon::setLBP --
#
#	Set the new state of the breakpoint in the nub.
#
# Arguments:
#	state	The new state of the breakpoint.
#	loc	The <loc> object used to set the breakpoint.
#
# Results:
#	None.

proc icon::setLBP {state loc} {
    set bps [dbg::getLineBreakpoints $loc]
    switch -exact $state {
	noBreak {
	    foreach bp $bps {
		pref::groupSetDirty Project 1
		dbg::removeBreakpoint $bp
	    }
	}
	enabledBreak {
	    foreach bp $bps {
		dbg::enableBreakpoint $bp
	    }
	}
	disabledBreak {
	    foreach bp $bps {
		dbg::disableBreakpoint $bp
	    }
	}
	default {
	    error "unknown state in icon::setLBP: $state"
	}
    }
}

# icon::drawLBP --
#
#	Draw a new breakpoint icon into the text widget.
#	It is assumed that any out-datted icon on this line 
#	have already been deleted.
#
#	Icons are embedded into the text widget with two tags
#	bound to them: setBreak and <tagName>.  SetBreak is used
#	to identify it as a generic breakpoint icon, and
#	<tagName> is used to identify the type of breakpoint.
#
# Arguments:
#	text		The text widget to draw the icon into.
#	index		The location in the text widget to insert the icon.
#	breakState	The type of icon to draw.
#	pcType  	String, used to indicate if the "current"
#			icon is also at this index and what type
#			the icon is (current or history.)
#
# Results:
#	None.

proc icon::drawLBP {text index breakState {pcType {}}} {
    switch -exact $breakState {
	noBreak {
	    if {$pcType != {}} {
		$text image create $index -name currentImage \
			-image $image::image($pcType)
	    }
	    return
	}
	enabledBreak {
	    if {$pcType != {}} {
		set imageName currentImage
		set imageType ${pcType}_enable
	    } else {
		set imageName enabledBreak
		set imageType break_enable
	    }
	    set tagName enabledBreak
	}
	disabledBreak {
	    if {$pcType != {}} {
		set imageName currentImage
		set imageType ${pcType}_disable
	    } else {
		set imageName disabledBreak
		set imageType break_disable
	    }
	    set tagName disabledBreak
	}
	mixedBreak {
	    if {$pcType != {}} {
		set imageName currentImage
		set imageType ${pcType}_mixed
	    } else {
		set imageName mixedBreak
		set imageType break_mixed
	    }
	    set tagName mixedBreak
	}
	default {
	    error "unknown codebar break state: $breakState"
	}
    }
    $text image create $index -name $imageName \
	    -image $image::image($imageType)
    $text tag add $tagName $index
    $text tag add setBreak $index
}

# icon::getVBPState --
#
#	Get the VBP state for a specific variable.
#
# Arguments:
#	level	The stack level of the variable location.
#	name	The variable name.
#
# Results:
#	The VBP state: enabledBreak, disabledBreak or noBreak.

proc icon::getVBPState {level name} {
    set state noBreak

    if {[gui::getCurrentState] == "stopped"} {
	set vbps [dbg::getVarBreakpoints $level $name]
	foreach vbp $vbps {
	    if {[break::getState $vbp] == "enabled"} {
		set state enabledBreak
	    } elseif {$state != "enabled"} {
		set state disabledBreak
	    }
	}
    }
    return $state
}

# icon::toggleVBPOnOff --
#
#	Toggle the VBP state between on and off and redraw 
#	the icon in the text widget.
#
# Arguments:
#	text 		The text widget to redraw the VBP icon in.
#	index		Location to delete and insert icons.
#	level 		The stack level of the variable location.
#	name		The name of the variable.
#	breakState	The current state of the breakpoint.
#	pcType  	String, used to indicate if the "current"
#			icon is also at this index and what type
#			the icon is (current or history.)
#
# Results:
#	None.

proc icon::toggleVBPOnOff {text index level name breakState {pcType {}}} {
    switch -exact $breakState {
	noBreak {
	    set bp [dbg::addVarBreakpoint $level $name]
	    break::setData $bp [list [list $level $name] [list]]
	    icon::drawVBP $text $index enabledBreak $pcType
	}
	enabledBreak {
	    # Delete "enabled" icon and set the state to "no break".
	    $text delete $index 
	    
	    icon::setVBP noBreak $level $name
	    icon::drawVBP $text $index noBreak $pcType
	}
	disabledBreak {
	    # Delete the icon and set the state back to "enabled".
	    $text delete $index 

	    icon::setVBP enabledBreak $level $name
	    icon::drawVBP $text $index enabledBreak $pcType
	}
	default {
	    error "unknown variable breakpoint state: $breakState"
	}
    }
}

# icon::toggleVBPEnableDisable --
#
#	Toggle the VBP state to enabled or disabled and redraw the icon
#	in the text widget.
#
# Arguments:
#	text 		The text widget to redraw the VBP icon in.
#	index		Location to delete and insert icons.
#	level 		The stack level of the variable location.
#	name		The name of the variable.
#	breakState	The current state of the breakpoint.
#	pcType  	String, used to indicate if the "current"
#			icon is also at this index and what type
#			the icon is (current or history.)
#
# Results:
#	None.

proc icon::toggleVBPEnableDisable {text index level name breakState \
	{pcType {}}} {

    switch -exact $breakState {
	noBreak {
	    return
	}
	enabledBreak {
	    # Delete the icon and set the state to "disabled".
	    $text delete $index

	    icon::setVBP disabledBreak $level $name
	    icon::drawVBP $text $index disabledBreak $pcType
	}
	disabledBreak {
	    # Delete the disabled icon and set the state back to "enabled".
	    $text delete $index

	    icon::setVBP enabledBreak $level $name
	    icon::drawVBP $text $index enabledBreak $pcType
	}
	default {
	    error "unknown variable breakpoint state: $breakState"
	}
    }
}

# icon::setVBP --
#
#	Set the new state of the VBP in the nub.
#
# Arguments:
#	state		The new state of the breakpoint.
#	level 		The stack level of the variable location.
#	name		The name of the variable.
#
# Results:
#	None.

proc icon::setVBP {state level name} {
    if {[gui::getCurrentState] != "stopped"} {
	error "icon::setVBP called when state is running"
    }
    set bps [dbg::getVarBreakpoints $level $name]
    switch -exact $state {
	noBreak {
	    foreach bp $bps {
		dbg::removeBreakpoint $bp
	    }
	}
	enabledBreak {
	    foreach bp $bps {
		dbg::enableBreakpoint $bp
		set orig [lindex [break::getData $bp] 0]
		if {$orig == {}} {
		    break::setData $bp [list [list $level $name] [list]]
		} else {
		    break::setData $bp [list $orig [list $level $name]]
		}
	    }
	}
	disabledBreak {
	    foreach bp $bps {
		dbg::disableBreakpoint $bp
		set orig [lindex [break::getData $bp] 0]
		break::setData $bp [list $orig [list $level $name]]
	    }
	}
	default {
	    error "unknown state in icon::setVBP: $state"
	}
    }    
}

# icon::drawVBP --
#
#	Draw a new breakpoint icon into the text widget.
#	It is assumed that any out-datted icon on this line 
#	have already been deleted.
#
#	Icons are embedded into the text widget with two tags
#	bound to them: setBreak and <tagName>.  SetBreak is used
#	to identify it as a generic breakpoint icon, and
#	<tagName> is used to identify the type of breakpoint.
#
# Arguments:
#	text		The text widget to draw the icon into.
#	index		The location in the text widget to insert the icon.
#	breakState	The type of icon to draw.
#	pcType  	String, used to indicate if the "current"
#			icon is also at this index and what type
#			the icon is (current or history.)
#
# Results:
#	None.

proc icon::drawVBP {text index breakState {pcType {}}} {
    
    # Var break points are only drawn where they occur.  If the
    # pcType is "history" then we should treat this as a line break 
    # point instead.

    if {$pcType == "history"} {
	icon::drawLBP $text $index $breakState $pcType
	return
    }

    switch -exact $breakState {
	noBreak {
	    if {$pcType != {}} {
		$text image create $index -name currentImage \
			-image $image::image($pcType)
	    }
	    return
	}
	enabledBreak {
	    if {$pcType != {}} {
		set imageName currentImage
		set imageType ${pcType}_var
	    } else {
		set imageName enabledBreak
		set imageType var_enable
	    }
	    set tagName enabledBreak
	}
	disabledBreak {
	    if {$pcType != {}} {
		error "This shouldn't happen:  current over disabled VBP!"
		set imageName currentImage
		set imageType ${pcType}_var_disable
	    } else {
		set imageName disabledBreak
		set imageType var_disable
	    }
	    set tagName disabledBreak
	}
	default {
	    error "unknown codebar break state: $breakState"
	}
    }
    $text image create $index -name $imageName \
	    -image $image::image($imageType)
    $text tag add $tagName $index
    $text tag add setBreak $index
}

# icon::getVBPOrigLevel --
#
#	Get the var name from when the VBP was created.
#
# Arguments:
#	vbp	The VBP handle.
#
# Results:
#	Return the var name from when the VBP was created.

proc icon::getVBPOrigLevel {vbp} {
    return [lindex [lindex [break::getData $vbp] 0] 0]
}

# icon::getVBPOrigName --
#
#	Get the stack level from when the VBP was created.
#
# Arguments:
#	vbp	The VBP handle.
#
# Results:
#	Return the stack level from when the VBP was created.

proc icon::getVBPOrigName {vbp} {
    return [lindex [lindex [break::getData $vbp] 0] 1]
}

# icon::getVBPNextName --
#
#	Get the var name from when the VBP was last set.
#
# Arguments:
#	vbp	The VBP handle.
#
# Results:
#	Return the var name from when the VBP was last set..

proc icon::getVBPNextName {vbp} {
    return [lindex [lindex [break::getData $vbp] 1] 1]
}

# icon::getVBPNextLevel --
#
#	Get the stack level from when the VBP was last set.
#
# Arguments:
#	vbp	The VBP handle.
#
# Results:
#	Return the stack level from when the VBP was last set.

proc icon::getVBPNextLevel {vbp} {
    return [lindex [lindex [break::getData $vbp] 1] 0]
}

# icon::isCurrentIconAtLine --
#
#	Determines if the "current" icon, if it exists, is
#	on the same line as index.
#
# Arguments:
#	text	Text widget to look for the "current" icon.
#	index	Text index where to look for the "current" icon.
#
# Results:
#	Boolean: true if "current" icon is on the same line
#	as index.

proc icon::isCurrentIconAtLine {text index} {
    set start  [$text index "$index linestart"]
    if {[catch {set cIndex [$text index currentImage]}] == 0} {
	if {$start == $cIndex} {
	    return 1
	}
    }
    return 0
}

# icon::setCurrentIcon --
#
#	Draw the "current" icon at index.  If an icon is
#	already on this line, delete it, and draw the 
#	overlapped icon.
#
# Arguments:
#	text	The text widget to insert the icon in to.
#	index	The location in the text widget to insert the icon.
#
# Results:
#	None.

proc icon::setCurrentIcon {text index breakType pcType} {
    
    if {$breakType == "var"} {
	icon::drawVBP $text $index enabledBreak $pcType
    } else {
	set loc [code::makeCodeLocation $text $index]
	set breakState [icon::getLBPState $loc]
	if {$breakState != "noBreak"} {
	    $text delete $index
	}
	icon::drawLBP $text $index $breakState $pcType
    }	
}

# icon::unsetCurrentIcon --
#
#	Delete the "current" icon and draw the icon that
#	represents the breakpoint state on this line.
#
# Arguments:
#	text	The text widget to delete the icon in from.
#	index	The location of the icon.
#
# Results:
#	None.

proc icon::unsetCurrentIcon {text iconIndex} {
    # Test to see if the index passed in was valid.  It might be 
    # "currentImage" which may or may not exist.  If it does set
    # "index" to the numeric index.

    if {[catch {$text index $iconIndex} index]} {
	return
    }
    set loc [code::makeCodeLocation $text $index]
    set breakState [icon::getLBPState $loc]
    $text delete $index
    icon::drawLBP $text $index $breakState
}
