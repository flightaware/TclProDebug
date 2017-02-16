# proj.tcl --
#
#	This file implements the Project APIs for the file based 
#	projects system.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.
# 

namespace eval proj {
    # The path of the currently loaded project file.

    variable projectPath {}

    # The projectOpen var is true if a project is currently open.

    variable projectOpen 0

    # The projectNeverSaved var is true if a project is new and has 
    # never been saved to disk.

    variable projectNeverSaved 0

    # The project file extension string.

    variable projFileExt $projectInfo::debuggerProjFileExt

    # The file types to use for all Project file dialogs.

    set projFileTypes [list \
	    [list "$::debugger::parameters(productName) Project Files" *$proj::projFileExt] \
	    [list "All files" *]]

    # The vwait variable that is set when BrowseFileWindow locates
    # a file or the user cancels the dialog.  The value set is the
    # new path or empty string if the dialog was canceled.

    variable fileFound

    # The current project file version number.  If the set of preferences
    # stored in a project file changes, then this value should be updated.

    variable version 1.0
}

# proj::openProjCmd --
#
#	Use this command for the widget commands.  This displays all of the
#	necessary GUI windows, performs all of the actions and checks the
#	error status of the open call.
#
# Arguments:
#	file	The name of the file to open.  If this is an empty string 
#		the user is prompted to select a project file.
#
# Results:
#	Return 1 if there was an error saving the project file.

proc proj::openProjCmd {{file {}}} {
    if {$file == {}} {
	set file [proj::openProjDialog]
    } else {
	set file [proj::checkOpenProjDialog $file]
    }

    if {[proj::openProj $file]} {
	tk_messageBox -icon error -type ok -title "Load Error" \
		-parent [gui::getParent] -message \
		"Error loading project.  Project file is unreadable or corrupt"
	return 1
    } else {
	return 0
    }
}

# proj::openProjDialog --
#
#	Display a file dialog window so users can search the disk for a 
#	saved project file.  
#
# Arguments:
#	None.
#
# Results:
#	The name of the file.  If the name is an empty string, then 
#	the user canceled the opening of the project file.

proc proj::openProjDialog {} {
    set file [proj::openFileWindow [gui::getParent] {} $proj::projFileTypes]
    if {$file != {}} {
	set file [proj::checkOpenProjDialog $file]
    }
    return $file
}

# proj::checkOpenProjDialog --
#
#	Show all necessary dialogs related to opening a project, determine 
#	if a project needs to be closed and saved, browse for a file if the
#	specified file does not exist.  NOTE: This dialog window has side 
#	effects.  If a project file is open it will be closed.  If the file
#	does not exist it will be removed from the recently used list of
#	project files.
#
# Arguments:
#	file	The name of the file to open.
#
# Results:
#	The name of the file.  If the name is an empty string, then 
#	the user canceled the opening of the project file.

proc proj::checkOpenProjDialog {file} {
    variable projectOpen

    # Close a project if one is opened.  This will display all of the 
    # necessary dialogs, save the file to disk and reset the state.

    if {$projectOpen} {
	set how [proj::closeProjDialog]
	if {$how == "CANCEL"} {
	    return {}
	} else {
	    if {[proj::closeProjCmd $how]} {
		tk_messageBox -icon error -type ok -title "Load Error" \
			-parent [gui::getParent] -message \
			"Error saving project:  [pref::GetSaveMsg]"
	    }
	}
    }

    # Verify the file exists.  If it does not, then show the file
    # missing window and prompt the user to browse for what they want.
    # If the return value is an empty string, then no valid file was 
    # located.
    
    if {![file exists $file]} {
        proj::RemoveRecentProj $file
	set file [proj::fileMissingWindow "Project file " \
		$file $proj::projFileTypes]
    }

    # If the project window is opened, destroy it now, so it does 
    # not perturb the next project that will be opened.

    if {[projWin::isOpen]} {
	projWin::DestroyWindow
    }

    return $file
}
    
# proj::openProj --
#
#	Open the project and initialize the debugger engine and GUI.
#	No dialog windows will be displayed prompting the user, use 
#	the openProjDialog or checkOpenProjDialog APIs to prompt the
#	user.
#
# Arguments:
#	file	The name of the file to open.
#
# Results:
#	Return 1 if there was an error restoring the project file.

