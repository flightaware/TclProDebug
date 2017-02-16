# bindings.tcl --
#
#	This file implemennts the common APIs for creating
#	the bindtags and establishing common bindings.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 

namespace eval bind {
    # Watch Window - Actions
    bind watchBind <<Dbg_DataDisp>> {
	menu::accKeyPress <<Dbg_DataDisp>>
    }
    bind watchBind <Double-1> {
	watch::showInspectorFromIndex %W current
    }
    bind watchBind <Return> {
        watch::toggleVBP %W [sel::getCursor %W].0 onoff
    }
    bind watchBind <Control-Return> {
        watch::toggleVBP %W [sel::getCursor %W].0 enabledisable
    }
    bind watchBind <Left> {
        watch::expandOrFlattenArray %W [sel::getCursor %W].0 flatten
    }
    bind watchBind <Right> {
        watch::expandOrFlattenArray %W [sel::getCursor %W].0 expand
    }
    bind watchBind <Configure> {
	watch::configure %W
    }
    bind watchBind <<Copy>> {
	watch::copy %W
    }
    bind watchBind <<Cut>> {
	watch::copy %W
    }

    # Watch Window - Scrolling
    bind watchBind <B1-Leave> {
	set watch::priv(x,%W) %x
	set watch::priv(y,%W) %y
	watch::tkTextAutoScan %W
	break
    }
    bind watchBind <B1-Enter> {
	watch::tkCancelRepeat %W
	break
    }

    # Watch Window - Select Line
    bind watchBind <<Dbg_SelAll>> {
	watch::selectAllLines %W
    }
    bind watchBind <1> {
	watch::initSelection %W current
    }
    bind watchBind <ButtonRelease-1> {
	watch::tkCancelRepeat %W
	if {[info exists watch::text(valu,%W)] \
		&& ([$watch::text(valu,%W) index @0,%y] == \
		$sel::selectStart($watch::text(valu,%W)))} {
	    watch::selectLine %W @0,%y
	}
   }
    bind watchBind <Key-Up> {
	watch::moveSelection %W -1
    }
    bind watchBind <Key-Down> {
	watch::moveSelection %W 1
    }
    bind watchBind <Prior> {
	watch::selectLine %W [sel::scrollPages %W -1]
    }
    bind watchBind <Next> {
	watch::selectLine %W [sel::scrollPages %W 1]
    }
    bind watchBind <Home> {
	watch::selectLine %W 1.0
    }
    bind watchBind <End> {
	watch::selectLine %W "end - 2 lines"
    }

    # Watch Window - Select Range
    bind watchBind <B1-Motion> {
	set watch::priv(x,%W) %x
	set watch::priv(y,%W) %y
	watch::selectLineRange %W @0,%y
    }
    bind watchBind <Shift-1> {
	watch::selectLineRange %W @0,%y
    }
    bind watchBind <Shift-Key-Up> {
	watch::moveSelectionRange %W -1
    }
    bind watchBind <Shift-Key-Down> {
	watch::moveSelectionRange %W 1
    }
    bind watchBind <Shift-Key-space> {
	watch::selectCursorRange %W
    }
    bind watchBind <Shift-Prior> {
	watch::selectLineRange %W [sel::scrollPages %W -1]
    }
    bind watchBind <Shift-Next> {
	watch::selectLineRange %W [sel::scrollPages %W 1]
    }
    bind watchBind <Shift-Home> {
	watch::selectLineRange %W 1.0
    }
    bind watchBind <Shift-End> {
	watch::selectLineRange %W "end - 2 lines"
    }

    # Watch Window - Move/Select Cursor
    bind watchBind <Control-ButtonRelease-1> {
	watch::selectMultiLine %W @0,%y
    }
    bind watchBind <Control-Key-Up> {
	watch::moveCursor %W -1;
    }
    bind watchBind <Control-Key-Down> {
	watch::moveCursor %W 1;
    }
    bind watchBind <Control-Prior> {
	watch::moveCursorToIndex %W [sel::scrollPages %W -1]
    }
    bind watchBind <Control-Next> {
	watch::moveCursorToIndex %W [sel::scrollPages %W 1]
    }
    bind watchBind <Control-Home> {
	watch::moveCursorToIndex %W 1.0
    }
    bind watchBind <Control-End> {
	watch::moveCursorToIndex %W "end - 1 lines"
    }
    bind watchBind <Key-space> {
	watch::selectCursor %W
    }
    bind watchBind <Control-Key-space> {
	watch::toggleCursor %W
    }
    bind watchBind <Control-Double-1> {
	break
    }
    bind watchBind <Shift-Double-1> {
	break
    }
    bind watchBind <Control-B1-Motion> {
	break
    }
    bind watchBind <Shift-B1-Motion> {
	break
    }

