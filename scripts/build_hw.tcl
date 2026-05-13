# scripts/build_hw.tcl - Optimized for Library and Order Support
set board_type [lindex $argv 0]
set part [lindex $argv 1]
set target_lang [lindex $argv 2]

if {$part == ""} {
    puts "❌ Error: No FPGA part specified. Pass it as the second argument."
    exit 1
}

set output_dir "./hw_build/${board_type}"
set bd_script "./board_configs/${board_type}_bd.tcl"
file mkdir $output_dir

# --- Helper: Read VHDL files with Order Support ---
proc read_vhdl_ordered {lib_name path} {
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
                lappend vhd_files "$path/$f"
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
        puts "📦 Reading [llength $vhd_files] files into library: $lib_name"
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
        read_vhdl_ordered $lib_name $lib_path
    }
}

# --- Read Local Sources ---
read_vhdl_ordered xil_defaultlib "./src/hdl"
read_xdc "./src/constr/${board_type}.xdc"

# --- Auto-Detect Block Design ---
if {[file exists $bd_script]} {
    puts "📝 Sourcing Board Configuration: $bd_script"
    source $bd_script
    set bd_file [get_files *.bd]
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

# 4. Export Hardware
write_hw_platform -fixed -force -file "$output_dir/system.xsa"
write_bitstream -force "$output_dir/system.bit"
