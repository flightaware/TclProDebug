##
## widget.tcl
##
## Barebones requirements for creating and querying megawidgets
##
## Copyright 1997 Jeffrey Hobbs, CADIX International
##
## Initiated: 5 June 1997
## Last Update:

##------------------------------------------------------------------------
## PROCEDURE
##	widget
##
## DESCRIPTION
##	Implements and modifies megawidgets
##
## ARGUMENTS
##	widget <subcommand> ?<args>?
##
## <classname> specifies a global array which is the name of a class and
## contains options database information.
##
## create classname
##	creates the widget class $classname based on the specifications
##	in the global array of the same name
##
## classes ?pattern?
##	returns the classes created with this command.
##
## OPTIONS
##	none
##
## RETURNS: the widget class
##
## NAMESPACE & STATE
##	The global variable WIDGET is used.  The public procedure is
## 'widget', with other private procedures beginning with 'widget'.
##
##------------------------------------------------------------------------
##
## For a well-commented example for creating a megawidget using this method,
## see the ScrolledText example at the end of the file.
##
## SHORT LIST OF IMPORTANT THINGS TO KNOW:
##
## Specify the "type", "base", & "components" keys of the $CLASS global array
##
## In the $w global array that is created for each instance of a megawidget,
## the following keys are set by the "widget create $CLASS" procedure:
##   "base", "basecmd", "container", "class", any option specified in the
##   $CLASS array, each component will have a named key
##
## The following public methods are created for you:
##   "cget", "configure", "destroy", & "subwidget"
## You need to write the following:
##   "$CLASS:construct", "$CLASS:configure"
## You may want the following that will be called when appropriate:
##   "$CLASS:init" (after initial configuration)
##   "$CLASS:destroy" (called first thing when widget is being destroyed)
##
## All ${CLASS}_* commands are considered public methods.  The megawidget
## routine will match your options and methods on a unique substring basis.
##
## END OF SHORT LIST

package require Tk
package provide Widget 1.12

global WIDGET
lappend WIDGET(containers) frame toplevel
proc widget { cmd args } {
    switch -glob $cmd {
	cr*	{ return [uplevel widget_create $args] }
	cl*	{ return [uplevel widget_classes $args] }
	default {
	    return -code error "unknown [lindex [info level 0] 0] subcommand\
		    \"$cmd\", must be one of: create, classes"
	}
    }
}

;proc widget_classes {{pattern "*"}} {
    global WIDGET
    set classes {}
    foreach name [array names WIDGET C:$pattern] {
	lappend classes [string range $name 2 end]
    }
    return $classes
}

;proc widget:eval {CLASS w subcmd args} {
    upvar \#0 $w data
    if {[string match {} [set arg [info commands ${CLASS}_$subcmd]]]} {
	set arg [info commands ${CLASS}_$subcmd*]
    }
    set num [llength $arg]
    if {$num==1} {
	return [uplevel $arg [list $w] $args]
    } elseif {$num} {
	regsub -all "${CLASS}_" $arg {} arg
	return -code error "ambiguous subcommand \"$subcmd\",\
		could be one of: [join $arg {, }]"
    } elseif {[catch {uplevel [list $data(basecmd) $subcmd] $args} err]} {
	return -code error $err
    } else {
	return $err
    }
}

