# scripts/program_fpga.tcl
set bitfile [lindex $argv 0]
set board_type [lindex $argv 1]

# 1. Check bitfile existence
if {![file exists $bitfile]} { 
    puts "❌ Error: Bitfile $bitfile not found"; 
    exit 1 
}

# 2. Start Hardware Manager
open_hw_manager
if { [catch {connect_hw_server -url localhost:3121} err] } {
    puts "❌ Error: Could not connect to hw_server. Is the cable plugged in?"; 
    exit 1
}

# 3. Try to open the target
if { [catch {open_hw_target} err] } {
    puts "❌ Error: JTAG Cable found, but no target device detected. Check Board Power/Jumper."; 
    exit 1
}

# 4. Check for the Zynq Chip (xc7z*)
set dev [get_hw_devices xc7z*]
if { [llength $dev] == 0 } {
    puts "❌ Error: Connected, but no Zynq-7000 device found in JTAG chain.";
    exit 1
}

puts "✅ Found Device: $dev. Programming $board_type..."

# 5. Program
current_hw_device $dev
set_property PROGRAM.FILE $bitfile $dev
program_hw_devices $dev
close_hw_manager

puts "🎉 Programming Successful!"
