# hiq.tcl --
#
#    Main code for the Hi-Q game.  This file initializes the global variables
#    and sources other code files.
#
# Copyright (c) 1996 Dartmouth College
# Copyright (c) 1998 Scriptics Corporation
# See the file "license.terms" for information on usage and redistribution of this file.
#
# RCS: @(#) $Id: hiq.tcl,v 1.2 2000/10/31 23:31:09 welch Exp $


# "color" is an associative array which we use to abstract away the font
#         and color attributes of all tk widgets.

set color(bg) white
set color(fg) black
set color(button-bg) steelblue
set color(button-mute) lightsteelblue
set color(button-fg) white
set color(canvas-bg) white
set color(canvas-fg) steelblue
set color(peg) pink
set color(hole) black
set color(fontsize) 24
set color(font) -*-helvetica-medium-r-*-*-24-*-*-*-*-*-*-*
#set color(fontsize) 14
#set color(font) -adobe-courier-medium-r-*-*-14-*-*-*-*-*-*-*

# source the other files...

source hiqGUI.tcl
source hiqState.tcl

# pop up the main window & start the game

set board_obj [pop_up_main_window]
start_game $board_obj
