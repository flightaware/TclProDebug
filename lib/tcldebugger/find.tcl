# find.tcl --
#
#	This file implements the Find and Goto Windows.  The find
#	namespace and associated code are at the top portion of
#	this file.  The goto namespace and associated files are 
#	at the bottom portion of this file.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 

namespace eval find {
    # These vars are used to generalized the find command
    # in case a new window wants to use the APIs.  Currently
    # the code is not re-entrant, but small modifications will
    # fix this (only if necessary.)
    #
    # findText		The text widget to search.
    # findSeeCmd 	The see cmd for the widget or set of widgets.
    # findYviewCmd 	The yview cmd for the widget or set of widgets.

    variable findText		{}
    variable findSeeCmd		{}
    variable findYviewCmd	{}

    # These are the var that strore the history and current search
    # patterns or words.
    #
    # findBox	The handle to the combobox used to show history.
    # findList	The list of items in the history (persistent between runs)
    # findVar	The pattern/word to search for.
    
    variable findBox
    variable findList  {}
    variable findVar   {}

    # These vars are booleans for the selected search options.
    #
    # wordVar	If true match the who word only.
    # caseVar	If true perform a case sensitive search.
    # regexpVar	If true perform a regexp based search.
    # searchVar	If true search in all open documents.
    # dirVar	If true search forwards.

    variable wordVar   0
    variable caseVar   0
    variable regexpVar 1
    variable searchVar 0
    variable dirVar    1

    # These vars are used for performing incremental searches.
    # Such as searching for the next var that matches.
    # 
    # blkIndex	The index where the search will start.
    # blkList	The list of blocks to search.
    # nextBlk	An index into the blkList that points to the 
    #		next block to search.
    # startBlk	Stores where the search began to pervent infinite loops.
    # found	Array that stores previously found words.

    variable blkList  {}
    variable blkIndex 1.0
    variable nextBlk  0
    variable startBlk 0
    variable found
}

# find::showWindow --
#
#	Show the Find Window.  If it dosent exist, then create it.
#
# Arguments:
#	None.
#
# Results:
#	The toplevel handle to the Find Window.

proc find::showWindow {} {
    # If the window already exists, show it, otherwise
    # create it from scratch.

    if {[info command $gui::gui(findDbgWin)] == $gui::gui(findDbgWin)} {
	wm deiconify $gui::gui(findDbgWin)
	focus $find::findBox.e
	return $gui::gui(findDbgWin)
    } else {
	find::createWindow
	focus $find::findBox.e
	return $gui::gui(findDbgWin)
    }  
}

