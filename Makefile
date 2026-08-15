# 1. Project-wide Configuration
# Create a file named 'project_config.mk' to persist these values.
-include project_config.mk

BOARD ?= my_board
PART  ?= xc7z010clg400-1
TARGET_LANGUAGE ?= VHDL
BD_NAME ?= system

# --- V2 Dynamic Configuration Logic ---
# Use command line APP if provided, otherwise use DEFAULT_APP from config
ACTIVE_APP = $(if $(APP),$(APP),$(DEFAULT_APP))

# Find the matching entry in APPS (e.g., "hello_world:basic_plat:standalone")
APP_TUPLE = $(filter $(ACTIVE_APP):%, $(APPS))

# Parse the tuple
APP_NAME = $(word 1,$(subst :, ,$(APP_TUPLE)))
PLAT_NAME = $(word 2,$(subst :, ,$(APP_TUPLE)))
APP_OS   = $(word 3,$(subst :, ,$(APP_TUPLE)))

# Fallback values if parsing fails
REAL_APP = $(if $(APP_NAME),$(APP_NAME),$(ACTIVE_APP))
REAL_PLAT = $(if $(PLAT_NAME),$(PLAT_NAME),$(BOARD)_standalone_plat)
REAL_OS = $(if $(APP_OS),$(APP_OS),standalone)

# Update paths to use the parsed components
FSBL_ELF = ./vitis_ws/$(REAL_PLAT)/zynq_fsbl/build/fsbl.elf
APP_ELF  ?= ./vitis_ws/$(REAL_APP)/build/$(REAL_APP).elf
ZYNQ_ELF = ./vitis_ws/$(REAL_APP)/build/$(REAL_APP).elf
PS_INIT  = ./vitis_ws/$(REAL_PLAT)/export/$(REAL_PLAT)/hw/sdt/ps7_init.tcl
BIT_FILE = ./hw_build/$(BOARD)/$(BD_NAME).bit
HW_XSA   = ./hw_build/$(BOARD)/$(BD_NAME).xsa

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
	@echo "  make edit-sw         - Opens Vitis Unified IDE for interactive development/testing"
	@echo "  make sync-sw         - Harvests source changes from Vitis GUI back to the framework"
	@echo "  make delete-sw       - Removes application sources and Vitis workspace artifacts"
	@echo "  make list-arm-params - Shows paths to generated xparameters.h and driver headers"
	@echo "  make docs            - Renders FRAMEWORK_GUIDE.md to docs/FRAMEWORK_GUIDE.html"

	@echo "  make load-ram        - Pushes BOOT.BIN to DDR (0x08000000) for manual NAND flashing"
	@echo "  make gui             - Launches a standard Vivado GUI instance"
	@echo "  make clean           - Wipes all build artifacts, temporary projects, and log files"
	@echo ""
	@echo "Current Project Settings (from project_config.mk):"
	@echo "  BOARD:           $(BOARD)"
	@echo "  PART:            $(PART)"
	@echo "  BD_NAME:         $(BD_NAME)"
	@echo "  TARGET_LANGUAGE: $(TARGET_LANGUAGE)"
	@echo "  ACTIVE APP:      $(APP)"
	@echo ""

.PHONY: all hw sw boot run edit-hw sync-scripts gui program clean help docs

# Build Hardware
hw:
	@if [ ! -f board_configs/$(BOARD)_bd.tcl ]; then \
		echo "❌ Error: Board configuration not found at board_configs/$(BOARD)_bd.tcl"; \
		echo "   Please run 'make edit-hw' first to create your hardware design."; \
		exit 1; \
	fi
	@echo "🚀 Building Hardware for $(BOARD) (Part: $(PART), BD: $(BD_NAME))..."
	rm -rf project_1 myproj clockInfo.txt
	vivado -mode batch -source scripts/build_hw.tcl -tclargs $(BOARD) $(PART) $(TARGET_LANGUAGE) $(BD_NAME)
	rm -f *.log *.jou clockInfo.txt

