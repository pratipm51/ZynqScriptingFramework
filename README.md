# 🚀 Zynq-VHDL Logic: The Script-First Framework

A professional, version-control-friendly workflow for Xilinx Zynq-7000 SoC development. This framework eliminates GUI-dependency for builds, supporting advanced features like **Hybrid Multi-CPU (ARM + Soft-CPU)**, custom toolchains, and automatic VHDL library management.

---

## ✨ Key Features

- **Hybrid Multi-CPU Support**: Simultaneously develop for the Zynq ARM PS and a soft-CPU in the PL (e.g., NeoRV32).
- **Universal Toolchain**: Use Vitis for ARM and any custom toolchain (RISC-V, etc.) for soft-CPUs via simple `sw/Makefile` prioritization.
- **Smart VHDL Pipeline**:
    - **External Libraries**: Manage complex IPs using `vhdl_libs.txt`.
    - **Smart Sort**: Automatic detection and prioritization of VHDL packages.
    - **Explicit Order**: Total control via `compile_order.txt`.
- **One-Click Sync**: Custom Vivado GUI button to instantly "freeze" Block Design changes back to the framework.
- **Integrated Utilities**: Includes a professional UART Terminal/Uploader (`utilities/upload_bin.py`) with `Ctrl+U` binary injection.
- **Developer-First CLI**: Single commands for everything (`make hw`, `make sw`, `make run`, `make boot`).

---

## 📂 Project Structure

```text
/project_root
├── src/
│   ├── hdl/           <-- Your VHDL files
│   └── constr/        <-- Physical constraints (*.xdc)
├── sw/                <-- Software source code
│   └── arm/           <-- (Optional) Dedicated Zynq ARM code
├── board_configs/     <-- Block Design scripts (*_bd.tcl)
├── utilities/         <-- Standalone tools (Uploader, etc.)
├── scripts/           <-- The Framework Engine
├── vhdl_libs.txt      <-- Configure external VHDL libraries
├── sw_sources.txt     <-- Configure Soft-CPU source directories
├── arm_sources.txt    <-- Configure Zynq ARM source directories
└── Makefile           <-- The Command Center
```

---

## 🚀 Quick Start

### 1. Requirements
- Vivado/Vitis 2025.2+
- (Optional) RISC-V toolchain for NeoRV32 support.

### 2. Initialization
1. Clone the repository.
2. Run `make edit-hw` to configure your Zynq Block Design.
3. Click the **"Sync to Framework"** button in Vivado.

### 3. Build & Run
```bash
make all   # Build Bitstream and Software (ARM + Soft-CPU)
make run   # Flash FPGA and execute via JTAG
```

For detailed instructions on multi-CPU setups and advanced features, see **[FRAMEWORK_GUIDE.md](FRAMEWORK_GUIDE.md)**.

---
*Developed for professional FPGA engineers who value automation and speed.*
