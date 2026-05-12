# 🚀 Zynq-VHDL Logic: The Script-First Framework
**A Professional Workflow for Xilinx Zynq-7000 SoC Development**

---

## 1. Introduction
This framework provides a structured, version-control-friendly environment for Zynq-7000 FPGA development. It prioritizes **VHDL** for logic and **C** for software.

---

## 2. Directory Structure
```text
/project_root
├── src/
│   ├── hdl/       <-- Your VHDL files (*.vhd, *.vhdl)
│   └── constr/    <-- Physical constraints (*.xdc)
├── sw/            <-- Software source code
├── board_configs/ <-- Your Block Design scripts (*_bd.tcl)
├── scripts/       <-- The framework engine (Automation scripts)
├── utilities/     <-- Standalone tools (Uploader, etc.)
├── docs/          <-- Design documentation
├── Makefile       <-- The framework command center
└── .gitignore     <-- Whitelist-based filter for Git
```

---

## 3. Hardware Hierarchy & Integration

This framework strictly follows a **User-First Master Top-Level** approach. 

1. **`top.vhd` (The Master - MANDATORY)**: 
   - This is your project's absolute top-level file and is **required for all designs**, even if your project only contains the Zynq PS and no additional HDL logic.
   - It acts as the permanent anchor for your physical pins (XDC constraints).
   - You are responsible for instantiating the Zynq System (the wrapper) here.
2. **The System Wrapper**: When you run `make hw`, the framework generates a VHDL wrapper for your Block Design. 
   - **Vivado 2025.1 and earlier**: The entity name is usually **`system_wrapper`**.
   - **Vivado 2025.2 and later**: The entity name is usually simply **`system`**.
   - **Verification**: Use the **Port Synchronization** step below to verify the correct name for your specific Vivado version.
3. **Naming Convention**: Your Block Design **must** be named `system` for the automation to work correctly.

---

## 4. The Two-Phase Workflow

### Phase 1: The Initialization (GUI Required)

Since every Zynq board is different, the framework does not include a default Block Design. Follow these steps to initialize your project:

1. **Construct/Open**: Run `make edit-hw`.
2. **Create Design**: Create a Block Design named **`system`**.
3. **Configure**: Add the **Zynq7 Processing System** IP. Run "Block Automation" (which applies board-specific presets if available).
4. **Port Synchronization**:
   - To ensure your `top.vhd` matches your hardware:
   - In the Sources tab, right-click `system.bd` and select **"Create HDL Wrapper"**.
   - Open the generated `system_wrapper.vhd` (or `system.vhd`) and copy its port list.
   - Update the `component` declaration in your `src/hdl/top.vhd` to match this list.
5. **Freeze to Script**:
   - In the Vivado GUI, click the **"Sync to Framework"** button on the top toolbar.
   - **OR** run this command in the Tcl Console:
     ```tcl
     write_bd_tcl -force ./board_configs/${BOARD}_bd.tcl
     ```

*(Note: You do **not** need to commit the generated wrapper; the framework handles this automatically during the build phase. Each run of `make hw` or `make edit-hw` will automatically clean up any existing temporary project files to ensure a fresh environment.)*

### Phase 2: The Development Loop (CLI)

Below is the complete guide to the framework's `Makefile` targets:

| Target | Description |
| :--- | :--- |
| `make hw` | **Hardware Build:** Runs Vivado in batch mode. Synthesizes VHDL, implements the design, generates the Bitstream, and exports the `.xsa` platform. |
| `make sw` | **Software Build:** Runs Vitis. Creates/updates the platform component and compiles the C application into an `.elf` file. |
| `make` | **Full Build:** Shortcut for `make hw` followed by `make sw`. |
| `make run` | **JTAG Execution:** The primary "Test" command. Performs a full PS7 initialization (enables clocks), downloads the Bitstream and ELF, and starts execution. |
| `make boot` | **Boot Image:** Uses `bootgen` to create a `BOOT.BIN` file containing the FSBL, Bitstream, and Application for SD/NAND booting. |
| `make program` | **Flash FPGA:** Downloads *only* the Bitstream to the FPGA. (Note: Clocks will remain disabled until a software init occurs). |
| `make edit-hw` | **GUI Editor:** Opens the Block Design in Vivado. Automatically adds the **"Sync to Framework"** button to the toolbar for easy saving. |
| `make list-arm-params` | **Discovery:** Shows the absolute paths to the generated `xparameters.h` and driver headers for Zynq ARM development. |
| `make load-ram` | **Maintenance:** Pushes the `BOOT.BIN` to DDR memory via JTAG at `0x08000000`. Useful for manual NAND flashing via U-Boot. |
| `make gui` | **Vivado GUI:** Launches a standard Vivado GUI instance in the background. |
| `make clean` | **Cleanup:** Wipes all build artifacts (`hw_build`, `vitis_ws`), temporary Vivado projects (`project_1`, `myproj`), and log files. |

---

## 5. Troubleshooting: Why isn't my PL logic running?

