# guiUtil.tcl --
#
#	Utility procedures for the debugger GUI.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 

package provide guiUtil 1.0
namespace eval guiUtil {
    # This array is used by the Pane and Table commands
    # to preserve and restore the geometry of the pane
    # or table between sessions.  The procs: 
    # guiUtil::savePaneGeometry and guiUtil::restorePaneGeometry
    # preserve the data in the prefs Default group between 
    # sessions.

    variable paneGeom
}


#-----------------------------------------------------------------------------
# Sliding Panel Procedures
#-----------------------------------------------------------------------------

# guiUtil::paneCreate --
#
#	Create a sliding pane between two frames.
#
# Arguments:
#	frm1	-
#	frm2 	Frames to create the pane between.
#	args	Optional argument that override the defaults.
#		-orient	  The orientation of the sliding pane.
#			  vertical   - slides left and right.
#			  horizontal - slides up and down.
#		-percent  Split between the two frames.
#		-in       The parent window to pack the frames into.
#
# Results: 
#	None.

proc guiUtil::paneCreate {frm1 frm2 args} {
    variable paneGeom

    # Map optional arguments into array values
    set t(-orient) vertical
    set t(-percent) 0.5
    set t(-in) [winfo parent $frm1]
    array set t $args

    # Keep state in an array associated with the master frame
    set master $t(-in)
    if {[info exists paneGeom($master)]} {
	set t(-percent) $paneGeom($master)
    }
    upvar #0 Pane$master pane
    array set pane [array get t]

    # Create the grip and set placement attributes that
    # will not change. A thin divider line is achieved by
    # making the two frames one pixel smaller in the
    # adjustable dimension and making the main frame black.

    set pane(1) $frm1
    set pane(2) $frm2
    if {[string match vert* $pane(-orient)]} {
	# Adjust boundary in Y direction (split top & bottom)
	set pane(D) Y		
	place $pane(1) -in $master -x 0 -rely 0.0 -anchor nw \
		-relwidth 1.0 -height -2
	place $pane(2) -in $master -x 0 -rely 1.0 -anchor sw \
		-relwidth 1.0 -height -2
	set pane(grip) [frame $master.grip -width 2 \
		-bd 3 -relief raised -cursor sb_v_double_arrow -height 2]
	set pane(bg) [$pane(grip) cget -bg]
    } else {
	# Adjust boundary in X direction (split left & right)
	set pane(D) X 		
	place $pane(1) -in $master -relx 0.0 -y 0 -anchor nw \
		-relheight 1.0 -width -2
	place $pane(2) -in $master -relx 1.0 -y 0 -anchor ne \
		-relheight 1.0 -width -2
	set pane(grip) [frame $master.grip -width 2 \
		-bd 3 -relief raised -cursor sb_h_double_arrow -width 2]
	set pane(bg) [$pane(grip) cget -bg]
    }

    # Set up bindings for resize, <Configure>, and 
    # for dragging the grip.

    bind $master <Configure> [list guiUtil::paneGeometry $master]
    bind $pane(grip) <ButtonPress-1> \
	    [list guiUtil::paneDrag $master %$pane(D)]
    bind $pane(grip) <B1-Motion> \
	    [list guiUtil::paneDrag $master %$pane(D)]
    bind $pane(grip) <ButtonRelease-1> \
	    [list guiUtil::paneStop $master]

    # Do the initial layout

    guiUtil::paneGeometry $master
}

# guiUtil::paneDrag --
#
#	Slides the panel in one direction based on the orientation.
#
# Arguments:
#	master	The parent window that contains both the sub frames.
#	D	???
#
# Results: 
#	None.