proc proj::openProj {file} {
    variable projectNeverSaved

    if {$file == {}} {
	return 0
    }

    # Create a new Project group and populate it with the preferences
    # from the project file.  If the file is not successfully restored
    # return false, indicating that the open failed.
    
    pref::groupNew Project {proj::SaveProjCmd [proj::getProjectPath]} \
	    [list proj::RestoreProjCmd $file]
    pref::groupCopy ProjectDefault Project
    if {[pref::groupRestore Project]} {
	return 1
    }

    # Reset the list of valid breakpoints.  This needs to be done before
    # we show the current file so line breakpoints show up in the codebar.

    bp::setProjectBreakpoints [pref::prefGet breakList]
    bp::updateWindow

    # Reset the list of watch variables.
    
    watch::setVarList [pref::prefGet watchList] 0
    watch::updateWindow

    proj::setProjectPath $file
    pref::prefSet GlobalDefault fileOpenDir [file dirname $file]
    proj::AddRecentProj $file
    proj::InitNewProj
    set projectNeverSaved 0

    return 0
}

# proj::closeProjCmd --
#
#	Use this command for the widget commands.  This displays all of the
#	necessary GUI windows, performs all of the actions and checks the
#	error status of the close call.
#
# Arguments:
#	how	How the project should be closed. Can be null.
#
# Results:
#	Return 1 if there was an error saving the project file.

proc proj::closeProjCmd {{how {}}} {
    if {$how == {}} {
	set how [proj::closeProjDialog]
    }
    if {$how == "CANCEL"} {
	return 0
    }
    # Cancel the project setting window if it is open.
    
    if {[projWin::isOpen]} {
	projWin::CancelProjSettings
    }

    if {[proj::closeProj $how]} {
	tk_messageBox -icon error -type ok -title "Load Error" \
		-parent [gui::getParent] -message \
		"Error saving project:  [pref::GetSaveMsg]"
	return 1
    } else {
        # Remove the name of the Project from the main title and remove the
	# code displayed in the code window.  Change the GUI state to be new,
	# indicating that a project is not loaded.  Set the current block to
	# nothing, and reset the gui window to it's default state.

	gui::setDebuggerTitle ""
        gui::changeState new
	gui::setCurrentBlock {}
	gui::resetWindow
	return 0
    }
}

# proj::closeProjDialog --
#
#	Show all necessary dialogs related to closing a project.  Determine 
#	if the project needs to be saved and verify that the user wants to 
#	save the file.  However, do not actually modify any state or save 
#	the project.
#
# Arguments:
#	None.
#
# Results:
#	NONE   if no projects are opened.
#	SAVE   if the project should be closed and saved.
#	CLOSE  if the project should be closed w/o saving the file.
#	CANCEL if the user canceled the action.

proc proj::closeProjDialog {} {
    variable projectOpen
    variable projectNeverSaved

    if {!$projectOpen} {
	return NONE
    }
    if {[gui::askToKill]} {
	return CANCEL
    }    
    if {!$projectNeverSaved && ![pref::groupIsDirty Project]} {
	return CLOSE
    }

    set file [proj::getProjectPath]
    switch -- [proj::saveOnCloseProjDialog $file] {
	YES {
	    set result SAVE
	}
	NO {
	    set result CLOSE

	    # HACK:  to keep "new" projects from trying to apply when the
	    # user doesn't save, empty the destroyCmd

	    set ::projWin::destroyCmd {}
	}
	CANCEL {
	    set result CANCEL
	}
	default {
	    error "saveOnCloseProjDialog returned unexpected value."
	}
    }
    
    if {$result != "CANCEL"} {
	if {[projWin::isOpen]} {
	    projWin::DestroyWindow
	}
    }
    return $result
}

# proj::closeProj --
#
#	Close the project and reset the state of the debugger engine and 
#	GUI.  If specified, save the project to disk.  No dialog windows
#	will be displayed prompting the user, use the closeProjDialog 
#	API to prompt the user.
#
# Arguments:
#	how	Indicates what action to take when closing the project.  
#		NONE and CANCEL indicate the project should not be closed.
#		SAVE means to save the project before closing.  CLOSE 
#		means close the project without saving the project.
#
# Results:
#	Return 1 if there was an error saving the project file.

proc proj::closeProj {how} {
    variable projectOpen
    variable projectNeverSaved

    if {$how == "NONE" || $how == "CANCEL"} {
	return 0
    }

    set result 0

    if {$how == "SAVE"} {
	if {[proj::saveProj [proj::getProjectPath]]} {
	    return 1
	}
    }

    if {!$result} {
        # Set the variable that indicates Debugger does not have an 
        # open project and set the projectPath to null.
        
	set projectOpen 0
	set projectNeverSaved 0
        proj::setProjectPath {}
	pref::groupDelete Project

	bp::setProjectBreakpoints {}
	bp::updateWindow

	watch::setVarList {} 0
	watch::updateWindow

	# Close the port the debugger is listening on, and reset dbg data.

	gui::quit
    }

    return $result
}

# proj::saveProjCmd --
#
#	Use this command for the widget commands.  This displays all of the
#	necessary GUI windows, performs all of the actions and checks the
#	error status of the save call.
#
# Arguments:
#	file	The name of the file to save.  If this is an empty string 
#		the user is prompted to select a project file.
#
# Results:
#	Return 1 if there was an error saving the project file.

