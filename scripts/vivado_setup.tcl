# Framework Setup Script for Vivado GUI (2025.2 Optimized)
set board_name [lindex $argv 0]
set script_path [file normalize "./board_configs/${board_name}_bd.tcl"]

# --- Cleanup old button names to avoid confusion ---
foreach old_cmd {SyncFramework SyncFramework_v2} {
    if {[get_gui_custom_commands $old_cmd] != ""} {
        remove_gui_custom_commands $old_cmd
    }
}

# Add a Custom Button to the Toolbar
# We use a completely RAW command string with no external procedure calls.
# This is the most compatible way to handle Vivado 2025.2's isolated GUI scope.
create_gui_custom_command -name "SyncFramework_v3" \
    -menu_name "Sync to Framework" \
    -command "write_bd_tcl -force \"$script_path\"; puts \"✅ Block Design successfully synced to $script_path\"" \
    -show_on_toolbar \
    -description "Saves the current Block Design into the framework scripts folder"

# Add a Tcl alias as a backup
interp alias {} sync {} write_bd_tcl -force $script_path

puts "--- Framework Active ---"
puts "  - Click 'Sync to Framework' button to save design."
puts "  - OR type 'sync' in the Tcl Console."

# Load the actual Block Design script
set bd_script "./board_configs/${board_name}_bd.tcl"
if {[file exists $bd_script]} {
    source $bd_script
}