proc guiUtil::paneDrag {master D} {
    upvar #0 Pane$master pane
    if {[info exists pane(lastD)]} {
	set delta [expr {double($pane(lastD) - $D) / $pane(size)}]
	set percent [expr {$pane(-percent) - $delta}]
	set setPercent 1
	set grip 0

	if {$percent < 0.0} {
	    set setPercent 0
	    set grip 4
	    set percent 0.0
	} elseif {$percent > 1.0} {
	    set setPercent 0
	    set grip -4
	    set percent 1.0
	}
	if {$pane(D) == "X"} {
	    $pane(grip) configure -width 4 -bg grey25
	    place $pane(grip) -relheight 1.0 -x $grip -relx $percent
	} else {
	    $pane(grip) configure -height 4 -bg grey25
	    place $pane(grip) -relwidth 1.0 -y $grip -rely $percent
	}
	if {!$setPercent} {
	    return
	}
	set pane(-percent) $percent
    }
    set pane(lastD) $D
}

# guiUtil::paneStop --
#
#	Releases the hold on the sliding panel.
#
# Arguments:
#	master	The parent window that contains both the sub frames.
#
# Results: 
#	None.

proc guiUtil::paneStop {master} {
    upvar #0 Pane$master pane
    guiUtil::paneGeometry $master
    catch {unset pane(lastD)}
    if {$pane(D) == "X"} {
	$pane(grip) configure -width 2 -bg $pane(bg)

    } else {
	$pane(grip) configure -height 2 -bg $pane(bg)
    }
}

# guiUtil::paneGeometry
#
#	Sets the geometry of the sub frames???
#
# Arguments:
#	master	The parent window that contains both the sub frames.
#
# Results: 
#	None.

proc guiUtil::paneGeometry {master} {
    upvar #0 Pane$master pane
    if {$pane(D) == "X"} {
	place $pane(1)    -relwidth $pane(-percent)
	place $pane(grip) -relx $pane(-percent) -relheight 1.0 -x -1 
	place $pane(2)    -relwidth [expr {1.0 - $pane(-percent)}] -x 2
	set pane(size) [winfo width $master]
    } else {
	place $pane(1)    -relheight $pane(-percent)
	place $pane(grip) -rely $pane(-percent) -relwidth 1.0
	place $pane(2)    -relheight [expr {1.0 - $pane(-percent)}]
	set pane(size) [winfo height $master]
    }
    set guiUtil::paneGeom($master) $pane(-percent)
}

#-----------------------------------------------------------------------------
# Table Procedures
#-----------------------------------------------------------------------------

# guiUtil::tableCreate --
#
#	Create a sliding pane between two frames.
#
# Arguments:
#	frm1	-
#	frm2 	Frames to create the pane between.
#	args	Optional argument that override the defaults.
#		-orient	  The orientation of the sliding pane.
#			  vertical   - slides left and right.
#			  horizontal - slides up and down.
#		-percent  Split between the two frames.
#		-in       The parent window to pack the frames into.
#
# Results: 
#	None.