;proc widget_create:constructor {CLASS} {
    upvar \#0 $CLASS class
    global WIDGET

    lappend datacons [list class $CLASS]
    set basecons {}
    if {[string compare $class(type) [lindex $class(base) 0]]} {
	lappend datacons "base \$w.[list [lindex $class(base) 2]]" \
		"basecmd $CLASS\$w.[list [lindex $class(base) 2]]"
	set comps "[list $class(base)] $class(components)"
    } else {
	lappend datacons "base \$w" "basecmd $CLASS\$w" \
		"[lindex $class(base) 1] \$w"
	set comps $class(components)
    }
    foreach comp $comps {
	switch [llength $comp] {
	    0 continue
	    1 { set name [set type [set wid $comp]]; set opts {} }
	    2 {
		set type [lindex $comp 0]
		set name [set wid [lindex $comp 1]]
		set opts {}
	    }
	    default {
		foreach {type name wid opts} $comp break
		set opts [string trim $opts]
	    }
	}
	lappend datacons "[list $name] \$w.[list $wid]"
	lappend basecons "$type \$data($name) $opts"
	if {[string match toplevel $type]} {
	    lappend basecons "wm withdraw \$data($name)"
	}
    }
    set datacons [join $datacons]
    set basecons [join $basecons "\n    "]
    
    ## More of this proc could be configured ahead of time for increased
    ## construction speed.  It's delicate, so handle with extreme care.
    ;proc $CLASS {w args} "
    upvar \#0 \$w data $CLASS class
    $class(type) \$w -class $CLASS
    [expr {[string match toplevel $class(type)]?{wm withdraw \$w\n}:{}}]
    ## Populate data array with user definable options
    foreach o \[array names class -*\] {
	if {\[string match -* \$class(\$o)\]} continue
	set data(\$o) \[option get \$w \[lindex \$class(\$o) 0\] $CLASS\]
    }

    ## Populate the data array
    array set data \[list $datacons\]
    ## Create all the base and component widgets
    $basecons

    ## Allow for an initialization proc to be eval'ed
    ## The user must create one
    if {\[catch {$CLASS:construct \$w} err\]} {
	catch {${CLASS}_destroy \$w}
	return -code error \"megawidget construction error: \$err\"
    }

    set base \$data(base)
    if {\[string compare \$base \$w\]} {
	## If the base widget is not the container, then we want to rename
	## its widget commands and add the CLASS and container bind tables
	## to its bindtags in case certain bindings are made
	rename \$w .\$w
	rename \$base \$data(basecmd)
	## Interp alias is the optimal solution, but exposes
	## a bug in Tcl7/8 when renaming aliases
	#interp alias {} \$base {} widget:eval $CLASS \$w
	;proc \$base args \"uplevel widget:eval $CLASS \[list \$w\] \\\$args\"
	bindtags \$base \[linsert \[bindtags \$base\] 1\
		[expr {[string match toplevel $class(type)]?{}:{$w}}] $CLASS\]
    } else {
	rename \$w \$data(basecmd)
    }
    ;proc \$w args \"uplevel widget:eval $CLASS \[list \$w\] \\\$args\"
    #interp alias {} \$w {} widget:eval $CLASS \$w

    ## Do the configuring here and eval the post initialization procedure
    if {(\[string compare {} \$args\] && \
	    \[catch {uplevel 1 ${CLASS}_configure \$w \$args} err\]) || \
	    \[catch {$CLASS:init \$w} err\]} {
	catch { ${CLASS}_destroy \$w }
	return -code error \"megawidget initialization error: \$err\"
    }

    return \$w\n"
    interp alias {} [string tolower $CLASS] {} $CLASS

    ## These are provided so that errors due to lack of the command
    ## existing don't arise.  Since they are stubbed out here, the
    ## user can't depend on 'unknown' or 'auto_load' to get this proc.
    if {[string match {} [info commands $CLASS:construct]]} {
	;proc $CLASS:construct {w} {
	    # the user should rewrite this
	    # without the following error, a simple megawidget that was just
	    # a frame would be created by default
	    return -code error "user must write their own\
		    [lindex [info level 0] 0] function"
	}
    }
    if {[string match {} [info commands $CLASS:init]]} {
	;proc $CLASS:init {w} {
	    # the user should rewrite this
	}
    }
}

