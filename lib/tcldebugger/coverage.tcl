# coverage.tcl --
#
#	This file contains the Debugger extension
#	to implement the code coverage feature.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
#

package provide coverage 1.0
namespace eval coverage {

    # The coverageEnabled variable knows whether coverage is on or off.
    # It is off by default.

    variable coverageEnabled 0

    # Store the list {line numRepeatedCoverage} for each range that
    # has been covered at least once.  The indices are stored as follows:
    # <blockNum>:R:<range>

    variable currentCoverage
    array set currentCoverage {}

    # Store the list line number for each range that has not yet been
    # covered.  The indices are stored as follows: <blockNum>:R:<range>

    variable currentUncoverage
    array set currentUncoverage {}

    # Store the name of the file associated with each instrumented block.
    # Use this array to find block num of a "selected" file.

    variable instrumentedBlock
    array set instrumentedBlock {}

    # Store number of times the most repeated command was covered.
    # Use this value to calculate the number of repetitions needed to
    # to increase the intensity of coverage shading.

    variable maxRepeatedCoverage 1

    # Handles to widgets in the Coverage Window.

    variable coverWin    .coverage
    variable coverText   {}
    variable showBut     {}
    variable clearBut    {}
    variable clearAllBut {}

    # Toggle between showing un-coverage: radio(val) = 1
    #                       and coverage: radio(val) = 0
    # Widget handles are radio(uncvr) and radio(cvr).

    variable radio
    array set radio {val 1}

    # Used to delay UI changes do to state change.
    variable afterID
}

# coverage::checkState --
#
#	Determine if the "Show Code" button should be normal
#	or disabled based on what is selected.
#
# Arguments:
#	text	The coverText widget.
#
# Results:
#	None.

proc coverage::checkState {text} {
    variable showBut
    variable clearBut
    variable clearAllBut
    variable coverText

    set state [gui::getCurrentState]
    if {$state != "stopped"} {
	$coverage::clearAllBut configure -state disabled
    } else {
	$coverage::clearAllBut configure -state normal
    }

    set cursor [sel::getCursor $text]
    if {[lsearch -exact [$coverText tag names $cursor.0] fileName] < 0} {
	$coverage::showBut configure -state disabled
	$coverage::clearBut configure -state disabled
    } else {
	$coverage::showBut configure -state normal
	$coverage::clearBut configure -state normal
    }

    if {[focus] == $coverText} {
	sel::changeFocus $coverText in
    }
}

# coverage::clearAllCoverage --
#
#	Remove all memory of having covered any code.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc coverage::clearAllCoverage {text} {
    variable instrumentedBlock

    set state [gui::getCurrentState]
    if {$state != "running" && $state != "stopped"} {
	return
    }

    coverage::clearCoverageArray    
    coverage::updateWindow
}

# coverage::clearBlockCoverage --
#
#	Remove all memory of having covered the specified block.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc coverage::clearBlockCoverage {text} {
    variable instrumentedBlock

    set state [gui::getCurrentState]
    if {$state != "running" && $state != "stopped"} {
	return
    }
    
    set line [sel::getCursor $text]
    if {[lsearch -exact [$text tag names $line.0] fileName] < 0} {
	return
    }

    # Get the name and block number associated with the selected file.
    
    set file [$text get "$line.0" "$line.0 lineend"]
    set blk $instrumentedBlock($file)
    
    coverage::clearCoverageArray $blk
    coverage::updateWindow
}

# coverage::clearCoverageArray --
#
#	Remove all memory of having covered the specified block.  If no
#	block is specified, do so for all blocks and reset
#	maxRepeatedCoverage to 1
#
# Arguments:
#	None.
#
# Results:
#	None.

proc coverage::clearCoverageArray {{blk -1}} {
    variable currentUncoverage
    variable currentCoverage
    variable maxRepeatedCoverage
    
    if {$blk == -1} {
	unset currentCoverage
	array set currentCoverage {}
	unset currentUncoverage
	array set currentUncoverage {}
	set maxRepeatedCoverage 1
    } else {
	foreach index [array names currentCoverage "${blk}:*"] {
	    unset currentCoverage($index)
	}

	foreach index [array names currentUncoverage "${blk}:*"] {
	    unset currentUncoverage($index)
	}
	catch {unset currentCoverage($blk)}
	catch {unset currentUncoverage($blk)}
    }
}

# coverage::createWindow --
#
#	Create the Coverage Window that will display
#	all the instrumented files in the running application. 
#
# Arguments:
#	None.
#
# Results:
#	None.