proc guiUtil::tableCreate {master frm1 frm2 args} {

    # Map optional arguments into array values
    set t(-percent) 0.5
    set t(-title1) ""
    set t(-title2) ""
    set t(-justify) left
    array set t $args
    if {[info exists guiUtil::paneGeom($master)]} {
	set t(-percent) $guiUtil::paneGeom($master)
    }

    # Keep state in an array associated with the master frame.
    upvar #0 Pane$master pane
    array set pane [array get t]
    
    $master configure -bd 2 -relief sunken
    # Create sub frames that contain the title bars and  windows.
    set title [frame $master.title] 
    set wins  [frame $master.wins]

    # Create the first pane with a title bar and the embedded 
    # window.  

    set pane(1) $frm1
    set pane(t1) [label $title.title0  -relief raised -bd 2 \
	    -text $pane(-title1) -justify $pane(-justify) \
	    -anchor w -padx 6]

    # Get the font height and re-configure the title bars
    # frame height.

    set fontHeight [lindex [font metrics [$pane(t1) cget -font]] 5]
    set lblHeight  [expr {int($fontHeight * 1.5)}]
    $title    configure -height $lblHeight

    place $pane(t1) -in $title -relx 0.0 -y 0 -anchor nw \
	    -height $lblHeight -relwidth 1.0
    place $pane(1) -in $wins -relx 0.0 -y 0 -anchor nw \
	    -relheight 1.0 -relwidth 1.0
    raise $pane(1) 


    # If there are two sub windows, create the grip to slide
    # the widows vertically and add the bindings.

    if {$frm2 != {}} {
	set pane(2) $frm2
	set pane(t2) [label $title.title1  -relief raised -bd 2 \
		-text $pane(-title2) -justify $pane(-justify) \
		-anchor w -padx 6]	
	set pane(grip) [frame $title.grip -bg gray50 \
		-bd 0 -cursor sb_h_double_arrow -width 2]
	place $pane(t2) -in $title -relx 1.0 -y 0 -anchor ne \
		-height $lblHeight -relwidth 0.5
	place $pane(2) -in $wins -relx 1.0 -y 0 -anchor ne \
		-relheight 1.0 -relwidth 0.5
	raise $pane(2)
	
	# Set up bindings for resize, <Configure>, and 
	# for dragging the grip.
	
	bind $pane(grip) <ButtonPress-1> \
		[list guiUtil::tableDrag $master %X]
	bind $pane(grip) <B1-Motion> \
		[list guiUtil::tableDrag $master %X]
	bind $pane(grip) <ButtonRelease-1> \
		[list guiUtil::tableStop $master]
	bind $master <Configure> [list guiUtil::tableGeometry $master]
	
	guiUtil::tableGeometry $master
    }

    pack $master  -fill both -expand true -padx 2
    pack $title -fill x
    pack $wins  -fill both -expand true
    
    pack propagate $master off
    pack propagate $title off
    pack propagate $wins off
}

# guiUtil::tableDrag --
#
#	Slides the panel in one direction based on the orientation.
#
# Arguments:
#	master	The parent window that contains both the sub frames.
#	D	???
#
# Results: 
#	None.

proc guiUtil::tableDrag {master x} {
    upvar #0 Pane$master pane
    if {[info exists pane(lastX)]} {
	set delta [expr {double($pane(lastX) - $x) \
		/ $pane(size)}]
	set percent [expr {$pane(-percent) - $delta}]
	set setPercent 1
	set grip 0
	if {$percent < 0.0} {
	    set setPercent 0
	    set grip 0
	    set percent 0.0
	} elseif {$percent > 1.0} {
	    set setPercent 0
	    set grip -4
	    set percent 1.0
	}
	$pane(grip) configure -width 4 -bg grey25
	place $pane(grip) -relheight 1.0 -x $grip -relx $percent
	if {!$setPercent} {
	    return
	}
	set pane(-percent) $percent
    }
    set pane(lastX) $x
}

# guiUtil::tableStop --
#
#	Releases the hold on the sliding panel.
#
# Arguments:
#	master	The parent window that contains both the sub frames.
#
# Results: 
#	None.

proc guiUtil::tableStop {master} {
    upvar #0 Pane$master pane
    guiUtil::tableGeometry $master
    catch {unset pane(lastX)}
    $pane(grip) configure -width 2 -bg gray50
}

# guiUtil::tableGeometry
#
#	Sets the geometry of the sub frames???
#
# Arguments:
#	master	The parent window that contains both the sub frames.
#
# Results: 
#	None.

