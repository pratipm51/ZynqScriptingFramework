# 1. Project-wide Configuration
# Create a file named 'project_config.mk' to persist these values.
-include project_config.mk

BOARD ?= my_board
PART  ?= xc7z010clg400-1
TARGET_LANGUAGE ?= VHDL
# Active application component name (default: zynq_app)
APP ?= zynq_app

# Extra VHDL libraries (alternative to vhdl_libs.txt file)
export EXTRA_VHDL_LIBS

# Software source directories (alternative to sw_sources.txt file)
export USER_SW_DIRS

# Custom target for the sw/Makefile (default to all)
SW_TARGET ?= all

HW_XSA = ./hw_build/$(BOARD)/system.xsa
BIT_FILE = ./hw_build/$(BOARD)/system.bit

FSBL_ELF = ./vitis_ws/$(BOARD)_plat/zynq_fsbl/build/fsbl.elf
# Default application ELF path (can be overridden for custom CPUs)
APP_ELF ?= ./vitis_ws/$(BOARD)_app/build/$(BOARD)_app.elf
# Zynq PS-side application (Active if arm_sources.txt or APP directory exists)
ZYNQ_ELF = ./vitis_ws/$(APP)/build/$(APP).elf
PS_INIT = ./vitis_ws/$(BOARD)_plat/export/$(BOARD)_plat/hw/sdt/ps7_init.tcl

.DEFAULT_GOAL := help

# 1. Project-wide Configuration
# ... (rest of config)

# --- Help System ---
help:
	@echo "🚀 ZynqScriptingFramework: The Script-First Workflow"
	@echo ""
	@echo "Available Targets:"
	@echo "  make hw              - Synthesize VHDL, implement design, and generate Bitstream"
	@echo "  make sw              - Build Zynq ARM Platform and all Application ELFs"
	@echo "  make all             - Full Build: Hardware + Software"
	@echo "  make run             - Performs PS7 Init, Flashes Bitstream, and executes ELFs via JTAG"
	@echo "  make boot            - Packages FSBL, Bitstream, and App into BOOT.BIN"
	@echo "  make program         - Downloads the Bitstream only to the PL (no software init)"
	@echo "  make edit-hw         - Opens the Block Design in Vivado GUI with Auto-Sync button"
	make edit-sw         - Opens Vitis Unified IDE for interactive development/testing
	make sync-sw         - Harvests source changes from Vitis GUI back to the framework
	make delete-sw       - Removes application sources and Vitis workspace artifacts
	make list-arm-params - Shows paths to generated xparameters.h and driver headers

	@echo "  make load-ram        - Pushes BOOT.BIN to DDR (0x08000000) for manual NAND flashing"
	@echo "  make gui             - Launches a standard Vivado GUI instance"
	@echo "  make clean           - Wipes all build artifacts, temporary projects, and log files"
	@echo ""
	@echo "Current Project Settings (from project_config.mk):"
	@echo "  BOARD:           $(BOARD)"
	@echo "  PART:            $(PART)"
	@echo "  TARGET_LANGUAGE: $(TARGET_LANGUAGE)"
	@echo "  ACTIVE APP:      $(APP)"
	@echo ""

.PHONY: all hw sw boot run edit-hw sync-scripts gui program clean help

# Build Hardware
hw:
	@if [ ! -f board_configs/$(BOARD)_bd.tcl ]; then \
		echo "❌ Error: Board configuration not found at board_configs/$(BOARD)_bd.tcl"; \
		echo "   Please run 'make edit-hw' first to create your hardware design."; \
		exit 1; \
	fi
	@echo "🚀 Building Hardware for $(BOARD) (Part: $(PART))..."
	rm -rf project_1 myproj clockInfo.txt
	vivado -mode batch -source scripts/build_hw.tcl -tclargs $(BOARD) $(PART) $(TARGET_LANGUAGE)
	rm -f *.log *.jou clockInfo.txt

# Build Software
sw:
	@if [ ! -f $(HW_XSA) ]; then \
        echo "❌ Error: Hardware XSA not found at $(HW_XSA). Run 'make hw' first."; \
        exit 1; \
    fi
	@echo "🚀 Ensuring Zynq Platform and Application '$(APP)' are ready..."
	vitis -s scripts/build_sw.py $(BOARD) $(APP)
	@if [ -f sw/Makefile ]; then \
		echo "🛠️  Detected custom software Makefile. Running target: $(SW_TARGET)..."; \
		$(MAKE) -C sw BOARD=$(BOARD) $(SW_TARGET); \
	fi