;proc widget_create {CLASS} {
    if {![string match {[A-Z]*} $CLASS] || [string match { } $CLASS]} {
	return -code error "invalid class name \"$CLASS\": it must begin\
		with a capital letter and contain no spaces"
    }

    global WIDGET
    upvar \#0 $CLASS class

    ## First check to see that their container type is valid
    if {[info exists class(type)]} {
	## I'd like to include canvas and text, but they don't accept the
	## -class option yet, which would thus require some voodoo on the
	## part of the constructor to make it think it was the proper class
	if {![regexp ^([join $WIDGET(containers) |])\$ $class(type)]} {
	    return -code error "invalid class container type \"$class(type)\",\
		    must be one of: [join $types {, }]"
	}
    } else {
	## Frame is the default container type
	set class(type) frame
    }
    ## Then check to see that their base widget type is valid
    ## We will create a default widget of the appropriate type just in
    ## case they use the DEFAULT keyword as a default value in their
    ## megawidget class definition
    if {[info exists class(base)]} {
	## We check to see that we can create the base, that it returns
	## the same widget value we put in, and that it accepts cget.
	if {[string match toplevel [lindex $class(base) 0]] && \
		[string compare toplevel $class(type)]} {
	    return -code error "\"toplevel\" is not allowed as the base\
		    widget of a megawidget (perhaps you intended it to\
		    be the class type)"
	}
    } else {
	## The container is the default base widget
	set class(base) $class(type)
    }
    set types($class(type)) 0
    switch [llength $class(base)] {
	1 { set name [set type [set wid $class(base)]]; set opts {} }
	2 {
	    set type [lindex $class(base) 0]
	    set name [set wid [lindex $class(base) 1]]
	    set opts {}
	}
	default { foreach {type name wid opts} $class(base) break }
    }
    set class(base) [list $type $name $wid $opts]
    if {[regexp {(^[\.A-Z]|[ \.])} $wid]} {
	return -code error "invalid $CLASS class base widget name \"$wid\":\
		it cannot begin with a capital letter,\
		or contain spaces or \".\""
    }
    set components(base) [set components($name) $type]
    set widgets($wid) 0
    set types($type) 0

    if {![info exists class(components)]} { set class(components) {} }
    set comps $class(components)
    set class(components) {}
    ## Verify component widget list
    foreach comp $comps {
	## We don't care if an opts item exists now
	switch [llength $comp] {
	    0 continue
	    1 { set name [set type [set wid $comp]] }
	    2 {
		set type [lindex $comp 0]
		set name [set wid [lindex $comp 1]]
	    }
	    default { foreach {type name wid} $comp break }
	}
	if {[info exists components($name)]} {
	    return -code error "component name \"$name\" occurs twice\
		    in $CLASS class"
	}
	if {[info exists widgets($wid)]} {
	    return -code error "widget name \"$wid\" occurs twice\
		    in $CLASS class"
	}
	if {[regexp {(^[\.A-Z]| |\.$)} $wid]} {
	    return -code error "invalid $CLASS class component widget\
		    name \"$wid\": it cannot begin with a capital letter,\
		    contain spaces or start or end with a \".\""
	}
	if {[string match *.* $wid] && \
		![info exists widgets([file root $wid])]} {
	    ## If the widget name contains a '.', then make sure we will
	    ## have created all the parents first.  [file root $wid] is
	    ## a cheap trick to remove the last .child string from $wid
	    return -code error "no specified parent for $CLASS class\
		    component widget name \"$wid\""
	}
	lappend class(components) $comp
	set components($name) $type
	set widgets($wid) 0
	set types($type) 0
    }

    ## Go through the megawidget class definition, substituting for ALIAS
    ## where necessary and setting up the options database for this $CLASS
    foreach o [array names class -*] {
	set name [lindex $class($o) 0]
	switch -glob -- $name {
	    -*	continue
	    ALIAS	{
		set len [llength $class($o)]
		if {$len != 3 && $len != 5} {
		    return -code error "wrong \# args for ALIAS, must be:\
			    {ALIAS componenttype option\
			    ?databasename databaseclass?}"
		}
		foreach {name type opt dbname dbcname} $class($o) break
		if {![info exists types($type)]} {
		    return -code error "cannot create alias \"$o\" to $CLASS\
			    component type \"$type\" option \"$opt\":\
			    component type does not exist"
		} elseif {![info exists config($type)]} {
		    if {[string compare toplevel $type]} {
			set w .__widget__$type
			catch {destroy $w}
			## Make sure the component widget type exists,
			## returns the widget name,
			## and accepts configure as a subcommand
			if {[catch {$type $w} result] || \
				[string compare $result $w] || \
				[catch {$w configure} config($type)]} {
			    ## Make sure we destroy it if it was a bad widget
			    catch {destroy $w}
			    ## Or rename it if it was a non-widget command
			    catch {rename $w {}}
			    return -code error "invalid widget type \"$type\""
			}
			catch {destroy $w}
		    } else {
			set config($type) [. configure]
		    }
		}
		set i [lsearch -glob $config($type) "$opt\[ \t\]*"]
		if {$i == -1} {
		    return -code error "cannot create alias \"$o\" to $CLASS\
			    component type \"$type\" option \"$opt\":\
			    option does not exist"
		}
		if {$len==3} {
		    foreach {opt dbname dbcname def} \
			    [lindex $config($type) $i] break
		} elseif {$len==5} {
		    set def [lindex [lindex $config($type) $i] 3]
		}
	    }
	    default	{
		if {[string compare {} $class($o)]} {
		    foreach {dbname dbcname def} $class($o) break
		} else {
		    set dbcname [set dbname [string range $o 1 end]]
		    set def {}
		}
	    }
	}
	set class($o) [list $dbname $dbcname $def]
	option add *$CLASS.$dbname $def widgetDefault
    }
    ## Ensure that the class is set correctly
    set class(class) $CLASS

    ## This creates the basic constructor procedure for the class
    ## Both $CLASS and [string tolower $CLASS] commands will be created
    widget_create:constructor $CLASS

    ## The user is not supposed to change this proc
    set comps [lsort [array names components]]
    ;proc ${CLASS}_subwidget {w widget} "
    upvar \#0 \$w data
    switch -- \$widget {
	[join $comps { - }] { return \$data(\$widget) }
	default {
	    return -code error \"No \$data(class) subwidget \\\"\$widget\\\",\
		    must be one of: [join $comps {, }]\"
	}
    }
    "

    ## The [winfo class %W] will work in this Destroy, which is necessary
    ## to determine if we are destroying the actual megawidget container.
    ## The ${CLASS}_destroy must occur to remove excess state elements.
    ## This will break in Tk4.1p1, but work with any other 4.1+ version.
    bind $CLASS <Destroy> "
    if {\[string compare {} \[widget classes \[winfo class %W\]\]\]} {
	catch {\[winfo class %W\]_destroy %W}
    }
    "

    ## The user is not supposed to change this proc
    ## Instead they create a $CLASS:destroy proc
    ## Some of this may be redundant, but at least it does the job
    ;proc ${CLASS}_destroy {w} "
    upvar \#0 \$w data
    catch { $CLASS:destroy \$w }
    catch { destroy \$data(base) }
    catch { destroy \$w }
    catch { rename \$data(basecmd) {} }
    catch { rename \$data(base) {} }
    catch { rename \$w {} }
    catch { unset data }
    return\n"
    
    if {[string match {} [info commands $CLASS:destroy]]} {
	## The user can optionally provide a special destroy handler
	;proc $CLASS:destroy {w args}  {
	    # empty
	}
    }

    ## The user is not supposed to change this proc
    ;proc ${CLASS}_cget {w args} {
	if {[llength $args] != 1} {
	    return -code error "wrong \# args: should be \"$w cget option\""
	}
	upvar \#0 $w data [winfo class $w] class
	if {[info exists class($args)] && [string match -* $class($args)]} {
	    set args $class($args)
	}
	if {[string match {} [set arg [array names data $args]]]} {
	    set arg [array names data ${args}*]
	}
	set num [llength $arg]
	if {$num==1} {
	    return $data($arg)
	} elseif {$num} {
	    return -code error "ambiguous option \"$args\",\
		    must be one of: [join $arg {, }]"
	} elseif {[catch {$data(basecmd) cget $args} err]} {
	    return -code error $err
	} else {
	    return $err
	}
    }

    ## The user is not supposed to change this proc
    ## Instead they create a $CLASS:configure proc
    ;proc ${CLASS}_configure {w args} {
	upvar \#0 $w data [winfo class $w] class

	set num [llength $args]
	if {$num==1} {
	    if {[info exists class($args)] && \
		    [string match -* $class($args)]} {
		set args $class($args)
	    }
	    if {[string match {} [set arg [array names data $args]]]} {
		set arg [array names data ${args}*]
	    }
	    set num [llength $arg]
	    if {$num==1} {
		## FIX one-elem config
		return "[list $arg] $class($arg) [list $data($arg)]"
	    } elseif {$num} {
		return -code error "ambiguous option \"$args\",\
			must be one of: [join $arg {, }]"
	    } elseif {[catch {$data(basecmd) configure $args} err]} {
		return -code error $err
	    } else {
		return $err
	    }
	} elseif {$num} {
	    ## Group the {key val} pairs to be distributed
	    if {$num&1} {
		set last [lindex $args end]
		set args [lrange $args 0 [incr num -2]]
	    }
	    set widargs {}
	    set cmdargs {}
	    foreach {key val} $args {
		if {[info exists class($key)] && \
			[string match -* $class($key)]} {
		    set key $class($key)
		}
		if {[string match {} [set arg [array names data $key]]]} {
		    set arg [array names data $key*]
		}
		set len [llength $arg]
		if {$len==1} {
		    lappend widargs $arg $val
		} elseif {$len} {
		    set ambarg [list $key $arg]
		    break
		} else {
		    lappend cmdargs $key $val
		}
	    }
	    if {[string compare {} $widargs]} {
		uplevel $class(class):configure [list $w] $widargs
	    }
	    if {[string compare {} $cmdargs] && [catch \
		    {uplevel [list $data(basecmd)] configure $cmdargs} err]} {
		return -code error $err
	    }
	    if {[info exists ambarg]} {
		return -code error "ambiguous option \"[lindex $ambarg 0]\",\
			must be one of: [join [lindex $ambarg 1] {, }]"
	    }
	    if {[info exists last]} {
		return -code error "value for \"$last\" missing"
	    }
	} else {
	    foreach opt [$data(basecmd) configure] {
		set options([lindex $opt 0]) [lrange $opt 1 end]
	    }
	    foreach opt [array names class -*] {
		if {[string match -* $class($opt)]} {
		    set options($opt) [string range $class($opt) 1 end]
		} else {
		    set options($opt) "$class($opt) [list $data($opt)]"
		}
	    }
	    foreach opt [lsort [array names options]] {
		lappend config "$opt $options($opt)"
	    }
	    return $config
	}
    }

    if {[string match {} [info commands $CLASS:configure]]} {
	## The user is intended to rewrite this one
	;proc $CLASS:configure {w args}  {
	    foreach {key val} $args {
		puts "$w: configure $key to [list $value]"
	    }
	}
    }

    set WIDGET(C:$CLASS) {}
    return $CLASS
}


