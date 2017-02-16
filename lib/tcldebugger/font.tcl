# font.tcl --
#
#	This file implements the font system that is used by 
#	all debugger text widgets that require a fixed font.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 

namespace eval font {
    variable fontList {}
    variable metrics
}

# font::createFontData --
#
#	Generate a list of fixed fonts on this system.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc font::createFontData {} {
    variable validFonts
    variable fontList

    font create findFixed
    set foundFixed 0
    set fontList   {}

    foreach font [system::getFontList] {
	font configure findFixed -family $font -size 10
	if {([font metrics findFixed -fixed]) && \
		[font actual findFixed -family] == $font} {
	    set foundFixed 1
	    lappend fontList $font
	}
    }
    if {!$foundFixed} {
	error "could not locate a fixed font on this system."
    }
    if {$fontList == {}} {
	error "could not find min size a fixed font on this system."
    }
    set fontList [lsort $fontList]
    font delete findFixed
}

# font::getFonts --
#
#	Return the list of valid fixed fonts.
#
# Arguments:
#	None.
#
# Results:
#	A list containing valid fonts.

proc font::getFonts {} {
    variable fontList
    
    if {$fontList == {}} {
	font::createFontData
    }
    return $fontList
}

# font::configure --
#
#	Set or reset font data the is used by the various widgets.
#
# Arguments:
#	font	The new font family to use.
#	size 	The requested size of the font.
#
# Results:
#	None.  The metrics array will be re-initalized with
#	new data about the currently selected font.  Use the
#	font::get command to retrieve font data.

proc font::configure {font size} {
    variable metrics
    
    set family [font actual [list $font] -family]
    if {[lsearch [font names] dbgFixedFont] < 0} {
	font create dbgFixedFont -family $family -size $size
	font create dbgFixedItalicFont -family $family -size $size \
		-slant italic
	font create dbgFixedBoldFont -family $family -size $size -weight bold
    } else {
	font configure dbgFixedFont -family $family -size $size
	font configure dbgFixedItalicFont -family $family -size $size \
		-slant italic
	font configure dbgFixedBoldFont -family $family -size $size \
		-weight bold
    }

    # Store as much info about the font as possible.  Including:
    # the actual family and size, font metrics, the same family
    # only with italics and bold, and the width of a single 
    # fixed character.

    if {[info exists metrics]} {
	unset metrics
    }
    array set metrics [font actual  dbgFixedFont]
    array set metrics [font metrics dbgFixedFont]
    set metrics(-font)       dbgFixedFont
    set metrics(-fontItalic) dbgFixedItalicFont
    set metrics(-fontBold)   dbgFixedBoldFont
    set metrics(-width)      [font measure $metrics(-font) "W"]
    set metrics(-maxchars) [expr {[winfo screenwidth .]/$metrics(-width)}]

    return [list $font $size]
}

# font::get --
#
#	Get data about the selected fixed font.
#
# Arguments:
#	option 	An option to request of the font.  Valid options are:
#		-ascent		-descent
#		-family		-fixed
#		-font		-fontBold
#		-fontItalic	-linespace
#		-overstrike	-size
#		-slant		-underline
#		-weight		-width
#
# Results:
#	Data about the font or empty string if no data exists.

proc font::get {option} {
    variable metrics

    if {[info exists metrics($option)]} {
	return $metrics($option)
    } else {
	return {}
    }
}