# GUI Workflow: Open Vitis for interactive development
edit-sw: sw
	@echo "🛠️ Opening Vitis Unified IDE for $(BOARD)..."
	vitis -w ./vitis_ws &

# Harvest changes from Vitis GUI back to the framework sources
sync-sw:
	@python3 scripts/sync_sw.py $(APP)

# Safely delete a software application
delete-sw:
	@echo "🗑️  Deleting application '$(APP)'..."
	@if [ "$(APP)" = "zynq_app" ] && [ -d sw/arm ]; then \
		rm -rf sw/arm; \
	elif [ -d sw/$(APP) ]; then \
		rm -rf sw/$(APP); \
	fi
	@rm -rf vitis_ws/$(APP)
	@echo "✅ Application '$(APP)' removed from framework and workspace."

# Generate BOOT.BIN
boot:
	@if [ ! -f $(FSBL_ELF) ] || [ ! -f $(BIT_FILE) ] || [ ! -f $(APP_ELF) ]; then \
		echo "❌ Error: Missing artifacts. Run 'make all' first."; \
		exit 1; \
	fi
	@echo "📦 Generating BOOT.BIN for $(BOARD)..."
	@echo "img: { [bootloader] $(FSBL_ELF) $(BIT_FILE) $(APP_ELF) }" > boot.bif
	bootgen -image boot.bif -arch zynq -o BOOT.BIN -w
	@rm boot.bif
	@echo "✅ BOOT.BIN created successfully."

# Stage BOOT.BIN to RAM for manual NAND flashing
load-ram:
	@if [ ! -f BOOT.BIN ]; then \
		echo "❌ Error: BOOT.BIN not found. Run 'make boot' first."; \
		exit 1; \
	fi
	@echo "🚀 Pushing BOOT.BIN to DDR at 0x08000000 via JTAG..."
	xsct -eval "connect; targets -set -nocase -filter {name =~ \"arm*#0\"}; stop; dow -data BOOT.BIN 0x08000000; con; exit"
	@echo "✅ Data loaded to RAM. Now use U-Boot to write to NAND."

# Launch Software via JTAG (Full Init)
run:
	@if [ ! -f $(BIT_FILE) ]; then \
		echo "❌ Error: Bitstream not found. Run 'make hw' first."; \
		exit 1; \
	fi
	@echo "🚀 Launching Full System on $(BOARD)..."
	@# We pass BOTH ELFs to the run script. It will handle loading them correctly.
	xsct scripts/run_sw.tcl $(BOARD) $(BIT_FILE) $(APP_ELF) $(PS_INIT) $(ZYNQ_ELF)

# GUI Workflow: Open for editing
edit-hw:
	@echo "🛠️ Opening Block Design for $(BOARD)..."
	rm -rf project_1 myproj clockInfo.txt
	@if [ -f board_configs/$(BOARD)_bd.tcl ]; then \
		vivado -mode gui -source scripts/vivado_setup.tcl -tclargs $(BOARD) $(TARGET_LANGUAGE); \
	else \
		echo "ℹ️ No configuration found. Opening blank Vivado instance for $(BOARD)..."; \
		vivado -mode gui -source scripts/vivado_setup.tcl -tclargs $(BOARD) $(TARGET_LANGUAGE); \
	fi

# Reminder for the user
sync-scripts:
	@echo "📝 Inside Vivado Tcl Console, run:"
	@echo "   write_bd_tcl -force ./board_configs/$(BOARD)_bd.tcl"

# Discover Zynq ARM hardware parameters and drivers
list-arm-params:
	@echo "🔍 Zynq Hardware Parameter Source of Truth:"
	@find ./vitis_ws/$(BOARD)_plat/export -name "xparameters.h" | head -n 1
	@echo ""
	@echo "📂 Zynq Driver Include Directory:"
	@find ./vitis_ws/$(BOARD)_plat/export -name "xil_printf.h" | xargs dirname | head -n 1

gui:
	vivado -mode gui &

program:
	@if [ ! -f $(BIT_FILE) ]; then \
		echo "❌ Error: $(BIT_FILE) not found. Run 'make hw' first."; \
		exit 1; \
	fi
	@echo "🛰️  Searching for JTAG Cable and Board..."
	vivado -mode batch -source scripts/program_fpga.tcl -tclargs $(BIT_FILE) $(BOARD)

clean:
	rm -rf hw_build vitis_ws .Xil .gen .srcs .cache project_1 myproj *.log *.jou BOOT.BIN boot.bif clockInfo.txt