# find::createWindow --
#
#	Create the Find Window.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc find::createWindow {} {
    variable findBox
    variable findList

    set bd 2
    set pad 6

    set top [toplevel $gui::gui(findDbgWin)]
    ::guiUtil::positionWindow $top
    wm minsize $top 100 100
    wm resizable $top 1 0
    wm title $top "Find"
    wm transient $top $gui::gui(mainDbgWin)

    set mainFrm [frame $top.mainFrm -bd $bd -relief raised]

    set findFrm [frame $mainFrm.findFrm]
    set findLbl [label $findFrm.findLbl -text "Find What "]
    set findBox [guiUtil::ComboBox $findFrm.findBox -ewidth 10\
	    -textvariable find::findVar -listheight 1]
    for {set i [expr {[llength $findList] - 1}]} {$i >= 0} {incr i -1} {
	$findBox add [lindex $findList $i]
    }
    pack $findLbl -side left -pady $pad
    pack $findBox -side left -pady $pad -fill x -expand true

    set checkFrm [frame $mainFrm.checkFrm]
    set wordChk [checkbutton $checkFrm.wordChk \
	    -variable find::wordVar \
	    -text "Match whole word only"]
    set caseChk [checkbutton $checkFrm.caseChk \
	    -variable find::caseVar \
	    -text "Match case" ]
    set regexpChk [checkbutton $checkFrm.regexpChk \
	    -variable find::regexpVar \
	    -text "Regular expression"]
    set searchChk [checkbutton $checkFrm.searchChk \
	    -variable find::searchVar \
	    -text "Search all open documents"]
    pack $wordChk -padx $pad -anchor w
    pack $caseChk -padx $pad -anchor w
    pack $regexpChk -padx $pad -anchor w
    pack $searchChk -padx $pad -anchor w

    set dirFrm [frame $mainFrm.dirFrm -bd $bd -relief groove]
    set dirLbl [label $dirFrm.dirLbl -text "Direction"]
    set upRad  [radiobutton $dirFrm.upRad -text Up \
	    -variable find::dirVar -value 0]
    set downRad [radiobutton $dirFrm.downRad -text Down \
	    -variable find::dirVar -value 1]
    pack $dirLbl -anchor nw -padx $pad -pady $pad
    pack $upRad -anchor w
    pack $downRad -anchor w

    set findBut [button $mainFrm.findBut -text "Find Next" -default active \
	    -command {find::execute}]
    set closeBut [button $mainFrm.closeBut -text "Close" -default normal \
	    -command {destroy $gui::gui(findDbgWin)}]

    grid $findFrm  -row 0 -column 0 -sticky nwe -columnspan 2 -padx $pad
    grid $findBut  -row 0 -column 2 -sticky nwe -padx $pad -pady $pad
    grid $closeBut  -row 1 -column 2 -sticky nwe -padx $pad -pady $pad
    grid $checkFrm -row 1 -column 0 -sticky nsw
    grid $dirFrm   -row 1 -column 1 -sticky nswe -padx $pad -pady $pad
    grid columnconfigure $mainFrm 1 -weight 1
    grid rowconfigure $mainFrm 2 -weight 1
    pack $mainFrm -fill both -expand true -padx $pad -pady $pad

    set winList [list $findBox.e $wordChk $caseChk $regexpChk \
	    $searchChk $upRad $downRad $findBut $closeBut]
    foreach win $winList {
	bind::addBindTags $win findDbgWin
    }
    bind::commonBindings findDbgWin $winList
    bind findDbgWin <Return> "$findBut invoke; break"
    bind $top <Escape> "$closeBut invoke; break"
}

# find::execute --
#
#	Initialize the search based on the Code Window widgets
#	and code functions.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc find::execute {} {
    variable findBox
    variable findList
    variable findVar
    variable findText
    variable findSeeCmd
    variable findYviewCmd

    # This is a feeble attempt to generalize the find command
    # so it is not tied directly to the Code Window.  If a new
    # text widget requires the find command then it will need
    # to re-implement this function and initialize these vars.

    set findText     $code::codeWin
    set findSeeCmd   code::see
    set findYviewCmd code::yview

    # Add the new pattern to the combo box history.
    set findList [$findBox add $findVar]

    # Initialize the search data and execute the search.
    find::init
    find::next

    # Put focus back to the Code Window and remove the Find Window.
    focus $findText
    destroy $gui::gui(findDbgWin)
}

# find::init --
#
#	Initialize a find request.  This is done when "Find Next"
#	is executed in the Find Window, or when <<Dbg_FindNext>> is
#	requested on a new block.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc find::init {} {
    variable findText
    variable searchVar
    variable blkList 
    variable blkIndex
    variable nextBlk
    variable startBlk
    variable found

    # Create the list of documents to search through.  If the
    # user selected "search all open..." then the list will 
    # contain all files, otherwise it will only contain the
    # currently displayed block.

    if {$searchVar} {
	set blkList [lsort [blk::getFiles]]
	set nextBlk [lsearch $blkList [gui::getCurrentBlock]]
	if {$nextBlk < 0} {
	    set nextBlk 0
	}
    } else {
	set blkList [gui::getCurrentBlock]
	set nextBlk 0
    }

    # Start the search from the index of the insert cursor
    # in the Code Win.

    set blkIndex [$findText index "insert + 1c"]

    # Cache this index into the blkList so we know when
    # to stop looping in the find::next function.

    set startBlk $nextBlk

    # If there is data for found matches, remove them and 
    # start searching fresh.

    if {[info exists found]} {
	unset found
    }
}

# find::nextOK --
#
#	Determine if data has been initialized so that 
#	find next will execute.
#
# Arguments:
#	None.
#
# Results:
#	Boolean, true is find next can be called.