proc guiUtil::tableGeometry {master} {
    upvar #0 Pane$master pane

    # Prevent loosing the grip if the percent is virtually
    # zero.  Otherwise place the grip off by two pixels for
    # aesthetics.
 
    place $pane(t1)   -width -2 -relwidth $pane(-percent)
    place $pane(1)    -relwidth $pane(-percent)
    if {$pane(-percent) < 0.01} {
	place $pane(grip) -relx $pane(-percent) -relheight 1.0
	place $pane(t2)   -relwidth [expr {1.0 - $pane(-percent)}]
	place $pane(2)    -relwidth [expr {1.0 - $pane(-percent)}]
    } else {
	place $pane(grip) -x -2 -relx $pane(-percent) -relheight 1.0
	place $pane(t2)   -x -2 -relwidth [expr {1.0 - $pane(-percent)}]
	place $pane(2)    -x -2 -relwidth [expr {1.0 - $pane(-percent)}]
    }

    set pane(size) [winfo width $master]
    set guiUtil::paneGeom($master) $pane(-percent)
}

#-----------------------------------------------------------------------------
# ComboBox Functions
#-----------------------------------------------------------------------------

proc guiUtil::ComboBox {ComboBox args} {
    variable comboCommand

    if {![info exists guiUtil::ComboBoxInitListBoxes]} {
	# HACK: Listboxes should be the same color as Text
	# boxes, but they are not.  Set the default Listbox
	# color to be the same as the Text widget's color.
	
	set temp [text .temoraryTextToConfigureListBoxes]
	set bg [$temp cget -bg]
	option add *Listbox.background $bg
	destroy $temp
	variable ComboBoxInitListBoxes 1
    }

    # We shall always call our toplevel $ComboBox_tl 
    set w [format "%s_tl" $ComboBox]
    catch {destroy $w}
    toplevel $w

    # Disable window manager control, borders, etc.
    wm overrideredirect $w 1

    # Hide the default frame procedure by renaming it
    frame $ComboBox -bd 2 -relief sunken
    rename ::$ComboBox ::$ComboBox.frame

    # Neat hack to pass $ComboBox right now and $args at run-time
    # From Zircon :-)
    proc ::$ComboBox {args} "eval guiUtil::ComboBox_call $ComboBox \$args"

    # Create the popup interface.

    set frm  [frame $w.frm -bg black -bd 1]
    set list [listbox $frm.list -yscroll "$frm.yscroll set" -bd 0 \
	    -highlightthickness 0]
    set sb   [scrollbar $frm.yscroll -command "$list yview"]
    pack $list -side left -fill both -expand yes
    pack $frm -fill both -expand true

    # Create the entry box and arrow button.

    set entry [entry $ComboBox.e -bd 0]
    set arrow [label $ComboBox.arrow -relief raised \
	    -image $image::image(comboArrow)]
    bind $arrow <1> "guiUtil::ComboBox_popup $ComboBox $w"
    pack $entry -side left -fill both -expand true
    pack $arrow -side left -fill y

    bind $list <ButtonRelease-1> "guiUtil::ComboBox_popdown $ComboBox $w"
    bind $list <Return> "guiUtil::ComboBox_popdown $ComboBox $w"
    bind $entry <Return>  "
	if {\$guiUtil::comboCommand($ComboBox) != {}} {
	    uplevel #0 \$guiUtil::comboCommand($ComboBox)
	}   
    "
    bind $entry <Up> "guiUtil::ComboBox_popup $ComboBox $w"
    bind $entry <Down> "guiUtil::ComboBox_popup $ComboBox $w"
    bind $w <Leave> {set guiUtil::comboCursor out}
    bind $w <Enter> {set guiUtil::comboCursor in}
    bind $w <1> guiUtil::testRemoveGrab
    wm withdraw $w

    set comboCommand($ComboBox) {}
    if { [string length $args] } {
	eval {guiUtil::ComboBox_configure $ComboBox} $args
    }
    
    return $ComboBox
}

# Proc to call the actual proc - we need to levels of indirection/evals
# in order to pass args at run time and $ComboBox at creation time.
# Thanks to Zircon for this neat hack
proc guiUtil::ComboBox_call {this op args} {

    set errno [catch {eval guiUtil::ComboBox_$op $this $args} errmsg]
    if { $errno } {
	tk_dialog ${this}_d Error "ERROR: Unknown ComboBox \
		widget function $op !" error 0 OK
	return -1
    } else {
	return "$errmsg"
    }
	
}

