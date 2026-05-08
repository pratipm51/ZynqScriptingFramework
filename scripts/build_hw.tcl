set board_type [lindex $argv 0]

# 1. Hardware Definitions
if {$board_type == "ebaz"} {
    set part "xc7z010clg400-1"
} elseif {$board_type == "zedboard"} {
    set part "xc7z020clg484-1"
} else {
    puts "Unknown board!"; exit 1
}

set output_dir "./hw_build/${board_type}"
set bd_script "./scripts/${board_type}_bd.tcl"
file mkdir $output_dir

# 2. Build Flow
create_project -in_memory -part $part

# --- Handle Extra VHDL Libraries ---
if {[info exists env(EXTRA_VHDL_LIBS)]} {
    set libs [split $env(EXTRA_VHDL_LIBS) ","]
    foreach lib_entry $libs {
        set parts [split $lib_entry ":"]
        set lib_name [string trim [lindex $parts 0]]
        set lib_path [string trim [lindex $parts 1]]
        if {$lib_name != "" && $lib_path != ""} {
            set vhd_files [glob -nocomplain "$lib_path/*.vhd" "$lib_path/*.vhdl"]
            if {[llength $vhd_files] > 0} {
                puts "📦 Adding [llength $vhd_files] files to library: $lib_name from $lib_path"
                read_vhdl -library $lib_name $vhd_files
            } else {
                puts "⚠️ Warning: No VHDL files found for library $lib_name in $lib_path"
            }
        }
    }
}

read_vhdl [glob -nocomplain ./src/hdl/*.vhd ./src/hdl/*.vhdl]
read_xdc "./src/constr/${board_type}.xdc"

# --- Auto-Detect Block Design ---
if {[file exists $bd_script]} {
    puts "📝 Found BD script for $board_type. Sourcing..."
    source $bd_script
    # Ensure the BD has a wrapper
    set bd_file [get_files *.bd]
    generate_target all $bd_file
    set wrapper_file [make_wrapper -files $bd_file -top]
    add_files -norecurse $wrapper_file
    set top_module "top"
} else {
    puts "ℹ️ No BD script found. Using pure HDL flow."
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