proc find::nextOK {} {
    return [expr {$find::findText != {}}]
}

# find::next --
#
#	Find the next match.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc find::next {} {
    variable findText
    variable dirVar   
    variable searchVar
    variable blkList 
    variable blkIndex
    variable nextBlk
    variable startBlk
    variable found
    variable findSeeCmd
    variable findYviewCmd

    # If the two blocks are different, then re-initialize the search
    # variables to start the search from this block and index.

    if {[lindex $blkList $nextBlk] != [gui::getCurrentBlock]} {
	find::init
    }

    # Short circut if we cannot find a match in this document and
    # we are not searching all open documents.

    set range [find::search]
    if {($range == {}) && ($searchVar == 0)} {
	return
    }

    # We are searching multiple documents, loop through the open
    # documents and try to find a match.  When the while loop is
    # entered, a new block may be loaded into the text widget so
    # we can perform text-based seraches.  If no match is found 
    # we want to restore the code display to its original state. 
    # Store this state.

    set thisBlk      [gui::getCurrentBlock]
    set restoreBlk   $thisBlk
    set restoreView  [lindex [$findText yview] 0]
    set restoreRange [$findText tag nextrange highlight 1.0 end]

    # Loop until range has a value that was not already an existing
    # match.  If the nextBlk equals the startBlk and range is an
    # empty string, then we cannot find a match in any documents.
    # In this case we will also break the loop.

    while {$range == {} || [info exists found($range,$thisBlk)]} {
	# Get the next block from the list of open blocks.
	# If the next block is the same as when we started,
	# (determined in find::init) then unset any found
	# data and continue.

	incr nextBlk 
	if {$nextBlk >= [llength $blkList]} {
	    set nextBlk 0
	}
	if {$nextBlk == $startBlk} {
	    bell
	    if {[info exists found]} {
		unset found
	    }
	    if {$range == {}} {
		break
	    }
	}

	# If we have a valid new block, bring that block into the
	# Code Window's text widget so we can perform text based
	# searches.  

	set thisBlk [lindex $blkList $nextBlk]
	if {$thisBlk != [gui::getCurrentBlock]} {
	    set loc [loc::makeLocation $thisBlk {}]
	    gui::showCode $loc
	}
	
	# Reset the starting search index and search the new block.
	if {$dirVar} {
	    set blkIndex 1.0
	} else {
	    set blkIndex end
	}
	set range [find::search]
    }

    if {$range != {}} {
	# Add this range and block to the found index so we know
	# when we looped searching in this block.

	set found($range,$thisBlk) 1
	set start [lindex $range 0]
	set end   [lindex $range 1]

	if {$dirVar} {
	    # Searching Forwards
	    set blkIndex [$findText index $end]
	} else {
	    # Searching Backwards
	    set blkIndex [$findText index "$start - 1c"]
	}	

	# Add the selection tag to the matched string, move the 
	# insertion cursor to this location and call the code:see
	# routine that lines up all of the code text widgets to 
	# the same view region.

	$findText tag remove sel  0.0 end
	$findText tag add sel $start $end
	$findText mark set insert $start
	$findSeeCmd $start
    } elseif {$restoreBlk != {}} {
	# Restore the original block, highlight the text,
	# reset the insertion cursor and view the region.

	gui::showCode [loc::makeLocation $restoreBlk {}]
	$findYviewCmd moveto $restoreView
	if {$restoreRange != {}} {
	    eval {$findText tag add highlight} $restoreRange
	    $findText mark set insert [lindex $restoreRange 0]
	}
    }
    focus $findText
    return
}

# find::search --
#
#	Search the Code Window to find a match.
#
# Arguments:
#	None.
#
# Results:
#	A range into the text widget with the start and 
#	end index of the match, or empty string if no
#	match was found.