proc proj::saveProjCmd {{file {}}} {
    if {$file == {}} {
	set file [proj::saveProjDialog]
    }

    if {[proj::saveProj $file]} {
	tk_messageBox -icon error -type ok -title "Load Error" \
		-parent [gui::getParent] -message \
		"Error saving project:  [pref::GetSaveMsg]"
	return 1
    } else {
	# Put the new name of the project in the main window.  Trim off
	# the path and file extension, so only the name of the file is 
	# displayed.
	
	set proj [file tail [proj::getProjectPath]]
	set proj [string range $proj 0 [expr {[string length $proj] - 5}]]
	wm title $gui::gui(mainDbgWin) "$::debugger::parameters(productName): $proj"
	projWin::updateWindow "Project: $proj"
 
	return 0
    }
}

# proj::saveAsProjCmd --
#
#	Use this command for the widget commands.  This displays all of the
#	necessary GUI windows, performs all of the actions and checks the
#	error status of the saveAs call.
#
# Arguments:
#	None.
#
# Results:
#	Return 1 if there was an error saving the project file.

proc proj::saveAsProjCmd {} {
    set file [proj::getProjectPath]

    if {[proj::saveProj [proj::saveAsProjDialog $file]]} {
	tk_messageBox -icon error -type ok -title "Load Error" \
		-parent [gui::getParent] -message \
		"Error saving project:  [pref::GetSaveMsg]"
	return 1
    } else {
	# Put the new name of the project in the main window.  Trim off
	# the path and file extension, so only the name of the file is 
	# displayed.
	
	set proj [file tail [proj::getProjectPath]]
	set proj [string range $proj 0 [expr {[string length $proj] - 5}]]
	wm title $gui::gui(mainDbgWin) "$::debugger::parameters(productName): $proj"
	projWin::updateWindow "Project: $proj"

	return 0
    }
}

# proj::saveOnCloseProjDialog --
#
#	If the file needs to be saved, ask the user if they want 
#	to save the file.  This does not modify any state or save 
#	the project.
#
# Arguments:
#	file	The name of the file to save.  Can be empty string.
#
# Results:
#	YES    if the project should be saved
#	NO     if the project should not be saved
#	CANCEL if the user canceled the action.

proc proj::saveOnCloseProjDialog {file} {
    variable projectOpen
    variable projectNeverSaved

    # If a project is opened and the project needs to be saved, either 
    # prompt the user to save the file or just set the result to save
    # if there is a preference to always save w/o askling.  Otherwise,
    # nothing needs to be saved, so just return NO.

    if {$projectOpen && ($projectNeverSaved || [pref::groupIsDirty Project])} {
	if {[pref::prefGet warnOnClose]} {
	    append msg "Do you want to save the project information for: "
	    append msg "${file}?"
	    set result [tk_messageBox -icon question -type yesnocancel \
		    -title "Save Project" -parent [gui::getParent] \
		    -message $msg]
	    set result [string toupper $result]
	} else {
	    set result YES
	}
    } else {
	set result NO
    }

    # If the user choose to save the file (by default or activly selecting to
    # save the file) display any necessary save dialogs.  If the result of
    # the save dialogs is a null file name, then the user canceled the action.
    # Change the result to CANCEL and return.  Otherwise, make sure the 
    # projectPath contains the new file name so the saveProj API save the 
    # project to the correct file.

    if {$result == "YES"} {
	set file [proj::saveProjDialog]
	if {$file == {}} {
	    set result CANCEL
	} else {
	    proj::setProjectPath $file
	}
    }
    return $result
}

# proj::saveProjDialog --
#
#	Display the saveAs dialog if the file does not exist.
#	This does not modify any state or save the project.
#	
# Arguments:
#	None.
#
# Results:
#	The name of the file if it exists and needs to be saved.  
#	Otherwise return an empty string.

proc proj::saveProjDialog {} {
    variable projectNeverSaved

    set file [proj::getProjectPath]

    if {$projectNeverSaved} {
	set file [proj::saveAsProjDialog $file]
    } elseif {![pref::groupIsDirty Project]} {
	set file {}
    }
    return $file
}

# proj::saveAsProjDialog --
#
#	Display the saveAs dialog prompting the user to specify a file 
#	name.  This does not modify any state or save the project.
#
# Arguments:
#	file	The name of the file to save.  Can be empty string.
#
# Results:
#	The name of the file if one was selected or empty string if the 
#	user canceled the action.

proc proj::saveAsProjDialog {file} {
    return [proj::saveAsFileWindow [gui::getParent] \
	    [file dirname $file] [file tail $file] \
	    $proj::projFileTypes $proj::projFileExt]
}

