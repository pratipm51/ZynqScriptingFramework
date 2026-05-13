# Framework Setup Script for Vivado GUI (2025.2 Self-Healing + Bootstrap)
set board_name [lindex $argv 0]
set target_lang [lindex $argv 1]
if {$target_lang == ""} { set target_lang "VHDL" }

set script_path [file normalize "./board_configs/${board_name}_bd.tcl"]

# --- THE SELF-HEALING REPAIR & BOOTSTRAP ---
proc ::sync_bd { {path ""} } {
    if {$path == ""} {
        global board_name
        set path [file normalize "./board_configs/${board_name}_bd.tcl"]
    }
    
    puts "🚀 Syncing Block Design to $path..."
    if { [catch {write_bd_tcl -force "$path"} err] } {
        puts "❌ Error syncing BD: $err"
        return
    }
    puts "✅ Block Design successfully synced!"

    # --- BOOTSTRAP TOP.VHD ---
    set top_vhd [file normalize "./src/hdl/top.vhd"]
    if {![file exists $top_vhd]} {
        puts "🌱 No top.vhd found. Attempting to bootstrap from Block Design..."
        
        set bd_files [get_files -quiet *.bd]
        if {$bd_files == ""} {
            puts "⚠️  No Block Design found in project. Skipping bootstrap."
            return
        }

        # Generate the wrapper to get the port list
        puts "🔨 Generating wrapper for [lindex $bd_files 0]..."
        set wrapper_path [make_wrapper -files $bd_files -top]
        
        if {[file exists $wrapper_path]} {
            # Read the wrapper and create a 'top' version
            set fp [open $wrapper_path r]
            set content [read $fp]
            close $fp
            
            # Simple replacement: rename the wrapper entity/architecture to 'top'
            # This works for both 'system' and 'system_wrapper' names
            set wrapper_entity [file rootname [file tail $wrapper_path]]
            regsub -all $wrapper_entity $content "top" new_content
            
            # Ensure the directory exists
            file mkdir [file dirname $top_vhd]
            
            # Write the new top-level
            set fp [open $top_vhd w]
            puts $fp $new_content
            close $fp
            puts "✅ Created bootstrap top-level at: $top_vhd"
            puts "👉 NOTE: You can now instantiate your Soft-CPU or custom logic inside this file."
        }
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
    set_property target_language $target_lang [current_project]
    set_property simulator_language Mixed [current_project]
    puts "⚙️  Framework: Forced target language to $target_lang"
}

puts "✅ Framework Active: Use the 'Sync to Framework' button or type 'sync_bd'."