# Proc to return the value of the ComboBox's entry field
proc guiUtil::ComboBox_get {ComboBox args} {
    return [$ComboBox.e get]
}

# Proc to set the value of the ComboBox's entry field
# The programmer could use this function to work-around the strict mode
# but then, the programmer is always right :-)
proc guiUtil::ComboBox_set {ComboBox args} {

    if { ![string compare [$ComboBox.e cget -state] "disabled"] } {
	$ComboBox.e configure -state normal
	$ComboBox.e delete 0 end
	$ComboBox.e insert end [lindex $args 0]
	$ComboBox.e configure -state disabled
    } else {
	$ComboBox.e delete 0 end
	$ComboBox.e insert end [lindex $args 0]
    }
    $ComboBox.e xview end
    if {$guiUtil::comboCommand($ComboBox) != {}} {
	uplevel #0 $guiUtil::comboCommand($ComboBox)
    }
}

# Proc to clear the value of the ComboBox's entry field
proc guiUtil::ComboBox_clear {ComboBox args} {
    if { ![string compare [$ComboBox.e cget -state] "disabled"] } {
	$ComboBox.e configure -state normal
	$ComboBox.e delete 0 end
	$ComboBox.e configure -state disabled
    } else {
	$ComboBox.e delete 0 end
    }
}

# Proc to remove elements from the listbox
proc guiUtil::ComboBox_del {ComboBox args } {
    # The toplevel is
    set w [format "%s_tl" $ComboBox]

    set height [$w.frm.list cget -height]
    incr height -1
    if {($height > 1) && ($height < 5)} {
	pack forget $w.frm.yscroll
	$w.frm.list configure -height $height
    }

    $w.frm.list delete [lindex $args 0] [lindex $args 1]
}

# Proc to add elements to the listbox
proc guiUtil::ComboBox_add {ComboBox args} {

    # The toplevel is
    set w [format "%s_tl" $ComboBox]

    # Sort the list of new and existing listbox entries.
    # Put the newest entries in the head of the list, then
    # remove any duplicate entries.

    set tmpList $args
    foreach arg [$w.frm.list get 0 end] {
	if {[lsearch $tmpList $arg] < 0} {
	    lappend tmpList $arg
	}
    }

    # Now remove all {} args from the list.
    set newList {}
    foreach arg $tmpList {
	if {$arg != {}} {
	    lappend newList $arg
	}
    }

    # If there were non-duplicate entries, insert each new
    # entry into the listbox.

    if {$newList != {}} {
	# Configure the size of the list box to 
	# be no greater then 4 lines long.

	set height [llength $newList]
	if {$height > 5} {
	    pack $w.frm.yscroll -side right -fill y
	    set height 5
	}
	$w.frm.list configure -height $height
	
	$w.frm.list delete 0 end
	foreach value $newList {
	    $w.frm.list insert end $value
	}
    }
    return [$w.frm.list get 0 end]
}

# Proc to emulate the cget command. 
proc guiUtil::ComboBox_cget { ComboBox args } {
    # The toplevel is
    set w [format "%s_tl" $ComboBox]

    # We shall ignore any arguments beyond the first one, rather than 
    # throwing up an error message.
    set option [lindex $args 0]

    if { [regexp {^-e} $option] } {
	return [$ComboBox.e cget [format "-%s" [string range $option 2 end]]]
    }  
    if { [regexp {^-list} $option] } {
	return [$w.frm.list cget [format "-%s" [string range $option 5 end]]]
    }
    if { [regexp {^-strict} $option] } {
	return [$ComboBox.e cget -state]
    }
    # The -cursor switch sets the cursor for all component widgets
    if { [regexp {^-cursor} $option] } {
	return [$ComboBox.e cget -state]
    }
    return [$ComboBox.e cget $option]

    # If we have got this far, $option is unknown
    tk_dialog ${ComboBox}_d Error "ERROR: Unknown ComboBox cget option $option !" error 0 OK
    return "ERROR"
}