# proj::saveProj --
#
#	Save the project to disk and update the debugger engine and GUI.
#	If the name of the file is an empty string this routine is a no-op.
#	No dialog windows will be displayed prompting the user, use the
#	saveProjDialog or saveOnCloseProjDialog APIs to prompt the user.
#	
# Arguments:
#	file	The name of the file to save.  Can be empty string.
#
# Results:
#	Return 1 if there was an error saving the project file.

proc proj::saveProj {file} {
    variable projectOpen
    variable projectNeverSaved

    if {$file == {}} {
	return 0
    }
    if {!$projectOpen} {
	error "error: saveProj called when no projects are open"
    }
    
    # Make sure to set the new projectPath , because the project's save command
    # relies on this value.  Then copy the breakpoint list into the project,
    # then save the preferences.

    proj::setProjectPath $file
    break::preserveBreakpoints breakList
    pref::prefSet Project breakList    $breakList
    pref::prefSet Project watchList    [watch::getVarList]
    pref::prefSet Project prevViewFile [gui::getCurrentFile]
    set result [pref::groupSave Project]

    # Only update the state if the file was correctly saved.  If the
    # value of 'result' is false, then the file saved w/o errors.
    
    if {!$result} {
	# Add the project to the list of "recently used projects" 
	# cascade menu.
	
	proj::AddRecentProj $file

	# Set the following bit indicating that the file has been saved.

	set projectNeverSaved 0
    }

    return $result
}

# proj::restartProj --
#
#	Restart the currently loaded project.  If an application is currently
#	running, it will be killed.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc proj::restartProj {} {
    set state [gui::getCurrentState]
    if {$state == "new"} {
	error "restartProj called when no project is loaded"
    }
    if {($state == "stopped") || ($state == "running")} {
	if {[gui::kill]} {
	    # User cancelled the kill action
	    return
	}
    }
    gui::run "dbg::run"
    return
}

# proj::getProjectPath --
#
#	Get the path to the currently loaded project file.
#
# Arguments:
#	None.
#
# Results:
#	The project path.
 
proc proj::getProjectPath {} {
    return $proj::projectPath
}

# proj::setProjectPath --
#
#	Set the path to the currently loaded project file.
#
# Arguments:
#	path	The project path.
#
# Results:
#	None.

proc proj::setProjectPath {path} {
    set proj::projectPath $path
    return
}

# proj::isProjectOpen --
#
#	Accessor function to determine if the system currently has
#	on open project file.
#
# Arguments:
#	None.
#
# Results:
#	Return 1 if a project file is open, return 0 if no project is open.

proc proj::isProjectOpen {} {
    return $proj::projectOpen
}

# proj::projectNeverSaved --
#
#	Accessor function to determine if the current project has never 
#	been saved (a new, "Untitled", project.)
#
# Arguments:
#	None.
#
# Results:
#	Return 1 if a the file has never been saved

proc proj::projectNeverSaved {} {
    return $proj::projectNeverSaved
}

# proj::checkProj --
#
#	Verify that the project information is valid.
#
# Arguments:
#	None.
#
# Results:
#	Return a boolean, 1 if the project information was valid.
#	Any errors will display a dialog stating the error.

proc proj::checkProj {} {
    variable projectNeverSaved

    set msg    {}
    set script [lindex [pref::prefGet appScriptList] 0]
    set arg    [lindex [pref::prefGet appArgList]    0]
    set dir    [lindex [pref::prefGet appDirList]    0]
    set interp [lindex [pref::prefGet appInterpList] 0]

    # Make the starting directory relative to the path of the project
    # file. If the script path is absolute, then the join does nothing.
    # Otherwise, the starting dir is relative from the project directory.

    if {!$projectNeverSaved} {
	set dir [file join [file dirname [proj::getProjectPath]] $dir]
    }

    if {$script == {}} {
	set msg "You must enter a script to Debug."
    } elseif {![file exist [file join $dir $script]]} {
	set msg "$script : File not found.\n"
	append msg "Please verify the correct filename was given."
    }
    if {$dir != {}} {
	if {(![file exist $dir]) || (![file isdirectory $dir])} {
	    set msg "$dir : Invalid directory\n"
	    append msg "Please verify the correct path was specified."
	}	    
    }
    if {$interp == {}} {
	set msg "You must specify an interpreter."
    }

    if {$msg != {}} {
	tk_messageBox -icon error -type ok -title "Load Error" \
	    -parent [gui::getParent] -message $msg
	set result 0
    } else {
	set result 1
    }
    return $result
}

# proj::isRemoteProj --
#
#	Determine if the currently loaded project is remote.
#
# Arguments:
#	None.
#
# Results:
#	Boolean, true if the project is connected remotely.

proc proj::isRemoteProj {} {
    return [expr {[pref::prefGet appType] == "remote"}]
}

