#exec wish "$0" ${1+"$@"}

#
## tkcon.tcl
## Enhanced Tk Console, part of the VerTcl system
##
## Originally based off Brent Welch's Tcl Shell Widget
## (from "Practical Programming in Tcl and Tk")
##
## Thanks to the following (among many) for bug reports & code ideas:
## Steven Wahl <steven@indra.com>, Jan Nijtmans <nijtmans@nici.kun.nl>
## Crimmins <markcrim@umich.edu>, Wart <wart@ugcs.caltech.edu>
##
## Copyright 1995-1997 Jeffrey Hobbs
## Initiated: Thu Aug 17 15:36:47 PDT 1995
##
## jeff.hobbs@acm.org, http://www.cs.uoregon.edu/~jhobbs/
##
## source standard_disclaimer.tcl
## source bourbon_ware.tcl
##

## FIX NOTES - ideas on the block:
## can tkConSplitCmd be used for debugging?
## can return/error be overridden for debugging?
## add double-click to proc editor or man page reader


namespace eval tkCon {

    variable TKCON

    array set TKCON {
	color,blink	\#C7C7C7
	color,proc	\#008800
	color,var	\#ffc0d0
	color,prompt	\#8F4433
	color,stdin	\#000000
	color,stdout	\#0000FF
	color,stderr	\#FF0000

	autoload	{}
	blinktime	1000
	blinkrange	0
	cols		40
	history		48
	lightbrace	1
	lightcmd	1
	maxBuffer	200
	rows		20
	scrollypos	right
	showmultiple	1
	subhistory	1

	appname		{}
	namesp		::
	cmd		{}
	cmdbuf		{}
	cmdsave		{}
	event		1
	histid		0
	errorInfo	{}
	version		1.1
	release		{8 October 1997}
	docs		{http://www.cs.uoregon.edu/research/tcl/script/tkcon/}
	email		{jeff.hobbs@acm.org}
	root		.evalDbgWin
    }

    set TKCON(prompt1) {[history nextid] % }
    set TKCON(A:version)   [info tclversion]
    set TKCON(A:namespace) [string compare {} [info commands namespace]]
}

## tkCon::InitUI - inits UI portion (console) of tkCon
## Creates all elements of the console window and sets up the text tags
# ARGS:	root	- widget pathname of the tkCon console root
#	title	- title for the console root and main (.) windows
# Calls:	 tkCon::Prompt
##
proc tkCon::InitUI {w title} {
    variable TKCON

    set root $TKCON(root)
    set TKCON(base) $w

    # Update history and buffer info that may have been 
    # changed in the prefs window.
    tkCon::update

    ## Text Console
    set TKCON(console) [set con [text $w.text -wrap char \
	    -padx 4 -pady 4 -font $font::metrics(-font) \
	    -yscrollcommand [list $w.sy set] \
	    -foreground $TKCON(color,stdin) \
	    -width $TKCON(cols) -height $TKCON(rows)]]
    bindtags $con [list $con PreCon TkConsole PostCon $root all]

    ## Scrollbar
    set TKCON(scrolly) [scrollbar $w.sy -takefocus 0 -bd 1 \
	    -command [list $con yview]]

    tkCon::Bindings

    pack $w.sy -side $TKCON(scrollypos) -fill y
    pack $con -side left -fill both -expand true

    tkCon::Prompt

    foreach col {prompt stdout stderr stdin proc} {
	$con tag configure $col -foreground $TKCON(color,$col)
    }
    $con tag configure var -background $TKCON(color,var)
    $con tag configure blink -background $TKCON(color,blink)
    $con tag configure disable -background gray25 -borderwidth 0 \
	-bgstipple gray12 


    return $TKCON(console)
}

# tkCon::update --
#
#	Update tkcon data in the TKCON array.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc tkCon::update {} {
    variable TKCON

    set TKCON(maxBuffer) [pref::prefGet screenSize]
    set TKCON(history)   [pref::prefGet historySize]
    history keep $TKCON(history)
}

