# 🚀 Zynq-HDL Logic: The Script-First Framework
**A Professional Workflow for Xilinx Zynq-7000 SoC Development**

---

## 1. Introduction
This framework provides a structured, version-control-friendly environment for Zynq-7000 FPGA development. It prioritizes **HDL (VHDL, Verilog, or SystemVerilog)** for logic and **C** for software.

> [!IMPORTANT]
> **Compatibility:** This framework is designed specifically for **Vivado/Vitis 2025.2 only**. It utilizes the new Python scripting APIs (`import vitis`) alongside traditional Tcl scripts for automation and project orchestration. Older versions of Vitis do not support these Python APIs and are incompatible.

---

## 2. Directory Structure
```text
/project_root
├── src/
│   ├── hdl/       <-- Your logic files (*.vhd, *.vhdl, *.v, *.sv)
│   └── constr/    <-- Physical constraints (*.xdc)
├── sw/            <-- Software source code
│   ├── zynq_ps/   <-- Zynq PS (Cortex-A9 ARM) application sources
│   └── soft_cpu/  <-- Soft-CPU (NeoRV32 RISC-V) application sources
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

1. **`top.vhd` / `top.v` (The Master - MANDATORY)**: 
   - This is your project's absolute top-level file and is **required for all designs**.
   - It acts as the permanent anchor for your physical pins (XDC constraints).
   - **Auto-Bootstrap**: If this file is missing when you click "Sync to Framework" in Vivado, the framework will **automatically create it** for you, pre-filled with the correct Zynq ports. It dynamically creates either `top.vhd` or `top.v` depending on whether the design wrapper is VHDL or Verilog.
2. **The System Wrapper (Instantiated Logic)**: 
   - When you run `make hw`, the framework automatically generates an HDL wrapper for your Block Design (which defaults to `system.bd` but can be customized with `BD_NAME` in `project_config.mk`).
   - The bootstrapped `top.vhd` is pre-configured to instantiate this wrapper.
   - **Versioning Note**: The framework automatically detects the correct entity name for your version (typically matching your block design's name, e.g., `system` in 2025.2+, or `system_wrapper` in older versions) during the bootstrapping process.
3. **Naming Convention**: Your Block Design defaults to being named `system`, but you can customize it dynamically using the `BD_NAME` variable in `project_config.mk`.

---

## 4. The Two-Phase Workflow

### Phase 1: The Initialization (GUI Required)

Since every Zynq board is different, the framework does not include a default Block Design. Follow these steps to initialize your project:

1. **Construct/Open**: Run `make edit-hw`.
2. **Create Design**: Create a Block Design (defaults to `system`, or use your custom name configured via `BD_NAME`).
3. **Configure**: Add the **Zynq7 Processing System** IP. Run "Block Automation" (which applies board-specific presets if available).
4. **Port Synchronization (Auto-Bootstrap)**:
   - For **new projects**: Simply click the **"Sync to Framework"** button on the top toolbar. The framework will automatically create `src/hdl/top.vhd` for you with the correct ports.
   - For **existing projects**: If you change ports in the Block Design, you must manually update the `component` declaration in your `src/hdl/top.vhd` to match. (Right-click `<your_bd_name>.bd` -> "Create HDL Wrapper" to see the updated port list).
5. **Freeze to Script**:
   - The "Sync to Framework" button also saves your Block Design to `board_configs/${BOARD}_bd.tcl`.
   - **OR** run this command in the Tcl Console:
     ```tcl
     write_bd_tcl -force ./board_configs/${BOARD}_bd.tcl
     ```

*(Note: You do **not** need to commit the generated wrapper; the framework handles this automatically during the build phase. Each run of `make hw` or `make edit-hw` will automatically clean up any existing temporary project files to ensure a fresh environment.)*

### Phase 2: The Development Loop (CLI)

Below is the complete guide to the framework's `Makefile` targets:

| Target | Description |
| :--- | :--- |
| `make hw` | **Hardware Build:** Runs Vivado in batch mode. Synthesizes HDL (VHDL/Verilog), implements the design, generates the Bitstream, and exports the `.xsa` platform. |
| `make sw` | **Software Build:** Runs Vitis in batch mode. Creates/updates the platform component, then creates/builds the application named by `APP` (or `DEFAULT_APP`). **Now includes auto-update logic for hardware changes.** Requires `APPS`/`DEFAULT_APP` to be configured (or `APP=` passed explicitly) — see the note below. |
| `make edit-sw` | **Vitis IDE:** Ensures the Vitis platform exists, then opens the Vitis Unified IDE for interactive development. **Does not create or build an application** — that step is always explicit, either inside Vitis or via a later `make sw APP=<name>`. Changes made in the GUI must be synced back using `make sync-sw`. |
| `make sync-sw` | **Export:** Harvests files created/modified in the Vitis GUI (recursively scanning all subdirectories) and copies them back to the framework's `sw/` folders for version control, preserving directory hierarchy. |
| `make delete-sw` | **Cleanup:** Removes the specified application sources and its corresponding Vitis workspace component. |
| `make all` | **Full Build:** Shortcut for `make hw` followed by `make sw`. |
| `make` | **Help:** Shows the interactive command menu and current project settings. |
| `make run` | **JTAG Execution:** The primary "Test" command. Performs a full PS7 initialization (enables clocks), downloads the Bitstream and ELF, and starts execution. |
| `make boot` | **Boot Image:** Uses `bootgen` to create a `BOOT.BIN` file containing the FSBL, Bitstream, and Application for SD/NAND booting. |
| `make program` | **Flash FPGA:** Downloads *only* the Bitstream to the FPGA. (Note: Clocks will remain disabled until a software init occurs). |
| `make edit-hw` | **GUI Editor:** Opens the Block Design in Vivado. Automatically adds the **"Sync to Framework"** button to the toolbar for easy saving. |
| `make list-arm-params` | **Discovery:** Shows the absolute paths to the generated `xparameters.h` and driver headers for Zynq ARM development. |
| `make load-ram` | **Maintenance:** Pushes the `BOOT.BIN` to DDR memory via JTAG at `0x08000000`. Useful for manual NAND flashing via U-Boot. |
| `make gui` | **Vivado GUI:** Launches a standard Vivado GUI instance in the background. |
| `make clean` | **Cleanup:** Wipes all build artifacts (`hw_build`, `vitis_ws`), temporary Vivado projects (`project_1`, `myproj`), and log files. |

> [!NOTE]
> **`make edit-sw` never auto-creates an application.** It only ensures the Vitis platform component exists, then opens the GUI. Creating (or importing) an application is always something you do explicitly — either inside Vitis or by running `make sw APP=<name>` from the CLI. This is intentional: opening the IDE to poke around shouldn't silently create/build software you didn't ask for.
>
> **`make sw`, `make run`, and `make all` require an application to be selected.** They resolve the active app from `APP` (command line) or `DEFAULT_APP` (`project_config.mk`), which must match a shortcut listed in `APPS`. If both `APPS` and `DEFAULT_APP` are left unset and no `APP=` is passed, there is no valid application to build and the command will fail — always configure `APPS`/`DEFAULT_APP` (see [Section 8](#8-global-configuration-project_configmk)) or pass `APP=<name>` explicitly.

---

## 5. Complete Walkthrough: "Hello World" from Blank Project to Hardware

This walks through the full loop end-to-end on a fresh clone: configuring the board, building a Block Design, creating a `hello_world` application, and running it on real hardware via JTAG.

### Step 1: Configure the board
Create `project_config.mk` in the project root (copy `project_config.mk.example`):
```make
BOARD           = my_board
PART            = xc7z010clg400-1
TARGET_LANGUAGE = VHDL
BD_NAME         = system