# proj::showNewProjWindow --
#
#	Display the Project Settings Window for a new project.  Use the
#	DefaultProject group to initialize the new project.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc proj::showNewProjWindow {} {
    variable projectNeverSaved

    # If there is a project currently open, check to see if it needs
    # to be saved.  If the save was canceled, then do not continue to
    # open this project.

    set how [proj::closeProjDialog] 
    if {$how == "CANCEL"} {
	return
    } else {
	proj::closeProjCmd $how
    }
    
    # Generate the new file name.

    set projPath "Untitled" 
    proj::setProjectPath $projPath

    # Create a new Project group.  Make the save command callback such that
    # it copies the preferences from Project into the project file.  Then
    # move the project default preferences into the Project group.

    pref::groupNew Project {proj::SaveProjCmd [proj::getProjectPath]} {}
    pref::groupCopy ProjectDefault Project

    # Set the bit that indicates this project has never been saved.

    set projectNeverSaved 1

    # Display the Project Settings Window, and register the callbacks
    # for Ok/Apply and Cancel.  The New Project Settings Window calls
    # the same apply routine regardless if OK, Apply or Cancel is 
    # pressed.  However, if the user doesn't save, we need to set the
    # projWin::destroyCmd var to empty in the proj::closeProjDialog proc.

    projWin::showWindow "Project: $projPath"  \
	    proj::applyThisProjCmd \
	    proj::applyThisProjCmd
    return
}

# proj::showThisProjWindow --
#
#	Display the Project Settings Window for the currently opened project.
#	If no project are loaded, then display the Default Project Settings
#	window.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc proj::showThisProjWindow {} {
    variable projectOpen

    # Verify that a project is currently opened.  If there are no projects
    # open, open the Default Settings window.

    if {!$projectOpen} {
	proj::showDefaultProjWindow
	return
    }
    
    # Display the Project Settings Window.

    set proj [file rootname [file tail [proj::getProjectPath]]]

    set projectNeverSaved 0

    # Show the Project Settings Window.  Register the callback when
    # OK/Apply is pressed.  Do not register a callback for the Cancel
    # button.

    projWin::showWindow "Project: $proj" proj::applyThisProjCmd {}
    return
}

# proj::applyThisProjCmd --
#
#	The command to execute when the Project Settings window, 
#	for a current project, is applied by the user.
#
# Arguments:
#	destroy	  Boolean, if true then destroy the toplevel window.
#
# Results:
#	None.

proc proj::applyThisProjCmd {destroy} {
    # If the doInstrument list is empty, then add the "*" pattern to it.

    projWin::nonEmptyInstruText

    if {![proj::isRemoteProj]} {
	# If the working directory is null, get the directory name from
	# the script argument, and implicitly set the working  directory.
	# Add the dir to the combo box, and add the dir to the preference
	# list.

	set dir    [lindex [pref::prefGet appDirList TempProj]    0]
	set script [lindex [pref::prefGet appScriptList TempProj] 0]
	if {($dir == {}) && ($script != {})} {
	    set dir   [file dirname $script]
	    set dList [projWin::AddToCombo $projWin::dirCombo $dir]
	    $projWin::dirCombo set $dir
	    pref::prefSet Project appDirList $dList
	}
    }

    # If this is a remote project, initialize the port now so the
    # debugger is waiting for the app to connect.  If this is a 
    # local project, make sure the debugger is not listening on a
    # port.

    proj::InitNewProj

    return
}

# proj::showDefaultProjWindow --
#
#	Display the Project Settings Window for setting default project 
#	values.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc proj::showDefaultProjWindow {} {
    # Create a new Project group.  Then move the project default preferences 
    # into the Project group.

    pref::groupNew Project
    pref::groupCopy ProjectDefault Project

    # Display the Project Settings Window. Register the callback when
    # OK/Apply is pressed.  Do not register a callback for the Cancel
    # button.

    projWin::showWindow "Default Project Settings" \
	    proj::applyDefaultProjCmd {}
    return
}

# proj::applyDefaultProjCmd --
#
#	The command to execute when the Project Settings window, 
#	for the default project, is applied by the user.
#
# Arguments:
#	destroy	  Boolean, if true then destroy the toplevel window.
#
# Results:
#	None.

proc proj::applyDefaultProjCmd {destroy} {
    # If the doInstrument list is empty, then add the "*" pattern to it.

    projWin::nonEmptyInstruText
    if {[proj::isRemoteProj]} {
	# Check if port value is valid (numeric); if it's not, make it valid
	set port [pref::prefGet portRemote]
	set newPort $port
	while {[catch {expr $newPort + 0}]} {
	    set newPort [portWin::showWindow $newPort]
	}
	pref::prefSet Project portRemote $newPort
    }
    pref::groupCopy Project ProjectDefault
    if {$destroy} {
	pref::groupDelete Project
    }
    return
}

