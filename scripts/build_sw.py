import vitis
import sys
import os
import time

# Arguments from Makefile: board, app_name, os_arg
board = sys.argv[1] if len(sys.argv) > 1 else "ebaz"
app_name = sys.argv[2] if len(sys.argv) > 2 else "zynq_app"
os_arg = sys.argv[3] if len(sys.argv) > 3 else "standalone"

# Normalize OS names (shortcut support)
os_map = {
    "standalone": "standalone",
    "freertos": "freertos",
    "freertos10_xilinx": "freertos"
}
os_type = os_map.get(os_arg.lower(), os_arg)

XSA_PATH = os.path.abspath(f"./hw_build/{board}/system.xsa")
WORKSPACE = os.path.abspath(f"./vitis_ws")

client = vitis.create_client()
time.sleep(2)
client.set_workspace(path=WORKSPACE)

# 1. Platform Component (Include OS in name to allow coexistence)
plat_name = f"{board}_{os_arg}_plat"
plat_dir = os.path.join(WORKSPACE, plat_name)
platform_xpfm = os.path.join(plat_dir, "export", plat_name, f"{plat_name}.xpfm")

# Self-healing: If directory exists but creation/build failed before, remove it
if os.path.exists(plat_dir) and not os.path.exists(platform_xpfm):
    print(f"🧹 Cleaning up failed platform attempt at {plat_name}...")
    import shutil
    shutil.rmtree(plat_dir)

if not os.path.exists(plat_dir):
    print(f"🚀 Creating Platform {plat_name} for OS: {os_type}...")
    platform = client.create_platform_component(
        name=plat_name,
        hw_design=XSA_PATH,
        os=os_type,
        cpu="ps7_cortexa9_0"
    )
    time.sleep(2)
    print(f"🔨 Building Platform {plat_name}...")
    platform.build()
else:
    print(f"✅ Platform {plat_name} already exists.")
    # Check if XSA is newer than the platform
    if os.path.exists(XSA_PATH) and os.path.exists(platform_xpfm):
        xsa_mtime = os.path.getmtime(XSA_PATH)
        plat_mtime = os.path.getmtime(platform_xpfm)
        if xsa_mtime > plat_mtime:
            print(f"🔄 Hardware specification changed. Updating Platform {plat_name}...")
            platform = client.get_component(name=plat_name)
            platform.update_hw(hw_design=XSA_PATH)
            time.sleep(2)
            print(f"🔨 Rebuilding Platform {plat_name}...")
            platform.build()
        else:
            print(f"ℹ️  Platform {plat_name} is up to date with hardware.")
    elif os.path.exists(XSA_PATH):
        # Platform exists but maybe not built yet?
        print(f"⚠️  Platform {plat_name} exists but .xpfm not found. Attempting update and build...")
        platform = client.get_component(name=plat_name)
        platform.update_hw(hw_design=XSA_PATH)
        platform.build()

platform_path = os.path.join(WORKSPACE, plat_name, "export", plat_name, f"{plat_name}.xpfm")

# 2. Determine Source Directory for Application
# Priority: 
# 1. sw/<app_name> directory
# 2. Paths in arm_sources.txt (if app_name is default 'zynq_app')
# 3. Default sw/ directory (legacy support)

src_dirs = []
app_dir = os.path.join("sw", app_name)

# Legacy check for zynq_app -> sw/arm
legacy_arm = os.path.join("sw", "arm")

if os.path.exists(app_dir):
    src_dirs.append(os.path.abspath(app_dir))
elif app_name == "zynq_app" and os.path.exists(legacy_arm):
    src_dirs.append(os.path.abspath(legacy_arm))
elif app_name == "zynq_app" and os.path.exists("arm_sources.txt"):
    with open("arm_sources.txt", "r") as f:
        for line in f:
            d = line.strip()
            if d and not d.startswith("#") and os.path.exists(d):
                src_dirs.append(os.path.abspath(d))
else:
    # If a specific app name is provided but directory doesn't exist,
    # we DO NOT default to ./sw, because the user wants a NEW project.
    if app_name == "zynq_app" and os.path.exists("sw"):
        src_dirs.append(os.path.abspath("sw"))

# 3. Create and Build Application
if src_dirs:
    # Source exists: Ensure Vitis component exists and build it
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
    
    # Import all source directories
    for d in src_dirs:
        print(f"   -> Importing sources from {d}")
        app.import_files(from_loc=d, dest_dir_in_cmp="src")
    
    print(f"🔨 Building {app_name}...")
    app.build()
else:
    # Source DOES NOT exist: Do not create the component automatically
    # This allows the user to use the Vitis GUI "Create from Template" workflow.
    print(f"ℹ️  Source directory for '{app_name}' not found.")
    print(f"   If you want to start a new project, use 'make edit-sw' and create the component '{app_name}' in the GUI.")
    print(f"   Once created, run 'make sync-sw' to save it to the framework.")

print("✅ Vitis Build Process Complete!")
