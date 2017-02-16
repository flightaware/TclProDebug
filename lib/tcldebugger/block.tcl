# block.tcl --
#
#	This file contains functions that maintain the block data structure.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 

package provide blk 1.0
namespace eval blk {
    # block data type --
    #
    #   A block encapsulates the state associated with a unit of 
    #   instrumented code.  Each block is represented by a Tcl array
    #   whose name is of the form blk<num> and contains the
    #   following elements:
    #		file		The name of the file that contains this
    #				block.  May be null if the block contains
    #				dynamic code.
    #		script		The original uninstrumented script.
    #		version		A version counter for the contents of
    #				the block.
    #		instrumented	Indicates that a block represents instrumented
    #				code.
    #		lines		A list of line numbers in the script that
    #				contain the start of a debugged statement.
    #				These are valid breakpoint lines.
    #
    # Fields:
    #	blockCounter	This counter is used to generate block names.
    #	blockFiles	This array maps from file names to blocks.
    #	blkTemp		This block is the shared temporary block.  It is
    #			used for showing uninstrumented code.

    variable blockCounter 0
    array set blockFiles {}
    array set blkTemp {file {} version 0 instrumented 0 script {} lines {}}
}
# end namespace blk

# blk::makeBlock --
#
#	Retrieve the block associated with a file, creating a new
#	block if necessary.
#
# Arguments:
#	file	The file that contains the block or {} for dynamic blocks.
#
# Results:
#	Returns the block identifier.

proc blk::makeBlock {file} {
    variable blockCounter
    variable blockFiles

    # check to see if the block already exists
    
    set formatFile [system::formatFilename $file]
    if {[info exists blockFiles($formatFile)]} {
	return $blockFiles($formatFile)
    }

    # find an unallocated block number and create the array

    incr blockCounter
    while {[info exists ::blk::blk$blockCounter]} {
	incr blockCounter
    }
    array set ::blk::blk${blockCounter} [list \
	    file $file \
	    version 0 \
	    instrumented 0 lines {}]
    
    # don't create an entry for dynamic blocks

    if {$file != ""} {
	set blockFiles($formatFile) $blockCounter
    }
    return $blockCounter
}

# blk::release --
#
#	Release the storage associated with one or more blocks.
#
# Arguments:
#	args	The blocks to release, "dynamic" to release all dynamic
#		blocks, or "all" to release all blocks.
#
# Results:
#	None.

proc blk::release {args} {
    if {$args == "dynamic"} {
	foreach block [info var ::blk::blk*] {
	    if {[set ${block}(file)] == ""} {
		unset $block
	    }
	}
    } elseif {$args == "all"} {
	if {[info exists ::blk::blockFiles]} {
	    unset ::blk::blockFiles
	}
	set all [info var ::blk::blk*]
	if {$all != ""} {
	    eval unset $all
	}
    } else {
	foreach block $args {
	    if {! [info exists ::blk::blk$block]} {
		continue
	    }
	    set file [getFile $block]
	    if {$file != ""} {
		unset ::blk::blockFiles([system::formatFilename $file])
	    }
	    unset ::blk::blk$block
	}
    }

    if {! [info exists ::blk::blkTemp]} {
	array set ::blk::blkTemp {file {} version 0 instrumented 0 script {}
	lines {}}
    }
}

# blk::exists --
#
#	Determine if the block still exists.
#
# Arguments:
#	blockNum	The block to check for existence.
#
# Results:
#	Return 1 if the block exists.

proc blk::exists {blockNum} {
    return [info exists ::blk::blk${blockNum}(instrumented)]
}


# blk::getSource --
#
#	Return the script associated with a block.  If block's script
#	has never been set, open the file and read the contents.
#
# Arguments:
#	blockNum	The block number.
#
# Results:
#	Returns the script.

proc blk::getSource {blockNum} {
    upvar #0 ::blk::blk$blockNum block

    if {[info exists block(script)]} {
	return $block(script)
    } elseif {$block(file) != ""} {
	set fd [open $block(file) r]
	set script [read $fd]
	close $fd
	incr block(version)
	return $script
    } else {
	return ""
    }
}

# blk::getFile --
#
#	Return the name associated with the given block.
#
# Arguments:
#	blockNum	The block number.
#
# Results:
#	Returns the file name or {} if the block is dynamic.

proc blk::getFile {blockNum} {
    return [set ::blk::blk${blockNum}(file)]
}

