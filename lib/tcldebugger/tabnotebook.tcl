##
## Copyright 1997 Jeffrey Hobbs, CADIX International
##

##------------------------------------------------------------------------
## PROCEDURE
##	tabnote
##
## DESCRIPTION
##	Implements a Tabbed Notebook megawidget
##
## ARGUMENTS
##	tabnote <window pathname> <options>
##
## OPTIONS
##	(Any entry widget option may be used in addition to these)
##
## -activebackground color		DEFAULT: {}
##	The background color given to the active tab.  A value of {}
##	means these items will pick up the widget's background color.
##
## -background color			DEFAULT: DEFAULT
##	The background color for the container subwidgets.
##
## -browsecmd script			DEFAULT: {}
##	A script that is executed each time a tab changes.  It appends
##	the old tab and the new tab to the script.  An empty string ({})
##	represents the blank (empty) tab.
##
## -disabledbackground color		DEFAULT: #c0c0c0 (dark gray)
##	The background color given to disabled tabs.
##
## -justify justification		DEFAULT: center
##	The justification applied to the text in multi-line tabs.
##	Must be one of: left, right, center.
##
## -linewidth pixels			DEFAULT: 1
##	The width of the line surrounding the tabs.  Must be at least 1.
##
## -linecolor color			DEFAULT: black
##	The color of the line surrounding the tabs.
##
## -normalbackground			DEFAULT: {}
##	The background color of items with normal state.  A value of {}
##	means these items will pick up the widget's background color.
##
## -padx pixels				DEFAULT: 4
##	The X padding for folder tabs around the items.
##
## -pady pixels				DEFAULT: 2
##	The Y padding for folder tabs around the items.
##
## RETURNS: the window pathname
##
## BINDINGS (in addition to default widget bindings)
##
## <1> in a tabs activates that tab.
##
## METHODS
##	These are the methods that the Tabnote widget recognizes.  Aside from
##	these, it accepts methods that are valid for entry widgets.
##
## configure ?option? ?value option value ...?
## cget option
##	Standard tk widget routines.
##
## activate id
##	Activates the tab specified by id.  id may either by the unique id
##	returned by the add command or the string used in the add command.
##
## add string ?-window widget? ?-state state?
##	Adds a tab to the tab notebook with the specified string, unless
##	the string is the name of an image, in which case the image is used.
##	Each string must be unique.  The widget specifies a widget to show
##	when that tab is pressed.  It must be a child of the tab notebook
##	(required for grid management) and exist prior to the 'add' command
##	being called.  The optional state can be normal (default), active or
##	or disabled.  If active is given, then this tab becomes the active
##	tab.  A unique tab id is returned.
##
## delete id
##	Deletes the tab specified by id.  id may either by the unique id
##	returned by the add command or the string used in the add command.
##
## itemconfigure ?option? ?value option value ...?
## itemcget option
##	Configure or retrieve the option of a tab notebook item.
##
## name tabId
##	Returns the text name for a given tabId.
##
## subwidget widget
##	Returns the true widget path of the specified widget.  Valid
##	widgets are hold (a frame), tabs (a canvas), blank (a frame).
##
## NAMESPACE & STATE
##	The megawidget creates a global array with the classname, and a
## global array which is the name of each megawidget created.  The latter
## array is deleted when the megawidget is destroyed.
##	Public procs of $CLASSNAME and [string tolower $CLASSNAME] are used.
## Other procs that begin with $CLASSNAME are private.  For each widget,
## commands named .$widgetname and $CLASSNAME$widgetname are created.
##
## EXAMPLE USAGE:
##
##
##------------------------------------------------------------------------

#package require Widget 1.0
package provide Tabnotebook 1.3

