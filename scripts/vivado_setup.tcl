# Framework Setup Script for Vivado GUI (2025.2 Optimized)
set board_name [lindex $argv 0]
set script_path [file normalize "./board_configs/${board_name}_bd.tcl"]

# Define the Sync Procedure in the GLOBAL namespace
# This ensures it survives even if the setup script scope ends.
proc ::sync_bd_framework {path} {
    puts "🚀 Syncing Block Design to $path..."
    if { [catch {write_bd_tcl -force "$path"} err] } {
        send_msg_id "Framework-002" "ERROR" "Failed to sync BD: $err"
    } else {
        send_msg_id "Framework-001" "INFO" "✅ Block Design successfully synced to $path"
    }
}

# Add a Custom Button to the Toolbar
# We use a NEW name to force Vivado to refresh the button and avoid old cached commands
if {[get_gui_custom_commands SyncFramework_v2] != ""} {
    remove_gui_custom_commands SyncFramework_v2
}

create_gui_custom_command -name "SyncFramework_v2" \
    -menu_name "Sync to Framework" \
    -command "::sync_bd_framework \"$script_path\"" \
    -show_on_toolbar \
    -description "Saves the current Block Design into the framework scripts folder"

# Load the actual Block Design script
set bd_script "./board_configs/${board_name}_bd.tcl"
if {[file exists $bd_script]} {
    source $bd_script
}
