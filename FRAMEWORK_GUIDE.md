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
| `make docs` | **Documentation:** Renders `FRAMEWORK_GUIDE.md` into styled HTML at `docs/FRAMEWORK_GUIDE.html` using `scripts/gen_docs.py`. |
| `make clean` | **Cleanup:** Wipes all build artifacts (`hw_build`, `vitis_ws`), temporary Vivado projects (`project_1`, `myproj`), and log files. |

> [!NOTE]
> **`make edit-sw` never auto-creates an application.** It only ensures the Vitis platform component exists, then opens the GUI. Creating (or importing) an application is always something you do explicitly — either inside Vitis or by running `make sw APP=<name>` from the CLI. This is intentional: opening the IDE to poke around shouldn't silently create/build software you didn't ask for.
>
> **`make sw`, `make run`, and `make all` require an application to be selected.** They resolve the active app from `APP` (command line) or `DEFAULT_APP` (`project_config.mk`), which must match a shortcut listed in `APPS`. If both `APPS` and `DEFAULT_APP` are left unset and no `APP=` is passed, there is no valid application to build and the command will fail — always configure `APPS`/`DEFAULT_APP` (see [Section 9](#9-global-configuration-project_configmk)) or pass `APP=<name>` explicitly.

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

## 6. Modifying an Existing Project: New Hardware, Apps, and Platforms

Section 5 covers the first Block Design, platform, and app from a blank project. This section covers the ongoing loop: changing the hardware later, and adding more apps (with either an existing or a brand-new platform) to a project that's already up and running.

### Modifying the Block Design
1. `make edit-hw` — reopens Vivado on your existing project/Block Design.
2. Make your changes (add IP, reconfigure the Zynq7 PS, etc.).
3. Click **"Sync to Framework"** again. If you added/changed ports, update `src/hdl/top.vhd`'s `component` declaration and `src/constr/${BOARD}.xdc` (or `src/constr/${BOARD}/*.xdc`) to match.
4. `make hw` to rebuild the bitstream against the new hardware.

**Important:** any *existing* platform in `vitis_ws/` is updated **incrementally** the next time it's built (`make sw`/`make edit-sw`), not recreated from scratch. Most hardware changes are handled fine this way. But changes that could shift a `Default`/`Auto`-resolved BSP setting — most commonly adding a timer, or changing what's available as stdin/stdout/interrupt controller — can leave a platform in a broken state (e.g. `undefined reference to XTime_GetTime`). See [Troubleshooting](#7-troubleshooting) below; the fix is to delete that platform directory under `vitis_ws/` and let it regenerate fresh.

### Adding a New App to an Existing Platform
If the new app doesn't need different BSP settings (libraries, timer config, stdin/stdout) than an app you already have, reuse its platform:
1. Add an entry to `APPS` in `project_config.mk`: `<new_shortcut>:<existing_platform_name>:<os>`.
2. `make edit-sw APP=<new_shortcut>` — opens Vitis with that platform ensured (already exists, so this is fast).
3. Create the app component in Vitis, targeting the existing platform.
4. Once the shortcut in `APPS` matches the real Vitis component name (see below if you used a template), run `make sync-sw`, then `make sw APP=<new_shortcut>` / `make run APP=<new_shortcut>`.

### Adding a New App With Its Own New Platform
Give the app its own platform when it needs BSP-level changes (enabled libraries like lwIP, different timer/interrupt config, etc.) that shouldn't affect your other apps — see [Multiple Platforms Per Board](#multiple-platforms-per-board) for why.

1. Add an entry with a **new** platform name: `<new_shortcut>:<new_platform_name>:<os>`.
2. **Target it explicitly**: `make edit-sw APP=<new_shortcut>`. This is easy to get wrong — running plain `make edit-sw` (no `APP=`) resolves the active app from `DEFAULT_APP`, so it will silently ensure your *old* platform instead and the new one simply won't appear in Vitis, with no error. Passing `APP=<new_shortcut>` is what makes the Makefile resolve `<new_platform_name>` and create it fresh (it doesn't exist in `vitis_ws/` yet).
3. Create the app component in Vitis targeting the new platform, and configure that platform's Board Support Package Settings (lwIP, timers, etc.) — changes here are isolated to this platform only.
4. If you used a Vitis template and don't know the component name in advance, see [Adding Apps Whose Name You Don't Know Yet](#adding-apps-whose-name-you-dont-know-yet-vitis-templates) — update the `APPS` shortcut to match before syncing.
5. `make sync-sw`, then `make sw APP=<new_shortcut>` / `make run APP=<new_shortcut>`.

---

## 7. Troubleshooting

### Why isn't my PL logic running?

If your HDL logic is clocked by a Zynq PS clock (e.g., `FCLK_CLK0`), it **will not run** by simply flashing the bitstream with `make program`. 

**The Zynq PS clocks are disabled by default on power-up.** You must run `make run` to execute the PS initialization (via `ps7_init.tcl`), which enables the clocks and resets the PL logic.

---

### Platform build fails after modifying the Block Design (e.g. `undefined reference to XTime_GetTime`)

If you go back into `make edit-hw`, add/change an IP block (e.g. enabling a timer like TTC0), run `make hw` again, and then `make edit-sw`/`make sw` fails while **rebuilding the platform** (not your application) with linker errors like:

```
undefined reference to `XTime_GetTime'
undefined reference to `XilSleepTimer_Init'
```

**Why this happens:** when a Vitis platform component already exists in `vitis_ws/`, the framework updates it *incrementally* (`platform.update_hw()` + rebuild) rather than recreating it from scratch. Some BSP settings default to `Default`/`Auto` (most commonly the `xiltimer` sleep/tick timer source). Adding a new candidate resource — like a TTC — can change how that auto-resolution behaves under the hood without the incremental update path fully re-running it, leaving the platform (and especially the FSBL, which has its own separate BSP config) linked against timer functions that never got compiled in.

This isn't unique to timers — any BD change that could plausibly shift an `Default`/`Auto`-resolved resource (timer source, stdin/stdout UART, interrupt controller assumptions) carries the same risk. Peripherals that don't compete for one of those "default" roles (typical Ethernet/I2C/SPI/GPIO additions) are much lower risk.

**Fix - regenerate the platform from scratch:**
1. Make sure Vitis is fully closed (check for lingering `vitis-ide`/`vitis-server`/`clangd` processes — closing the window doesn't always kill them).
2. Delete the stale platform directory: `rm -rf vitis_ws/${PLATFORM_NAME}` (e.g. `vitis_ws/Zynq_Bajie_standalone_plat`). Your application component(s) elsewhere in `vitis_ws/` don't need to be touched.
3. If `sw/platforms/${PLATFORM_NAME}.yaml` exists (a saved BSP config from a previous `sync-sw`-style export), check it doesn't still contain the stale `Default` setting before it gets re-merged into the fresh platform.
4. Run `make edit-sw` again. This triggers a full `create_platform_component()` instead of an incremental update, forcing all BSP/timer auto-resolution to run fresh against the current hardware.

**Alternative (avoids full regeneration):** explicitly pin the ambiguous setting instead of leaving it on `Default`. In Vitis, right-click the platform component → **Board Support Package Settings** → set `XILTIMER_sleep_timer` (and `XILTIMER_tick_timer` if used) to the specific instance you added (e.g. `ps7_ttc_0`). Do this for both the main platform's BSP settings and the FSBL's own separate BSP settings if the FSBL build is the one failing.

---

## 8. Advanced Features

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

### External IP Repositories (`ip_repos.txt`)
If your Block Design references third-party or custom-packaged Vivado IP (e.g. Digilent's open-source `rgb2dvi` HDMI encoder) that isn't in the standard Xilinx IP catalog, create a file named `ip_repos.txt` in your project root listing the repository path(s) to register before the Block Design is built.

**Format:** one absolute path per line (each path is a directory containing IP-XACT `component.xml`-based IP, i.e. a Vivado IP repository root).

**Example `ip_repos.txt`:**
```text
/home/user/vivado-library
```

**Key Features:**
- Registered via `set_property ip_repo_paths` and `update_ip_catalog` before any `create_bd_cell` calls in `board_configs/${BOARD}_bd.tcl` run, so `make hw` resolves the IP in batch mode with no manual "Settings → IP → Repository" step needed each time.
- If `ip_repos.txt` is missing, the framework falls back to a comma-separated `EXTRA_IP_REPOS` environment variable, or skips repository registration entirely if neither is set.
- You still need to add the repository once in the interactive Vivado GUI (`make edit-hw`) so the IP appears in the IP Catalog while you're building the Block Design by hand — `ip_repos.txt` is what makes the *scripted* `make hw` rebuild find it too.

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

### Modular Pin Constraints (`src/constr/${BOARD}/`)
Instead of maintaining one large `src/constr/${BOARD}.xdc` file, you can split constraints into per-component files under a directory named after your board:

```text
src/constr/
└── Zynq_Bajie/
    ├── ethernet.xdc
    ├── hdmi.xdc
    ├── i2c.xdc
    └── spi.xdc
```

**Key Features:**
- **Filenames are arbitrary.** Every file ending in `.xdc` inside `src/constr/${BOARD}/` is picked up automatically — name them after the peripheral they constrain (`ethernet.xdc`, `hdmi.xdc`, etc.) for clarity.
- **Sorted, deterministic read order.** Files are read alphabetically, not by creation time. This only matters if two files constrain the *same* signal differently (the later one wins) or you rely on ordered timing exceptions — independent per-peripheral pin constraints are unaffected by order.
- **Both conventions can coexist.** If `src/constr/${BOARD}.xdc` also exists, it's read first, followed by everything in `src/constr/${BOARD}/*.xdc`. Use the single file for base/shared constraints and the directory for modular, per-peripheral ones — or just use one or the other.
- **At least one must exist.** `make hw` fails fast with a clear error if neither `src/constr/${BOARD}.xdc` nor `src/constr/${BOARD}/` (with at least one `.xdc` file) is found.

This is especially useful for boards without an official Vivado board file: build up `src/constr/${BOARD}/` one peripheral at a time as you bring up Ethernet, HDMI, I2C, SPI, etc., testing hardware after each addition.

---

### VHDL/Verilog Compilation Order
For complex designs with multiple packages and dependencies, you can control the compilation order:

1. **Smart Sort (Automatic)**: By default, the framework automatically identifies files containing `_package` or `_pkg` in their name and compiles them before other logic files in the same library.
2. **Explicit Order**: If you need total control, create a file named `compile_order.txt` in the source folder (e.g., `src/hdl/compile_order.txt`). List one filename per line in the desired compilation sequence.

---

## 9. Global Configuration (`project_config.mk`)

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


## 10. Hybrid Multi-CPU Support (ARM + Soft-CPU)

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

## 11. Utilities

### VHDL IP Design Templates (`utilities/hdl_templates/`)
The framework provides generic, parameterized, and fully synthesizable reference VHDL IP cores for common bus structures:

- **[Custom Bus Types Package](file:///home/pratip/data/FPGA/ZynqScriptingFramework/utilities/hdl_templates/bus_types_pkg.vhd) (`bus_types_pkg.vhd`)**: A VHDL package declaring the unconstrained 2D array type `gpio_array_t` (requires VHDL-2008) and custom `record` structures for AXI-Lite (`axil_m2s_t`/`axil_s2m_t`) and Wishbone (`wb_m2s_t`/`wb_s2m_t`) transactions, along with their matching array types (`axil_m2s_array_t`, `axil_s2m_array_t`, `wb_m2s_array_t`, `wb_s2m_array_t`).
- **[AXI-Lite GPIO Array](file:///home/pratip/data/FPGA/ZynqScriptingFramework/utilities/hdl_templates/axi_gpio.vhd) (`axi_gpio.vhd`)**: Parameterized to instantiate `NUM_INPUT_REGS` input-only registers and `NUM_OUTPUT_REGS` output registers of configurable width (`GPIO_WIDTH`). Uses the AXI-Lite record interfaces (`s_axi_m2s` / `s_axi_s2m`) and `gpio_array_t` 2D array ports instead of flattened vectors.
- **[AXI-Lite PWM Controller](file:///home/pratip/data/FPGA/ZynqScriptingFramework/utilities/hdl_templates/axi_pwm.vhd) (`axi_pwm.vhd`)**: Parameterized N-channel AXI-Lite PWM pulse generator (default 3 channels for Zybo Z7 tri-color RGB LEDs) with hardware clock prescaler, variable period/resolution, and individual duty cycle registers.
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

## 12. Advanced Software Management

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

### Multiple Platforms Per Board
The `<shortcut>:<platform_name>:<os>` format in `APPS` isn't limited to one platform per board/OS pair — you can point different apps at entirely different platform names to give each one its own isolated BSP configuration:

```make
APPS = hello_world:Zynq_Bajie_standalone_plat:standalone eth_server:Zynq_Bajie_lwip_plat:standalone
```

**Why you'd want this:** BSP-level settings (enabled libraries like `lwip220`, `xiltimer` sleep/tick source, stdin/stdout, etc.) live on the *platform* component, not the app. If `eth_server` needs lwIP and different timer settings, building it against the same platform as `hello_world` would apply those changes to `hello_world` too. Giving it its own platform (`Zynq_Bajie_lwip_plat`) isolates the change — configure that platform's Board Support Package Settings independently in Vitis without touching any other app's platform.

Running `make edit-sw APP=eth_server` (with a matching `APPS` entry) creates `Zynq_Bajie_lwip_plat` fresh the first time, since it doesn't exist yet in `vitis_ws/`.

### Adding Apps Whose Name You Don't Know Yet (Vitis Templates)
`make edit-sw` never reads the app-shortcut part of the `APPS` tuple — only the platform name and OS. That means you don't need to know your new app's final name before running `make edit-sw`; you only need *some* `APPS` entry so `APP=<shortcut>` can resolve the right platform:

1. Add a placeholder entry: `APPS = ... placeholder:Zynq_Bajie_lwip_plat:standalone`.
2. `make edit-sw APP=placeholder` — ensures/creates `Zynq_Bajie_lwip_plat` and opens Vitis.
3. In Vitis, create the app from whatever template you want (e.g. **Create Application Component → From Template → lwip_echo_server**) and let Vitis name it however it wants. Don't try to rename a Vitis component after creation — it's known to cause issues.
4. Check the real component name (`ls vitis_ws/` or the Vitis component list), then edit `project_config.mk` so the `APPS` shortcut matches that name exactly.
5. Only then run `make sync-sw` / `make sw` / `make run` — these all key off the `APPS` shortcut to locate `vitis_ws/<shortcut>/`, so it must match before they're used.

### Automatic PHY Speed Driver Patches (`sw/patches/`)

Some Zynq development boards use Ethernet PHY chips that differ from standard Xilinx driver defaults (such as the Realtek RTL8211E-VL on the **Zybo Z7** or **EBAZ4205**). Stock Xilinx lwIP drivers primarily target Marvell or TI PHYs; without board-specific handling, Realtek PHY autonegotiation and link status probing can fail during startup with errors such as `Phy setup error : link_speed invalid`.

To support non-standard or board-specific PHYs without modifying global Xilinx Vitis installation files, the framework automatically injects patches during `make sw`:

#### How Patch Discovery Works
During software builds, `scripts/build_sw.py` scans `sw/patches/` in the project root:
1. **Board-Specific Patch**: `sw/patches/xemacpsif_physpeed.c.<BOARD>` (e.g., `sw/patches/xemacpsif_physpeed.c.zybo_z7` when `BOARD = zybo_z7`).
2. **Generic Fallback Patch**: `sw/patches/xemacpsif_physpeed.c` (used if no board-specific patch matches).

If a patch file is found, the framework automatically copies it into the BSP's lwIP network interface directory:
```text
vitis_ws/<PLATFORM>/ps7_cortexa9_0/<OS>_ps7_cortexa9_0/bsp/libsrc/lwip220/src/lwip-2.2.0/contrib/ports/xilinx/netif/xemacpsif_physpeed.c
```
and recompiles `liblwip220.a` into your application.

#### Zybo Z7 PHY Patch Details (`xemacpsif_physpeed.c.zybo_z7`)
- **Target Chip**: Realtek RTL8211E-VL PHY.
- **Link Status & Latching Reads**: Reads the IEEE BMSR (Register 1) twice to clear latching-low link status bits and checks both BMSR link status and PHYSR (Register 17) speed/duplex resolved bits.
- **Graceful Disconnected Link Fallback**: If an Ethernet cable is unplugged at boot, the driver logs a warning (`Ethernet link down (cable disconnected). Defaulting link speed to 1000 Mbps`) and defaults the Zynq SLCR clock dividers to 1000 Mbps instead of aborting MAC initialization with `XST_FAILURE`. This allows lwIP and FreeRTOS to initialize cleanly so that networking functions immediately when a cable is plugged in later.

---

## 14. Integrating Custom VHDL/Verilog & AXI IP (`top.vhd`)

A core strength of this framework is combining **graphical Block Design orchestration** with **hand-written VHDL/Verilog custom logic**. Custom hardware modules (such as `axi_pwm.vhd`, `axi_gpio.vhd`, custom DSP accelerators, or motor controllers) are instantiated directly in `src/hdl/top.vhd` without needing to package them as complex Vivado IP blocks.

> [!IMPORTANT]
> **Why `top.vhd` Is Safe From Overwriting:**
> The framework auto-bootstraps `src/hdl/top.vhd` **only if it does not already exist**. Once created, clicking "Sync to Framework" in Vivado or running `make hw` will **never overwrite your `top.vhd`**. You can safely edit `top.vhd`, add custom component declarations, instantiate custom VHDL/Verilog entities, and wire up FPGA pins.

> [!NOTE]
> **Architecture Clarification (`top.vhd` Master vs `system_wrapper` BD Subsystem):**
> Clicking **"Sync to Framework"** in Vivado automatically syncs the Block Design wrapper directly to **`src/hdl/system_wrapper.vhd`** (retaining entity name `system_wrapper`).
> `src/hdl/top.vhd` is your permanent master top-level module and instantiates the BD wrapper directly using VHDL entity instantiation (`system_i : entity work.system_wrapper`).
> Because `top.vhd` uses direct entity instantiation (`entity work.system_wrapper`), VHDL automatically binds to the updated `system_wrapper.vhd` generated by Vivado whenever Block Design ports change. You never have to manually copy component port declarations or merge `.new` files!

---

### Step-by-Step Walkthrough: Connecting Custom AXI PWM to Zynq ARM

#### Step A: Expose AXI Bus in Block Design (`make edit-hw`)
1. Open the Block Design in Vivado (`make edit-hw`).
2. Double-click the **ZYNQ7 Processing System** IP → Select **PS-PL Configuration** in the left Page Navigator → Expand **AXI Non Secure Enablement** → **GP Master AXI Interface** → Check **`M AXI GP0 interface`** (or set `set_property CONFIG.PCW_USE_M_AXI_GP0 1 [get_bd_cells processing_system7_0]` in Tcl).
3. Connect `M_AXI_GP0` to an **AXI Interconnect** or **AXI SmartConnect** IP.
4. On the AXI Interconnect, create a Master interface port (e.g., `M00_AXI`) and **make it External** (Right-click `M00_AXI` → **Make External**), or externalize individual AXI signals (`m_axi_awaddr`, `wdata`, `wvalid`, etc.).
5. Connect `FCLK_CLK0` to an external clock port `pl_clk0` and associate it with the external AXI port:
   - Since `FCLK_CLK0` is already connected to internal IPs, right-click Block Design canvas → **Create Port...** → Name: `pl_clk0`, Direction: `Output`, Type: `Clock`.
   - Connect `pl_clk0` port to the existing `FCLK_CLK0` net.
   - Click `pl_clk0` port → Block Port Properties → Config → Set `ASSOCIATED_BUSIF` to your **exact external AXI port name** (e.g., `M00_AXI` or `M04_AXI_0`).
     > [!TIP]
     > **Port Naming Note:** `ASSOCIATED_BUSIF` must match the exact **external top-level BD port name** reported in the Vivado Validation warning (e.g., `M04_AXI_0`), which may differ from the internal block pin name (e.g., `M01_AXI`).
   - *Tcl equivalent:*
     ```tcl
     create_bd_port -dir O -type clk pl_clk0
     connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_ports pl_clk0]
     set_property CONFIG.ASSOCIATED_BUSIF {M04_AXI_0} [get_bd_ports /pl_clk0]
     ```
   *(Note: Associating the clock port resolves Vivado warning `[BD 41-2559] AXI interface port is not associated to any clock port`).*
6. Open the **Address Editor** tab in Vivado and assign a memory base address to the external AXI interface (e.g., `0x43C00000`, Range: `64K`).
7. Click **"Sync to Framework"** on the Vivado toolbar to update `board_configs/${BOARD}_bd.tcl`.

---

#### Step B: Instantiate Custom IP & Wire Ports in `src/hdl/top.vhd`
1. Copy or reference your custom VHDL module (e.g. [`utilities/hdl_templates/axi_pwm.vhd`](file:///home/pratip/data/FPGA/ZynqScriptingFramework/utilities/hdl_templates/axi_pwm.vhd)) into `src/hdl/`.
2. Add external pin ports (e.g., `rgb_led_o`) to `entity top` in `src/hdl/top.vhd`:

```vhdl
entity top is
  port (
    -- Standard Zynq PS & DDR Ports ...
    FIXED_IO_mio : inout STD_LOGIC_VECTOR (53 downto 0);
    DDR_addr     : inout STD_LOGIC_VECTOR (14 downto 0);
    
    -- Custom FPGA Top-Level Pins
    rgb_led_o    : out STD_LOGIC_VECTOR (2 downto 0) -- Red, Green, Blue Tri-Color LED
  );
end top;
```

3. Instantiate `axi_pwm` inside `architecture STRUCTURE of top` and connect it to the AXI signals exposed by the Block Design wrapper `system_i`:

```vhdl
architecture STRUCTURE of top is
    -- AXI Record signals from bus_types_pkg
    signal axil_m2s : axil_m2s_t;
    signal axil_s2m : axil_s2m_t;
begin
    -- Connect BD wrapper output to AXI record structure
    axil_m2s.awaddr  <= m_axi_gp0_awaddr;
    axil_m2s.awvalid <= m_axi_gp0_awvalid;
    axil_m2s.wdata   <= m_axi_gp0_wdata;
    axil_m2s.wstrb   <= m_axi_gp0_wstrb;
    axil_m2s.wvalid  <= m_axi_gp0_wvalid;
    axil_m2s.bready  <= m_axi_gp0_bready;
    axil_m2s.araddr  <= m_axi_gp0_araddr;
    axil_m2s.arvalid <= m_axi_gp0_arvalid;
    axil_m2s.rready  <= m_axi_gp0_rready;

    m_axi_gp0_awready <= axil_s2m.awready;
    m_axi_gp0_wready  <= axil_s2m.wready;
    m_axi_gp0_bvalid  <= axil_s2m.bvalid;
    m_axi_gp0_bresp   <= axil_s2m.bresp;
    m_axi_gp0_arready <= axil_s2m.arready;
    m_axi_gp0_rdata   <= axil_s2m.rdata;
    m_axi_gp0_rresp   <= axil_s2m.rresp;
    m_axi_gp0_rvalid  <= axil_s2m.rvalid;

    -- Instantiate 3-Channel AXI PWM Controller
    inst_rgb_pwm : entity work.axi_pwm
        generic map (
            NUM_CHANNELS => 3,  -- 3 Channels: 0=Red, 1=Green, 2=Blue
            PWM_WIDTH    => 16
        )
        port map (
            s_axi_aclk    => pl_clk0,
            s_axi_aresetn => pl_reset0_n,
            s_axi_m2s     => axil_m2s,
            s_axi_s2m     => axil_s2m,
            pwm_o         => rgb_led_o
        );

    system_i : component system
        port map (
            -- Wire up Block Design ports ...
        );
end STRUCTURE;
```

4. Add physical pin constraints to `src/constr/${BOARD}.xdc`:
```tcl
# Zybo Z7 Tri-Color LED LD6 Constraints
set_property -dict { PACKAGE_PIN V16   IOSTANDARD LVCMOS33 } [get_ports { rgb_led_o[0] }]; # Red
set_property -dict { PACKAGE_PIN F17   IOSTANDARD LVCMOS33 } [get_ports { rgb_led_o[1] }]; # Green
set_property -dict { PACKAGE_PIN M17   IOSTANDARD LVCMOS33 } [get_ports { rgb_led_o[2] }]; # Blue
```

---

#### Step C: Control Custom Hardware from C / FreeRTOS (`sw/zynq_ps/`)
In your software application, write to the registers using the AXI base address assigned in Step A:

```c
#include "xil_io.h"

#define PWM_BASEADDR  0x43C00000

#define PWM_REG_CTRL  (PWM_BASEADDR + 0x00)
#define PWM_REG_PRESC (PWM_BASEADDR + 0x04)
#define PWM_REG_PERIOD(PWM_BASEADDR + 0x08)
#define PWM_REG_RED   (PWM_BASEADDR + 0x0C)
#define PWM_REG_GREEN (PWM_BASEADDR + 0x10)
#define PWM_REG_BLUE  (PWM_BASEADDR + 0x14)

void init_rgb_led(void) {
    // 1. Set prescaler: divide 100MHz PL clock by 100 -> 1 MHz counter clock
    Xil_Out32(PWM_REG_PRESC, 99);

    // 2. Set period: 1000 counts -> 1 kHz PWM frequency
    Xil_Out32(PWM_REG_PERIOD, 1000);

    // 3. Enable PWM Generator (Bit 0 = 1)
    Xil_Out32(PWM_REG_CTRL, 0x01);
}

void set_rgb_color(uint16_t red, uint16_t green, uint16_t blue) {
    Xil_Out32(PWM_REG_RED,   red);   // 0 to 1000
    Xil_Out32(PWM_REG_GREEN, green); // 0 to 1000
    Xil_Out32(PWM_REG_BLUE,  blue);  // 0 to 1000
}
```

---

## 15. Git Best Practices
This repository uses a **Whitelist .gitignore**. Only source files and scripts are tracked. Build artifacts are ignored automatically.

**Before you commit:**
1. Run `make clean`.
2. Ensure you have run `write_bd_tcl` if you modified the Block Design.
3. `git add .` then `git commit`.

---
*Generated by Gemini CLI Framework Assistant*

