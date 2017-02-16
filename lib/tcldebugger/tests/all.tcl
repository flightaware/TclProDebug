# all.tcl --
#
#	This file contains a top-level script to run all of the
#	tcldebugger tests.
#
# Copyright (c) 1998-2000 by Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 

if {[info exists ::tcltest::testSingleFile]} {
    if {!$::tcltest::testSingleFile} {
	set saveOutput $::tcltest::temporaryDirectory
    }   
}

lappend auto_path [file join [file dirname [info script]] ..]
package require protest
catch {namespace import ::protest::*}

if {[info exists saveOutput]} {
    set ::tcltest::temporaryDirectory $saveOutput
}

puts "Temporary files stored in $::tcltest::temporaryDirectory"
set timeCmd {clock format [clock seconds]}
puts stdout "Tests began at [eval $timeCmd]"

if {$tcl_platform(platform) == "windows"} {
    ::protest::testAllFiles "" wish$::protest::currentVersion(Tk-short)
} else {
    ::protest::testAllFiles "" wish$::protest::currentVersion(Tk)
}

set numFailures [llength $::tcltest::failFiles]

puts stdout "\nTests ended at [eval $timeCmd]"
::tcltest::cleanupTests 1

if {$numFailures > 0} {
    return -code error -errorcode $numFailures \
	    -errorinfo "Found $numFailures test file failures"
} else {
    return
}