proc coverage::createWindow {} {
    variable coverText
    variable showBut
    variable clearBut
    variable clearAllBut
    variable radio
    variable coverWin

    set top [toplevel $coverWin]
    ::guiUtil::positionWindow $top 400x225
    wm minsize $top 175 100
    wm title $top "Code Coverage"
    wm transient $top $gui::gui(mainDbgWin)

    set bd 2
    set pad  6

    # Create the text widget that displays all files and the 
    # "Show Code" button.

    set mainFrm [frame $top.mainFrm -bd $bd -relief raised]

    set radio(cvr)  [radiobutton $mainFrm.radioCvr -variable coverage::radio(val) \
	    -value 0 -text "Highlight Covered Code for Selected File." \
	    -command coverage::updateWindow]
    set radio(uncvr)  [radiobutton $mainFrm.radioUncvr \
	    -variable coverage::radio(val) -value 1 \
	    -text "Highlight Uncovered Code for Selected File." \
	    -command coverage::updateWindow]
    set coverText [text $mainFrm.coverText -width 30 -height 5 \
	    -yscroll [list $mainFrm.coverText.sb set]]
    set sb [scrollbar $coverText.sb -command [list $coverText yview]]

    set butFrm [frame $mainFrm.butFrm]
    set showBut [button $butFrm.showBut -text "Show Code" \
	    -command [list coverage::showCode $coverText]]
    set clearBut [button $butFrm.clearBut -text "Clear Selected Coverage" \
	    -command [list coverage::clearBlockCoverage $coverText]]
    set clearAllBut [button $butFrm.clearAllBut -text "Clear All Coverage" \
	    -command [list coverage::clearAllCoverage $coverText]]
    set closeBut [button $butFrm.closeBut -text "Close" \
	    -command {destroy $::coverage::coverWin}]
    pack $showBut -fill x
    pack $clearBut -fill x
    pack $clearAllBut -fill x
    pack $closeBut -fill x -anchor s

    grid $radio(uncvr) -row 1 -column 0 -sticky nw -columnspan 3
    grid $radio(cvr) -row 2 -column 0 -sticky nw -columnspan 3
    grid $coverText -row 3 -column 0 -sticky nswe -padx $pad -pady $pad \
	    -columnspan 2
    grid $butFrm  -row 3 -column 2 -sticky nwe -padx $pad -pady $pad
    grid columnconfigure $mainFrm 1 -weight 1
    grid rowconfigure $mainFrm 3 -weight 1

    pack $mainFrm -padx $pad -pady $pad -fill both -expand true

    # Add defualt bindings and define tab order.

    bind::addBindTags $coverText [list scrollText selectFocus selectLine \
	    selectRange moveCursor selectCopy coverDbgWin]
    bind::addBindTags $showBut  coverDbgWin
    bind::addBindTags $clearBut  coverDbgWin
    bind::addBindTags $clearAllBut  coverDbgWin
    bind::commonBindings coverDbgWin [list $coverText $showBut $clearBut \
					 $clearAllBut]
    gui::setDbgTextBindings $coverText $sb

    sel::setWidgetCmd $coverText all {
	coverage::checkState $coverage::coverText
    }
    bind coverDbgWin <<Dbg_ShowCode>> {
	coverage::showCode $coverage::coverText
	break
    }
    bind $coverText <Double-1> {
	if {![sel::indexPastEnd %W current]} {
	    coverage::showCode %W
	}
	break
    }
    bind $coverText <Return> {
	coverage::showCode %W
	break
    }
}

# coverage::getLines --
#
#	Output the list of lines that are not fully covered in the block.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc coverage::getLines {blk} {
    variable currentUncoverage
    variable currentCoverage
    variable radio

    if {$radio(val)} {
	set indexLineList [array get currentUncoverage "${blk}:R:*"]
	foreach {index line} $indexLineList {
	    set tmp($line) 1
	}
	set result [array names tmp]
    } else {
	set indexLineList [array get currentCoverage "${blk}:R:*"]
	foreach {index pair} $indexLineList {
	    set line [lindex $pair 0]
	    set qty [lindex $pair 1]
	    if {[info exists tmp($line)]} {
		incr tmp($line) $qty
	    } else {
		set tmp($line) $qty
	    }
	}
    }

    set file [::blk::getFile $blk]
}

# coverage::highlightRanges --
#
#	Highlight either the covered or uncovered ranges, depending on
#	the value of radio(val).
#
# Arguments:
#	blk	the block in which to highlight ranges
#
# Results:
#	None.