APPS            = hello_world:my_board_standalone_plat:standalone
DEFAULT_APP     = hello_world
```
`APPS` maps the shortcut `hello_world` to a platform component `my_board_standalone_plat` running `standalone`. `DEFAULT_APP` makes `hello_world` the application that `make sw` / `make run` build when `APP=` isn't passed on the command line.

### Step 2: Build the Block Design (Vivado GUI)
1. `make edit-hw` — opens Vivado and creates/opens the project for `BOARD`.
2. Create a Block Design named `system` (or your `BD_NAME`).
3. Add the **ZYNQ7 Processing System** IP, then run **Block Automation** to apply any board-specific presets.
4. (Optional) Add PL peripherals (GPIO, custom IP, etc.) and wire them up.
5. Click **"Sync to Framework"** on the toolbar. This generates `src/hdl/top.vhd` (if missing, pre-wired to the PS ports) and writes `board_configs/${BOARD}_bd.tcl` so the design is fully scripted and reproducible.
6. Close Vivado — `make hw` cleans up temporary project files automatically on the next run.

### Step 3: Wire up pin constraints
Edit `src/constr/${BOARD}.xdc` and map the ports declared in `top.vhd` (UART, LEDs, clock, etc.) to your board's physical pins.

### Step 4: Build the bitstream
```bash
make hw
```
Runs Vivado in batch mode, synthesizes/implements the design, and exports `hw_build/${BOARD}/${BD_NAME}.xsa`.

### Step 5: Create the `hello_world` application
```bash
make edit-sw
```
This ensures the Vitis platform (`my_board_standalone_plat`) exists and opens the Vitis Unified IDE — it will **not** create the app for you. Inside Vitis:
1. **File → New Component → Application Component**.
2. Name it `hello_world` (must match the shortcut used in `APPS`).
3. Select the platform `my_board_standalone_plat` and domain `standalone_ps7_cortexa9_0`.
4. Choose the **Hello World** template (or **Empty Application** and write your own `main.c`).
5. Build once inside Vitis to confirm it compiles.

### Step 6: Harvest the sources back into the framework
```bash
make sync-sw
```
Copies whatever you created/edited in the Vitis GUI back into `sw/zynq_ps/hello_world/` (or `sw/hello_world/`) so it's tracked in Git and rebuildable from the CLI.

### Step 7: Rebuild from the CLI
```bash
make sw
```
Confirms the harvested sources build cleanly outside the GUI, producing `vitis_ws/hello_world/build/hello_world.elf`.

### Step 8: Run it on the board
```bash
make run
```
Connects via JTAG, performs PS7 clock/DDR initialization (`ps7_init.tcl`), downloads the bitstream and `hello_world.elf`, and starts execution. Open a serial terminal (e.g. `screen /dev/ttyUSB1 115200`) to see the UART output.

### Step 9 (optional): Package for standalone boot
```bash
make boot   # produces BOOT.BIN (FSBL + bitstream + hello_world.elf)
```
Copy `BOOT.BIN` to an SD card, or use `make load-ram` plus U-Boot, to boot without JTAG attached.

---

## 6. Troubleshooting: Why isn't my PL logic running?

If your HDL logic is clocked by a Zynq PS clock (e.g., `FCLK_CLK0`), it **will not run** by simply flashing the bitstream with `make program`. 

**The Zynq PS clocks are disabled by default on power-up.** You must run `make run` to execute the PS initialization (via `ps7_init.tcl`), which enables the clocks and resets the PL logic.

---

## 7. Advanced Features

### External HDL Libraries (`vhdl_libs.txt`)
If your project requires external HDL codebases (VHDL, Verilog, or SystemVerilog) that must be compiled into specific libraries (e.g., **NeoRV32**), create a file named `vhdl_libs.txt` in your project root. 

**Format:** `lib_name:path/to/rtl` (one per line).

**Example `vhdl_libs.txt`:**
```text
neorv32:/home/user/neorv32/rtl/core
custom_lib:./src/custom_rtl
```

**Key Features:**
- **Automatic Detection:** The framework finds all `.vhd`, `.vhdl`, `.v`, and `.sv` files in the specified path.
- **Library Mapping:** It uses Vivado's `read_vhdl -library` or `read_verilog -library` commands to assign the files to the correct namespace.
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

### VHDL/Verilog Compilation Order
For complex designs with multiple packages and dependencies, you can control the compilation order:

1. **Smart Sort (Automatic)**: By default, the framework automatically identifies files containing `_package` or `_pkg` in their name and compiles them before other logic files in the same library.
2. **Explicit Order**: If you need total control, create a file named `compile_order.txt` in the source folder (e.g., `src/hdl/compile_order.txt`). List one filename per line in the desired compilation sequence.

---

## 8. Global Configuration (`project_config.mk`)

Instead of passing configuration values on the command line every time, you can create a file named **`project_config.mk`** in the root of your project. The framework will automatically read this file and use these values as defaults for all commands.

Below is a detailed guide to all configuration variables supported by the framework `Makefile`:

### Hardware & Project Variables

| Variable | Description | Default Value | Example |
| :--- | :--- | :--- | :--- |
| `BOARD` | The name of the target board. The framework uses this to locate `./board_configs/$(BOARD)_bd.tcl` for the block design and `./src/constr/$(BOARD).xdc` for pin constraints. | `my_board` | `BOARD = ebaz4205` |
| `PART` | The target Xilinx FPGA part number. | `xc7z010clg400-1` | `PART = xc7z020clg400-1` |
| `TARGET_LANGUAGE` | The target hardware description language for the Vivado project, synthesis, and generated block design wrappers. Valid values are `VHDL` or `Verilog`. | `VHDL` | `TARGET_LANGUAGE = Verilog` |
| `BD_NAME` | The name of the Block Design (e.g. `system.bd`). | `system` | `BD_NAME = system` |

### Software & Application Management Variables

| Variable | Description | Default Value | Example |
| :--- | :--- | :--- | :--- |
| `APPS` | A space-separated list of application tuples mapping a shortcut name, target platform, and operating system. Format: `<shortcut>:<platform_name>:<os>` | *None* | `APPS = hello_world:sys_plat:standalone my_rtos:rtos_plat:freertos` |
| `DEFAULT_APP` | The default application shortcut to build if the `APP` variable is not specified on the command line. Must match a shortcut defined in `APPS`. **Required for `make sw`/`make run`/`make all` unless `APP=` is passed on every invocation** — leaving both `APPS` and `DEFAULT_APP` unset gives those targets no valid application to build. Does **not** affect `make edit-sw`, which never builds an app. | *None* | `DEFAULT_APP = hello_world` |
| `APP` | Command line parameter or configuration variable to choose the active application workspace component to compile and run. | `$(DEFAULT_APP)` | `make sw APP=my_rtos` |
| `APP_ELF` / `ZYNQ_ELF` | Overrides the target path to the compiled ARM Cortex-A9 software ELF executable file. | `./vitis_ws/$(REAL_APP)/build/...` | `APP_ELF = ./sw/zynq_ps/build.elf` |

### Complete `project_config.mk` Example:

```make
# project_config.mk - Project-wide settings
BOARD           = ebaz4205
PART            = xc7z010clg400-1
TARGET_LANGUAGE = VHDL
BD_NAME         = system

