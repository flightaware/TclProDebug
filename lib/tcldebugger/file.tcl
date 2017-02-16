# file.tcl --
#
#	This file implements the file database that maintains
#	unique file names and a most-recently-used file list.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 

namespace eval file {
    # A list of most-recently-used files in their absolute
    # path form.

    variable mruList     {}
    variable orderedList {}
    variable uniqueList  {}

    variable updateOrdered 1
    variable updateUnique  1
}

# file::update --
#
#	The list of ordered blocks and unique file names
#	is computed lazily and the results are cached 
#	internally.  Call this command when the lists
#	need to be re-computed (e.g. after a break.)
#
# Arguments:
#	hard	Boolean, if true, do a hard update that 
#		resets the mruList to {}.  This should
#		only be true when the app is restarted.
#
# Results:
#	None.

proc file::update {{hard 0}} {
    variable updateOrdered 1
    variable updateUnique  1
    if {$hard} {
	variable mruList     {}
	variable orderedList {}
	variable uniqueList  {}
    }
}

# file::getOrderedBlocks --
#
#	Get an ordered list of open block, where the order
#	is most-recently-used, with any remining blocks
#	appended to the end.
#
# Arguments:
#	None.
#
# Results:
#	Returns an ordered list of blocks.  The list
#	is ordered in a most-recently-used order, then 
#	any remaining blocks are appended to the end.

proc file::getOrderedBlocks {} {
    variable orderedList 
    variable updateOrdered

    if {$updateOrdered} {
	# Copy the list of MRU blocks into the result.  Then
	# append any blocks that are not in the MRU list onto
	# the end of the new list.
	
	set orderedList $file::mruList
	set blockList   [lsort [blk::getFiles]]
	foreach block $blockList {
	    if {[blk::isDynamic $block]} {
		continue
	    }
	    if {[lsearch -exact $file::mruList $block] < 0} {
		lappend orderedList $block
	    }
	}
	set updateOrdered 0
    }
    return $orderedList
}

# file::getUniqueFiles --
#
#	Get a list of open files where each name is a 
#	unique name for the file.  If there are more than
#	one open file with the same name, then the name 
#	will have a unique identifier.
#
# Arguments:
#	None.
#
# Results:
#	Returns a list of tuples containing the unique name
#	and the block number for the file.  The list
#	is ordered in a most-recently-used order, then 
#	any remaining files are appended to the end.

proc file::getUniqueFiles {} {
    variable prevUnique
    variable uniqueList 
    variable updateUnique

    if {$updateUnique} {
	set blockList [file::getOrderedBlocks]
	set uniqueList {}
	foreach block $blockList {
	    set short [file tail [blk::getFile $block]]
	    if {[info exists prevUnique($block)]} {
		# The file previously recieved a unique
		# identifier (i.e "fileName <2>".)  To
		# maintain consistency, use the old ID.

		set short "$short <$prevUnique($block)>"
	    } elseif {[info exists unique($short)]} {
		# A new file has been loaded that matches
		# a previously loaded filename.  Bump
		# the unique ID and append a unique ID,
		# cache the ID for future use.

		incr unique($short)
		set prevUnique($block) $unique($short) 
		set short "$short <$unique($short)>"
	    } else {
		# This is a file w/o a matching name,
		# just initialize the unique ID.

		set unique($short) 1
	    }
	    lappend uniqueList $short $block
	}
	set updateUnique 0
    }
    return $uniqueList
}

# file::getUniqueFile --
#
#	Get the unique name for the block.
#
# Arguments:
#	block	The block type for the file.
#
# Results:
#	The unique name of the block.

proc file::getUniqueFile {block} {
    foreach {file uBlock} [file::getUniqueFiles] {
	if {$uBlock == $block} {
	    return $file
	}
    }
    return ""
}

# file::pushBlock --
#
#	Push a new block onto the list of most-recently-used
#	blocks.
#
# Arguments:
#	block	The block of the file to push onto the stack.
#
# Results:
#	None.

proc file::pushBlock {block} {
    variable mruList

    if {($block != {}) && (![blk::isDynamic $block])} {
	if {[set index [lsearch -exact $mruList $block]] >= 0} {
	    set mruList [lreplace $mruList $index $index]
	}
	set mruList [linsert $mruList 0 $block]
	file::update
    }
}

# file::getUntitledFile --
#
#	Return a filename of <Name><N> where Name is the default name
#	to use and N is the first integer that creates a filename the 
#	doesn't exist in this directory.
#
# Arguments:
#	dir	The directory to search finding name conflicts.
#	name	The default name of the file.
#	ext	The file extension to append to the filename.
#
# Results:
#	A string that is the filename to use.  The directory is not 
#	included in the filename.

proc file::getUntitledFile {dir name ext} {
    for {set i 1} {1} {incr i} {
	if {![file exists [file join $dir ${name}${i}${ext}]]} {
	    return ${name}${i}${ext}
	}
    }
}