# proj::fileMissingWindow --
#
#	Display a dialog box that states the file cannot be found , and ask 
#	the user if they want to browse for this file.
#
# Arguments:
#	prefix	A string that describes what type of file is missing.  This
#		is prepend to the error message displayed.
#	path	The path of the missing file.
#	types	The file types to use in the dialog.  Can be an empty string.
#
# Results:
#	Returns a new path if one is located, otherwise 

proc proj::fileMissingWindow {prefix path types} {
    proj::ShowFileMissingWindow $prefix $path $types
    vwait proj::fileFound
    return $proj::fileFound
}

# proj::saveAsFileWindow --
#
#	Display a file dialog for browsing for a file to save.  If the dir
#	name does not exists, then use the current working directory.
#
# Arguments:
#	parent	The parent window of the open dialog.
#	dir	The directory name of current working directory.  If the value
#		does not reference a valid path, current working dir is used.
#	file	Default name for file.  Can be null.
#	types	File types to put into the fileDialog.  If null a default 
#		value is set.
#	ext	The default extension to use.
#
# Results:
#	Return a boolean, 1 means that the save succeeded
#	and 0 means the user canceled the save.


proc proj::saveAsFileWindow {parent dir file {types {}} {ext {}}} {
    # Do some basic sanity checking here.

    if {![file exist $dir]} {
	set dir [pref::prefGet fileOpenDir]
    }
    if {$file == {}} {
	set file [file::getUntitledFile $dir Untitled $proj::projFileExt]
    }

    # If types is empty, then use the default values.

    if {$types == {}} {
	set types {
	    {"Tcl Scripts"		{.tcl .tk}	}
	    {"Text files"		{.txt .doc}	TEXT}
	    {"All files"		*}
	}
    }

    set file [tk_getSaveFile -filetypes $types -parent $parent \
	    -initialdir $dir -initialfile $file -defaultextension $ext]

    if {$file != {}} {
	pref::prefSet GlobalDefault fileOpenDir [file dirname $file]
    }
    return $file
}

# proj::openFileWindow --
#
#	Display a file dialog for browsing for a file to open.  If the dir
#	name does not exists, then use the current working directory.
#
# Arguments:
#	parent	The parent window of the open dialog.
#	dir	The directory name of current working directory.  If the value
#		does not reference a valid path, current working dir is used.
#	types	File types to put into the fileDialog.  If null a default 
#		value is set.
#
# Results:
#	The name of the file to open or empty string of nothing was selected.

proc proj::openFileWindow {parent dir {types {}}} {
    # Do some basic sanity checking here.

    if {![file exists $dir]} {
	set dir [pref::prefGet fileOpenDir]
    }
    if {![file isdirectory $dir]} {
	set dir [file dirname $dir]
    }

    # If types is empty, then use the default values.

    if {$types == {}} {
	set types {
	    {"Tcl Scripts"		{.tcl .tk}	}
	    {"Text files"		{.txt .doc}	TEXT}
	    {"All files"		*}
	}
    }

    set file [tk_getOpenFile -filetypes $types -parent $parent \
	    -initialdir $dir]
    if {$file != {}} {
	pref::prefSet GlobalDefault fileOpenDir [file dirname $file]
    }
    return $file
}

# proj::openComboFileWindow --
#
#	Display a fileDialog for browsing.  Extract the dir name
#	from the combobox.  If the dir name exists, then set this
#	as the default dir for browsing.  When the dialog exits,
#	write the value to the combobox.
#
# Arguments:
#	combo	The combobox to extract and place file info.
#	types	File types to put into the fileDialog.
#
# Results:
#	None.

proc proj::openComboFileWindow {combo types} {
    set file [$combo get]
    if {[file isdirectory $file]} {
	set dir $file
    } elseif {$file != {}} {
	set dir [file dirname $file]
    } else {
	set dir {}
    }
    if {![file exists $dir]} {
	set dir [pref::prefGet fileOpenDir]
    }

    if {$types == {}} {
	set types {
	    {"Tcl Scripts"		{.tcl .tk}	}
	    {"Text files"		{.txt .doc}	TEXT}
	    {"All files"		*}
	}
    }
    set file [tk_getOpenFile -filetypes $types -parent [gui::getParent] \
	    -initialdir $dir]
    if {[string compare $file ""]} {
	$combo set $file
    }
    return
}

# proj::ShowFileMissingWindow --
#
#	Show the window that tells the user their file is missing
#	and ask them if they want to browse for a new path.
#
# Arguments:
#	prefix	A string that describes what type of file is missing.  This
#		is prepend to the error message displayed.
#	path	The path of the missing file.
#	types	The file types to use in the dialog.  Can be an empty string.
#
# Results:
#	None.

