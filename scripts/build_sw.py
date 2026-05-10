import vitis
import sys
import os
import time
import shutil

# Get board name from Makefile
board = sys.argv[1] if len(sys.argv) > 1 else "ebaz"

XSA_PATH = os.path.abspath(f"./hw_build/{board}/system.xsa")
WORKSPACE = os.path.abspath(f"./vitis_ws")

client = vitis.create_client()
time.sleep(2)
client.set_workspace(path=WORKSPACE)

# 1. Platform Component (Mandatory for hardware init/clocks)
plat_name = f"{board}_plat"
if not os.path.exists(os.path.join(WORKSPACE, plat_name)):
    print(f"🚀 Creating Platform {plat_name}...")
    platform = client.create_platform_component(
        name=plat_name,
        hw_design=XSA_PATH,
        os="standalone",
        cpu="ps7_cortexa9_0"
    )
    time.sleep(2)
    print(f"🔨 Building Platform {plat_name}...")
    platform.build()
else:
    print(f"✅ Platform {plat_name} already exists.")

platform_path = os.path.join(WORKSPACE, plat_name, "export", plat_name, f"{plat_name}.xpfm")

# 2. Hybrid Application Support
# We check for a dedicated 'arm_sources.txt' to enable custom Zynq PS software
arm_sources_file = "arm_sources.txt"
sw_makefile_exists = os.path.exists("sw/Makefile")

if os.path.exists(arm_sources_file):
    app_name = "zynq_app"
    print(f"🚀 Creating custom Zynq ARM Application {app_name}...")
    app = client.create_app_component(
        name=app_name,
        platform=platform_path,
        domain="standalone_ps7_cortexa9_0"
    )
    
    # Import directories listed in arm_sources.txt
    with open(arm_sources_file, "r") as f:
        for line in f:
            d = line.strip()
            if d and not d.startswith("#") and os.path.exists(d):
                print(f"   -> Importing ARM sources from {d}")
                app.import_files(from_loc=os.path.abspath(d), dest_dir_in_cmp="src")
    
    print(f"🔨 Building {app_name}...")
    app.build()

# 3. Fallback/Standard Vitis App (If no Soft-CPU Makefile and no arm_sources.txt)
elif not sw_makefile_exists:
    app_name = f"{board}_app"
    print(f"🚀 Creating default Vitis Application {app_name}...")
    app = client.create_app_component(
        name=app_name,
        platform=platform_path,
        domain="standalone_ps7_cortexa9_0"
    )
    
    # Default to importing the sw/ directory
    src_dir = os.path.abspath("./sw")
    if os.path.exists(src_dir):
        app.import_files(from_loc=src_dir, dest_dir_in_cmp="src")
    
    print(f"🔨 Building {app_name}...")
    app.build()

else:
    print("ℹ️ Custom Soft-CPU detected via sw/Makefile. Skipping Vitis ARM app unless arm_sources.txt is provided.")

print("✅ Vitis Build Process Complete!")
