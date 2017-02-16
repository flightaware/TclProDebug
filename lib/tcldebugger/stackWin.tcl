# stackWin.tcl --
#
#	This file implements the Stack Window.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 

namespace eval stack {
    # Handle to the stack text widget.

    variable stackText {}

    # The stack::stack array stores opaque <location> types for each
    # stack displayed in the stack window.  Each time the stack is
    # updated (i.e., calls to stack::updateStackWindow) this array
    # is re-initalized.  The <location> types are indexed using the 
    # line number of the text widget.
    
    variable stack

    # For every stack level displayed in the Stack Window, store
    # the current PC for that block.  Thsi information is used
    # to show where the last statement was executed in this block
    # when the user moves up and down the stack.

    variable blockPC

    variable selectedArg
    
    # If this variable is set, selecting a line in the stack window will
    # update the rest of the gui.

    variable needsUpdate 1
}

# createWindow --
#
#	Create the Stack Window and all of the sub elements.
#
# Arguments:
#	masterFrm	The frame that contains the stack frame.
#
# Results:
#	The frame that contains the Stack Window.

proc stack::createWindow {masterFrm} {
    variable stackText

    set stackFrm  [frame $masterFrm.stack]
    set subFrm    [frame $stackFrm.sub]
    set stackText [text $subFrm.text -width 0 -height 20 -bd 0]
    set scrollbar [scrollbar $stackText.sb -command [list $stackText yview]]

    guiUtil::tableCreate $subFrm $stackText {} -title1 "Stack Frames"
    gui::setDbgTextBindings $stackText $scrollbar
    bind::addBindTags $stackText [list stackDbgWin scrollText \
	    selectFocus selectCopy selectLine moveCursor]

    sel::setWidgetCmd $stackText line {
	stack::checkState
    }
    bind stackDbgWin <1> {
	focus $stack::stackText
    }
    bind stackDbgWin <Configure> {
	gui::formatText %W right
    }
    bind stackDbgWin <Return> {
	sel::selectLine %W [sel::getCursor %W].0
	break
    }
    bind stackDbgWin <space> {
	sel::selectLine %W [sel::getCursor %W].0
	break
    }
    $stackText tag bind stackArg <1> {
	stack::selectArg %W current
    }
    return $stackFrm
}

# stack::updateWindow --
#
#	Update the Stack Window after (1) a file is loaded 
#	(2) a breakpoint is reached or (3) a new stack level 
#	was selected from the stack window.
#
# Arguments:
#	currentLevel	The current level being displayed by
#			debugger.
#
# Results: 
#	None.

