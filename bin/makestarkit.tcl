#!/usr/bin/env tclsh

set startDir [pwd]

try {
	set binDir [file dir [file norm [file join [info script] .. __dummy__]]]
	cd $binDir
	set appDir [file root [file tail [file dir $binDir]]]
	file delete -force ./$appDir.vfs
	file mkdir ./$appDir.vfs
	set f [open ../starkit.manifest]
	foreach sfile [read $f] {
		file mkdir [file join $appDir.vfs [file dir $sfile]]
		file copy ../$sfile [file join $appDir.vfs $sfile]
	}
	lassign [concat [lindex $argv 0] sdx.kit] sdx
	if {![file isfile $sdx]} {
		error "please specify pathname of sdx.kit on command line."
	}
	exec [info nameofexecutable] $sdx wrap $appDir.kit
} finally {
	close $f
	cd $startDir
}