proc find::search {} {
    variable findText
    variable findVar
    variable wordVar
    variable caseVar
    variable regexpVar
    variable dirVar   
    variable blkIndex

    if {$caseVar} {
	set nocase ""
    } else {
	set nocase "-nocase"
    }
    if {$regexpVar} {
	set match "-regexp"
    } else {
	set match "-exact"
    }
    if {$dirVar} {
	set dir "-forwards"
    } else {
	set dir "-backwards"
    }

    # Try to find the next match in this block.  The value of
    # index is the first char that matches the pattern or 
    # empty string if no match was found.  If a match was
    # found, then the var "numChars" will be set with the 
    # number of chars that matched.

    set index [eval "$findText search $dir $match $nocase \
	    -count numChars --  [list $findVar] $blkIndex"]

    if {$index != {}} {
	set start $index
	set end   "$index + ${numChars}c"
	if {[find::wholeWordMatch $start $end]} {
	    return [list $start $end]
	}
    }
    return {}
}

# find::wholeWordMatch --
#
#	If "Match whole word..." was selected determine if the
#	the current selection actually matched the whole word.
#
# Arguments:
#	start	The starting index of the match.
#	end	The ending index of the match.
#
# Results:
#	Boolean, true if the string matches the whole word or
#	the option was not selected.

proc find::wholeWordMatch {start end} {
    variable wordVar
    variable findText

    # Match only the whole word.  If the index for the
    # end of the word is greater than the end index of
    # the search result, then the match failed.  Call
    # find::next to search further.
    
    if {$wordVar} {
	set wordEnd "$start wordend"
	if {[$findText compare $wordEnd > $end]} {
	    return 0
	}
    }
    return 1
}

namespace eval goto {
    # Handles to the Goto Window's widgets.

    variable choiceVar
    variable lineEnt
    variable gotoBut

    # The selected option in the combobox.
    variable choiceVar

    # The list of goto option in the choice combobox.

    variable gotoOptions  [list "Move Up Lines" "Move Down Lines" "Goto Line"]
}

# goto::showWindow --
#
#	Show the Goto Window.  If it dosent exist, then create it.
#
# Arguments:
#	None.
#
# Results:
#	The toplevel handle to the Goto Window.

proc goto::showWindow {} {
    # If the window already exists, show it, otherwise
    # create it from scratch.

    if {[info command $gui::gui(gotoDbgWin)] == $gui::gui(gotoDbgWin)} {
	wm deiconify $gui::gui(gotoDbgWin)
	focus $goto::lineEnt
	return $gui::gui(gotoDbgWin)
    } else {
	goto::createWindow
	focus $goto::lineEnt
	return $gui::gui(gotoDbgWin)
    }
}

# goto::createWindow --
#
#	Create the Goto Window.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc goto::createWindow {} {
    variable gotoOptions 
    variable choiceVar
    variable choiceBox
    variable lineEnt
    variable gotoBut

    set bd 2
    set pad 6

    set top [toplevel $gui::gui(gotoDbgWin)]
    ::guiUtil::positionWindow $top
    wm resizable $top 0 0
    wm title $top "Goto"
    wm transient $top $gui::gui(mainDbgWin)

    set mainFrm [frame $top.mainFrm -bd $bd -relief raised]

    set choiceLbl [label $mainFrm.choiceLbl -text "Goto what"]
    set lineLbl   [label $mainFrm.lineLbl -text "Enter line number" \
	    -textvariable goto::lineVar]
    set choiceBox [guiUtil::ComboBox $mainFrm.choiceBox -listheight 3 \
	    -textvariable goto::choiceVar -strict 1 -ewidth 15 \
	    -command {goto::updateLabels}]
    foreach choice $gotoOptions {
	$choiceBox add $choice
    }
    set choiceVar [lindex $gotoOptions end]
    set lineEnt [entry $mainFrm.lineEnt]
    set placeFrm [frame $mainFrm.placeFrm]
    set gotoBut [button $placeFrm.gotoBut -text $choiceVar -default active \
	    -command {goto::execute} -width 10]
    set closeBut [button $placeFrm.closeBut -text Close -default normal\
	    -command {destroy $gui::gui(gotoDbgWin)} -width 10]

    grid $gotoBut   -row 0 -column 0 -sticky w -padx $pad
    grid $closeBut  -row 0 -column 1 -sticky w -padx $pad
    grid rowconfigure $placeFrm 0 -weight 1

    grid $choiceLbl -row 0 -column 0 -sticky nw -padx $pad -pady $pad
    grid $lineLbl   -row 0 -column 1 -sticky nw -pady $pad
    grid $choiceBox -row 1 -column 0 -sticky w -padx $pad 
    grid $lineEnt   -row 1 -column 1 -sticky we
    grid $placeFrm  -row 2 -column 0 -columnspan 2 -padx $pad -pady $pad
    grid columnconfigure $mainFrm 1 -weight 1
    grid rowconfigure $mainFrm 2 -weight 1
    pack $mainFrm -fill both -expand true -padx $pad -pady $pad 

    bind::addBindTags $choiceBox.e gotoDbgWin
    bind::addBindTags $lineEnt     gotoDbgWin
    bind::addBindTags $gotoBut     gotoDbgWin
    bind::commonBindings gotoDbgWin [list $choiceBox $lineEnt \
	    $gotoBut $closeBut]

    bind gotoDbgWin <Return> "$gotoBut invoke; break"
    bind gotoDbgWin <Escape> "$closeBut invoke; break"

    bind gotoDbgWin <Up> {
	goto::changeCombo -1 
    }
    bind gotoDbgWin <Down> {
	goto::changeCombo 1 
    }
}