proc proj::ShowFileMissingWindow {prefix path types} {
    set top [toplevel $gui::gui(projMissingWin)]
    wm title $top "Project File Not Found"
    wm minsize  $top 100 100
    wm transient $top $gui::gui(mainDbgWin)

    set bd       2
    set pad      6
    set pad2     [expr {$pad / 2}]
    set width    300
    set height   100
    set butWidth 6 

    # Center window on the screen.

    set w [winfo screenwidth .]
    set h [winfo screenheight .]
    wm geometry $gui::gui(projMissingWin) \
	    +[expr {($w/2) - ($width/2)}]+[expr {($h/2) - ($height/2)}]

    set msg "$prefix\"$path\" not found.  Press Browse to locate the file."

    set mainFrm  [frame $top.mainFrm -bd $bd -relief raised]
    set imageLbl [label $mainFrm.imageLbl -bitmap error]
    set msgLbl   [label $mainFrm.msgLbl -wraplength $width -text $msg]

    set butFrm  [frame $top.butFrm]
    set browseBut [button $butFrm.browseBut -text "Browse" -width $butWidth \
            -command [list proj::BrowseFileMissingWindow $path $types]] 
    set cancelBut [button $butFrm.cancelBut -text "Cancel" -width $butWidth \
            -command {proj::CancelFileMissingWindow}]

    pack $imageLbl -side left
    pack $msgLbl -side left
    pack $cancelBut $browseBut -side right -padx $pad

    pack $butFrm -side bottom -fill x -pady $pad2
    pack $mainFrm -side bottom -fill both -expand true -padx $pad -pady $pad

    focus -force $butFrm.browseBut
    return
}

# proj::BrowseFileMissingWindow --
#
#	Open the file browser dialog.  When a file is selected or the
#	window is canceled, set the fileFound vwait variable to the 
#	file name if one is found, or empty string if nothing was found.
#
# Arguments:
#	path	The path of the missing file.  Use this as a starting point
#		for locating the new file.
#	types	The file types to use in the dialog.  Can be an empty string.
#
# Results:
#	None.

proc proj::BrowseFileMissingWindow {path types} {
    set dir [file dirname $path]
    if {![file exists $dir]} {
        set dir [pwd]
    }
    set proj::fileFound [proj::openFileWindow [gui::getParent] $dir $types]

    destroy $gui::gui(projMissingWin)
    return
}

# proj::CancelFileMissingWindow --
#
#	The File Missing window has been canceled.  Set the fileFound vwait
#	variable to empty string indicating this window has been canceled.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc proj::CancelFileMissingWindow {} {
    set proj::fileFound {}
    destroy $gui::gui(projMissingWin)
    return
}

# proj::InitNewProj --
#
#	Update information when a new project or project file is opened.
#	Note:  this proc should probably be renamed to UpdateProj.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc proj::InitNewProj {} {
    # Set the variable that indicate Debugger has an open project
    # and the global pref to indicate the project path.

    set proj::projectOpen 1
    set projPath [proj::getProjectPath]

    # Invoke all of the update routines to ensure we notice any changes
    # since the last project.

    pref::groupUpdate Project

    # Put the name of the project in the main window.  Trim off the 
    # path and file extension, so only the name of the file is 
    # displayed.

    set proj [file rootname [file tail $projPath]]
    gui::setDebuggerTitle $proj
    
    # If the Debugger is not running an application, update the GUI state
    # to reflect the change in project settings.

    set state [gui::getCurrentState]
    if {($state == "new") || ($state == "dead")} { 
	if {[proj::isRemoteProj]} {
	    # Update the server port if we are currenly not listening or
	    # the listening port is different from the preference.

	    proj::initPort
	} else {
	    # Quitting the debugger will insure the connection status is
	    # current.  This is necessary if the user switched from a 
	    # remote project (currently listening on the port) to a local
	    # project (when the debugger should not be listening.)
	    # Note: We want to preserve the breakpoints.  The quit routine,
	    # amoung other tasks, clears them.  So save the bps before, then
	    # restore them after.
	    
	    break::preserveBreakpoints breakList
	    gui::quit
	    bp::setProjectBreakpoints $breakList
	}

	# Update the GUI to reflect the possible change from a local
	# to remote, vice versa, or the changing of the remote port.

	gui::changeState dead

	# Show the last viewed file.  If this is a new project, use the
	# script argument for this project.  Verify that the file name
	# entered is actually valid.
	
	set file    [pref::prefGet prevViewFile Project]
	set script  [lindex [pref::prefGet appScriptList] 0]
	set workDir [lindex [pref::prefGet appDirList] 0]
	set script  [file join $workDir $script]
	
	if {($script != {}) && [file exists $script]} {
	    set loc [loc::makeLocation [blk::makeBlock $script] {}]
	} elseif {[file exists $file]} {
	    set loc [loc::makeLocation [blk::makeBlock $file] {}]
	} else {
	    set loc {}
	}
	if {$loc != {}} {
	    gui::showCode $loc
	}
    }

    return
}

