# Framework Setup Script for Vivado GUI (2025.2 Self-Healing)
set board_name [lindex $argv 0]
set target_lang [lindex $argv 1]
if {$target_lang == ""} { set target_lang "VHDL" }

set script_path [file normalize "./board_configs/${board_name}_bd.tcl"]

# --- THE SELF-HEALING REPAIR ---
proc ::sync_bd { {path ""} } {
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
catch { remove_gui_custom_commands SyncFramework }
catch { remove_gui_custom_commands SyncFramework_v2 }
catch { remove_gui_custom_commands SyncFramework_v3 }

if {[get_gui_custom_commands SyncFramework_Final] == ""} {
    create_gui_custom_command -name "SyncFramework_Final" \
        -menu_name "Sync to Framework" \
        -command "::sync_bd" \
        -show_on_toolbar \
        -description "Saves the current Block Design into the framework scripts folder"
}

# --- Load the actual Block Design script ---
set bd_script "./board_configs/${board_name}_bd.tcl"
if {[file exists $bd_script]} {
    source $bd_script
    
    # --- FORCE LANGUAGE OVERRIDE ---
    # We do this AFTER sourcing because the BD script often resets to Verilog
    set_property target_language $target_lang [current_project]
    set_property simulator_language Mixed [current_project]
    puts "⚙️  Framework: Forced target language to $target_lang"
}

puts "✅ Framework Active: Use the 'Sync to Framework' button or type 'sync_bd'."
