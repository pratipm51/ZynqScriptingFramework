# Framework Setup Script for Vivado GUI
set board_name [lindex $argv 0]

# Define the Sync Procedure
proc sync_bd {} {
    global board_name
    set script_file "./scripts/${board_name}_bd.tcl"
    if { [catch {write_bd_tcl -force $script_file} err] } {
        send_msg_id "Framework-002" "ERROR" "Failed to sync BD: $err"
    } else {
        send_msg_id "Framework-001" "INFO" "✅ Block Design successfully synced to $script_file"
    }
}

# Add a Custom Button to the Toolbar
# Note: Use the plural 'remove_gui_custom_commands' to avoid ambiguity
if {[get_gui_custom_commands SyncFramework] != ""} {
    remove_gui_custom_commands SyncFramework
}

create_gui_custom_command -name "SyncFramework" \
    -menu_name "Sync to Framework" \
    -command "sync_bd" \
    -show_on_toolbar \
    -description "Saves the current Block Design into the framework scripts folder"

# Load the actual Block Design script
set bd_script "./scripts/${board_name}_bd.tcl"
if {[file exists $bd_script]} {
    source $bd_script
}
