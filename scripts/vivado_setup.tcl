# Framework Setup Script for Vivado GUI (2025.2 Compatibility)
set board_name [lindex $argv 0]
set script_path [file normalize "./board_configs/${board_name}_bd.tcl"]

# --- COMPATIBILITY FIX ---
# The user has a stale button calling 'sync_bd'. 
# We define it globally to make that button work again.
proc ::sync_bd {} {
    set path [file normalize "./board_configs/[lindex $::argv 0]_bd.tcl"]
    puts "🚀 Syncing Block Design to $path..."
    if { [catch {write_bd_tcl -force "$path"} err] } {
        puts "❌ Error: $err"
    } else {
        puts "✅ Block Design successfully synced!"
    }
}

# --- AGGRESSIVE CLEANUP ---
# Remove all known previous iterations of the button
foreach cmd [get_gui_custom_commands *SyncFramework*] {
    remove_gui_custom_commands $cmd
}
if {[get_gui_custom_commands sync_bd] != ""} {
    remove_gui_custom_commands sync_bd
}

# Create a fresh, clean button
create_gui_custom_command -name "SyncFramework_v4" \
    -menu_name "Sync to Framework" \
    -command "::sync_bd" \
    -show_on_toolbar \
    -description "Saves the current Block Design into the framework scripts folder"

# Add a backup alias
interp alias {} sync {} ::sync_bd

puts "--- Framework Active ---"
puts "  - Click 'Sync to Framework' button to save design."
puts "  - You can also type 'sync' or 'sync_bd' in the Tcl Console."

# Load the actual Block Design script
set bd_script "./board_configs/${board_name}_bd.tcl"
if {[file exists $bd_script]} {
    source $bd_script
}
