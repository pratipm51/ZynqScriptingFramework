BOARD ?= ebaz

# Extra VHDL libraries (alternative to vhdl_libs.txt file)
export EXTRA_VHDL_LIBS

# Software source directories (alternative to sw_sources.txt file)
export USER_SW_DIRS

HW_XSA = ./hw_build/$(BOARD)/system.xsa
BIT_FILE = ./hw_build/$(BOARD)/system.bit

FSBL_ELF = ./vitis_ws/$(BOARD)_plat/zynq_fsbl/build/fsbl.elf
APP_ELF = ./vitis_ws/$(BOARD)_app/build/$(BOARD)_app.elf
PS_INIT = ./vitis_ws/$(BOARD)_plat/export/$(BOARD)_plat/hw/sdt/ps7_init.tcl

.PHONY: all hw sw boot run edit-hw sync-scripts gui program clean

all: hw sw

# Build Hardware
hw:
	@echo "🚀 Building Hardware for $(BOARD)..."
	rm -rf project_1 myproj clockInfo.txt
	vivado -mode batch -source scripts/build_hw.tcl -tclargs $(BOARD)
	rm -f *.log *.jou clockInfo.txt

# Build Software
sw:
	@if [ ! -f $(HW_XSA) ]; then \
        echo "❌ Error: Hardware XSA not found at $(HW_XSA). Run 'make hw' first."; \
        exit 1; \
    fi
	@echo "🚀 Building Software for $(BOARD)..."
	vitis -s scripts/build_sw.py $(BOARD)

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
	@if [ ! -f $(BIT_FILE) ] || [ ! -f $(APP_ELF) ]; then \
		echo "❌ Error: Missing artifacts. Run 'make all' first."; \
		exit 1; \
	fi
	@echo "🚀 Launching Software and Hardware on $(BOARD)..."
	xsct scripts/run_sw.tcl $(BOARD) $(BIT_FILE) $(APP_ELF) $(PS_INIT)

# GUI Workflow: Open for editing
edit-hw:
	@echo "🛠️ Opening Block Design for $(BOARD)..."
	rm -rf project_1 myproj clockInfo.txt
	@if [ -f board_configs/$(BOARD)_bd.tcl ]; then \
		vivado -mode gui -source scripts/vivado_setup.tcl -tclargs $(BOARD); \
	else \
		vivado; \
	fi

# Reminder for the user
sync-scripts:
	@echo "📝 Inside Vivado Tcl Console, run:"
	@echo "   write_bd_tcl -force ./board_configs/$(BOARD)_bd.tcl"

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
