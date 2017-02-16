# hiqGUI.tcl --
#
#    GUI code for the Hi-Q game.  This file creates the game board window.
#
# Copyright (c) 1996 Dartmouth College
# Copyright (c) 1998 Scriptics Corporation
# See the file "license.terms" for information on usage and redistribution of this file.
#
# RCS: @(#) $Id: hiqGUI.tcl,v 1.2 2000/10/31 23:31:09 welch Exp $

# pop-up_main_window --
#
proc pop_up_main_window {} {
    global color

    frame .hiq -borderwidth 10 -bg $color(bg) \
	-highlightbackground $color(bg) -highlightcolor $color(bg) ;
  
    set w .hiq.board

    # create hiq board
    canvas $w -height 400 -width 500 -background $color(canvas-bg) \
	-relief groove -highlightt 0

    # create a button frame
    frame .hiq.butt_frame -borderwidth 5 -bg $color(bg) \
	-highlightbackground $color(bg) -highlightcolor $color(bg) ;
  
    # create a restart button
    button .hiq.butt_frame.restart -text "Restart" -command "start_game $w 1" \
	-fg $color(button-fg) -activeforeground $color(button-fg) \
	-bg $color(button-bg) -activebackground $color(button-bg) \
	-highlightthickness 0

    # create an undo button
    button .hiq.butt_frame.undo -text "Undo" -command "undo_move $w" \
	-fg $color(button-fg) -activeforeground $color(button-fg) \
	-bg $color(button-bg) -activebackground $color(button-bg) \
	-disabledforeground $color(button-fg) -state disabled \
	-highlightthickness 0
    
    pack $w
    focus $w
    pack .hiq.butt_frame.restart -side left -padx 5
    pack .hiq.butt_frame.undo -side left -padx 5
    pack .hiq.butt_frame
    pack .hiq

    # draw the triangle
    $w create polygon 0 360 250 0 500 360 -fill $color(canvas-fg)
    
    # create a message object
    $w create text 250 385 -fill $color(fg) -tags message
    
    return $w
}

# CanvasMark --
#

proc CanvasMark {w x y tag} {
    global current_peg
    
    new_message $w ""
    $w raise $tag

    set current_peg(oldx) $x
    set current_peg(oldy) $y
    
    set current_peg(x) $x
    set current_peg(y) $y
}

# CanvasDrag --
#

proc CanvasDrag {w x y tag} {
    global current_peg

    $w move $tag [expr {$x - $current_peg(x)}] [expr {$y - $current_peg(y)}]
    set current_peg(x) $x
    set current_peg(y) $y
}

# CanvasDrop --
#

proc CanvasDrop {w x y row column} {
    global current_peg list_of_moves

    set hole_was_found 0
  
    foreach num [$w find enclosed \
		     [expr {$x - 30}] [expr {$y - 30}] \
		     [expr {$x + 30}] [expr {$y + 30}]] {
	
	set taglist [$w gettags $num]

	if {[lsearch $taglist "hole"] >= 0} {
	    set newrow [lindex $taglist 1]
	    set newcolumn [lindex $taglist 2]

	    # find the coordinates of the hole
	    set hole_coords [$w coords $num]
	    set hole_was_found 1
	    break
	}
    }
  
    # if no hole was found, then error
    if {!$hole_was_found} {
	new_message $w "peg is not over a hole"
	replace_peg $w peg($row,$column) $x $y
	return
    }

    # if user made an illegal move, then error
    set answer [move_peg $row $column $newrow $newcolumn]
    if {$answer == ""} {
	new_message $w "illegal move"
	replace_peg $w peg($row,$column) $x $y
	return
    }  
    
    # center the peg over the new hole
    eval "$w coords peg($row,$column) $hole_coords"
    
    # change the peg's tag to reflect the move
    $w addtag peg($newrow,$newcolumn) withtag peg($row,$column)
    $w dtag peg($newrow,$newcolumn) peg($row,$column)
    
    # remove the peg that was jumped over
    set midrow [lindex $answer 0]
    set midcolumn [lindex $answer 1]
    $w delete peg($midrow,$midcolumn)
    
    # add this move to the list of moves
    lappend list_of_moves \
	[list $row $column $newrow $newcolumn $midrow $midcolumn]
    
    # if game is over, unbind all pegs
    if {[lindex $answer 2]} {
	unbind_all_pegs $w
	set tally [llength [$w find withtag "peg"]]
	if {$tally == 1} {
	    new_message $w "Game over!  You won!!!"
	} else {
	    new_message $w "Game over!  You have $tally pegs left."
	}
    }
}

# replace_peg --
#
#    put the peg back where it came from
#
proc replace_peg {w tag x y} {
    global current_peg

    $w move $tag [expr {$current_peg(oldx) - $x}] \
	[expr {$current_peg(oldy) - $y}]
}
		    
# bind_peg --
#
proc bind_peg {w row column tag} {
    global color

    .hiq.butt_frame.undo configure -state normal -bg $color(button-bg)
    
    $w bind $tag <ButtonPress-1> "CanvasMark $w %x %y $tag"
    $w bind $tag <B1-Motion> "CanvasDrag $w %x %y $tag"
    $w bind $tag <ButtonRelease-1> "CanvasDrop $w %x %y $row $column"
}

# unbind_all_pegs --
#
proc unbind_all_pegs {w} {
    global color

    .hiq.butt_frame.undo configure -state disabled -bg $color(button-mute)
    
    foreach num [$w find withtag "peg"] {

	set tag [lindex [$w gettags $num] 1]

	$w bind $tag <ButtonPress-1> {}
	$w bind $tag <B1-Motion> {}
	$w bind $tag <ButtonRelease-1> {}
    }
}

# create_pegs_and_holes --
#
#    add holes to the board
#    add pegs to the board (over the wholes)
#    bind click-and-drag for each peg
#
proc create_pegs_and_holes {w row x y} {
    global color

    for {set column 0; set horiz $x} {$column <= $row} \
	{incr column; incr horiz 100} {

	    $w create oval $horiz $y [expr {$horiz + 20}] [expr {$y + 20}] \
		-fill $color(hole) -outline $color(hole) \
		-tags "hole $row $column hole($row,$column)"

	    $w create oval $horiz $y [expr {$horiz + 20}] [expr {$y + 20}] \
		-fill $color(peg) -outline $color(hole) \
		-tags "peg peg($row,$column)"

	    bind_peg $w $row $column peg($row,$column)
	}
    if {$row < 4} {

	create_pegs_and_holes $w [expr {$row + 1}] \
	    [expr {$x - 50}] [expr {$y + 70}]
    }
}
