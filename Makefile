BOARD ?= ebaz
HW_XSA = ./hw_build/$(BOARD)/system.xsa
BIT_FILE = ./hw_build/$(BOARD)/system.bit

FSBL_ELF = ./vitis_ws/$(BOARD)_plat/zynq_fsbl/build/fsbl.elf
APP_ELF = ./vitis_ws/$(BOARD)_app/build/$(BOARD)_app.elf

.PHONY: all hw sw boot edit-hw sync-scripts gui program clean

all: hw sw

# Build Hardware
hw:
	@echo "🚀 Building Hardware for $(BOARD)..."
	vivado -mode batch -source scripts/build_hw.tcl -tclargs $(BOARD)
	rm -f *.log *.jou

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

# GUI Workflow: Open for editing
edit-hw:
	@echo "🛠️ Opening Block Design for $(BOARD)..."
	@if [ -f scripts/$(BOARD)_bd.tcl ]; then \
		vivado -source scripts/$(BOARD)_bd.tcl; \
	else \
		vivado; \
	fi

# Reminder for the user
sync-scripts:
	@echo "📝 Inside Vivado Tcl Console, run:"
	@echo "   write_bd_tcl -force ./scripts/$(BOARD)_bd.tcl"

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
	rm -rf hw_build vitis_ws .Xil .gen .srcs .cache project_1 *.log *.jou BOOT.BIN boot.bif