## tkCon::Eval - evaluates commands input into console window
## This is the first stage of the evaluating commands in the console.
## They need to be broken up into consituent commands (by tkCon::CmdSep) in
## case a multiple commands were pasted in, then each complete command
## is appended to one large statement and passed to tkCon::EvalCmd.  Any
## uncompleted command will not be eval'ed.
# ARGS:	w	- console text widget
# Calls:	tkCon::CmdGet, tkCon::CmdSep, tkCon::EvalCmd
## 
proc tkCon::Eval {w} {
    set incomplete [tkCon::CmdSep [tkCon::CmdGet $w] cmds last]
    $w mark set insert end-1c
    $w insert end \n

    if {[llength $cmds]} {
	set evalCmd {}
	foreach c $cmds {
	    append evalCmd "$c\n"
	}
	tkCon::EvalCmd $w $evalCmd
	$w insert insert $last {}
    } elseif {!$incomplete} {
	tkCon::EvalCmd $w $last
    }
    $w see insert
}

## tkCon::EvalCmd - evaluates a single command, adding it to history
# ARGS:	w	- console text widget
# 	cmd	- the command to evaluate
# Calls:	tkCon::Prompt
# Outputs:	result of command to stdout (or stderr if error occured)
# Returns:	next event number
## 
proc tkCon::EvalCmd {w cmd} {
    variable TKCON
    $w mark set output end
    if {[string compare {} $cmd]} {
	set code 0
	if {$TKCON(subhistory)} {
	    set ev [history nextid]
	    incr ev -1
	    if {[string match !! $cmd]} {
		set code [catch {history event $ev} cmd]
		if {!$code} {$w insert output $cmd\n stdin}
	    } elseif {[regexp {^!(.+)$} $cmd dummy event]} {
		## Check last event because history event is broken
		set code [catch {history event $ev} cmd]
		if {!$code && ![string match ${event}* $cmd]} {
		    set code [catch {history event $event} cmd]
		}
		if {!$code} {$w insert output $cmd\n stdin}
	    } elseif {[regexp {^\^([^^]*)\^([^^]*)\^?$} $cmd dummy old new]} {
		set code [catch {history event $ev} cmd]
		if {!$code} {
		    regsub -all -- $old $cmd $new cmd
		    $w insert output $cmd\n stdin
		}
	    }
	}
	if {$code} {
	    $w insert output $cmd\n stderr
	} else {
	    ## We are about to evaluate the command, so move the limit
	    ## mark to ensure that further <Return>s don't cause double
	    ## evaluation of this command - for cases like the command
	    ## has a vwait or something in it
	    $w mark set limit end
	    history add $cmd
	    set id [evalWin::evalCmd [list eval $cmd]]
	    $w mark set result$id [$w index "end - 2 chars"]
	}
    }
    tkCon::Prompt
    set TKCON(event) [history nextid]
}

## tkCon::EvalSlave - evaluates the args in the associated slave
## args should be passed to this procedure like they would be at
## the command line (not like to 'eval').
# ARGS:	args	- the command and args to evaluate
##
proc tkCon::EvalSlave {args} {
    variable TKCON

    return [evalWin::evalCmd $args]
}

proc tkCon::EvalResult {id code result errInfo errCode} {
    variable TKCON
    
    if {![winfo exists $TKCON(console)]} {
	return
    }
    set w $TKCON(console)

    # If the index of the result is >= limit then the text
    # buffer was cleared and the marks have been altered.
    # Update the index to be the current "output" mark and
    # insert the newline before the result string.  Otherwise
    # the current result mark is valid, just insert the 
    # newine after the result.

    set index [$w index result$id]
    if {[$w compare $index >= limit]} {
	set index output
	set result $result\n
    } else {
	set result \n$result
    }

    if {$code} {
	set TKCON(errorInfo) $errInfo
	$w insert $index $result stderr
    } elseif {[string compare {} $result]} {
	$w insert $index $result stdout
    }
    $TKCON(console) see end
}

## tkCon::CmdGet - gets the current command from the console widget
# ARGS:	w	- console text widget
# Returns:	text which compromises current command line
## 
proc tkCon::CmdGet w {
    if {[string match {} [$w tag nextrange prompt limit end]]} {
	$w tag add stdin limit end-1c
	return [$w get limit end-1c]
    }
}