proc coverage::highlightRanges {blk} {
    variable currentUncoverage
    variable currentCoverage
    variable hilitUncvr
    variable radio
    
    # remove any prior "*covered*" tags

    foreach tag [$code::codeWin tag names] {
	if {[regexp "covered" $tag]} {
	    $code::codeWin tag remove $tag 0.0 end
	}
    }
    
    if {$radio(val)} {

	# Find the uncovered ranges, tag them "uncovered", and
	# change their background color.

	set color yellow
	set indexList [array names currentUncoverage "${blk}:R:*"]
	foreach index $indexList {
	    set range [lindex [split $index :] 2]
	    tagRange $blk $range uncovered
	}
	$code::codeWin tag configure uncovered -background $color
    } else {

	# For each <step> times a line is covered, its intensity is
	# There are <numShades> possible intensities, and <step> must
	# be at least 2.

	variable maxRepeatedCoverage
	set numShades 20
	set step [expr int($maxRepeatedCoverage / $numShades) + 1]
	if {$step < 2} {
	    set step 2
	}

	set indexList [array get currentCoverage "${blk}:R:*"]

	# Find the covered ranges, and tag them "covered<intensity>"

	foreach {index pair} $indexList {
	    set range [lindex [split $index :] 2]
	    set intensity [expr {int([lindex $pair 1] / $step)}]
	    set intensityArray($intensity) 1
	    tagRange $blk $range "covered${intensity}"
	}

	# For each increasing intensity, darken the background color by
	# subtracting <diff> from the red and blue color values.

	set minIntensity 17 ;# min base 10 number == 2 digits in hex
	set maxIntensity 255 ;# max base 10 number == 2 digits in hex

	set diff [expr {int(($maxIntensity - $minIntensity) / $step)}]

	foreach intensity [lsort [array names intensityArray]] {

	    set shade [expr {$maxIntensity - ($intensity * $diff)}]
	    if {$shade < $minIntensity} {
		set shade $minIntensity
	    }
	    
	    # Construct a color by convertin <shade> to hex:
	    # #<shade>00<shade>

	    set shade [format "%x" $shade]
	    $code::codeWin tag configure "covered${intensity}" \
		-background "\#${shade}00${shade}" -foreground white
	}
    }
}

# coverage::init --
#
#	Set up the debugger event hooks for monitoring document status.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc coverage::init {} {
    variable coverageEnabled

    if {$coverageEnabled} {
        tool::addButton $image::image(win_cover) $image::image(win_cover) \
	    {Display the Code Coverage Window.} coverage::showWindow

	# Add an entry to the View menu.
	$menu::menu(view) insert "Connection status*" command \
		-label "Code Coverage..." \
		-command coverage::showWindow -underline 0
    }
    return
}

# coverage::resetWindow --
#
#	Reset the window to be blank, or leave a message 
#	in the text box.
#
# Arguments:
#	msg	If not empty, then put this message in the 
#		coverText text widget.
#
# Results:
#	None.

proc coverage::resetWindow {{msg {}}} {
    variable coverText
    variable coverWin
    
    if {![winfo exists $coverWin]} {
	return
    }

    $coverage::radio(cvr) configure -state disabled
    $coverage::radio(uncvr) configure -state disabled

    $coverText delete 0.0 end
    checkState $coverText
    if {$msg != {}} {
	$coverText insert 0.0 $msg
    }
}

# coverage::showCode --
#
#	This function is run when we want to display the selected
#	file in the Coverage Window.  It will interact with the
#	text box to find the selected file, find the corresponding
#	block, and tell the code window to display the file's coverage.
#
# Arguments:
#	text	The text window.
#
# Results:
#	None.

proc coverage::showCode {text} {
    variable instrumentedBlock
    variable coverText

    set state [gui::getCurrentState]
    if {$state != "running" && $state != "stopped"} {
	return
    }
    set line [sel::getCursor $text]
    if {[lsearch -exact [$text tag names $line.0] fileName] < 0} {
	return
    }

    # Get the name and block number associated with the selected file.

    set file [$text get "$line.0" "$line.0 lineend"]
    set blk $instrumentedBlock($file)

    # Show the selected block in the code window, and get the current
    # coverage from the nub.

    gui::showCode [loc::makeLocation $blk {}]
    coverage::updateWindow
}

# coverage::showWindow --
#
#	Create the Coverage Window that will display
#	all the instrumented files in the running application. 
#
# Arguments:
#	None.
#
# Results:
#	The name of the Coverage Window's toplevel.

proc coverage::showWindow {} {
    variable coverWin

    if {[winfo exists $coverWin]} {
	coverage::updateWindow
	wm deiconify $coverWin
	focus $coverage::coverText
	return $coverWin
    } else {
	coverage::createWindow
	coverage::updateWindow
	focus $coverage::coverText
	return $coverWin
    }
}

