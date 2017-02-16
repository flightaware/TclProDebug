# makeXpm.tcl --
#
#    Alpha Debugger Demo.  This file demonstrates variable and stack data in
#    the debugger.
#
# Copyright (c) 1998 Scriptics Corporation
# See the file "license.terms" for information on usage and redistribution of this file.
#
# RCS: @(#) $Id: makeXpm.tcl,v 1.2 2000/10/31 23:31:13 welch Exp $

proc red {width} {

    upvar sideSpace space

    set color v
    for {set colorCount 0} {$colorCount < $space} {incr colorCount} {
	append result $color
    }

    set color r
    for {set colorCount 0} {$colorCount < $width} {incr colorCount} {
	append result $color
    }
    orange $width result
    for {set colorCount 0} {$colorCount < $width} {incr colorCount} {
	append result $color
    }

    set color v
    for {set colorCount 0} {$colorCount < $space} {incr colorCount} {
	append result $color	
    }
    return $result 
}

proc orange {width var} {

    upvar $var result
    set color o

    for {set colorCount 0} {$colorCount < $width} {incr colorCount} {
	append result $color
    }
    yellow $width result
    for {set colorCount 0} {$colorCount < $width} {incr colorCount} {
	append result $color	
    }
}

proc yellow {width var} {

    upvar $var result
    set color y

    for {set colorCount 0} {$colorCount < $width} {incr colorCount} {
	append result $color
    }
    green $width result
    for {set colorCount 0} {$colorCount < $width} {incr colorCount} {
	append result $color
    }
}

proc green {width var} {

    upvar $var result
    set color g

    for {set colorCount 0} {$colorCount < $width} {incr colorCount} {
	append result $color
    }
    blue $width result
    for {set colorCount 0} {$colorCount < $width} {incr colorCount} {
	append result $color
    }
}

proc blue {width var} {

    upvar $var result
    set color b

    for {set colorCount 0} {$colorCount < $width} {incr colorCount} {
	append result $color	
    }
    indigo $width result
    for {set colorCount 0} {$colorCount < $width} {incr colorCount} {
	append result $color
    }
}

proc indigo {width var} {

    upvar $var result
    upvar \#1 centerSpace space

    set color i
    for {set colorCount 0} {$colorCount < $width} {incr colorCount} {
	append result $color	
    }

    if {$space > 0} {
	set color v
	for {set colorCount 0} {$colorCount < $space} {incr colorCount} {
	    append result $color
	}
	set color i
	for {set colorCount 0} {$colorCount < $width} {incr colorCount} {
	    append result $color
	}
    }
}

proc writeToFile {fileId repeat} {

    global length width outputFile

    set centerSpace 0
    set sideSpace $width

    set fullWidth [expr {$width * $repeat * 13}]
    set fullLength [expr {$length * $repeat * 13}]

    puts $fileId "/* XPM */"
    puts $fileId "static char * $outputFile\[\] = \{"
    puts $fileId "\"$fullWidth $fullLength 7 1\","
    puts $fileId "\"r	c #666666660000\",	/* medium green */"
    puts $fileId "\"o	c #666600006666\",	/* dark blue */"
    puts $fileId "\"y	c #000066666666\",	/* light grey */"
    puts $fileId "\"g	c #444400004444\",	/* light blue */"
    puts $fileId "\"b	c #444444440000\",	/* medium blue */"
    puts $fileId "\"i	c #000044444444\",	/* medium grey */"
    puts $fileId "\"v	c #888800008888\",	/* dark green */"

    for {set lineNumber 1} {$lineNumber <= $fullLength} {incr lineNumber} {

	puts -nonewline $fileId "\""
	
	for {set repeatNumber 0} {$repeatNumber < $repeat} {incr repeatNumber} {
	    puts -nonewline $fileId [red $width]
	}

	if {$lineNumber < $fullLength} {
	    puts $fileId "\","
	    if {[expr {$lineNumber % $length}] == 0} {
		set temp $centerSpace
		set centerSpace $sideSpace
		set sideSpace $temp
	    }
	}
    }
    puts $fileId "\"\};"
}

if {$argc == 4} {

    # the following is a nice sequence for the command line args:
    # 6 8 4 rainbow.xpm

    set repeat [lindex $argv 0]
    set length [lindex $argv 1]
    set width [lindex $argv 2]
    set outputFile [lindex $argv 3]
} else {
    error "command line args required:  repetitions length width file"
}

if {[catch {open $outputFile w} fileId]} {
    error "Cannot open $outputFile for writing:  $fileId"
}

writeToFile $fileId $repeat

close $fileId

exec xv $outputFile