# Proc to configure the widget
proc guiUtil::ComboBox_configure { ComboBox args} {

    # The toplevel is
    set w [format "%s_tl" $ComboBox]

    set i 0
    foreach option $args {
	if { [regexp {^-} $option] } {
	    set tag $option
	} else {
	    switch -- $tag {
		"-efont" -
		"-efg" -
		"-ebg" -
		"-ebd" -
		"-ehighlightthickness" -
		"-ewidth" -
		"-erelief" {
		    set realOption [string range $tag 2 end]
		    $ComboBox.e configure -$realOption $option
		}
		"-listexportselection" -
		"-listfont" -
		"-listheight" -
		"-listwidth" -
		"-listfg" -
		"-listbg" -
		"-listbd" -
		"-listrelief" { 
		    set realOption [string range $tag 5 end]
		    $w.frm.list configure -$realOption $option 
		}
		"-command" {
		    set guiUtil::comboCommand($ComboBox) $option
		}
		"-cursor" { 
		    $ComboBox.e configure -cursor $option
		    $w.frm.list configure -cursor $option
		    $ComboBox.arrow configure -cursor $option 
		}
		"-strict" { 
		    if {$option == 1} {
			$ComboBox.e configure -state disabled 
			$ComboBox.e configure -cursor [system::getArrow]
		    } else { 
			$ComboBox.e configure -state normal
			$ComboBox.e configure -cursor xterm
		    }
		}
		"-textvariable" {
		    $ComboBox.e configure -textvariable $option
		}
		default { 
		    tk_dialog ${ComboBox}_d Error \
			    "ERROR: Bad combobox configure option $tag" \
			    error 0 OK
		}
	    }
	}
	incr i
    }

    if { $i%2 } {
	tk_dialog ${ComboBox}_d Error \
		"ERROR: ComboBox_configure called with an odd # of args !" \
		error 0 OK
	return -1
    }
    return 0
}

proc guiUtil::ComboBox_popdown { {frame .f} {win .combobox} } {

    if { ![string compare [$frame.e cget -state] "disabled"] } {
	$frame.e configure -state normal
	set index [$win.frm.list curselection]
	if {$index != {}} {
	    $frame.e delete 0 end
	    $frame.e insert end [$win.frm.list get $index]
	}
	$frame.e configure -state disabled
    } else {
	set index [$win.frm.list curselection]
	if {$index != {}} {
	    $frame.e delete 0 end
	    $frame.e insert end [$win.frm.list get $index]
	}
    }
    $frame.e xview end
    if {$guiUtil::comboCommand($frame) != {}} {
	uplevel #0 $guiUtil::comboCommand($frame)
    }
    guiUtil::removeGrab
}

