import vitis
import sys
import os
import time
import shutil

# Get board name from Makefile
board = sys.argv[1] if len(sys.argv) > 1 else "ebaz"
# Optional flag: --platform-only or --app-only
mode = sys.argv[2] if len(sys.argv) > 2 else "both"

XSA_PATH = os.path.abspath(f"./hw_build/{board}/system.xsa")
WORKSPACE = os.path.abspath(f"./vitis_ws")

client = vitis.create_client()
time.sleep(2)
client.set_workspace(path=WORKSPACE)

# 1. Platform Component (Zynq Hardware Support + FSBL)
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

if mode == "--platform-only":
    print("Done (Platform Only).")
    sys.exit(0)

# 2. Application Component (The Software Logic)
app_name = f"{board}_app"
if not os.path.exists(os.path.join(WORKSPACE, app_name)):
    print(f"🚀 Creating Application {app_name}...")
    platform_path = os.path.join(WORKSPACE, plat_name, "export", plat_name, f"{plat_name}.xpfm")
    app = client.create_app_component(
        name=app_name,
        platform=platform_path,
        domain="standalone_ps7_cortexa9_0"
    )
else:
    app = client.get_component(name=app_name)

# 3. Import and Build (Only if we aren't using a custom Makefile)
# Note: If sw/Makefile exists, the main Makefile handles the build, 
# but we still use this script to ensure the Platform is ready.
if os.path.exists("sw/Makefile"):
    print("ℹ️ Custom software Makefile detected. Skipping Vitis Application build.")
else:
    print(f"🔨 Importing sources and building {app_name}...")
    # Import files from sw_sources.txt
    sw_dirs = []
    if os.path.exists("sw_sources.txt"):
        with open("sw_sources.txt", "r") as f:
            sw_dirs = [os.path.abspath(l.strip()) for l in f if l.strip() and not l.startswith("#")]
    else:
        sw_dirs = [os.path.abspath("./sw")]

    for src_dir in sw_dirs:
        if os.path.exists(src_dir):
            app.import_files(from_loc=src_dir, dest_dir_in_cmp="src")
    
    app.build()
    print("✅ Vitis Software Build Complete!")
