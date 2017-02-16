# hiqState.tcl --
#
#    This file contains procedures that change the state of the game board.
#
# Copyright (c) 1996 Dartmouth College
# Copyright (c) 1998 Scriptics Corporation
# See the file "license.terms" for information on usage and redistribution of this file.
#
# RCS: @(#) $Id: hiqState.tcl,v 1.2 2000/10/31 23:31:09 welch Exp $


# start_game --
#
proc start_game {w {restart 0}} {
    global list_of_moves

    initialize_board

    # delete old pegs and holes
    if {$restart} {
	global msg

	$w delete peg
	$w delete hole
	new_message $w "-----------RESTARTING GAME-----------"
	update
	after 2000 "new_message $w {restarted game}"	  
	vwait msg
    } else {
	new_message $w "started new game"
    }
    
    # create pegs and holes
    create_pegs_and_holes $w 0 240 40

    # all pegs become visible except the top of the pyramid
    $w raise peg
    $w delete peg(0,0)
    
    # reinitialize the list of moves
    set list_of_moves {}
}

# initialize_board --
#
proc initialize_board {} {
    global board

    # the board is full except the top hole
    for {set col 0} {$col < 5} {incr col} {
	for {set row 0} {$row <= $col} {incr row} {
	    set board($col,$row) 1
	}
    }
    set board(0,0) 0
}

# move_peg --
#
proc move_peg {oldx oldy newx newy} {
    global board

    # if the peg jumped into a full hole, return ""
    if {$board($newx,$newy) == 1} {
	return ""
    }
    # if the peg was not moved a valid distance, return ""
    if {[correct_distance [expr {$newx - $oldx}] \
	     [expr {$newy - $oldy}]] == 0} {
	return ""
    }
    # if the peg jumped over an empty hole, return ""
    set avgx [expr {($oldx + $newx) / 2}]
    set avgy [expr {($oldy + $newy) / 2}]
    if {$board($avgx,$avgy) == 0} {
	return ""
    }
    # remove the old piece
    set board($oldx,$oldy) 0
    # add the new piece
    set board($newx,$newy) 1
    # remove the piece in between the new and old pieces
    set board($avgx,$avgy) 0
    
    set game_is_over [find_new_moves]
    
    # return x and y coords of peg to remove and game_is_over bool
    return "$avgx $avgy $game_is_over"
}

# unmove_peg --
#
proc unmove_peg {oldx oldy newx newy midx midy} {
    global board

    # add the old piece
    set board($oldx,$oldy) 1
    # remove the new piece
    set board($newx,$newy) 0
    # add the piece in between the new and old pieces
    set board($midx,$midy) 1
}

# find_new_moves --
#
proc find_new_moves {} {
    global board
    
    # for each peg,
    for {set pcol 0} {$pcol < 5} {incr pcol} {
	for {set prow 0} {$prow <= $pcol} {incr prow} {
	    if {$board($pcol,$prow)} {
		# for each hole,
		for {set hcol 0} {$hcol < 5} {incr hcol} {
		    for {set hrow 0} {$hrow <= $hcol} {incr hrow} {
			if {!$board($hcol,$hrow)} {
			    set coldiff [expr {$pcol - $hcol}]
			    set rowdiff [expr {$prow - $hrow}]
			    set dist [correct_distance $coldiff $rowdiff]
			    set colavg [expr {($pcol + $hcol) / 2}]
			    set rowavg [expr {($prow + $hrow) / 2}]
			    if {$dist && $board($colavg,$rowavg)} {
				return 0
			    }
			}
		    }
		}
	    }
	}
    }
    return 1
}

# correct_distance --
#
proc correct_distance {xdiff ydiff} {

    set abs_xdiff [expr {abs($xdiff)}]
    set abs_ydiff [expr {abs($ydiff)}]

    # moving horizontally, or
    if {($abs_xdiff == 2) && ($ydiff == 0)} {return 1}
    
    # moving southwest or northeast, or
    if {($xdiff == 0) && ($abs_ydiff == 2)} {return 1}
    
    # moving northwest or southeast
    if {$xdiff == $ydiff && $abs_xdiff == 2} {return 1}
    
    return 0
}

# undo_move --
#
proc undo_move {w} {
    global list_of_moves color
    
    set moves [llength $list_of_moves]
  
    if {!$moves} {
	new_message $w "no moves to be undone"
	return
    }

    incr moves -1
    set move_to_undo [lindex $list_of_moves $moves]
    set oldrow [lindex $move_to_undo 0]
    set oldcol [lindex $move_to_undo 1]
    set newrow [lindex $move_to_undo 2]
    set newcol [lindex $move_to_undo 3]
    set midrow [lindex $move_to_undo 4]
    set midcol [lindex $move_to_undo 5]

    # change the peg's tag to reflect the undone move
    $w addtag peg($oldrow,$oldcol) withtag peg($newrow,$newcol)
    $w dtag peg($newrow,$newcol) peg($newrow,$newcol)

    # move the peg from new to old
    set old_coords [$w coords hole($oldrow,$oldcol)]
    eval "$w coords peg($oldrow,$oldcol) $old_coords"

    # add the peg that was jumped over
    set jumped_coords [$w coords hole($midrow,$midcol)]
    newMessage $w "$move_to_undo, $jumped_coords"
    $w create oval [lindex $jumped_coords 0] [lindex $jumped_coords 1] \
	[lindex $jumped_coords 2] [lindex $jumped_coords 3] \
	-fill $color(peg) -outline $color(hole) \
	-tags "peg peg($midrow,$midcol)"

    # record the changes to the board
    eval "unmove_peg $move_to_undo"
    
    # remove the move from the list of moves
    set list_of_moves [lreplace $list_of_moves $moves $moves] 
  
    new_message $w "undid one move"
}

# new_message --
#
#    update message at the bottom of the GUI
#
proc new_message {w string} {
    global msg

    $w itemconfigure message -text $string
    set msg 1
}