array set Tabnotebook {
    type		frame
    base		frame
    components		{
	{frame hold hold {-relief raised -bd 1}}
	{frame blank}
	{frame hide hide \
		{-background $data(-background) -height 1 -width 40}}
	{canvas tabs tabs {-bg $data(-background) \
		-highlightthickness 0 -takefocus 0}}
    }

    -activebackground	{activeBackground ActiveBackground {}}
    -bg			-background
    -background		{ALIAS frame -background}
    -bd			-borderwidth
    -borderwidth	{ALIAS frame -borderwidth}
    -browsecmd		{browseCmd	BrowseCommand	{}}
    -disabledbackground	{disabledBackground DisabledBackground #a3a3a3}
    -normalbackground	{normalBackground normalBackground #c3c3c3}
    -justify		{justify	Justify		center}
    -minwidth		{minWidth	Width		-1}
    -minheight		{minHeight	Height		-1}
    -padx		{padX		PadX		4}
    -pady		{padY		PadY		2}
    -relief		{ALIAS frame -relief}
    -linewidth		{lineWidth	LineWidth	1}
    -linecolor		{lineColor	LineColor	black}
}
# Create this to make sure there are registered in auto_mkindex
# these must come before the [widget create ...]
proc Tabnotebook args {}
proc tabnotebook args {}
widget create Tabnotebook

;proc Tabnotebook:construct {w args} {
    upvar \#0 $w data

    ## Private variables
    array set data {
	curtab	{}
	numtabs	0
	width	2
	height	0
	ids	{}
    }

    $data(tabs) yview moveto 0
    $data(tabs) xview moveto 0

    grid $data(tabs) -sticky ew
    grid $data(hold) -sticky news
    grid $data(blank) -in $data(hold) -row 0 -column 0 -sticky nsew
    grid columnconfig $w 0 -weight 1
    grid rowconfig $w 1 -weight 1
    grid columnconfig $data(hold) 0 -weight 1
    grid rowconfig $data(hold) 0 -weight 1

    bind $data(tabs) <Configure> "
    if {\[string compare $data(tabs) %W\]} return
    Tabnotebook:resize [list $w] %w
    "
    bind $data(tabs) <2>		{ %W scan mark %x 0 }
    bind $data(tabs) <B2-Motion>	{
	%W scan dragto %x 0
	Tabnotebook:resize [winfo parent %W] [winfo width %W]
    }
}

;proc Tabnotebook:configure { w args } {
    upvar \#0 $w data

    set truth {^(1|yes|true|on)$}
    set post {}
    foreach {key val} $args {
	switch -- $key {
	    -activebackground {
		if {[string compare $data(curtab) {}]} {
		    $data(tabs) itemconfig POLY:$data(curtab) -fill $val
		}
		if {[string compare $val {}]} {
		    $data(hide) config -bg $val
		} else {
		    lappend post {$data(hide) config -bg $data(-background)}
		}
	    }
	    -background	{
		$data(tabs) config -bg $val
		$data(hold) config -bg $val
		$data(blank) config -bg $val
	    }
	    -borderwidth {
		$data(hold) config -bd $val
		$data(hide) config -height $val
	    }
	    -disabledbackground {
		foreach i $data(ids) {
		    if {[string match disabled $data(:$i:-state)]} {
			$data(tabs) itemconfig POLY:$i -fill $val
		    }
		}
	    }
	    -justify	{ $data(tabs) itemconfig TEXT -justify $val }
	    -linewidth	{
		$data(tabs) itemconfigure LINE -width $val
	    }
	    -linecolor	{
		$data(tabs) itemconfigure LINE -fill $val
	    }
	    -minwidth	{
		if {$val >= 0} { grid columnconfig $w 0 -minsize $val }
	    }
	    -minheight	{
		if {$val >= 0} { grid rowconfig $w 1 -minsize $val }
	    }
	    -normalbackground {
		foreach i $data(ids) {
		    if {[string match normal $data(:$i:-state)]} {
			$data(tabs) itemconfig POLY:$i -fill $val
		    }
		}
	    }
	    -padx - -pady {
		if {$val <= 0} { set val 1 }
	    }
	    -relief {
		$data(hold) config -relief $val
	    }
	}
	set data($key) $val
    }
    if {[string compare $post {}]} {
	eval [join $post \n]
    }
}

;proc Tabnotebook_add { w text args } {
    upvar \#0 $w data

    set c $data(tabs)
    if {[string match {} $text]} {
	return -code error "non-empty text required for noteboook label"
    } elseif {[string compare {} [$c find withtag ID:$text]]} {
	return -code error "tab \"$text\" already exists"
    }
    array set s {
	-window	{}
	-state	normal
    }
    foreach {key val} $args {
	switch -glob -- $key {
	    -w*	{
		if {[string compare $val {}]} {
		    if {![winfo exist $val]} {
			return -code error "window \"$val\" does not exist"
		    } elseif {[string comp $w [winfo parent $val]] && \
			    [string comp $data(hold) [winfo parent $val]]} {
			return -code error "window \"$val\" must be a\
				child of the tab notebook ($w)"
		    }
		}
		set s(-window) $val
	    }
	    -s* {
		if {![regexp {^(normal|disabled|active)$} $val]} {
		    return -code error "unknown state \"$val\", must be:\
			    normal, disabled or active"
		}
		set s(-state) $val
	    }
	    default {
		return -code error "unknown option '$key', must be:\
			[join [array names s] {, }]"
	    }
	}
    }
    set tabnum [incr data(numtabs)]
    set px $data(-padx)
    set py $data(-pady)
    if {[lsearch -exact [image names] $text] != -1} {
	set i [$c create image $px $py -image $text -anchor nw \
		-tags [list IMG ID:$text TAB:$tabnum]]
    } else {
	set i [$c create text [expr {$px+1}] $py -text $text -anchor nw \
		-tags [list TEXT ID:$text TAB:$tabnum] \
		-justify $data(-justify)]
    }
    foreach {x1 y1 x2 y2} [$c bbox $i] {
	set W  [expr {$x2-$x1+$px}]
	set FW [expr {$W+$px}]
	set FH [expr {$y2-$y1+3*$py}]
    }
    set diff [expr {$FH-$data(height)}]
    if {$diff > 0} {
	$c move all 0 $diff
	$c move $i 0 -$diff
	set data(height) $FH
    }

    array set color [system::getColor]
    set darkInside   $color(darkInside)
    set darkOutside  $color(darkOutside)
    set lightInside  $color(lightInside)
    set lightOutside $color(lightOutside)
    
    set LW $data(-linewidth)
    set CI [expr {2 * $LW}]
    
    set cw1 [list $CI $FH]
    set cw2 [list $CI $CI]
    set cw3 [list $CI $CI]
    set cw4 [list [expr {$FW - $CI + 1}] $CI]

    set cb1 [list [expr {$FW - $CI + 1}] $LW]
    set cb2 [list $FW $CI]
    set cb3 [list $FW $FH]

    set cd1 [list $LW $FH]
    set cd2 [list $LW $CI]
    set cd3 [list [expr {$LW + 1}] $LW]
    set cd4 [list [expr {$FW - int($CI / 2)}] $LW]

    set cg1 [list [expr {$FW - $LW}] [expr {$LW * 2}]]
    set cg2 [list [expr {$FW - $LW}] $FH]

    set borderW [join [list $cw1 $cw2 $cw3 $cw4] { }]
    set borderB [join [list $cb1 $cb2 $cb3] { }]
    set borderD [join [list $cd1 $cd2 $cd3 $cd4] { }]
    set borderG [join [list $cg1 $cg2] { }]
    set outline [join [list $cw1 $cw2 $cw3 $cb2 $cb3] { }]

    eval {$c create line} $borderW {  \
	    -tags [list LINE LINE:$tabnum TAB:$tabnum] \
	    -width $data(-linewidth) -fill $lightOutside}

    eval {$c create line} $borderB {  \
	    -tags [list LINE LINE:$tabnum TAB:$tabnum] \
	    -width $data(-linewidth) -fill $darkOutside}

    eval {$c create line} $borderD {  \
	    -tags [list LINE LINE:$tabnum TAB:$tabnum] \
	    -width $data(-linewidth) -fill $lightInside}

    eval {$c create line} $borderG {  \
	    -tags [list LINE LINE:$tabnum TAB:$tabnum] \
	    -width $data(-linewidth) -fill $darkInside}

    eval {$c create poly} $outline {-fill {} \
	    -tags [list POLY POLY:$tabnum TAB:$tabnum]}

    $c move TAB:$tabnum $data(width) [expr {($diff<0)?-$diff:0}]
    $c raise $i
    $c raise LINE:$tabnum
    incr data(width) [expr {$FW + 1}]
    $c config -width $data(width) -height $data(height) \
	    -scrollregion "0 0 $data(width) $data(height)"
    $c bind TAB:$tabnum <1> [list Tabnotebook_activate $w $tabnum]
    array set data [list :$tabnum:-window $s(-window) \
	    :$tabnum:-state $s(-state)]
    if {[string compare $s(-window) {}]} {
	grid $s(-window) -in $data(hold) -row 0 -column 0 -sticky nsew
	lower $s(-window)
    }
    switch $s(-state) {
	active	{ Tabnotebook_activate $w $tabnum }
	disabled {$c itemconfig POLY:$tabnum -fill $data(-disabledbackground)}
	normal	{$c itemconfig POLY:$tabnum -fill $data(-normalbackground)}
    }
    lappend data(ids) $tabnum
    return $tabnum
}

;proc Tabnotebook_activate { w id } {
    upvar \#0 $w data

    if {[string compare $id {}]} {
	set tab [Tabnotebook:verify $w $id]
	if {[string match disabled $data(:$tab:-state)]} return
    } else {
	set tab {}
    }
    if {[string match $data(curtab) $tab]} return
    set c $data(tabs)
    set oldtab $data(curtab)
    if {[string compare $oldtab {}]} {
	$c itemconfig POLY:$oldtab -fill $data(-normalbackground)
	set data(:$oldtab:-state) normal
    }
    set data(curtab) $tab
    if {[string compare $tab {}]} {
	set data(:$tab:-state) active
	$c itemconfig POLY:$tab -fill $data(-activebackground)
    }
    if {[info exists data(:$tab:-window)] && \
	    [winfo exists $data(:$tab:-window)]} {
	raise $data(:$tab:-window)
	focus $data(:$tab:-window)
    } else {
	raise $data(blank)
    }
    Tabnotebook:resize $w [winfo width $w]
    if {[string comp $data(-browsecmd) {}]} {
	uplevel \#0 $data(-browsecmd) \
		[list [Tabnotebook_name $w $oldtab] [Tabnotebook_name $w $tab]]
    }
}

;proc Tabnotebook_delete { w id } {
    upvar \#0 $w data

    set tab [Tabnotebook:verify $w $id]
    set c $data(tabs)
    foreach {x1 y1 x2 y2} [$c bbox TAB:$tab] { set W [expr {$x2-$x1-3}] }
    $c delete TAB:$tab
    for { set i [expr {$tab+1}] } { $i <= $data(numtabs) } { incr i } {
	$c move TAB:$i -$W 0
    }
    foreach {x1 y1 x2 y2} [$c bbox all] { set H [expr {$y2-$y1-3}] }
    if {$H<$data(height)} {
	$c move all 0 [expr {$H-$data(height)}]
	set data(height) $H
    }
    incr data(width) -$W
    $c config -width $data(width) -height $data(height) \
	    -scrollregion "0 0 $data(width) $data(height)"
    set i [lsearch $data(ids) $tab]
    set data(ids) [lreplace $data(ids) $i $i]
    catch {grid forget $data(:$tab:-window)}
    unset data(:$tab:-state) data(:$tab:-window)
    if {[string match $tab $data(curtab)]} {
	set data(curtab) {}
	raise $data(blank)
    }
}

;proc Tabnotebook_itemcget { w id key } {
    upvar \#0 $w data

    set tab [Tabnotebook:verify $w $id]
    set opt [array names data :$tab:$key*]
    set len [llength $opt]
    if {$len == 1} {
	return $data($opt)
    } elseif {$len == 0} {
	set all [array names data :$tab:-*]
	foreach o $all { lappend opts [lindex [split $o :] end] }
	return -code error "unknown option \"$key\", must be one of:\
		[join $opts {, }]"
    } else {
	foreach o $opt { lappend opts [lindex [split $o :] end] }
	return -code error "ambiguous option \"$key\", must be one of:\
		[join $opts {, }]"
    }
}

;proc Tabnotebook_itemconfigure { w id args } {
    upvar \#0 $w data

    set tab [Tabnotebook:verify $w $id]
    set len [llength $args]
    if {$len == 1} {
	return [uplevel [list Tabnotebook_itemcget $w $tab] $args]
    } elseif {$len&1} {
	return -code error "uneven set of key/value pairs in \"$args\""
    }
    if {[string match {} $args]} {
	set all [array names data :$tab:-*]
	foreach o $all { lappend res [lindex [split $o :] end] $data($o) }
	return $res
    }
    foreach {key val} $args {
	switch -glob -- $key {
	    -w*	{
		if {[string comp $val {}]} {
		    if {![winfo exist $val]} {
			return -code error "window \"$val\" does not exist"
		    } elseif {[string comp $w [winfo parent $val]] && \
			    [string comp $data(hold) [winfo parent $val]]} {
			return -code error "window \"$val\" must be a\
				child of the tab notebook ($w)"
		    }
		}
		set old $data(:$tab:-window)
		if {[winfo exists $old]} { grid forget $old }
		set data(:$tab:-window) $val
		if {[string comp $val {}]} {
		    grid $val -in $data(hold) -row 0 -column 0 \
			    -sticky nsew
		    lower $val
		}
		if {[string match active $data(:$tab:-state)]} {
		    if {[string comp $val {}]} {
			raise $val
		    } else {
			raise $data(blank)
		    }
		}
	    }
	    -s* {
		if {![regexp {^(normal|disabled|active)$} $val]} {
		    return -code error "unknown state \"$val\", must be:\
			    normal, disabled or active"
		}
		if {[string match $val $data(:$tab:-state)]} return
		set old $data(:$tab:-state)
		switch $val {
		    active		{
			set data(:$tab:-state) $val
			Tabnotebook_activate $w $tab
		    }
		    disabled	{
			if {[string match active $old]} {
			    Tabnotebook_activate $w {}
			}
			$data(tabs) itemconfig POLY:$tab \
				-fill $data(-disabledbackground)
			set data(:$tab:-state) $val
		    }
		    normal		{
			if {[string match active $old]} {
			    Tabnotebook_activate $w {}
			}
			$data(tabs) itemconfig POLY:$tab -fill {}
			set data(:$tab:-state) $val
		    }
		}
	    }
	    default {
		return -code error "unknown option '$key', must be:\
			[join [array names s] {, }]"
	    }
	}
    }
}

## given a tab number, return the text
;proc Tabnotebook_name { w id } {
    upvar \#0 $w data

    if {[string match {} $id]} return
    set text {}
    foreach item [$data(tabs) find withtag TAB:$id] {
	set tags [$data(tabs) gettags $item]
	if {[set i [lsearch -glob $tags {ID:*}]] != -1} {
	    set text [string range [lindex $tags $i] 3 end]
	    break
	}
    }
    return $text
}

;proc Tabnotebook:resize { w x } {
    upvar \#0 $w data

    if {[string compare $data(curtab) {}]} {
	set x [expr {round(-[$data(tabs) canvasx 0])}]
	foreach {x1 y1 x2 y2} [$data(tabs) bbox TAB:$data(curtab)] {
	    place $data(hide) -y [winfo y $data(hold)] -x [expr {$x1+$x+3}]
	    $data(hide) config -width [expr {$x2-$x1-5}]
	}
    } else {
	place forget $data(hide)
    }
}

;proc Tabnotebook:see { w id } {
    upvar \#0 $w data

    set c $data(tabs)
    set box [$c bbox $id]
    if {[string match {} $box]} return
    foreach {x y x1 y1} $box {left right} [$c xview] \
	    {p q xmax ymax} [$c cget -scrollregion] {
	set xpos [expr {(($x1+$x)/2.0)/$xmax - ($right-$left)/2.0}]
    }
    $c xview moveto $xpos
}

;proc Tabnotebook:verify { w id } {
    upvar \#0 $w data

    set c $data(tabs)
    if {[string comp {} [set i [$c find withtag ID:$id]]]} {
	if {[regexp {TAB:([0-9]+)} [$c gettags [lindex $i 0]] junk id]} {
	    return $id
	}
    } elseif {[string comp {} [$c find withtag TAB:$id]]} {
	return $id
    }
    return -code error "unrecognized tab \"$id\""
}

proc Tabnotebook_top { w } {
    upvar \#0 $w data
    
    set id $data(curtab)
    if {[string compare $id {}]} {
	set tab [Tabnotebook:verify $w $id]
    }
    if {[info exists data(:$tab:-window)] && \
	    [winfo exists $data(:$tab:-window)]} {
	return $data(:$tab:-window)
    }
    return {}
}