# Calculate the position of the listbox and pop it up. Code hacked from Tix
# Thanks, Ioi !
proc guiUtil::ComboBox_popup { {frame .f} {win .combobox} } {
    variable comboPopup
    variable comboParent 
    variable comboCursor 

    if { ![string compare [wm state $win] "normal"] } {
	guiUtil::removeGrab
	unset comboPopup
	unset comboParent
	return 0
    }
    set comboPopup $win
    set comboParent $win
    set comboCursor out

    # calculate the size
    set  y [winfo rooty $frame.e]
    incr y [winfo height $frame.e]
    incr y 3

    set bd [$win cget -bd]
    incr bd [$win cget -highlightthickness]
    set height [expr {[winfo reqheight $win.frm.list] + 2*$bd}]

    set x1 [winfo rootx $frame]
    set x2 [expr {$x1 + [winfo width $frame]}]
    set width [expr {$x2 - $x1}]
    
    set reqwidth [winfo reqwidth $win]
    if {$reqwidth < $width} {
	set reqwidth $width
    } else {
	if {$reqwidth > ($width *3)} {
	    set reqwidth [expr {$width *3}]
	}
	if {$reqwidth > [winfo vrootwidth .]} {
	    set reqwidth [winfo vrootwidth .]
	}
    }
    set width $reqwidth

    # If the listbox is too far right, pull it back to the left
    #
    set scrwidth [winfo vrootwidth .]
    if {$x2 > $scrwidth} {
	set x1 [expr {$scrwidth - $width}]
    }

    # If the listbox is too far left, pull it back to the right
    #
    if {$x1 < 0} {
	set x1 0
    }

    # If the listbox is below bottom of screen, put it upwards
    #
    set scrheight [winfo vrootheight .]
    set bottom [expr {$y+$height}]
    if {$bottom > $scrheight} {
	set y [expr {$y-$height-[winfo height $frame.e]-5}]
    }
 
    # OK , popup the shell
    #

    wm deiconify $win
    raise $win
    focus $win.frm.list
    wm geometry $win ${width}x${height}+${x1}+${y}

    set text [$frame.e get]
    set list [$win.frm.list get 0 end]

    if {[set index [lsearch -exact $list $text]] < 0} {
	set index 0
    }
    $win.frm.list selection set $index
    $win.frm.list activate $index
    $win.frm.list see active

    # Grab the server so that user cannot move the windows around
    #
    # $data(rootCmd) config -cursor arrow
    catch {
	# We catch here because grab may fail under a lot of circumstances
	# Just don't want to break the code ...
	grab -global $comboParent
    }

}

# guiUtil::removeGrab --
#
#	Rewmove the global grab created by the Combo Box.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc guiUtil::removeGrab {} {
    variable comboPopup
    variable comboParent

    if {[info exists comboPopup]} {
	wm withdraw $comboPopup
	grab release $comboParent
    }
    if {[info exists comboParent]} {
    }

}

# guiUtil::testRemoveGrab --
#
#	Rewmove the global grab created by the Combo Box if
# 	Button-1 was pressed outside of the listbox.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc guiUtil::testRemoveGrab {} {
    variable comboPopup
    variable comboCursor
    
    if {($comboCursor == "out")} {
	guiUtil::removeGrab
    }
}

#-----------------------------------------------------------------------------
# Misc Functions
#-----------------------------------------------------------------------------

# guiUtil::fileDialog --
#
#	Create a file dialog box that writes the result
#	to the entry widget.
#
# Arguments:
#	top	Toplevel window calling this proc.
#	ent	Entry widget to write the result to.
#	op	The type of operation (open or save)
#	types	File types to place in the dialog.
#
# Results:
#	None.

proc guiUtil::fileDialog {top ent op {types {}}} {
    set file [$ent get]
    set dir  [file dirname $file]

    if {$types == {}} {
	set types {
	    {"Tcl Scripts"		{.tcl .tk}	}
	    {"Text files"		{.txt .doc}	TEXT}
	    {"All files"		*}
	}
    }
    if {$op == "open"} {
	set file [tk_getOpenFile -filetypes $types -parent $top \
		-initialdir $dir]
    } else {
	set file [tk_getSaveFile -filetypes $types -parent $top \
	    -initialfile Untitled -defaultextension .tcl -initialdir $dir]
    }

    if {[string compare $file ""]} {
	$ent delete 0 end
	$ent insert 0 $file
	$ent xview end
    }
}

# guiUtil::positionWindow --
#
#	Given a top level window this procedure will position the window
#	in the same location it was the last time it was used (if we knew
#	about it).  If the location would be off the screen we move it so
#	it will be visable.  We also set up a destroy handler so that we
#	save the window state when the window goes away.
#
# Arguments:
#	win		A toplevel window.
#	defaultGeom	A default geometry if none exists.
#
# Results:
#	None.