# blk::getLines --
#
#	Return the list of line numbers that represent valid
#	break-points for this block.  If the block does not
#	exist or the block is not instrumented we return -1.
#
# Arguments:
#	blockNum	The block number.
#
# Results:
#	Returns a list of line numbers.

proc blk::getLines {blockNum} {
    if {! [info exists ::blk::blk${blockNum}(instrumented)] \
	    || ! [set ::blk::blk${blockNum}(instrumented)]} {
	return -1
    }
    return [set ::blk::blk${blockNum}(lines)]
}

# blk::getRanges --
#
#     Return the list of ranges that represent valid
#     break-pints for this block.  If the block does not
#     exist or the block is not instrumented, we return -1.
#
# Arguments:
#     blockNum        The block number.
#
# Results:
#     Returns a list of range numbers.

proc blk::getRanges {blockNum} {
    if {! [info exists ::blk::blk${blockNum}(instrumented)]} {
      return -1
    }
    if {! [set ::blk::blk${blockNum}(instrumented)]} {
      return -1
    }
    return [lsort [set ::blk::blk${blockNum}(ranges)]]
}

# blk::Instrument --
#
#	Set the source script associated with a block and return the
#	instrumented form.
#
# Arguments:
#	blockNum	The block number.
#	script		The new source for the block that should be
#			instrumented.
#
# Results:
#	Returns the instrumented script.

proc blk::Instrument {blockNum script} {
    SetSource $blockNum $script
    set script [instrument::Instrument $blockNum]

    # Don't mark the block as instrumented unless we have successfully
    # completed instrumentation.

    if {$script != ""} {
	set ::blk::blk${blockNum}(instrumented) 1

	# Compute the sorted list of line numbers containing statements.
	# We need to suppress duplicates since there may be more than one
	# statement per line.

	if {[info exists tmp]} {
	    unset tmp
	}
	foreach x $::instrument::lines {
	    set tmp($x) ""
	}

	# Ensure that the lines are in numerically ascending order.

	set ::blk::blk${blockNum}(lines) [lsort -integer [array names tmp]]

	# Get the coverable ranges for this block.

	set ::blk::blk${blockNum}(ranges) $::instrument::ranges
    }
    return $script
}

# blk::isInstrumented --
#
#	Test whether a block has been instrumented.
#
# Arguments:
#	blockNum	The block number.
#
# Results:
#	Returns 1 if the block is instrumented else 0.

proc blk::isInstrumented {blockNum} {
    if {[catch {set ::blk::blk${blockNum}(instrumented)} result]} {
	return 0
    }
    return $result
}

# blk::unmarkInstrumented --
#
#	Mark all the instrumented blocks as uninstrumented.  If it's
#	a block to a file remove the source.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc blk::unmarkInstrumented {} {
    foreach block [info var ::blk::blk*] {
	if {[set ${block}(instrumented)] == 1} {
	    set ${block}(instrumented) 0
	    if {[set ${block}(file)] != ""} {
		unset ${block}(script)
	    }
	}
    } 
   return
}

# blk::getVersion --
#
#	Retrieve the source version for the block.
#
# Arguments:
#	blockNum	The block number.
#
# Results:
#	Returns the version number.

proc blk::getVersion {blockNum} {
    return [set ::blk::blk${blockNum}(version)]
}

# blk::getFiles --
#
#	This function retrieves all of the blocks that are associated
#	with files.
#
# Arguments:
#	None.
#
# Results:
#	Returns a list of blocks.

proc blk::getFiles {} {
    set result {}
    foreach name [array names ::blk::blockFiles] {
	lappend result $::blk::blockFiles($name)
    }
    return $result
}

# blk::SetSource --
#
#	This routine sets the script attribute of a block and incremenets
#	the version number.
#
# Arguments:
#	blockNum	The block number.
#	script		The new contents of the block.
#
# Results:
#	None.

proc blk::SetSource {blockNum script} {
    set ::blk::blk${blockNum}(script) $script
    incr ::blk::blk${blockNum}(version)
    return
}

# blk::isDynamic --
#
#	Check whether the current block is associated with a file or
#	is a dynamic block.
#
# Arguments:
#	blockNum	The block number.
#
# Results:
#	Returns 1 if the block is not associated with a file.

proc blk::isDynamic {blockNum} {
    return [expr {[set ::blk::blk${blockNum}(file)] == ""}]
}