## tkCon::CmdSep - separates multiple commands into a list and remainder
# ARGS:	cmd	- (possible) multiple command to separate
# 	list	- varname for the list of commands that were separated.
#	last	- varname of any remainder (like an incomplete final command).
#		If there is only one command, it's placed in this var.
# Returns:	constituent command info in varnames specified by list & rmd.
## 
proc tkCon::CmdSep {cmd list last} {
    upvar 1 $list cmds $last inc
    set inc {}
    set cmds {}
    foreach c [split [string trimleft $cmd] \n] {
	if {[string compare $inc {}]} {
	    append inc \n$c
	} else {
	    append inc [string trimleft $c]
	}
	if {[info complete $inc] && ![regexp {[^\\]\\$} $inc]} {
	    if {[regexp "^\[^#\]" $inc]} {lappend cmds $inc}
	    set inc {}
	}
    }
    set i [string compare $inc {}]
    if {!$i && [string compare $cmds {}] && ![string match *\n $cmd]} {
	set inc [lindex $cmds end]
	set cmds [lreplace $cmds end end]
    }
    return $i
}

## tkCon::CmdSplit - splits multiple commands into a list
# ARGS:	cmd	- (possible) multiple command to separate
# Returns:	constituent commands in a list
## 
proc tkCon::CmdSplit {cmd} {
    set inc {}
    set cmds {}
    foreach cmd [split [string trimleft $cmd] \n] {
	if {[string compare {} $inc]} {
	    append inc \n$cmd
	} else {
	    append inc [string trimleft $cmd]
	}
	if {[info complete $inc] && ![regexp {[^\\]\\$} $inc]} {
	    #set inc [string trimright $inc]
	    if {[regexp "^\[^#\]" $inc]} {lappend cmds $inc}
	    set inc {}
	}
    }
    if {[regexp "^\[^#\]" $inc]} {lappend cmds $inc}
    return $cmds
}

## tkCon::Prompt - displays the prompt in the console widget
# ARGS:	w	- console text widget
# Outputs:	prompt (specified in TKCON(prompt1)) to console
## 
proc tkCon::Prompt {{pre {}} {post {}} {prompt {}}} {
    variable TKCON
    if {![winfo exists $TKCON(console)]} {
	return
    }
    set w $TKCON(console)

    set buffer [lindex [split [$w index end] .] 0]
    if {$buffer > $TKCON(maxBuffer)} {
	set newStart [expr {$buffer - $TKCON(maxBuffer)}]
	$w delete 0.0 $newStart.0
    }

    if {[string compare {} $pre]} { $w insert end $pre stdout }
    set i [$w index end-1c]
    if {[string compare {} $TKCON(appname)]} {
	$w insert end ">$TKCON(appname)< " prompt
    }
    if {[string compare :: $TKCON(namesp)]} {
	$w insert end "<$TKCON(namesp)> " prompt
    }
    if {[string compare {} $prompt]} {
	$w insert end $prompt prompt
    } else {
	$w insert end [subst $TKCON(prompt1)] prompt
    }
    $w mark set output $i
    $w mark set insert end
    $w mark set limit insert
    $w mark gravity limit left
    if {[string compare {} $post]} { $w insert end $post stdin }
    $w see "end + 1 lines"
}

## tkCon::Event - get history event, search if string != {}
## look forward (next) if $int>0, otherwise look back (prev)
# ARGS:	W	- console widget
##
proc tkCon::Event {int {str {}}} {
    if {!$int} return

    variable TKCON
    if {![winfo exists $TKCON(console)]} {
	return
    }
    set w $TKCON(console)

    set nextid [history nextid]
    if {[string compare {} $str]} {
	## String is not empty, do an event search
	set event $TKCON(event)
	if {$int < 0 && $event == $nextid} { set TKCON(cmdbuf) $str }
	set len [string len $TKCON(cmdbuf)]
	incr len -1
	if {$int > 0} {
	    ## Search history forward
	    while {$event < $nextid} {
		if {[incr event] == $nextid} {
		    $w delete limit end
		    $w insert limit $TKCON(cmdbuf)
		    break
		} elseif {
		    ![catch {history event $event} res] &&
		    ![string compare $TKCON(cmdbuf) [string range $res 0 $len]]
		} {
		    $w delete limit end
		    $w insert limit $res
		    break
		}
	    }
	    set TKCON(event) $event
	} else {
	    ## Search history reverse
	    while {![catch {history event [incr event -1]} res]} {
		if {![string compare $TKCON(cmdbuf) \
			[string range $res 0 $len]]} {
		    $w delete limit end
		    $w insert limit $res
		    set TKCON(event) $event
		    break
		}
	    }
	} 
    } else {
	## String is empty, just get next/prev event
	if {$int > 0} {
	    ## Goto next command in history
	    if {$TKCON(event) < $nextid} {
		$w delete limit end
		if {[incr TKCON(event)] == $nextid} {
		    $w insert limit $TKCON(cmdbuf)
		} else {
		    $w insert limit [history event $TKCON(event)]
		}
	    }
	} else {
	    ## Goto previous command in history
	    if {$TKCON(event) == $nextid} {
		set TKCON(cmdbuf) [tkCon::CmdGet $w]
	    }
	    if {[catch {history event [incr TKCON(event) -1]} res]} {
		incr TKCON(event)
	    } else {
		$w delete limit end
		$w insert limit $res
	    }
	}
    }
    $w mark set insert end
    $w see end
}