If your VHDL logic is clocked by a Zynq PS clock (e.g., `FCLK_CLK0`), it **will not run** by simply flashing the bitstream with `make program`. 

**The Zynq PS clocks are disabled by default on power-up.** You must run `make run` to execute the PS initialization (via `ps7_init.tcl`), which enables the clocks and resets the PL logic.

---

## 6. Advanced Features

### External VHDL Libraries (`vhdl_libs.txt`)
If your project requires external VHDL codebases that must be compiled into specific libraries (e.g., **NeoRV32**), create a file named `vhdl_libs.txt` in your project root. 

**Format:** `lib_name:path/to/rtl` (one per line).

**Example `vhdl_libs.txt`:**
```text
neorv32:/home/user/neorv32/rtl/core
custom_lib:./src/custom_rtl
```

**Key Features:**
- **Automatic Detection:** The framework finds all `.vhd` and `.vhdl` files in the specified path.
- **Library Mapping:** It uses Vivado's `read_vhdl -library` command to assign the files to the correct namespace.
- **Path Flexibility:** Supports both **absolute paths** (recommended for shared cores) and **relative paths**.

**VHDL Usage:**
Once configured, you can access the library in your code like this:
```vhdl
library neorv32;
use neorv32.neorv32_package.all;
```

---

### Multiple Software Directories (`sw_sources.txt`)
To include multiple software source or include directories, create a file named `sw_sources.txt` in your project root. List one directory path per line:

```text
# Example sw_sources.txt
./sw
../shared_libs/common
../neorv32/sw/lib/runtime
```

The framework will automatically:
1. Read this file during `make sw`.
2. Import all files from these directories into your Vitis project.
3. If this file is missing, it falls back to the `./sw` directory.

---

### VHDL Compilation Order
For complex designs with multiple packages and dependencies, you can control the compilation order:

1. **Smart Sort (Automatic)**: By default, the framework automatically identifies files containing `_package` or `_pkg` in their name and compiles them before other logic files in the same library.
2. **Explicit Order**: If you need total control, create a file named `compile_order.txt` in the source folder (e.g., `src/hdl/compile_order.txt`). List one filename per line in the desired compilation sequence.

---

## 7. Global Configuration (`project_config.mk`)

Instead of passing `BOARD` and `PART` on the command line every time, you can create a file named **`project_config.mk`** in the root of your project.

**Format:**
```make
BOARD = ebaz4205
PART  = xc7z010clg400-1
```

The framework will automatically read this file and use these values as the defaults for all commands.

---

## 8. Hybrid Multi-CPU Support (ARM + Soft-CPU)

This framework supports true **Dual-CPU** development, where you can have custom code running on both the Zynq ARM core and a soft-CPU in the PL (e.g., NeoRV32).

### Case A: Custom Soft-CPU (PL) Only
If you only care about the soft-CPU:
1. Create `sw/Makefile` (see template at `sw/Makefile.neorv32`).
2. The framework will still build a Vitis "Platform" (to handle Zynq clocks/DDR init) but will use your Makefile for the main app.
3. Set `APP_ELF = sw/main.elf` in your project `Makefile`.
4. **Custom Targets**: You can pass specific targets to your software Makefile using the `SW_TARGET` variable (e.g., `make sw SW_TARGET=clean`).

### Case B: Custom ARM (PS) + Custom Soft-CPU (PL)
If you want to customize the Zynq side (e.g., for Ethernet drivers) while also running a soft-CPU:
1. **Soft-CPU**: Define its build in `sw/Makefile` and `sw_sources.txt`.
2. **ARM core**: Create a directory (e.g., **`sw/arm/`**) and list it in **`arm_sources.txt`**.
3. **Template**: A minimal ARM manager template is available at `sw/arm/main.c.example`.
4. The framework will build **two separate ELFs** and load both of them automatically during `make run`.

**Note on C++ Support**: 
- **ARM side**: Vitis natively supports C++. Just add `.cpp` files to your ARM directory.
- **Soft-CPU side**: Supported if your custom Makefile is configured for it. See the updated `sw/Makefile.neorv32` for a template that handles both C and C++ (.cpp) files.

### Case C: ARM Only (Standard Zynq)
If you aren't using a soft-CPU, just put your code in `sw/` (or use `arm_sources.txt`). The framework defaults to the standard Vitis ARM build flow.

---

## 8. Utilities

### Binary UART Uploader (`utilities/upload_bin.py`)
A simple Python tool to upload compiled binary files to the NeoRV32 soft-CPU via its UART bootloader.

**Usage:**
```bash
./utilities/upload_bin.py /dev/ttyUSB0 19200 sw/main.bin
```
*(Requires `pyserial`. Install via `pip install pyserial`)*

---

## 9. Git Best Practices
This repository uses a **Whitelist .gitignore**. Only source files and scripts are tracked. Build artifacts are ignored automatically.

**Before you commit:**
1. Run `make clean`.
2. Ensure you have run `write_bd_tcl` if you modified the Block Design.
3. `git add .` then `git commit`.

---
*Generated by Gemini CLI Framework Assistant*
