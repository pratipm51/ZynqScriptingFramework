import vitis
import sys
import os
import time
import shutil
import glob

# Arguments from Makefile: board, app_name, plat_name, os_arg, bd_name
board = sys.argv[1] if len(sys.argv) > 1 else "ebaz"
app_name = sys.argv[2] if len(sys.argv) > 2 else "zynq_app"
plat_name = sys.argv[3] if len(sys.argv) > 3 else f"{board}_standalone_plat"
os_arg = sys.argv[4] if len(sys.argv) > 4 else "standalone"
bd_name = sys.argv[5] if len(sys.argv) > 5 else "system"

# Normalize OS names
os_map = {"standalone": "standalone", "freertos": "freertos", "freertos10_xilinx": "freertos"}
os_type = os_map.get(os_arg.lower(), os_arg)

XSA_PATH = os.path.abspath(f"./hw_build/{board}/{bd_name}.xsa")
WORKSPACE = os.path.abspath(f"./vitis_ws")
SAVED_PLAT_DIR = os.path.abspath("./sw/platforms")
SAVED_APP_ROOT = os.path.abspath("./sw/apps")

client = vitis.create_client()
time.sleep(2)
client.set_workspace(path=WORKSPACE)

def restore_bsp_config(platform):
    saved_yaml = os.path.join(SAVED_PLAT_DIR, f"{plat_name}.yaml")
    if not os.path.exists(saved_yaml):
        print(f"ℹ️  No saved BSP configuration found for {plat_name}. Using defaults.")
        return

    print(f"🔄 Restoring BSP configuration from {saved_yaml}...")
    # Find where Vitis put the new bsp.yaml
    plat_dir = os.path.join(WORKSPACE, plat_name)
    target_yamls = glob.glob(os.path.join(plat_dir, "**", "bsp.yaml"), recursive=True)
    
    if target_yamls:
        for target in target_yamls:
            print(f"   -> Overwriting {target}")
            shutil.copy2(saved_yaml, target)
    else:
        print("   ⚠️  Warning: Target bsp.yaml not found to overwrite.")

# 1. Platform Component
plat_dir = os.path.join(WORKSPACE, plat_name)
platform_xpfm = os.path.join(plat_dir, "export", plat_name, f"{plat_name}.xpfm")

if not os.path.exists(plat_dir):
    print(f"🚀 Creating Platform {plat_name} for OS: {os_type}...")
    platform = client.create_platform_component(
        name=plat_name,
        hw_design=XSA_PATH,
        os=os_type,
        cpu="ps7_cortexa9_0"
    )
    # Restore saved config BEFORE the first build
    restore_bsp_config(platform)
    print(f"🔨 Building Platform {plat_name}...")
    platform.build()
else:
    print(f"✅ Platform {plat_name} already exists.")
    platform = client.get_component(name=plat_name)
    
    needs_rebuild = False
    if os.path.exists(XSA_PATH) and os.path.exists(platform_xpfm):
        if os.path.getmtime(XSA_PATH) > os.path.getmtime(platform_xpfm):
            print(f"🔄 Hardware specification changed. Updating Platform {plat_name}...")
            platform.update_hw(hw_design=XSA_PATH)
            needs_rebuild = True

    # Always attempt restore (in case user updated the saved YAML manually)
    restore_bsp_config(platform)
    
    print(f"🔨 Rebuilding Platform {plat_name}...")
    platform.build()

platform_path = os.path.join(WORKSPACE, plat_name, "export", plat_name, f"{plat_name}.xpfm")

# 2. Application Component
if app_name == "zynq_app":
    src_dir = os.path.abspath("./sw/zynq_ps")
else:
    src_dir = os.path.abspath(f"./sw/zynq_ps/{app_name}")
    if not os.path.exists(src_dir):
        src_dir = os.path.abspath(f"./sw/{app_name}")

if os.path.exists(src_dir):
    if not os.path.exists(os.path.join(WORKSPACE, app_name)):
        print(f"🚀 Creating Vitis Application {app_name} on platform {plat_name}...")
        app = client.create_app_component(
            name=app_name,
            platform=platform_path,
            domain=f"{os_type}_ps7_cortexa9_0"
        )
    else:
        print(f"✅ Application {app_name} already exists. Syncing sources...")
        app = client.get_component(name=app_name)
    
    print(f"   -> Importing sources from {src_dir}")
    app.import_files(from_loc=src_dir, dest_dir_in_cmp="src")
    
    print(f"🔨 Building {app_name}...")
    app.build()
else:
    print(f"ℹ️  Source directory for '{app_name}' not found.")
    print(f"   To start a new project, use 'make edit-sw' and create the component in the GUI.")

print("✅ Vitis Build Process Complete!")