########################################################################
########################## EXAMPLES ####################################
########################################################################

########################################################################
########################## ScrolledText ################################
########################################################################

##------------------------------------------------------------------------
## PROCEDURE
##	scrolledtext
##
## DESCRIPTION
##	Implements a ScrolledText mega-widget
##
## ARGUMENTS
##	scrolledtext <window pathname> <options>
##
## OPTIONS
##	(Any text widget option may be used in addition to these)
##
## -autoscrollbar TCL_BOOLEAN			DEFAULT: 1
##	Whether to have dynamic or static scrollbars.
##
## RETURNS: the window pathname
##
## BINDINGS (in addition to default widget bindings)
##
## SUBCOMMANDS
##	These are the subcmds that an instance of this megawidget recognizes.
##	Aside from those listed here, it accepts subcmds that are valid for
##	text widgets.
##
## configure ?option? ?value option value ...?
## cget option
##	Standard tk widget routines.
##
## subwidget widget
##	Returns the true widget path of the specified widget.  Valid
##	widgets are text, xscrollbar, yscrollbar.
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
## pack [scrolledtext .st -width 40 -height 10] -fill both -exp 1
##
##------------------------------------------------------------------------

## Create a global array with that is the name of the class: ScrolledText
## Each widget created will also have a global array created by the
## instantiation procedure that is the name of the widget (represented
## as $w below).  There three special key names in the $CLASS array:
##
## type
##    the type of base container we want to use (frame or toplevel).
##    This would default to frame.  This widget will be created for us
##    by the constructor function.  The $w array will have a "container"
##    key that will point to the exact widget name.
##
## base
##   the base widget type for this class.  This key is optional and
##   represents what kind of widget will be the base for the class. This
##   way we know what default methods/options you'll have.  If not
##   specified, it defaults to the container type.  
##   To the global $w array, the key "basecmd" will be added by the widget
##   instantiation function to point to a new proc that will be the direct
##   accessor command for the base widget ("text" in the case of the
##   ScrolledText megawidget).  The $w "base" key will be the valid widget
##   name (for passing to [winfo] and such), but "basecmd" will be the
##   valid direct accessor function
##
## components
##   the component widgets of the megawidget.  This is a list of tuples
##   (ie: {{listbox listbox} {scrollbar yscrollbar} {scrollbar xscrollbar}})
##   where each item is in the form {widgettype name}.  These components
##   will be created before the $CLASS:construct proc is called and the $w
##   array will have keys with each name pointing to the appropriate
##   widget in it.  Use these keys to access your subwidgets.  It is from
##   this component list and the base and type about that the subwidget
##   method is created.
##  
## Aside from that, any $CLASS key that matches -* will be considered an
## option that this megawidget handles.  The value can either be a
## 3-tuple list of the form {databaseName databaseClass defaultValue}, or
## it can be one element matching -*, which means this key (say -bd) is
## an alias for the option specified in the value (say -borderwidth)
## which must be specified fully somewhere else in the class array.
##
## If the value is a list beginning with "ALIAS", then the option is derived
## from a component of the megawidget.  The form of the value must be a list
## with the elements:
##	{ALIAS componenttype option ?databasename databaseclass?}
## An example of this would be inheriting a label components anchor:
##	{ALIAS label -anchor labelAnchor Anchor}
## If the databasename is not specified, it determines the final options
## database info from the component and uses the components default value.
## Otherwise, just the components default value is used.
##
## The $w array will be populated by the instantiation procedure with the
## default values for all the specified $CLASS options.
##
array set ScrolledText {
    type	frame
    base	{text text text \
	    {-xscrollcommand [list $data(xscrollbar) set] \
	    -yscrollcommand [list $data(yscrollbar) set]}}
    components	{
	{scrollbar xscrollbar sx {-orient h -bd 1 -highlightthickness 1 \
		-command [list $w xview]}}
	{scrollbar yscrollbar sy {-orient v -bd 1 -highlightthickness 1 \
		-command [list $w yview]}}
    }

    -autoscrollbar	{autoScrollbar AutoScrollbar 1}
}