# Define all available applications
APPS = hello_world:ebaz_plat:standalone my_rtos:ebaz_freertos_plat:freertos

# Set the default application
DEFAULT_APP = hello_world
```


## 9. Hybrid Multi-CPU Support (ARM + Soft-CPU)

This framework supports true **Dual-CPU** development, where you can have custom code running on both the Zynq ARM core and a soft-CPU in the PL (e.g., NeoRV32).

### Case A: Custom Soft-CPU (PL) Only
If you only care about the soft-CPU:
1. Put your soft-CPU code in `sw/soft_cpu/` and configure the Makefile at [sw/soft_cpu/Makefile](file:///home/pratip/data/FPGA/ZynqScriptingFramework/sw/soft_cpu/Makefile).
2. The framework will still build a Vitis "Platform" (to handle Zynq clocks/DDR init) but will use your soft-CPU Makefile for the main app.
3. Set `APP_ELF = sw/soft_cpu/main.elf` in your project `Makefile`.
4. **Custom Targets**: You can pass specific targets to your software Makefile using the `SW_TARGET` variable (e.g., `make sw SW_TARGET=clean`).

### Case B: Custom ARM (PS) + Custom Soft-CPU (PL)
If you want to customize the Zynq side (e.g., for Ethernet drivers) while also running a soft-CPU:
1. **Soft-CPU**: Define its build in `sw/soft_cpu/Makefile` and `sw_sources.txt`.
2. **ARM core**: Create a directory (e.g., **`sw/zynq_ps/`**) and list it in **`arm_sources.txt`**.
3. **Template**: A minimal ARM manager template is available at [sw/zynq_ps/main.c.example](file:///home/pratip/data/FPGA/ZynqScriptingFramework/sw/zynq_ps/main.c.example).
4. The framework will build **two separate ELFs** and load both of them automatically during `make run`.

**Note on C++ Support**: 
- **ARM side**: Vitis natively supports C++. Just add `.cpp` files to your Zynq PS directory.
- **Soft-CPU side**: Supported if your custom Makefile is configured for it. See the updated [sw/soft_cpu/Makefile](file:///home/pratip/data/FPGA/ZynqScriptingFramework/sw/soft_cpu/Makefile) for a template that handles both C and C++ (.cpp) files.

### Case C: ARM Only (Standard Zynq)
If you aren't using a soft-CPU, just put your code in `sw/zynq_ps/` (or use `arm_sources.txt`). The framework defaults to the standard Vitis ARM build flow.

---

## 10. Utilities

### VHDL IP Design Templates (`utilities/hdl_templates/`)
The framework provides generic, parameterized, and fully synthesizable reference VHDL IP cores for common bus structures:

- **[Custom Bus Types Package](file:///home/pratip/data/FPGA/ZynqScriptingFramework/utilities/hdl_templates/bus_types_pkg.vhd) (`bus_types_pkg.vhd`)**: A VHDL package declaring the unconstrained 2D array type `gpio_array_t` (requires VHDL-2008) and custom `record` structures for AXI-Lite (`axil_m2s_t`/`axil_s2m_t`) and Wishbone (`wb_m2s_t`/`wb_s2m_t`) transactions, along with their matching array types (`axil_m2s_array_t`, `axil_s2m_array_t`, `wb_m2s_array_t`, `wb_s2m_array_t`).
- **[AXI-Lite GPIO Array](file:///home/pratip/data/FPGA/ZynqScriptingFramework/utilities/hdl_templates/axi_gpio.vhd) (`axi_gpio.vhd`)**: Parameterized to instantiate `NUM_INPUT_REGS` input-only registers and `NUM_OUTPUT_REGS` output registers of configurable width (`GPIO_WIDTH`). Uses the AXI-Lite record interfaces (`s_axi_m2s` / `s_axi_s2m`) and `gpio_array_t` 2D array ports instead of flattened vectors.
- **[Wishbone GPIO Array](file:///home/pratip/data/FPGA/ZynqScriptingFramework/utilities/hdl_templates/wishbone_gpio.vhd) (`wishbone_gpio.vhd`)**: Parameterized Wishbone Classic slave register array containing input/output ports mapped via `gpio_array_t` and bus connections via the Wishbone records (`wb_m2s` / `wb_s2m`).
- **[AXI-Lite 1-to-N Interconnect Decoder](file:///home/pratip/data/FPGA/ZynqScriptingFramework/utilities/hdl_templates/axi_lite_interconnect.vhd) (`axi_lite_interconnect.vhd`)**: Address decoding router routing transaction channels from one AXI-Lite manager record to an array of AXI-Lite subordinate records (`s_axi_m2s` / `s_axi_s2m` of type `axil_m2s_array_t` / `axil_s2m_array_t`) based on parameterized base addresses and masks.
- **[Wishbone 1-to-N Interconnect Decoder](file:///home/pratip/data/FPGA/ZynqScriptingFramework/utilities/hdl_templates/wishbone_interconnect.vhd) (`wishbone_interconnect.vhd`)**: Combinatorial shared-bus address decoder routing Wishbone cycles from one master record to an array of Wishbone slave records (`s_wb_m2s` / `s_wb_s2m` of type `wb_m2s_array_t` / `wb_s2m_array_t`).
- **[AXI-Lite to Native BRAM Controller](file:///home/pratip/data/FPGA/ZynqScriptingFramework/utilities/hdl_templates/axi_bram_ctrl.vhd) (`axi_bram_ctrl.vhd`)**: Translates AXI-Lite records (`s_axi_m2s`/`s_axi_s2m`) to a native Block RAM interface (enable, byte-write enables, address, write/read data) with mode configurations (`"READ_WRITE"`, `"READ_ONLY"`, `"WRITE_ONLY"`).
- **[Wishbone to Native BRAM Controller](file:///home/pratip/data/FPGA/ZynqScriptingFramework/utilities/hdl_templates/wb_bram_ctrl.vhd) (`wb_bram_ctrl.vhd`)**: Translates Wishbone Classic records (`wb_m2s`/`wb_s2m`) to a native Block RAM interface (enable, byte-write enables, address, write/read data) with mode configurations (`"READ_WRITE"`, `"READ_ONLY"`, `"WRITE_ONLY"`).
- **[True Dual-Port Block RAM](file:///home/pratip/data/FPGA/ZynqScriptingFramework/utilities/hdl_templates/true_dual_port_bram.vhd) (`true_dual_port_bram.vhd`)**: A parameterized block RAM with dual independent read/write ports, separate clocks (`clk_a`, `clk_b`), and byte-write enables, inferred using a synthesizable VHDL-2008 Write-First memory array.

*Note: By utilizing VHDL-2008 records and arrays of records, the entire bus interface logic is collapsed into single-port record connections, allowing clean and modular hardware composition without manually wiring dozens of individual address, data, and handshaking signals.*


---

### Binary UART Uploader (`utilities/upload_bin.py`)
A simple Python tool to upload compiled binary files to the NeoRV32 soft-CPU via its UART bootloader.

**Usage:**
```bash
./utilities/upload_bin.py /dev/ttyUSB0 19200 sw/main.bin
```
*(Requires `pyserial`. Install via `pip install pyserial`)*

---

## 11. Advanced Software Management

### Hardware-Aware Platform Updates
The framework automatically detects when your hardware design has changed. If you run `make hw` and then `make sw`, the script will compare the timestamp of the generated `.xsa` file with the existing Vitis platform. 

If the hardware is newer, it will automatically:
1. Update the hardware specification of the platform.
2. Rebuild the platform (regenerating `xparameters.h`, FSBL, and drivers).
3. Rebuild your application against the new hardware.

### Multi-OS Selection (`APP=name:os`)
You can manage different operating systems (Standalone vs. FreeRTOS) directly via the `APP` variable. This allows you to maintain multiple software environments for the same hardware.

**Syntax:** `make sw APP=<app_name>:<os>`

| OS Shortcut | Full Vitis OS Name |
| :--- | :--- |
| `standalone` | `standalone` (Default) |
| `freertos` | `freertos10_xilinx` |

**Examples:**
- **Bare-metal:** `make sw APP=my_app` or `make sw APP=my_app:standalone`
- **FreeRTOS:** `make sw APP=my_rtos_app:freertos`

**Note:** The framework creates separate platform components for each OS (e.g., `board_standalone_plat` and `board_freertos_plat`). This ensures that switching between OS types is instant and does not require a full rebuild of the other platform.

---

## 12. Git Best Practices
This repository uses a **Whitelist .gitignore**. Only source files and scripts are tracked. Build artifacts are ignored automatically.

**Before you commit:**
1. Run `make clean`.
2. Ensure you have run `write_bd_tcl` if you modified the Block Design.
3. `git add .` then `git commit`.

---
*Generated by Gemini CLI Framework Assistant*