# goto::updateLabels --
#
#	Make the button label and line label consistent 
#	with the current goto option.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc goto::updateLabels {} {
    variable gotoOptions
    variable choiceVar
    variable lineVar
    variable gotoBut

    set option [lsearch $gotoOptions $choiceVar]
    switch $option {
	0 {
	    # Move up lines.
	    $gotoBut configure -text "Move Up"	    
	    set lineVar "Number of lines"
	}
	1 {
	    # Move down lines.
	    $gotoBut configure -text "Move Down"	    
	    set lineVar "Number of lines"
	}
	2 {
	    # Goto line.
	    $gotoBut configure -text "Goto Line"
	    set lineVar "Enter line number"
	}
    }
}

# goto::execute --
#
#	Execute the goto request.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc goto::execute {} {
    variable gotoOptions
    variable choiceVar
    variable lineEnt
    variable gotoBut

    if {[gui::getCurrentBlock] == {}} {
	bell -displayof $gui::gui(gotoDbgWin)
	return
    }

    # Get the line number and verify that it is numeric.

    set line [$lineEnt get]
    if {$line == ""} {
	return
    }

    set end [code::getCodeSize]
    if {[catch {incr line 0}]} {
	if {$line == "end"} {
	    set line $end
	} else {
	    bell -displayof $gui::gui(gotoDbgWin)
	    $lineEnt delete 0 end
	    return
	}
    }

    set option [lsearch $gotoOptions $choiceVar]
    switch $option {
	0 {
	    # Move up lines.
	    set start  [code::getInsertLine]
	    set moveTo [expr {$start - $line}]
	    if {$moveTo > $end} {
		set moveTo $end
	    }
	    set loc [code::makeCodeLocation $code::codeWin $moveTo.0]
	}
	1 {
	    # Move down lines.
	    set start  [code::getInsertLine]
	    set moveTo [expr {$start + $line}]
	    if {$moveTo > $end} {
		set moveTo $end
	    }
	    set loc [code::makeCodeLocation $code::codeWin $moveTo.0]
	}
	2 {
	    # Goto line.
	    if {$line > $end} {
		set line $end
	    }
	    set loc [code::makeCodeLocation $code::codeWin $line.0]
	}
    }
    gui::showCode $loc
}

# goto::changeCombo --
#
#	Callback to cycle the choice in the combobox.
#
# Arguments:
#	amount	The number of choice to increment.
#
# Results:
#	None.

proc goto::changeCombo {amount} {
    variable gotoOptions
    variable choiceVar
    variable choiceBox

    set index [expr {[lsearch $gotoOptions $choiceVar] + $amount}]
    set length [llength $gotoOptions]
    if {$index < 0} {
	set index [expr {$length - 1}]
    } elseif {$index >= $length} {
	set index 0
    }
    $choiceBox set [lindex $gotoOptions $index]
}