    bind noEdit <B1-Leave> {
	set ::tk::Priv(x) %x
	set ::tk::Priv(y) %y
	code::tkTextAutoScan $code::codeWin
	break;
    }
    bind noEdit <B1-Enter> {
	::tk::CancelRepeat
	break
    }
    bind noEdit <ButtonRelease-1> {
	::tk::CancelRepeat
	break
    }
    bind noEdit <1> {
	::tk::TextButton1 %W %x %y
	%W tag remove sel 0.0 end
    }
    bind noEdit <B1-Motion> {
	set ::tk::Priv(x) %x
	set ::tk::Priv(y) %y
	::tk::TextSelectTo %W %x %y
    }
    bind noEdit <Double-1> {
	set ::tk::Priv(selectMode) word
	::tk::TextSelectTo %W %x %y
	catch {%W mark set insert sel.first}
    }
    bind noEdit <Triple-1> {
	set ::tk::Priv(selectMode) line
	::tk::TextSelectTo %W %x %y
	catch {%W mark set insert sel.first}
    }
    bind noEdit <Shift-1> {
	::tk::TextResetAnchor %W @%x,%y
	set ::tk::Priv(selectMode) char
	::tk::TextSelectTo %W %x %y
    }
    bind noEdit <Double-Shift-1>	{
	set ::tk::Priv(selectMode) word
	::tk::TextSelectTo %W %x %y
    }
    bind noEdit <Triple-Shift-1>	{
	set ::tk::Priv(selectMode) line
	::tk::TextSelectTo %W %x %y
    }
    bind noEdit <B1-Leave> {
	set ::tk::Priv(x) %x
	set ::tk::Priv(y) %y
	::tk::TextAutoScan %W
    }
    bind noEdit <B1-Enter> {
	::tk::CancelRepeat
    }
    bind noEdit <ButtonRelease-1> {
	::tk::CancelRepeat
    }
    bind noEdit <Control-1> {
	%W mark set insert @%x,%y
    }
    bind noEdit <Left> {
	::tk::TextSetCursor %W insert-1c
    }
    bind noEdit <Right> {
	::tk::TextSetCursor %W insert+1c
    }
    bind noEdit <Up> {
	::tk::TextSetCursor %W [::tk::TextUpDownLine %W -1]
    }
    bind noEdit <Down> {
	::tk::TextSetCursor %W [::tk::TextUpDownLine %W 1]
    }
    bind noEdit <Shift-Left> {
	::tk::TextKeySelect %W [%W index {insert - 1c}]
    }
    bind noEdit <Shift-Right> {
	::tk::TextKeySelect %W [%W index {insert + 1c}]
    }
    bind noEdit <Shift-Up> {
	::tk::TextKeySelect %W [::tk::TextUpDownLine %W -1]
    }
    bind noEdit <Shift-Down> {
	::tk::TextKeySelect %W [::tk::TextUpDownLine %W 1]
    }
    bind noEdit <Control-Left> {
	::tk::TextSetCursor %W [::tk::TextPrevPos %W insert tcl_startOfPreviousWord]
    }
    bind noEdit <Control-Right> {
	::tk::TextSetCursor %W [::tk::TextNextWord %W insert]
    }
    bind noEdit <Control-Up> {
	::tk::TextSetCursor %W [::tk::TextPrevPara %W insert]
    }
    bind noEdit <Control-Down> {
	::tk::TextSetCursor %W [::tk::TextNextPara %W insert]
    }
    bind noEdit <Shift-Control-Left> {
	::tk::TextKeySelect %W [::tk::TextPrevPos %W insert tcl_startOfPreviousWord]
    }
    bind noEdit <Shift-Control-Right> {
	::tk::TextKeySelect %W [::tk::TextNextWord %W insert]
    }
    bind noEdit <Shift-Control-Up> {
	::tk::TextKeySelect %W [::tk::TextPrevPara %W insert]
    }
    bind noEdit <Shift-Control-Down> {
	::tk::TextKeySelect %W [::tk::TextNextPara %W insert]
    }
    bind noEdit <Prior> {
	::tk::TextSetCursor %W [::tk::TextScrollPages %W -1]
    }
    bind noEdit <Shift-Prior> {
	::tk::TextKeySelect %W [::tk::TextScrollPages %W -1]
    }
    bind noEdit <Next> {
	::tk::TextSetCursor %W [::tk::TextScrollPages %W 1]
    }
    bind noEdit <Shift-Next> {
	::tk::TextKeySelect %W [::tk::TextScrollPages %W 1]
    }
    bind noEdit <Control-Prior> {
	%W xview scroll -1 page
    }
    bind noEdit <Control-Next> {
	%W xview scroll 1 page
    }
    bind noEdit <Home> {
	::tk::TextSetCursor %W {insert linestart}
    }
    bind noEdit <Shift-Home> {
	::tk::TextKeySelect %W {insert linestart}
    }
    bind noEdit <End> {
	::tk::TextSetCursor %W {insert lineend}
    }
    bind noEdit <Shift-End> {
	::tk::TextKeySelect %W {insert lineend}
    }
    bind noEdit <Control-Home> {
	::tk::TextSetCursor %W 1.0
    }
    bind noEdit <Control-Shift-Home> {
	::tk::TextKeySelect %W 1.0
    }
    bind noEdit <Control-End> {
	::tk::TextSetCursor %W {end - 1 char}
    }
    bind noEdit <Control-Shift-End> {
	::tk::TextKeySelect %W {end - 1 char}
    }
    bind noEdit <Control-space> {
	%W mark set anchor insert
    }
    bind noEdit <Select> {
	%W mark set anchor insert
    }
    bind noEdit <Control-Shift-space> {
	set ::tk::Priv(selectMode) char
	::tk::TextKeyExtend %W insert
    }
    bind noEdit <Shift-Select> {
	set ::tk::Priv(selectMode) char
	::tk::TextKeyExtend %W insert
    }
    bind noEdit <Control-slash> {
	%W tag add sel 1.0 end
    }
    bind noEdit <Control-backslash> {
	%W tag remove sel 1.0 end
    }
    bind noEdit <<Copy>> {
	tk_textCopy %W
    }
    bind noEdit <<Cut>> {
	tk_textCopy %W
    }
    bind noEdit <MouseWheel> {
	%W yview scroll [expr - (%D / 120) * 4] units
    }
    bind noEdit <Alt-KeyPress> {
	# nothing 
    }
    bind noEdit <Meta-KeyPress> {
	# nothing
    }
    bind noEdit <Control-KeyPress> {
	# nothing
    }
    bind noEdit <Escape> {
	# nothing
    }
    bind noEdit <KP_Enter> {
	# nothing
    }
    if {$tcl_platform(platform) == "macintosh"} {
	bind noEdit <Command-KeyPress> {# nothing}
    }

    # Create the key binding in the Main Debugger Window.
    # This will create bindings on the Stack, Var and
    # Code Windows that are common in all three.

    if { [string equal $::tcl_platform(platform) "windows"] } {
	set mainKeyBindings [list \
	    <<Proj_New>> <<Proj_Open>> <<Proj_Close>> <<Proj_Save>> \
	    <<Proj_Settings>> <<Dbg_Open>> <<Dbg_Refresh>> <<Dbg_Exit>> \
	    <<Dbg_Pref>> <<Dbg_Find>> <<Dbg_FindNext>> <<Dbg_Goto>> \
	    <<Dbg_TclHelp>> <<Dbg_Help>> <<Dbg_Run>> <<Dbg_In>> \
	    <<Dbg_Over>> <<Dbg_Out>> <<Dbg_To>> <<Dbg_CmdResult>> \
	    <<Dbg_Stop>> \
	    <<Dbg_Kill>> <<Dbg_Restart>> <<Dbg_Break>> <<Dbg_Eval>> \
	    <<Dbg_Proc>> <<Dbg_Watch>> <<Dbg_DataDisp>>]
	
    } else {
	# On non-windows, there is no Tcl/Tk Help

	set mainKeyBindings [list \
	    <<Proj_New>> <<Proj_Open>> <<Proj_Close>> <<Proj_Save>> \
	    <<Proj_Settings>> <<Dbg_Open>> <<Dbg_Refresh>> <<Dbg_Exit>> \
	    <<Dbg_Pref>> <<Dbg_Find>> <<Dbg_FindNext>> <<Dbg_Goto>> \
	    <<Dbg_Help>> <<Dbg_Run>> <<Dbg_In>> \
	    <<Dbg_Over>> <<Dbg_Out>> <<Dbg_To>> <<Dbg_CmdResult>> \
	    <<Dbg_Stop>> \
	    <<Dbg_Kill>> <<Dbg_Restart>> <<Dbg_Break>> <<Dbg_Eval>> \
	    <<Dbg_Proc>> <<Dbg_Watch>> <<Dbg_DataDisp>>]
    }

    foreach virtual $mainKeyBindings {
	bind mainDbgWin $virtual "\
		menu::accKeyPress $virtual; \
		break;
	"
    }
    bind mainDbgWin <KeyPress> {
	# No op.
    }

    # To protect against key stokes being entered at 
    # inappropriate times append this bind tag to the
    # text widget.  Note that we need to pass through any
    # bindings that appear on "all" so system menus continue
    # to function properly.

    bind disableKeys <Key> {
	break
    }
    foreach binding [bind all] {
	bind disableKeys $binding {continue}
    }

    bind disableButtons <Any-1> {
	break
    }
    bind disableButtons <Any-2> {
	break
    }
    bind disableButtons <Any-3> {
	break
    }
    bind disableButtons <ButtonRelease-1> {
	break
    }
    bind disableButtons <ButtonRelease-2> {
	break
    }
    bind disableButtons <ButtonRelease-3> {
	break
    }
    bind disableButtons <B1-Motion> {
	break
    }
    bind disableButtons <B2-Motion> {
	break
    }
    bind disableButtons <B3-Motion> {
	break
    }
}

# bind::addBindTags --
#
#	Add bindtags to the widget.
#
# Arguments:
#	w		The widget to add the tags to.
#	tags		A list of tags to add.
#	prepend		Boolean, true means append the tags
#			to the front of the existing list.
#
# Results:
#	None.

proc bind::addBindTags {w tags {prepend 1}} {
    set curTags [bindtags $w]
    if {$prepend} {
	set newTags [join [list $tags $curTags] { }]
    } else {
	set newTags [join [list $curTags $tags] { }]
    }   
    bindtags $w $newTags
}

# bind::removeBindTag --
#
#	Remove the first occurence of tag from the bindtags list.
#
# Arguments:
#	w		The widget to remove the tags from.
#	tags		A tag to remove.
#
# Results:
#	None.

proc bind::removeBindTag {w tag} {
    set tags [bindtags $w]
    if {[set index [lsearch $tags $tag]] >= 0} {
	set tags [lreplace $tags $index $index]
	bindtags $w $tags
    }
}

# bind::tagExists --
#
#	Determine if a tag is already in the tag list.
#
# Arguments:
#	w		The widget to search for tag.
#	tags		A list of tags to add.
#
# Results:
#	Boolean, true if the tag is in the tag list.

proc bind::tagExists {w tag} {
    set tags [bindtags $w]
    if {[set index [lsearch $tags $tag]] >= 0} {
	return 1
    }
    return 0
}


# bind::commonBindings --
#
#	Add common bindings to the widget and create the 
#	tab order.
#
# Arguments:
#	tags		A list of tags to add.
#	tabOrder	The tab order for the bindtag.
#
# Results:
#	None.

proc bind::commonBindings {tag tabOrder} {
    bind $tag <<Dbg_Close>> {
	destroy [winfo toplevel %W]
    }

    if {$tabOrder != {}} {
	bind $tag <Key-Tab> "bind::tabNext \%W $tabOrder;break"
	bind $tag <Shift-Key-Tab> "bind::tabPrev \%W $tabOrder;break"
    }
}

# bind::tabNext --
#
#	Tab to the next widget accepting focus.
#
# Arguments:
#	w		The widget with the current focus.
#	args		The tab order list.
#
# Results:
#	None.

proc bind::tabNext {w args} {
    set len   [llength $args]
    set index [lsearch -exact $args $w]

    if {$index == ($len - 1)} {
	set next 0
    } else {
	set next [expr {$index + 1}]
    }

    if {[string match {\[*} $next]} {
	set next [uplevel #0 $next]
    }

    while {![::tk::FocusOK [lindex $args $next]]} {
	incr next
	if {$next == $index} {
	    break
	}
	if {$next == $len} {
	    set next 0
	}
	if {[string match {\[*} $next]} {
	    set next [uplevel #0 $next]
	}
    }
    focus [lindex $args $next]
}

# bind::tabPrev --
#
#	Tab to the previous widget accepting focus.
#
# Arguments:
#	w		The widget with the current focus.
#	args		The tab order list.
#
# Results:
#	None.

proc bind::tabPrev {w args} {
    set len   [llength $args]
    set end   [expr {$len - 1}]
    set index [lsearch -exact $args $w]

    set next [expr {$index - 1}]
    if {$next < 0} {
	set next $end
    }

    while {![::tk::FocusOK [lindex $args $next]]} {
	incr next -1
	if {$next == $index} {
	    break
	}
	if {$next < 0} {
	    set next $end
	}
    }
    focus [lindex $args $next]
}