##
## Some procedures to make up for lack of built-in shell commands
##

## clear - clears the buffer of the console (not the history though)
## This is executed in the parent interpreter
## 
proc tkCon::clear {{pcnt 100}} {
    variable TKCON
    if {![winfo exists $TKCON(console)]} {
	return
    }

    if {![regexp {^[0-9]*$} $pcnt] || $pcnt < 1 || $pcnt > 100} {
	return -code error \
		"invalid percentage to clear: must be 1-100 (100 default)"
    } elseif {$pcnt == 100} {
	$TKCON(console) delete 1.0 end
    } else {
	set tmp [expr {$pcnt/100.0*[tkcon console index end]}]
	$TKCON(console) delete 1.0 "$tmp linestart"
    }
}

proc tkCon::Bindings {} {
    variable TKCON
    global tcl_platform tk_version

    #-----------------------------------------------------------------------
    # Elements of tkPriv that are used in this file:
    #
    # char -		Character position on the line;  kept in order
    #			to allow moving up or down past short lines while
    #			still remembering the desired position.
    # mouseMoved -	Non-zero means the mouse has moved a significant
    #			amount since the button went down (so, for example,
    #			start dragging out a selection).
    # prevPos -		Used when moving up or down lines via the keyboard.
    #			Keeps track of the previous insert position, so
    #			we can distinguish a series of ups and downs, all
    #			in a row, from a new up or down.
    # selectMode -	The style of selection currently underway:
    #			char, word, or line.
    # x, y -		Last known mouse coordinates for scanning
    #			and auto-scanning.
    #-----------------------------------------------------------------------

    switch -glob $tcl_platform(platform) {
	win*	{ set TKCON(meta) Alt }
	mac*	{ set TKCON(meta) Command }
	default	{ set TKCON(meta) Meta }
    }

    ## Get all Text bindings into TkConsole
    foreach ev [bind Text] {
	bind TkConsole $ev [bind Text $ev]
    }	
    ## We really didn't want the newline insertion
    bind TkConsole <Control-Key-o> {}

    ## Now make all our virtual event bindings
    foreach {ev key} [subst -nocommand -noback {
	<<TkCon_Tab>>		<Control-i>
	<<TkCon_Tab>>		<$TKCON(meta)-i>
	<<TkCon_Eval>>		<Return>
	<<TkCon_Eval>>		<KP_Enter>
	<<TkCon_Clear>>		<Control-l>
	<<TkCon_Previous>>	<Up>
	<<TkCon_PreviousImmediate>>	<Control-p>
	<<TkCon_PreviousSearch>>	<Control-r>
	<<TkCon_Next>>		<Down>
	<<TkCon_NextImmediate>>	<Control-n>
	<<TkCon_NextSearch>>	<Control-s>
	<<TkCon_Transpose>>	<Control-t>
	<<TkCon_ClearLine>>	<Control-u>
	<<TkCon_SaveCommand>>	<Control-z>
    }] {
	event add $ev $key
	## Make sure the specific key won't be defined
	bind TkConsole $key {}
    }

    ## Redefine for TkConsole what we need
    ##
    event delete <<Paste>> <Control-V>
    tkCon::ClipboardKeysyms <Copy> <Cut> <Paste>

    bind TkConsole <Insert> {
	catch { tkCon::Insert %W [selection get -displayof %W] }
    }

    bind TkConsole <Triple-1> {+
	catch {
	    eval %W tag remove sel [%W tag nextrange prompt sel.first sel.last]
	    eval %W tag remove sel sel.last-1c
	    %W mark set insert sel.first
	}
    }

    ## binding editor needed
    ## binding <events> for .tkconrc

    bind TkConsole <<TkCon_Tab>> {
	if {[%W compare insert >= limit]} {
	    tkCon::Insert %W \t
	}
    }
    bind TkConsole <<TkCon_Eval>> {
	tkCon::Eval %W
    }
    bind TkConsole <Delete> {
	if {[string compare {} [%W tag nextrange sel 1.0 end]] \
		&& [%W compare sel.first >= limit]} {
	    %W delete sel.first sel.last
	} elseif {[%W compare insert >= limit]} {
	    %W delete insert
	    %W see insert
	}
    }
    bind TkConsole <BackSpace> {
	if {[string compare {} [%W tag nextrange sel 1.0 end]] \
		&& [%W compare sel.first >= limit]} {
	    %W delete sel.first sel.last
	} elseif {[%W compare insert != 1.0] && [%W compare insert > limit]} {
	    %W delete insert-1c
	    %W see insert
	}
    }
    bind TkConsole <Control-h> [bind TkConsole <BackSpace>]

    bind TkConsole <KeyPress> {
	tkCon::Insert %W %A
    }
    bind TkConsole <Control-a> {
	if {[%W compare {limit linestart} == {insert linestart}]} {
	    ::tk::TextSetCursor %W limit
	} else {
	    ::tk::TextSetCursor %W {insert linestart}
	}
    }
    bind TkConsole <Control-d> {
	if {[%W compare insert < limit]} break
	%W delete insert
    }
    bind TkConsole <Control-k> {
	if {[%W compare insert < limit]} break
	if {[%W compare insert == {insert lineend}]} {
	    %W delete insert
	} else {
	    %W delete insert {insert lineend}
	}
    }
    bind TkConsole <<TkCon_Clear>> {
	## Clear console buffer, without losing current command line input
	set tkCon::TKCON(tmp) [tkCon::CmdGet %W]
	tkCon::clear
	tkCon::Prompt {} $tkCon::TKCON(tmp)
    }
    bind TkConsole <<TkCon_Previous>> {
	if {[%W compare {insert linestart} != {limit linestart}]} {
	    ::tk::TextSetCursor %W [::tk::TextUpDownLine %W -1]
	} else {
	    tkCon::Event -1
	}
    }
    bind TkConsole <<TkCon_Next>> {
	if {[%W compare {insert linestart} != {end-1c linestart}]} {
	    ::tk::TextSetCursor %W [::tk::TextUpDownLine %W 1]
	} else {
	    tkCon::Event 1
	}
    }
    bind TkConsole <<TkCon_NextImmediate>>  { 
	tkCon::Event 1
    }
    bind TkConsole <<TkCon_PreviousImmediate>> {
	tkCon::Event -1 
    }
    bind TkConsole <<TkCon_PreviousSearch>> { 
	tkCon::Event -1 [tkCon::CmdGet %W] 
    }
    bind TkConsole <<TkCon_NextSearch>>	{ 
	tkCon::Event 1 [tkCon::CmdGet %W] 
    }
    bind TkConsole <<TkCon_Transpose>>	{
	## Transpose current and previous chars
	if {[%W compare insert > "limit+1c"]} { ::tk::TextTranspose %W }
    }
    bind TkConsole <<TkCon_ClearLine>> {
	## Clear command line (Unix shell staple)
	%W delete limit end
    }
    bind TkConsole <<TkCon_SaveCommand>> {
	## Save command buffer (swaps with current command)
	set tkCon::TKCON(tmp) $tkCon::TKCON(cmdsave)
	set tkCon::TKCON(cmdsave) [tkCon::CmdGet %W]
	if {[string match {} $tkCon::TKCON(cmdsave)]} {
	    set tkCon::TKCON(cmdsave) $tkCon::TKCON(tmp)
	} else {
	    %W delete limit end-1c
	}
	tkCon::Insert %W $tkCon::TKCON(tmp)
	%W see end
    }
    catch {bind TkConsole <Key-Up>   { ::tk::TextScrollPages %W -1 }}
    catch {bind TkConsole <Key-Prior>     { ::tk::TextScrollPages %W -1 }}
    catch {bind TkConsole <Key-Down> { ::tk::TextScrollPages %W 1 }}
    catch {bind TkConsole <Key-Next>      { ::tk::TextScrollPages %W 1 }}
    bind TkConsole <$TKCON(meta)-d> {
	if {[%W compare insert >= limit]} {
	    %W delete insert {insert wordend}
	}
    }
    bind TkConsole <$TKCON(meta)-BackSpace> {
	if {[%W compare {insert -1c wordstart} >= limit]} {
	    %W delete {insert -1c wordstart} insert
	}
    }
    bind TkConsole <$TKCON(meta)-Delete> {
	if {[%W compare insert >= limit]} {
	    %W delete insert {insert wordend}
	}
    }
    bind TkConsole <ButtonRelease-2> {
	if {
	    (!$::tk::Priv(mouseMoved) || $tk_strictMotif) && \
	    (![catch {selection get -displayof %W} tkCon::TKCON(tmp)] || \
	    ![catch {selection get -displayof %W -type TEXT} tkCon::TKCON(tmp)]\
	    || ![catch {selection get -displayof %W \
		    -selection CLIPBOARD} tkCon::TKCON(tmp)])
	} {
	    if {[%W compare @%x,%y < limit]} {
		%W insert end $tkCon::TKCON(tmp)
	    } else {
		%W insert @%x,%y $tkCon::TKCON(tmp)
	    }
	    if {[string match *\n* $tkCon::TKCON(tmp)]} {tkCon::Eval %W}
	}
    }

    ##
    ## End TkConsole bindings
    ##

    ##
    ## Bindings for doing special things based on certain keys
    ##
    bind PostCon <Key-parenright> {
	if {$tkCon::TKCON(lightbrace) && $tkCon::TKCON(blinktime)>99 && \
		[string compare \\ [%W get insert-2c]]} {
	    tkCon::MatchPair %W \( \) limit
	}
    }
    bind PostCon <Key-bracketright> {
	if {$tkCon::TKCON(lightbrace) && $tkCon::TKCON(blinktime)>99 && \
		[string compare \\ [%W get insert-2c]]} {
	    tkCon::MatchPair %W \[ \] limit
	}
    }
    bind PostCon <Key-braceright> {
	if {$tkCon::TKCON(lightbrace) && $tkCon::TKCON(blinktime)>99 && \
		[string compare \\ [%W get insert-2c]]} {
	    tkCon::MatchPair %W \{ \} limit
	}
    }
    bind PostCon <Key-quotedbl> {
	if {$tkCon::TKCON(lightbrace) && $tkCon::TKCON(blinktime)>99 && \
		[string compare \\ [%W get insert-2c]]} {
	    tkCon::MatchQuote %W limit
	}
    }
}



