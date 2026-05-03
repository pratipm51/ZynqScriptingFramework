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
read_vhdl [glob -nocomplain ./src/hdl/*.vhd ./src/hdl/*.vhdl]
read_xdc "./src/constr/${board_type}.xdc"

# --- Auto-Detect Block Design ---
if {[file exists $bd_script]} {
    puts "📝 Found BD script for $board_type. Sourcing..."
    source $bd_script
    # Ensure the BD has a wrapper
    set bd_file [get_files *.bd]
    set wrapper_file [make_wrapper -files $bd_file -top]
    add_files -norecurse $wrapper_file
    set top_module "system_wrapper"
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
