# image.tcl --
#
#	This file is loaded by startup.tcl to populate the image::image
#	array with platform dependent pre-loaded image types to be used
#	throughout the gui.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 

namespace eval image {
    variable image

    # Unix images are of the "photo" type.  We store the photo data in
    # base64 format (converted from gif format) to aid packaging by
    # eliminating binary files.
    
    
    set image(break_disable) [image create photo \
	    -file $::debugger::libdir/images/break_d.gif]
    set image(break_enable) [image create photo \
	    -file $::debugger::libdir/images/break_e.gif]
    set image(var_disable) [image create photo \
	    -file $::debugger::libdir/images/var_d.gif]
    set image(var_enable) [image create photo \
	    -file $::debugger::libdir/images/var_e.gif]
    set image(comboArrow) [image create photo \
	    -file $::debugger::libdir/images/combo_arrow.gif]
    set image(current) [image create photo \
	    -file $::debugger::libdir/images/current.gif]
    set image(current_disable) [image create photo \
	    -file $::debugger::libdir/images/current_d.gif]
    set image(current_enable) [image create photo \
	    -file $::debugger::libdir/images/current_e.gif]
    set image(current_var) [image create photo \
	    -file $::debugger::libdir/images/current_v.gif]
    set image(run_disable) [image create photo \
	    -file $::debugger::libdir/images/go_d.gif]
    set image(run) [image create photo \
	    -file $::debugger::libdir/images/go.gif]
    set image(kill_disable) [image create photo \
	    -file $::debugger::libdir/images/kill_d.gif]
    set image(kill) [image create photo \
	    -file $::debugger::libdir/images/kill.gif]
    set image(restart_disable) [image create photo \
	    -file $::debugger::libdir/images/restart_d.gif]
    set image(restart) [image create photo \
	    -file $::debugger::libdir/images/restart.gif]
    set image(refreshFile_disable) [image create photo \
	    -file $::debugger::libdir/images/refresh_d.gif]
    set image(refreshFile) [image create photo \
	    -file $::debugger::libdir/images/refresh.gif]
    set image(into_disable) [image create photo \
	    -file $::debugger::libdir/images/stepin_d.gif]
    set image(into) [image create photo \
	    -file $::debugger::libdir/images/stepin.gif]
    set image(out_disable) [image create photo \
	    -file $::debugger::libdir/images/stepout_d.gif]
    set image(out) [image create photo \
	    -file $::debugger::libdir/images/stepout.gif]
    set image(over_disable) [image create photo \
	    -file $::debugger::libdir/images/stepover_d.gif]
    set image(over) [image create photo \
	    -file $::debugger::libdir/images/stepover.gif]
    set image(stop_disable) [image create photo \
	    -file $::debugger::libdir/images/stop_d.gif]
    set image(stop) [image create photo \
	    -file $::debugger::libdir/images/stop.gif]
    set image(history_disable) [image create photo \
	    -file $::debugger::libdir/images/history_disable.gif]
    set image(history_enable) [image create photo \
	    -file $::debugger::libdir/images/history_enable.gif]
    set image(history) [image create photo \
	    -file $::debugger::libdir/images/history.gif]
    set image(to_disable) [image create photo \
	    -file $::debugger::libdir/images/stepto_d.gif]
    set image(to) [image create photo \
	    -file $::debugger::libdir/images/stepto.gif]
    set image(cmdresult) [image create photo \
	    -file $::debugger::libdir/images/stepresult.gif]
    set image(cmdresult_disable) [image create photo \
	    -file $::debugger::libdir/images/stepresult_d.gif]
    
    set image(win_break) [image create photo \
	    -file $::debugger::libdir/images/win_break.gif]
    set image(win_eval) [image create photo \
	    -file $::debugger::libdir/images/win_eval.gif]
    set image(win_proc) [image create photo \
	    -file $::debugger::libdir/images/win_proc.gif]
    set image(win_watch) [image create photo \
	    -file $::debugger::libdir/images/win_watch.gif]
    set image(win_cover) [image create photo \
	    -file $::debugger::libdir/images/win_cover.gif]
    
}