# proj::initPort --
#
#	Update the server port if we are currenly not listening or
#	the listening port is different from the preference.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc proj::initPort {} {
    foreach {status server sock peer} [dbg::getServerPortStatus] {}
    set listenPort [lindex $server 0]
    set port       [pref::prefGet portRemote Project]

    if {($status != "Listening") || ($listenPort != $port)} {
	# Attempt to set the server port with the port preference.  
	# If an error occurs, display the window that prompts the 
	# user for a new port.
	
	while {![dbg::setServerPort $port]} {
	    proj::validatePortDialog
	    set port [pref::prefGet portRemote Project]
	}
    }
    return
}

# proj::validatePortDialog --
#
#	Verify the remote port preference is valid and available for 
#	use.  If any errors occur, pormpt the user to enter a new 
#	remote port preference.  If the preference changes, it will
#	automatically set the preference.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc proj::validatePortDialog {} {
    set port [pref::prefGet portRemote]
    set newPort $port
    
    while {![portWin::isPortValid $newPort]} {
	set newPort [portWin::showWindow $newPort]
    }
    
    if {$newPort != $port} {
	if {[pref::groupExists Project]} {
	    pref::prefSet Project portRemote $newPort
	}
	if {[pref::groupExists TempProj]} {
	    pref::prefSet TempProj portRemote $newPort
	}
    }
    return
}

# proj::AddRecentProj --
#
#	Add the project to the list of recently used projects.
#
# Arguments:
#	projPath	The path to the project file.
#
# Results:
#	None.

proc proj::AddRecentProj {projPath} {
    # Try to ensure that the same file doesn't appear twice in 
    # the recent project list by making it native.

    set projPath [file nativename $projPath]
    set projList [pref::prefGet projectList GlobalDefault]

    # Make sure we do an case insensitive comparison on Windows.

    if {$::tcl_platform(platform) == "windows"} {
	set list [string toupper $projList]
	set file [string toupper $projPath]
    } else {
	set list $projList
	set file $projPath
    }

    # Remove any duplicate project names if they are anywhere
    # in the list except for the first element.

    set index [lsearch -exact $list $file]
    if {$index > 0} {
	set projList [lreplace $projList $index $index]
    }
    
    # If the project is not already at the head of the list, 
    # insert the project path.

    if {($index < 0) || ($index > 0)} {
	set projList [linsert $projList 0 $projPath]
	pref::prefSet GlobalDefault projectList $projList
    }
    return
}

# proj::RemoveRecentProj --
#
#	Remove the project to the list of recently used projects.  If the
# 	project is not in the list, nothing happens.
#
# Arguments:
#	projPath	The path to the project file.
#
# Results:
#	None.

proc proj::RemoveRecentProj {projPath} {
    # All files in recent project list are native.

    set projPath [file nativename $projPath]

    # Remove any duplicate project names if they are anywhere
    # in the list except for the first element.

    set list [pref::prefGet projectList GlobalDefault]
    set index [lsearch -exact $list $projPath]
    if {$index >= 0} {
	set list [lreplace $list $index $index]
	pref::prefSet GlobalDefault projectList $list
    }

    return
}

# proj::SaveProjCmd --
#
#	This is the command that is called when the Project group
#	is asked to save its preferences.  All error checking is 
#	assumed to have been made, and errors should be caught
#	in the groupSave routine.
#
# Arguments:
#	projPath	The path to the project file.
#	group		The group doing the saving.
#
# Results:
#	Return a boolean, 1 means that the save did not succeed, 
#	0 means it succeeded.

proc proj::SaveProjCmd {projPath group} {
    set result [catch {
	file mkdir [file dirname $projPath]
	set id [open $projPath w]
	foreach pref [pref::GroupGetPrefs $group] {
	    puts $id [list $pref [pref::prefGet $pref $group]]
	}
	close $id
    } msg]

    pref::SetSaveMsg $msg
    return $result
}

# proj::RestoreProjCmd --
#
#	This is the command that is called when the Project group
#	is asked to restore its preferences.  All error checking is 
#	assumed to have been made, and errors should be caught
#	in the groupRestore routine.
#
# Arguments:
#	projPath	The path to the project file.
#	group		The group doing the saving.
#
# Results:
#	Return a boolean, 1 means that the save did not succeed, 
#	0 means it succeeded.

proc proj::RestoreProjCmd {projPath group} {
    set result [catch {
	set id [open $projPath r]
	set prefs [read $id]
	pref::GroupSetPrefs $group $prefs
	close $id
    } msg]

    pref::SetRestoreMsg $msg
    return $result
}