# coverage::tabulateCoverage --
#
#	Compare expected coverage with existing coverage.  Update
#	currentCoverage and currentUncoverage arrays.
#
# Arguments:
#	coverage	A list of {location numRepeatedCoverage} pairs
#			that represent the locations covered since the
#			last breakpoint.
#
# Results:
#	No value.

proc coverage::tabulateCoverage {coverage} {
    variable currentUncoverage
    variable currentCoverage
    variable maxRepeatedCoverage
    
    # For each covered location store the block number, range, line number,
    # total number of times the location was covered.

    foreach {location qty} $coverage {
	set location [lindex [split $location :] 1]
	
	set blk [::loc::getBlock $location]
	set line [::loc::getLine $location]
	set range [::loc::getRange $location]
	    
	set currentCoverage(${blk}:R:${range}) [list $line $qty]
	if {$qty > $maxRepeatedCoverage} {
	    set maxRepeatedCoverage $qty
	}
    }

    for {set blk 1} {$blk <= $blk::blockCounter} {incr blk} {

	# Optimization:  Only calculate all possible ranges if
	# currentUncoverage($blk) doesn't exist.  Once all possible
	# ranges are calculated, just un-set the ones that have been
	# covered since the last breakpoint.

	if {[info exists currentUncoverage($blk)]} {
	    foreach index [array names currentCoverage ${blk}:R:*] {
		catch {unset currentUncoverage($index)}
	    }
	} else {
	    set expectedRanges [::blk::getRanges $blk]
	    
	    # remove uninstrumented block from the array

	    if {$expectedRanges == -1} {
		clearCoverageArray $blk
		continue
	    }

	    set currentUncoverage($blk) 1
	    foreach range $expectedRanges {
		if {![info exists currentCoverage(${blk}:R:${range})]} {
		    set currentUncoverage(${blk}:R:${range}) \
			[::loc::getLine \
			     [::loc::makeLocation $blk {} $range]]
		}
	    }
	}
    }
    return
}

# coverage::tagRange --
#
#	Given a range, tag that range in the code display.
#
# Arguments:
#	blk	the block in which to tag the range
#	range	the range to tag
#	tag	the value of the tag to apply
#
# Results:
#	None.

proc coverage::tagRange {blk range tag} {
    set src   [blk::getSource $blk]
    set start [parse charindex $src $range]
    set end   [expr {$start + [parse charlength $src $range]}]
    
    set cmdStart [$code::codeWin index "0.0 + $start chars"]
    set cmdMid   [$code::codeWin index "$cmdStart lineend"]
    set cmdEnd   [$code::codeWin index "0.0 + $end chars"]

    # If cmdEnd > cmdMid, the range spans multiple lines, we only
    # want to tag the first line.
    if {[$code::codeWin compare $cmdEnd > $cmdMid]} {
	set cmdEnd $cmdMid
    }

    $code::codeWin tag add $tag $cmdStart $cmdEnd
}

# coverage::updateWindow --
#
#	Populate the Coverage Window's list box with file names
#	currently instrumented in the running app. 
#
# Arguments:
#	None.
#
# Results:
#	None.

proc coverage::updateWindow {} {
    variable coverWin
    variable instrumentedBlock
    variable coverText
    variable radio
    variable afterID

    if {![winfo exists $coverWin]} {
	return
    }

    if {[info exists afterID]} {
	after cancel $afterID
	unset afterID
    }

    # If the state is not running or stopped, then delete
    # the display and disable the "Show Code" button

    set state [gui::getCurrentState]
    if {$state != "stopped"} {
	if {$state == "running"} {
	    set afterID [after $gui::afterTime ::coverage::resetWindow]
	} else {
	    coverage::resetWindow
	}
	return
    }

    set yview  [lindex [$coverText yview] 0]
    $coverText delete 0.0 end

    # Find the unique names of the files that are instrumented.
    # Store the corresponding block number for each file in the
    # instrumentedBlock array.  Add each file to the text widget.

    foreach index [array names instrumentedBlock] {
	unset instrumentedBlock($index)
    }
    foreach {file block} [file::getUniqueFiles] {
	if {[blk::isInstrumented $block]} {
	    set instrumentedBlock($file) $block
	    $coverText insert end "$file\n" fileName 
	}
    }

    $coverage::radio(cvr) configure -state normal
    $coverage::radio(uncvr) configure -state normal
    $coverText yview moveto $yview
    coverage::checkState $coverText
    highlightRanges $gui::gui(currentBlock)

    # restore the blue or red color if one was previously present

    $code::codeWin tag configure highlight \
	-background [pref::prefGet highlight]
    $code::codeWin tag configure highlight_error \
	-background [pref::prefGet highlight_error]
}

