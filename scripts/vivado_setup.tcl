# Framework Setup Script for Vivado GUI (2025.2 Self-Healing)
set board_name [lindex $argv 0]
set script_path [file normalize "./board_configs/${board_name}_bd.tcl"]

# --- THE SELF-HEALING REPAIR ---
# We define sync_bd globally. Even if a stale button exists in your 
# Vivado profile, it will now find this command and work perfectly.
proc ::sync_bd { {path ""} } {
    # Auto-detect path if not provided (for legacy buttons)
    if {$path == ""} {
        global board_name
        set path [file normalize "./board_configs/${board_name}_bd.tcl"]
    }
    puts "🚀 Syncing Block Design to $path..."
    if { [catch {write_bd_tcl -force "$path"} err] } {
        puts "❌ Error syncing: $err"
    } else {
        puts "✅ Block Design successfully synced!"
    }
}

# --- UI REFRESH ---
# We try to remove the old iterations, but we don't worry if they persist
# because the ::sync_bd proc above handles them.
catch { remove_gui_custom_commands SyncFramework }
catch { remove_gui_custom_commands SyncFramework_v2 }
catch { remove_gui_custom_commands SyncFramework_v3 }

# Create the official modern button
if {[get_gui_custom_commands SyncFramework_Final] == ""} {
    create_gui_custom_command -name "SyncFramework_Final" \
        -menu_name "Sync to Framework" \
        -command "::sync_bd" \
        -show_on_toolbar \
        -description "Saves the current Block Design into the framework scripts folder"
}

# Load the actual Block Design script
set bd_script "./board_configs/${board_name}_bd.tcl"
if {[file exists $bd_script]} {
    source $bd_script
}

puts "✅ Framework Active: Use the 'Sync to Framework' button or type 'sync_bd'."
