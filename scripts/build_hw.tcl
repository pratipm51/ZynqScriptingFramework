# scripts/build_hw.tcl - Optimized for Library and Order Support
set board_type [lindex $argv 0]
set part [lindex $argv 1]
set target_lang [lindex $argv 2]
set bd_name [lindex $argv 3]

if {$part == ""} {
    puts "❌ Error: No FPGA part specified. Pass it as the second argument."
    exit 1
}

set output_dir "./hw_build/${board_type}"
set bd_script "./board_configs/${board_type}_bd.tcl"
file mkdir $output_dir

# --- Helper: Read Source files with Multi-Language and Order Support ---
proc read_sources {lib_name path} {
    # 1. Read Verilog (.v)
    set v_files [glob -nocomplain "$path/*.v"]
    if {[llength $v_files] > 0} {
        puts "📦 Reading [llength $v_files] Verilog files into library: $lib_name"
        read_verilog -library $lib_name $v_files
    }

    # 2. Read SystemVerilog (.sv)
    set sv_files [glob -nocomplain "$path/*.sv"]
    if {[llength $sv_files] > 0} {
        puts "📦 Reading [llength $sv_files] SystemVerilog files into library: $lib_name"
        read_verilog -sv -library $lib_name $sv_files
    }

    # 3. Read VHDL (.vhd, .vhdl) with Order Support
    set order_file "$path/compile_order.txt"
    set vhd_files {}

    if {[file exists $order_file]} {
        puts "📜 Using explicit compile order from $order_file"
        set fp [open $order_file r]
        set lines [split [read $fp] "\n"]
        close $fp
        foreach line $lines {
            set f [string trim $line]
            if {$f != "" && ![string match "#*" $f]} {
                set file_ext [file extension $f]
                if {$file_ext == ".vhd" || $file_ext == ".vhdl"} {
                    lappend vhd_files "$path/$f"
                } elseif {$file_ext == ".v"} {
                    read_verilog -library $lib_name "$path/$f"
                } elseif {$file_ext == ".sv"} {
                    read_verilog -sv -library $lib_name "$path/$f"
                }
            }
        }
    } else {
        # Fallback: Smart Sort (Packages first)
        set all_files [glob -nocomplain "$path/*.vhd" "$path/*.vhdl"]
        set pkgs {}
        set logic {}
        foreach f $all_files {
            if {[string match "*_package.vhd*" $f] || [string match "*_pkg.vhd*" $f]} {
                lappend pkgs $f
            } else {
                lappend logic $f
            }
        }
        set vhd_files [concat [lsort $pkgs] [lsort $logic]]
    }

    if {[llength $vhd_files] > 0} {
        puts "📦 Reading [llength $vhd_files] VHDL files into library: $lib_name"
        read_vhdl -library $lib_name $vhd_files
    }
}

# 2. Build Flow
create_project -in_memory -part $part
set_property target_language $target_lang [current_project]

# --- Handle Extra VHDL Libraries from vhdl_libs.txt or environment ---
set libs_file "vhdl_libs.txt"
set lib_entries {}

if {[file exists $libs_file]} {
    puts "📖 Reading VHDL libraries from $libs_file"
    set fp [open $libs_file r]
    set lines [split [read $fp] "\n"]
    close $fp
    foreach line $lines {
        set entry [string trim $line]
        if {$entry != "" && ![string match "#*" $entry]} {
            lappend lib_entries $entry
        }
    }
} elseif {[info exists env(EXTRA_VHDL_LIBS)]} {
    set lib_entries [split $env(EXTRA_VHDL_LIBS) ","]
}

foreach lib_entry $lib_entries {
    set parts [split $lib_entry ":"]
    set lib_name [string trim [lindex $parts 0]]
    set lib_path [string trim [lindex $parts 1]]
    if {$lib_name != "" && $lib_path != ""} {
        read_sources $lib_name $lib_path
    }
}

# --- Read Local Sources ---
read_sources xil_defaultlib "./src/hdl"
read_xdc "./src/constr/${board_type}.xdc"

# --- Auto-Detect Block Design ---
if {[file exists $bd_script]} {
    puts "📝 Sourcing Board Configuration: $bd_script"
    source $bd_script
    
    # --- FORCE LANGUAGE OVERRIDE ---
    # We do this AFTER sourcing because the BD script often has a hardcoded language
    set_property target_language $target_lang [current_project]
    
    # Detect the block design file dynamically
    set bd_design [current_bd_design]
    if {$bd_design == ""} {
        set bd_files [get_files *.bd]
        if {[llength $bd_files] == 0} {
            puts "❌ Error: No Block Design (.bd) file found."
            exit 1
        }
        set bd_file [lindex $bd_files 0]
    } else {
        set bd_file [get_files [get_property NAME $bd_design].bd]
    }
    puts "📂 Using Block Design: $bd_file"

    # Dynamic fallback for bd_name if not provided
    if {$bd_name == ""} {
        if {$bd_design != ""} {
            set bd_name [get_property NAME $bd_design]
        } else {
            set bd_name [file rootname [file tail $bd_file]]
        }
    }

    generate_target all $bd_file
    set wrapper_file [make_wrapper -files $bd_file -top]
    puts "📦 Generated Wrapper: $wrapper_file"
    add_files -norecurse $wrapper_file
    set top_module "top"
} else {
    puts "ℹ️ No board configuration found. Using pure HDL flow with top module: 'top'"
    set top_module "top"
}

# 3. Synthesis & Implementation
synth_design -top $top_module
opt_design
place_design
route_design

if {$bd_name == ""} {
    set bd_name "system"
}

# 4. Export Hardware
puts "📂 Exporting Hardware Platform to: $output_dir/${bd_name}.xsa"
write_hw_platform -fixed -force -file "$output_dir/${bd_name}.xsa"
puts "📂 Exporting Bitstream to: $output_dir/${bd_name}.bit"
write_bitstream -force "$output_dir/${bd_name}.bit"