# Create this to make sure there are registered in auto_mkindex
# these must come before the [widget create ...]
proc ScrolledText args {}
proc scrolledtext args {}
widget create ScrolledText

## Then we "create" the widget.  This makes all the necessary default widget
## routines.  It creates the public accessor functions ($CLASSNAME and
## [string tolower $CLASSNAME]) as well as the public cget, configure, destroy
## and subwidget methods.  The cget and configure commands work like the
## regular Tk ones.  The destroy method is superfluous, as megawidgets will
## respond properly to [destroy $widget] (the Tk destroy command).
## The subwidget method has the following form:
##
##   $widget subwidget name
##	name	- the component widget name
##   Returns the widget patch to the component widget name.
##   Allows the user direct access to your subwidgets.
##
## THE USER SHOULD PROVIDE AT LEAST THE FOLLOWING:
##
## $CLASSNAME:construct {w}		=> return value ignored
##	w	- the widget name, also the name of the global data array
## This procedure is called by the public accessor (instantiation) proc
## right after creating all component widgets and populating the global $w
## array with all the default option values, the "base" key and the key
## names for any other components.  The user should then grid/pack all
## subwidgets into $w.  At this point, the initial configure has not
## occured, so the widget options are all the default.  If this proc
## errors, so does the main creation routine, returning your error.
##
## $CLASSNAME:configure	{w args}	=> return ignored (should be empty)
##	w	- the widget name, also the name of the global data array
##	args	- a list of key/vals (already verified to exist)
## The user should process the key/vals however they require  If this
## proc errors, so does the main creation routine, returning your error.
##
## THE FOLLOWING IS OPTIONAL:
##
## $CLASSNAME:init {w}			=> return value ignored
##	w	- the widget name, also the name of the global data array
## This procedure is called after the public configure routine and after
## the "basecmd" key has been added to the $w array.  Ideally, this proc
## would be used to do any widget specific one-time initialization.
##
## $CLASSNAME:destroy {w}		=> return ignored (should be empty)
##	w	- the widget name, also the name of the global data array
## A default destroy handler is provided that cleans up after the megawidget
## (all state info), but if special cleanup stuff is needed, you would provide
## it in this procedure.  This is the first proc called in the default destroy
## handler.
##

