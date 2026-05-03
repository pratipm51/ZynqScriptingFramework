import vitis
import sys
import os
import time
import shutil

# Get board name from Makefile
board = sys.argv[1] if len(sys.argv) > 1 else "ebaz"
XSA_PATH = os.path.abspath(f"./hw_build/{board}/system.xsa")
WORKSPACE = os.path.abspath(f"./vitis_ws")

# Nuclear Option: Clean workspace to avoid "Already Exists" or version issues
if os.path.exists(WORKSPACE):
    print("🧹 Cleaning existing Vitis workspace...")
    shutil.rmtree(WORKSPACE)

client = vitis.create_client()
client.set_workspace(path=WORKSPACE)

# 1. Create Platform Component
plat_name = f"{board}_plat"
print(f"🚀 Creating Platform {plat_name}...")
platform = client.create_platform_component(
    name=plat_name,
    hw_design=XSA_PATH,
    os="standalone",
    cpu="ps7_cortexa9_0"
)
platform.build()

# 2. Create Application Component
app_name = f"{board}_app"
print(f"🚀 Creating Application {app_name}...")
platform_path = os.path.join(WORKSPACE, plat_name, "export", plat_name, f"{plat_name}.xpfm")
app = client.create_app_component(
    name=app_name,
    platform=platform_path,
    domain="standalone_ps7_cortexa9_0"
)

# 3. Import and Build source code
print(f"🔨 Importing sources and building {app_name}...")
app.import_files(
    from_loc=os.path.abspath("./sw"),
    dest_dir_in_cmp="src"
)
app.build()

print("✅ Software Build Complete!")