proc stack::updateWindow {currentLevel} {
    variable blockPC
    variable stack
    variable stackText

    # The stack array caches <location> types based on the current
    # line number.  Unset any existing data and delete the contents 
    # of the stack text widget.

    stack::resetWindow

    # Insert the stack information backwards so we can detect
    # hidden frames.  If the next level is > the previous,
    # then we know that the next level is hidden by a previous
    # level.

    set stkList [dbg::getStack]
    set end     [llength $stkList]
    set line    $end
    set first 1
    for {set i [expr {$end - 1}]} {$i >= 0} {incr i -1} {
	set stk   [lindex $stkList $i]
	set level [lindex $stk 0]
	set loc   [lindex $stk 1]
	set type  [lindex $stk 2]
	set name  [lindex $stk 3]
	set args  [lindex $stk 4]

	# Convert all of the newlines to \n's so the values
	# span only one line in the text widget.

	set name [code::mangle $name]
	set args [code::mangle $args]

	# Determine if the level is a hidden level and 
	# insert the newline now so the last line in the 
	# text is not an empty line after a newline.

	set hiddenLevel 0
	set hiddenTag {}
	if {!$first} {
	    if {($level >= $prevLevel) && ($level > 0)} {
		set hiddenLevel 1
		set hiddenTag hiddenLevel
	    }
	    $stackText insert 0.0 "\n"
	}
	if {!$hiddenLevel} {
	    set prevLevel $level
	}
	set first 0

	# Trim the "name" argument if the type is "proc" or
	# "source".  If the type is "proc", then trim leading
	# namespace colons (if >= 8.0),   If the type is 
	# "source", then convert the name into a unique, short
	# file name.  

	set shortName $name
	switch $type {
	    proc {
		set shortName [procWin::trimProcName $shortName]
	    }
	    source {
		set block [loc::getBlock $loc]
		if {($block != {}) && (![blk::isDynamic $block])} { 
		    set shortName [file::getUniqueFile $block]
		}
	    }
	}

	# Add spaces separately so they do not inherit
	# the tags put on the the other text items. Add
	# the hiddenTag to the vars, since they are the
	# only elements affected by hidden levels.

	$stackText insert 0.0 "$args" "stackEntry stackArg $hiddenTag"
	$stackText insert 0.0 " "
	$stackText insert 0.0 "$shortName" "stackEntry stackProc $hiddenTag"
	$stackText insert 0.0 " "
	$stackText insert 0.0 "$type" "stackEntry stackType $hiddenTag"
	$stackText insert 0.0 " "
	$stackText insert 0.0 "$level" "stackEntry stackLevel $hiddenTag $line"

	# If the current level is identical to the this level,
	# cache all of the stack data for easy access by other
	# windows (e.g., the Inspector window wants to know which
	# proc the var is located in.)

	if {$currentLevel == $level && !$hiddenLevel} {
	    gui::setCurrentLevel $level
	    gui::setCurrentType  $type
	    gui::setCurrentProc  $name
	    gui::setCurrentArgs  $args
	    if {$type == "name"} {
		gui::setCurrentScope $name
	    } else {
		gui::setCurrentScope $type
	    }
	}

	# Cache each opaque location type based on line number.

	set stack($line) $loc
	incr line -1
    }

    # Make sure the last line entered is visible in the text 
    # window, and that the lines are formatted correctly.

    set ::stack::needsUpdate 0
    sel::selectLine $stackText $end.0
    set ::stack::needsUpdate 1
}

# stack::updateDbgWindow --
#
#	Update the debugger window to display the stack frame
#	selected in the Stack window.  The line number of the text
#	widget is an index into the stack() array that stores
#	the <location> opaque type.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc stack::updateDbgWindow {} {
    variable stackText
    variable selectedArg

    set line      [sel::getSelectedLines $stackText]
    set loc       [stack::getLocation $line]
    set hidden    [stack::isVarFrameHidden]
    set level     [stack::getSelectedLevel]

    # Update the Stack, Var, Watch and Code window to the
    # current stack level.  If the var frame is hidden,
    # then give feedback in the Var Window and set all
    # values in the Watch Window to <No Value>..

    gui::setCurrentLevel $level
    gui::showCode $loc

    if {$hidden} {
	watch::resetWindow {}
	var::resetWindow "No variable info for this stack."
    } elseif {$::stack::needsUpdate} {
	# Display the var selected from the stack window.  This 
	# function must be called after gui::showCode. 
	
	watch::varDataReset
	var::updateWindow
	watch::updateWindow

	if {$selectedArg != ""} {
	    var::seeVarInWindow $selectedArg 0
	    set selectedArg {}
	}
    }
}

# stack::resetWindow --
#
#	Clear the Stack Window and insert the message in it's
#	place.
#
# Arguments:
#	msg	If not null, then insert this message in the
#		Stack window after clearing it.
#
# Results:
#	None.

proc stack::resetWindow {{msg {}}} {
    variable stackText
    variable selectedArg
    variable stack
    variable blockPC

    if {[info exists stack]} {
	unset stack
    }
    if {[info exists blockPC]} {
	unset blockPC
    }
    set selectedArg {}
    gui::unsetFormatData $stackText
    $stackText delete 0.0 end
    if {$msg != {}} {
	$stackText insert 0.0 $msg message
    }
}