# tkCon::ClipboardKeysyms --
# This procedure is invoked to identify the keys that correspond to
# the "copy", "cut", and "paste" functions for the clipboard.
#
# Arguments:
# copy -	Name of the key (keysym name plus modifiers, if any,
#		such as "Meta-y") used for the copy operation.
# cut -		Name of the key used for the cut operation.
# paste -	Name of the key used for the paste operation.

proc tkCon::ClipboardKeysyms {copy cut paste} {
    bind TkConsole <$copy>	{tkCon::Copy %W}
    bind TkConsole <$cut>	{tkCon::Cut %W}
    bind TkConsole <$paste>	{tkCon::Paste %W}
}

proc tkCon::Cut w {
    if {[string match $w [selection own -displayof $w]]} {
	clipboard clear -displayof $w
	catch {
	    clipboard append -displayof $w [selection get -displayof $w]
	    if {[$w compare sel.first >= limit]} {
		$w delete sel.first sel.last
	    }
	}
    }
}
proc tkCon::Copy w {
    if {[string match $w [selection own -displayof $w]]} {
	clipboard clear -displayof $w
	catch {
	    clipboard append -displayof $w [selection get -displayof $w]
	}
    }
}
## Try and get the default selection, then try and get the selection
## type TEXT, then try and get the clipboard if nothing else is available
## Why?  Because the Kanji patch screws up the selection types.
proc tkCon::Paste w {
    if {
	![catch {selection get -displayof $w} tmp] ||
	![catch {selection get -displayof $w -type TEXT} tmp] ||
	![catch {selection get -displayof $w -selection CLIPBOARD} tmp] ||
	![catch {selection get -displayof $w -selection CLIPBOARD \
		-type STRING} tmp]
    } {
	if {[$w compare insert < limit]} {
	    $w mark set insert end
	}
	$w insert insert $tmp
	$w see insert
	if {[string match *\n* $tmp]} {
	    tkCon::Eval $w
	}
    }
}

