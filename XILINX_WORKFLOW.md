# THE UNIFIED XILINX 2025.1 MULTI-BOARD WORKFLOW GUIDE

Save this entire document as a single file named **XILINX_GOLDEN_WORKFLOW.md**.

## 1. Introduction
This guide provides a professional, script-based workflow for Vivado/Vitis 2025.1. It allows you to manage multiple Zynq boards (EBAZ4205, Zedboard, etc.) in a single Git repository without tracking tool-generated "junk" files.

---

## 2. Directory Structure
Create this structure in your project root:
```text
/project_root
├── src/
│   ├── hdl/       <-- Your Verilog/VHDL files
│   └── constr/    <-- ebaz.xdc, zedboard.xdc, etc.
├── scripts/       <-- build_hw.tcl, build_sw.py, and board_bd.tcl
├── sw/            <-- Your C/C++ application source code
├── hw_build/      <-- (Ignored) Vivado build outputs
└── vitis_ws/      <-- (Ignored) Vitis workspace
```

---

## 3. Configuration Files

### A. The Whitelist .gitignore
Save as `.gitignore` in the root.
```git
# Ignore everything
*
!*/

# Whitelist Sources
!src/
!scripts/
!sw/
!README.md
!.gitignore
!Makefile

# Whitelist Extensions
!*.v
!*.sv
!*.vhd
!*.c
!*.h
!*.py
!*.tcl
!*.xdc

# Ignore Build Artifacts
hw_build/
vitis_ws/
.Xil/
*.log
*.jou
```

### B. Master Makefile
Save as `Makefile` in the root. It includes a check to ensure Hardware exists before Software builds.
```makefile
BOARD ?= ebaz
HW_XSA = ./hw_build/$(BOARD)/system.xsa

all: hw sw

# Build Hardware
hw:
	@echo "🚀 Building Hardware for $(BOARD)..."
	vivado -mode batch -source scripts/build_hw.tcl -tclargs $(BOARD)

# Build Software (with safety check for XSA)
sw:
	@if [ ! -f $(HW_XSA) ]; then \
		echo "❌ Error: Hardware XSA not found at $(HW_XSA). Run 'make hw' first."; \
		exit 1; \
	fi
	@echo "🚀 Building Software for $(BOARD)..."
	vitis -s scripts/build_sw.py $(BOARD)

gui:
	vivado -mode gui &

clean:
	rm -rf hw_build vitis_ws .Xil *.log *.jou
```

### C. Vivado Build Script (with Auto-BD Detection)
Save as `scripts/build_hw.tcl`.
```tcl
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
read_verilog [glob -nocomplain ./src/hdl/*.v]
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
```

### D. Vitis Python Script
Save as `scripts/build_sw.py`.
```python
import vitis
import sys
import os

# Get board name from Makefile
board = sys.argv[1] if len(sys.argv) > 1 else "ebaz"
XSA_PATH = f"./hw_build/{board}/system.xsa"
WORKSPACE = f"./vitis_ws/{board}"

client = vitis.create_client()
client.set_workspace(path=WORKSPACE)

# 1. Create Platform Component
platform = client.create_platform_component(
    name=f"{board}_plat", 
    hw=XSA_PATH, 
    os="standalone", 
    cpu="ps7_cortexa9_0"
)
platform.build()

# 2. Create Application Component
app = client.create_app_component(
    name=f"{board}_app", 
    platform=f"{board}_plat", 
    domain="standalone_ps7_cortexa9_0", 
    template="empty_application"
)

# 3. Link Git-tracked source code
app.import_sources(from_loc="./sw", target_loc="src", soft_link=True)
app.build()
```

---

## 4. Summary of Use
- **Default Build (EBAZ):** `make`
- **Specific Board Build:** `make BOARD=zedboard`
- **Cleaning:** `make clean`
- **Adding IP/Block Design:** 
  1. `make gui`
  2. Modify visually.
  3. Run `write_bd_tcl -force scripts/ebaz_bd.tcl` in Vivado console.
  4. Save and close.
- **Git Commit:** Just `git add .` and `git commit`. Only your code and scripts will be saved.