proc guiUtil::positionWindow {win {defaultGeom {}}} {
    if {![winfo exists $win] || ($win != [winfo toplevel $win])} {
	error "positionWindow not called on toplevel"
    }

    set tag [string range $win 1 end]
    set winGeoms [pref::prefGet winGeoms]
    set index    [lsearch -regexp $winGeoms [list $tag *]]

    if {$index == -1} {
	if {$defaultGeom != ""} {
	    wm geometry $win $defaultGeom
	}
    } else {
	set geom [lindex [lindex $winGeoms $index] 1]

	# See if window is on the screen.  If it isn't then don't
	# use the saved value.  Either use the default or nothing.

	foreach {w h x y} {0 0 0 0} {}
	scan $geom "%dx%d+%d+%d" w h x y
	set slop 10
	set sw [expr {[winfo screenwidth $win]  - $slop}]
	set sh [expr {[winfo screenheight $win] - $slop}]
	
	if {($x > $sw) || ($x < 0) || ($y > $sh) || ($y < 0)} {
	    if {($defaultGeom != "")} {
		# Perform some sanity checking on the default value.

		foreach {w h x y} {0 0 0 0} {}
		scan $defaultGeom "%dx%d+%d+%d" w h x y
		if {$w > $sw} {
		    set w $sw
		    set x $slop
		}
		if {$h > $sh} {
		    set h $sh
		    set y $slop
		}
		if {($x < $slop) || ($x > $sw)} {
		    set x $slop
		}
		if {($y < $slop) || ($y > $sh)} {
		    set y $slop
		}
		wm geometry $win ${w}x${h}+${x}+${y}
	    }
	} else {
	    wm geometry $win ${w}x${h}+${x}+${y}
	}
    }
    
    bind $win <Destroy> {::guiUtil::saveGeometry %W}
}

# guiUtil::saveGeometry --
#
#	Given a toplevel window this procedure will save the geometry
#	state of the window so it can be placed in the same position
#	the next time it is created.
#
# Arguments:
#	win	A toplevel window.
#
# Results:
#	None.  State is stored in global preferences.

proc guiUtil::saveGeometry {win} {
    set result [catch {set top [winfo toplevel $win]}]
    if {($result != 0) || ($win != $top)} {
	return
    }

    # If wins geometry has been saved before, get an index into the list and 
    # replace the old value with the new value.  If wins has not been saved
    # before the index value will be -1.

    set geometry [wm geometry $win]
    set tag [string range $win 1 end]
    set winGeoms [pref::prefGet winGeoms GlobalDefault]
    set index    [lsearch -regexp $winGeoms [list $tag *]]

    # If the window was never saved before, append the tag name and the 
    # geometry of the window onto the list.  Otherwise replace the value
    # referred to at index.

    if {$index == -1} {
	lappend winGeoms [list $tag $geometry]
    } else {
	set winGeoms [lreplace $winGeoms $index $index [list $tag $geometry]]
    }

    # Update the winGeoms preference value in the GlobalDefault group

    pref::prefSet GlobalDefault winGeoms $winGeoms 
    return
}

# guiUtil::restorePaneGeometry --
#
#	Restore the pane's -percent value, so the window
#	can be restored to it's identical percentage of 
#	distribution.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc guiUtil::restorePaneGeometry {} {
    array set guiUtil::paneGeom [pref::prefGet paneGeom GlobalDefault] 
    return
}

# guiUtil::preservePaneGeometry --
#
#	Save the pane's -percent value, so the window can
#	be restored to it's identical percentage of 
#	distribution.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc guiUtil::preservePaneGeometry {} {
    # Update the winGeoms preference value in the GlobalDefault group
    
    pref::prefSet GlobalDefault paneGeom [array get ::guiUtil::paneGeom]
    return
}