## tkCon::MatchPair - blinks a matching pair of characters
## c2 is assumed to be at the text index 'insert'.
## This proc is really loopy and took me an hour to figure out given
## all possible combinations with escaping except for escaped \'s.
## It doesn't take into account possible commenting... Oh well.  If
## anyone has something better, I'd like to see/use it.  This is really
## only efficient for small contexts.
# ARGS:	w	- console text widget
# 	c1	- first char of pair
# 	c2	- second char of pair
# Calls:	tkCon::Blink
## 
proc tkCon::MatchPair {w c1 c2 {lim 1.0}} {
    if {[string compare {} [set ix [$w search -back $c1 insert $lim]]]} {
	while {
	    [string match {\\} [$w get $ix-1c]] &&
	    [string compare {} [set ix [$w search -back $c1 $ix-1c $lim]]]
	} {}
	set i1 insert-1c
	while {[string compare {} $ix]} {
	    set i0 $ix
	    set j 0
	    while {[string compare {} [set i0 [$w search $c2 $i0 $i1]]]} {
		append i0 +1c
		if {[string match {\\} [$w get $i0-2c]]} continue
		incr j
	    }
	    if {!$j} break
	    set i1 $ix
	    while {$j && [string compare {} \
		    [set ix [$w search -back $c1 $ix $lim]]]} {
		if {[string match {\\} [$w get $ix-1c]]} continue
		incr j -1
	    }
	}
	if {[string match {} $ix]} { set ix [$w index $lim] }
    } else { set ix [$w index $lim] }
    variable TKCON
    if {$TKCON(blinkrange)} {
	tkCon::Blink $w $ix [$w index insert]
    } else {
	tkCon::Blink $w $ix $ix+1c [$w index insert-1c] [$w index insert]
    }
}