# stack::checkState --
#
#	This proc is executed whenever the selection 
#	in the Stack Window changes.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc stack::checkState {} {
    variable stackText

    gui::formatText $stackText right
    stack::updateDbgWindow 
}

# stack::selectArg --
#
#	If the user clicks on a procedure's argument in the
#	Stack Window, cache the argument so it will become
#	visible in the Var Window on the next update.
#
# Arguments:
#	text	The stackText widget.
#	index	The index of the button press.
#
# Results:
#	None.

proc stack::selectArg {text index} {
    variable selectedArg

    set range [stack::getStackWordRange $text $index stackEntry]
    if {$range != {}} {
	set selectedArg [eval {$text get} $range]
    } else {
	set selectedArg {}
    }
}

# stack::isVarFrameHidden --
#
#	Determine of the stack level located at <index> is
#	a hidden stack frame.
#
# Arguments:
#	None.
#
# Results:
#	Boolean, true if the selected stack is hidden.

proc stack::isVarFrameHidden {} {
    variable stackText
    
    # If the tag "hiddenLevel" is on the text item, then this
    # is a stack entry with conflicting variable frames.

    set line [sel::getSelectedLines $stackText]
    if {$line == {}} {
	return 1
    } 
    if {[lsearch [$stackText tag names $line.0] hiddenLevel] < 0} {
	return 0
    }
    return 1
}

# stack::getSelectedLevel --
#
#	Get the level of the Stack inside the Stack text
#	widget at index.
#
# Arguments:
#	None.
#
# Results:
#	The level of the Stack entry at <index>.

proc stack::getSelectedLevel {} {
    variable stackText
    
    set line [sel::getSelectedLines $stackText]
    set range [stack::getStackWordRange $stackText \
	    "$line.0 lineend" stackLevel]
    return [eval {$stackText get} $range]
}

# stack::getLocation --
#
#	Get the opaque <location> type for a stack displayed in the
#	Stack Window.  The location is cached in the stack::stack
#	array, and the key is the line number of the text widget.
#
# Arguments:
#	line	Line number of a stack being displayed in the 
#		Stack Window.
#
# Results:
#	A location opaque type for a stack.

proc stack::getLocation {line} {
    return $stack::stack($line)
}

# stack::getPC --
#
#	Return the <location> opaque type of the currently 
#	selected stack frame.
#
# Arguments:
#	None.
#
# Results:
#	Return the <location> opaque type of the currently 
#	selected stack frame, or empty string if there is 
#	no stack data.

proc stack::getPC {} {
    if {[gui::getCurrentState] != "stopped"} {
	return {}
    }
    return [stack::getLocation [sel::getCursor $stack::stackText]]
}

# stack::getPCType --
#
#	Return the type of PC to display.  If the currently
#	selected stack frame is the top-most frame, then the
# 	type is "current", otherwise it is "history".
#
# Arguments:
#	None.
#
# Results:
#	Return the type of PC to display, or empty string if there
#	is no stack data. 

proc stack::getPCType {} {
    # If the selection cursor is on the last line, then 
    # the PC type is "current".

    if {[gui::getCurrentState] != "stopped"} {
	return {}
    }
    set cursor [sel::getCursor $stack::stackText]
    set end    [lindex [split [$stack::stackText index "end - 1l"] .] 0]
    if {$cursor == $end} {
	return current
    }
    return history
}

# stack::getStackWordRange --
#
#	Get the range of a word in the Stack Window, where the 
#	word may have embedded whitespace.  The word must have a
#	tag from beginning to end, with non-tagged delimiting
#	whitespace on either ends.
#
# Arguments:
#	text	The Stack text widget.
#	index	The index anywhere in the middle of the word.
#	tag	The delimiting tag on the word.
#
# Results:
#	The range of the word in the text widget.

proc stack::getStackWordRange {text index tag} {
    set index [$text index $index]
    return [$text tag prevrange $tag "$index + 1 chars"]    
}