# Build Software
sw:
	@if [ ! -f $(HW_XSA) ]; then \
        echo "❌ Error: Hardware XSA not found at $(HW_XSA). Run 'make hw' first."; \
        exit 1; \
    fi
	@echo "🚀 Ensuring Zynq Platform '$(REAL_PLAT)' and App '$(REAL_APP)' ($(REAL_OS)) are ready..."
	vitis -s scripts/build_sw.py $(BOARD) $(REAL_APP) $(REAL_PLAT) $(REAL_OS) $(BD_NAME)

# GUI Workflow: Open Vitis for interactive development
# Ensures the platform exists but does NOT create/build an app - that's left
# to the user inside the GUI (or a later 'make sw APP=...' / 'make sync-sw').
edit-sw:
	@if [ ! -f $(HW_XSA) ]; then \
		echo "❌ Error: Hardware XSA not found at $(HW_XSA). Run 'make hw' first."; \
		exit 1; \
	fi
	@echo "🚀 Ensuring Zynq Platform '$(REAL_PLAT)' is ready (no app will be created)..."
	vitis -s scripts/build_sw.py $(BOARD) "" $(REAL_PLAT) $(REAL_OS) $(BD_NAME)
	@echo "🛠️ Opening Vitis Unified IDE for $(BOARD)..."
	vitis -w ./vitis_ws &

# Harvest changes from Vitis GUI back to the framework sources
# Loops through ALL apps and platforms defined in project_config.mk
sync-sw:
	@echo "🔄 Syncing ALL applications and platforms back to framework..."
	@for app_entry in $(APPS); do \
		app=$$(echo $$app_entry | cut -d':' -f1); \
		plat=$$(echo $$app_entry | cut -d':' -f2); \
		echo "📂 Syncing App: $$app (Plat: $$plat)..."; \
		python3 scripts/sync_sw.py $$app $$plat; \
	done

# Safely delete a software application
delete-sw:
	@echo "🗑️  Deleting application '$(APP_NAME)'..."
	@if [ "$(APP_NAME)" = "zynq_app" ] && [ -d sw/zynq_ps ]; then \
		rm -rf sw/zynq_ps; \
	elif [ -d sw/$(APP_NAME) ]; then \
		rm -rf sw/$(APP_NAME); \
	fi
	@rm -rf vitis_ws/$(APP_NAME)
	@echo "✅ Application '$(APP_NAME)' removed from framework and workspace."

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
		vivado -mode gui -source scripts/vivado_setup.tcl -tclargs $(BOARD) $(TARGET_LANGUAGE) $(PART); \
	else \
		echo "ℹ️ No configuration found. Opening blank Vivado instance for $(BOARD)..."; \
		vivado -mode gui -source scripts/vivado_setup.tcl -tclargs $(BOARD) $(TARGET_LANGUAGE) $(PART); \
	fi

# Reminder for the user
sync-scripts:
	@echo "📝 Inside Vivado Tcl Console, run:"
	@echo "   write_bd_tcl -force ./board_configs/$(BOARD)_bd.tcl"

# Discover Zynq ARM hardware parameters and drivers
list-arm-params:
	@echo "🔍 Zynq Hardware Parameter Source of Truth:"
	@find ./vitis_ws/$(REAL_PLAT)/export -name "xparameters.h" | head -n 1
	@echo ""
	@echo "📂 Zynq Driver Include Directory:"
	@find ./vitis_ws/$(REAL_PLAT)/export -name "xil_printf.h" | xargs dirname | head -n 1

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

# Generate HTML docs from FRAMEWORK_GUIDE.md (untracked, gitignored output)
docs:
	@echo "📖 Rendering FRAMEWORK_GUIDE.md -> docs/FRAMEWORK_GUIDE.html..."
	python3 scripts/gen_docs.py FRAMEWORK_GUIDE.md docs/FRAMEWORK_GUIDE.html