## tkCon::MatchQuote - blinks between matching quotes.
## Blinks just the quote if it's unmatched, otherwise blinks quoted string
## The quote to match is assumed to be at the text index 'insert'.
# ARGS:	w	- console text widget
# Calls:	tkCon::Blink
## 
proc tkCon::MatchQuote {w {lim 1.0}} {
    set i insert-1c
    set j 0
    while {[string compare [set i [$w search -back \" $i $lim]] {}]} {
	if {[string match {\\} [$w get $i-1c]]} continue
	if {!$j} {set i0 $i}
	incr j
    }
    if {[expr {$j&1}]} {
	variable TKCON
	if {$TKCON(blinkrange)} {
	    tkCon::Blink $w $i0 [$w index insert]
	} else {
	    tkCon::Blink $w $i0 $i0+1c [$w index insert-1c] [$w index insert]
	}
    } else {
	tkCon::Blink $w [$w index insert-1c] [$w index insert]
    }
}

## tkCon::Blink - blinks between n index pairs for a specified duration.
# ARGS:	w	- console text widget
# 	i1	- start index to blink region
# 	i2	- end index of blink region
# 	dur	- duration in usecs to blink for
# Outputs:	blinks selected characters in $w
## 
proc tkCon::Blink {w args} {
    variable TKCON
    eval $w tag add blink $args
    after $TKCON(blinktime) eval $w tag remove blink $args
    return
}


## tkCon::Insert
## Insert a string into a text console at the point of the insertion cursor.
## If there is a selection in the text, and it covers the point of the
## insertion cursor, then delete the selection before inserting.
# ARGS:	w	- text window in which to insert the string
# 	s	- string to insert (usually just a single char)
# Outputs:	$s to text widget
## 
proc tkCon::Insert {w s} {
    if {[string match {} $s] || [string match disabled [$w cget -state]]} {
	return
    }
    if {[$w comp insert < limit]} {
	$w mark set insert end
    }
    catch {
	if {[$w comp sel.first <= insert] && [$w comp sel.last >= insert]} {
	    $w delete sel.first sel.last
	}
    }
    $w insert insert $s
    $w see insert
}
