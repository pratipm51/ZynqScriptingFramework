# Framework Setup Script for Vivado GUI
set board_name [lindex $argv 0]

# Add a Custom Button to the Toolbar
# We define the command logic directly in the button to avoid scope issues in 2025.2
if {[get_gui_custom_commands SyncFramework] != ""} {
    remove_gui_custom_commands SyncFramework
}

set script_path [file normalize "./board_configs/${board_name}_bd.tcl"]

create_gui_custom_command -name "SyncFramework" \
    -menu_name "Sync to Framework" \
    -command "puts \"🚀 Syncing Block Design to $script_path...\"; if { \[catch {write_bd_tcl -force \"$script_path\"} err\] } { send_msg_id \"Framework-002\" \"ERROR\" \"Failed to sync BD: \$err\" } else { send_msg_id \"Framework-001\" \"INFO\" \"✅ Block Design successfully synced to $script_path\" }" \
    -show_on_toolbar \
    -description "Saves the current Block Design into the framework scripts folder"

# Load the actual Block Design script
set bd_script "./board_configs/${board_name}_bd.tcl"
if {[file exists $bd_script]} {
    source $bd_script
}