;proc ScrolledText:construct {w} {
    upvar \#0 $w data

    grid $data(text) $data(yscrollbar) -sticky news
    grid $data(xscrollbar) -sticky ew
    grid columnconfig $w 0 -weight 1
    grid rowconfig $w 0 -weight 1
    grid remove $data(yscrollbar) $data(xscrollbar)
    bind $data(text) <Configure> [list ScrolledText:resize $w 1]
}

;proc ScrolledText:configure {w args} {
    upvar \#0 $w data
    set truth {^(1|yes|true|on)$}
    foreach {key val} $args {
	switch -- $key {
	    -autoscrollbar	{
		set data($key) [regexp -nocase $truth $val]
		if {$data($key)} {
		    ScrolledText:resize $w 0
		} else {
		    grid $data(xscrollbar)
		    grid $data(yscrollbar)
		}
	    }
	}
    }
}

;proc ScrolledText_xview {w args} {
    upvar \#0 $w data
    if {[catch {uplevel $data(basecmd) xview $args} err]} {
	return -code error $err
    }
}

;proc ScrolledText_yview {w args} {
    upvar \#0 $w data
    if {[catch {uplevel $data(basecmd) yview $args} err]} {
	return -code error $err
    } elseif {![winfo ismapped $data(xscrollbar)] && \
	    [string compare {0 1} [$data(basecmd) xview]]} {
	## If the xscrollbar was unmapped, but is now needed, show it
	grid $data(xscrollbar)
    }
}

;proc ScrolledText_insert {w args} {
    upvar \#0 $w data
    set code [catch {uplevel $data(basecmd) insert $args} err]
    if {[winfo ismapped $w]} { ScrolledText:resize $w 0 }
    return -code $code $err
}

;proc ScrolledText_delete {w args} {
    upvar \#0 $w data
    set code [catch {uplevel $data(basecmd) delete $args} err]
    if {[winfo ismapped $w]} { ScrolledText:resize $w 1 }
    return -code $code $err
}

;proc ScrolledText:resize {w d} {
    upvar \#0 $w data
    ## Only when deleting should we consider removing the scrollbars
    if {!$data(-autoscrollbar)} return
    if {[string compare {0 1} [$data(basecmd) xview]]} {
	grid $data(xscrollbar)
    } elseif {$d} {
	grid remove $data(xscrollbar)
    }
    if {[string compare {0 1} [$data(basecmd) yview]]} {
	grid $data(yscrollbar)
    } elseif {$d} {
	grid remove $data(yscrollbar)
    }
}
