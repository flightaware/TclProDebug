if {::tcl_platform(platform) ne {windows}} {
	error "package only valid on Windows platform."
}

proc ::kill {pid} {
	exec [auto_execok taskkill] /PID $pid /F
}

proc ::start {args} {
	exec {*}$args &
}

package provide dbgext 2.0