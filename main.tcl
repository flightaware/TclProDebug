#!/usr/bin/env tclsh

# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.

# This is the only way to know definitively if a package is available without
# putting "package require" in a catch statement.  Catch statement is bad
# because it hides the errors you don't anticipate as well as the ones you do:
if {"starkit" ni [package names]} {
	eval [package unknown] starkit
}

# Now "package names" holds the definitive answer as to whether the desired
# package is available:
if {"starkit" in [package names]} {
	package require starkit

	# unset existing state vars in case this is a nested starkit and 
	# startup has been done before:
	unset -nocomplain ::starkit::mode ::starkit::topdir

	::starkit::startup

	# Starkits predate Tcl modules.  Starkit boot doesn't anticipate that
	# module paths may lie outside starkit dir, thus losing true
	# encapsulation.
	# In case this is a starpack, strip out module paths outside the vfs,
	# thus ensuring only modules loaded are those within the vfs:
	set tpaths [::tcl::tm::path list]
	if {$::starkit::mode ne {starpack}} {
		set tpaths {}
	}
	foreach tpath $tpaths {
		if {[string first $::starkit::topdir/ $tpath/]} {
			::tcl::tm::path remove $tpath
		}
	}

} else {
	# Should be possible to run an unwrapped starkit even without starkit
	# package.  If missing, do the things ::starkit::startup would do:
	namespace eval ::starkit {
		set topscript [
			file dirname [
				file norm [
					file join [info script] x
				]
			]
		]
		variable topdir [file dirname $topscript]
		variable mode sourced
		if {$topscript eq [
			file dirname [
				file norm [
					file join $::argv0 x
				]
			]
		]} {
			variable mode unwrapped
		}
	}

	if {
		[lsearch -exact $::auto_path $::starkit::topdir/lib] < 0 &&
		[file isdir $::starkit::topdir/lib]
	} {
		lappend ::auto_path $::starkit::topdir/lib
	}
}

unset -nocomplain tpath tpaths topscript

# If this is the first starkit started, save state variables in global space
# so that any nested starkit can access them:
if {![info exists topdir]} {
	set topdir $::starkit::topdir
	set mode $::starkit::mode
}

# Add module path within package lib path:
::tcl::tm::path add [file dirname $::starkit::topdir]//[file tail $::starkit::topdir]/lib/tm

source $::starkit::topdir/src/startup.tcl

