# Framework Setup Script for Vivado GUI (2025.2 Bulletproof)
set board_name [lindex $argv 0]
set script_path [file normalize "./board_configs/${board_name}_bd.tcl"]

# 1. Clean up ALL previous button attempts
foreach cmd [get_gui_custom_commands *SyncFramework*] {
    remove_gui_custom_commands $cmd
}

# 2. Create a button that uses ONLY native Vivado commands
# We avoid calling ANY custom procs here.
create_gui_custom_command -name "SyncFramework_Final" \
    -menu_name "Sync to Framework" \
    -command "write_bd_tcl -force \"$script_path\"" \
    -show_on_toolbar \
    -description "Saves the current Block Design into the framework scripts folder"

# 3. Add a simple procedure as a backup for the console
proc ::sync_bd {} {
    set board [lindex $::argv 0]
    write_bd_tcl -force [file normalize "./board_configs/${board}_bd.tcl"]
}

puts "--- Framework 2025.2 Active ---"
puts "  Target: $script_path"
# Load the actual Block Design script
set bd_script "./board_configs/${board_name}_bd.tcl"
if {[file exists $bd_script]} {
    source $bd_script
}
