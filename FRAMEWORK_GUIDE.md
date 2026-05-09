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
├── sw/            <-- C application source code (*.c, *.h)
├── board_configs/ <-- Your Block Design scripts (*_bd.tcl)
├── scripts/       <-- The framework engine (Automation scripts)
├── docs/          <-- Design documentation
├── Makefile       <-- The framework command center
└── .gitignore     <-- Whitelist-based filter for Git
```

---

## 3. Hardware Hierarchy & Integration

This framework uses a **User-First Top-Level** approach. 

1. **`top.vhd` (The Master)**: This is your project's absolute top-level file. You are responsible for defining the FPGA pins here and instantiating both your custom logic and the Zynq system.
2. **`system_wrapper` (The Zynq PS)**: When you run `make hw`, the framework generates a VHDL wrapper for your Block Design (named `system`). You must instantiate this component inside your `top.vhd`.
3. **Your Logic**: You can instantiate your own VHDL modules (like NeoRV32) alongside the Zynq wrapper, connecting them via signals.

**Key Requirement**: Your Block Design **must** be named `system` for the automation to correctly generate the `system_wrapper` component that `top.vhd` expects.

---

## 4. The Two-Phase Workflow

### Phase 1: The Initialization (GUI Required)
1. **Reconstruct/Open**: Run `make edit-hw`.
2. **Create Design**: Create a Block Design named **`system`**.
3. **Configure**: Add the **Zynq7 Processing System** IP. Run "Block Automation" (which applies board-specific presets if available).
4. **Port Synchronization (Important for New Boards)**:
   - To ensure your `top.vhd` matches your hardware:
   - In the Sources tab, right-click `system.bd` and select **"Create HDL Wrapper"**.
   - Open the generated `system_wrapper.vhd` and copy its port list.
   - Update the `component system_wrapper` declaration in your `src/hdl/top.vhd` to match this list.
5. **Freeze to Script**:
   - In the Vivado GUI, simply click the new **"Sync to Framework"** button on the top toolbar.
   - Alternatively, you can still run `write_bd_tcl -force ./scripts/ebaz_bd.tcl` in the Tcl Console.
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
| `make load-ram` | **Maintenance:** Pushes the `BOOT.BIN` to DDR memory via JTAG at `0x08000000`. Useful for manual NAND flashing via U-Boot. |
| `make gui` | **Vivado GUI:** Launches a standard Vivado GUI instance in the background. |
| `make clean` | **Cleanup:** Wipes all build artifacts (`hw_build`, `vitis_ws`), temporary Vivado projects (`project_1`, `myproj`), and log files. |

---

## 5. Troubleshooting: Why isn't my PL logic running?

If your VHDL logic is clocked by a Zynq PS clock (e.g., `FCLK_CLK0`), it **will not run** by simply flashing the bitstream with `make program`. 

**The Zynq PS clocks are disabled by default on power-up.** You must run `make run` to execute the PS initialization (via `ps7_init.tcl`), which enables the clocks and resets the PL logic.

---

## 6. Advanced Features

### External VHDL Libraries (`EXTRA_VHDL_LIBS`)
If your project requires external VHDL codebases that must be compiled into specific libraries (e.g., **NeoRV32**), you can use the `EXTRA_VHDL_LIBS` variable in the `Makefile`.

**Format:** `lib_name:path/to/rtl` (comma-separated for multiple libraries).

**Key Features:**
- **Automatic Detection:** The framework finds all `.vhd` and `.vhdl` files in the specified path.
- **Library Mapping:** It uses Vivado's `read_vhdl -library` command to assign the files to the correct namespace.
- **Path Flexibility:** Supports both **absolute paths** (recommended for shared cores) and **relative paths**.

**Example for NeoRV32 + Custom Lib:**
```make
EXTRA_VHDL_LIBS ?= neorv32:/home/user/neorv32/rtl/core,custom_lib:./src/custom_rtl
```

**VHDL Usage:**
Once configured, you can access the library in your code like this:
```vhdl
library neorv32;
use neorv32.neorv32_package.all;
```

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

## 7. Git Best Practices
This repository uses a **Whitelist .gitignore**. Only source files and scripts are tracked. Build artifacts are ignored automatically.

**Before you commit:**
1. Run `make clean`.
2. Ensure you have run `write_bd_tcl` if you modified the Block Design.
3. `git add .` then `git commit`.

---
*Generated by Gemini CLI Framework Assistant*
