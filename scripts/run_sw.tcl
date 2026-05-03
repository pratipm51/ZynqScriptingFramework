# scripts/run_sw.tcl
set board [lindex $argv 0]
set bitstream [lindex $argv 1]
set elf [lindex $argv 2]
set ps7_init [lindex $argv 3]

puts "🚀 Connecting to hw_server..."
if { [catch {connect} err] } {
    puts "❌ Connection failed: $err. Trying tcp:localhost:3121..."
    connect -url tcp:localhost:3121
}

# Select the ARM core
puts "🛰️ Selecting ARM Target..."
targets -set -nocase -filter {name =~ "arm*#0"}

# Interrupt U-Boot immediately
puts "🛑 Force-Stopping ARM Core..."
catch {stop}
after 200

# We use processor reset only to avoid triggering NAND bootrom again
puts "📦 Resetting ARM Core..."
rst -processor
after 500
catch {stop}

puts "💎 Programming Bitstream: $bitstream..."
fpga -f $bitstream

puts "⚙️ Initializing PS7 Hardware..."
source $ps7_init
ps7_init
ps7_post_config

puts "🚀 Loading Application ELF: $elf..."
dow $elf

puts "🎉 Executing Application..."
con
after 2000
exit
