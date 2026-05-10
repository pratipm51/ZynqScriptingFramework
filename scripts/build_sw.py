import vitis
import sys
import os
import time
import shutil

# Get board name from Makefile
board = sys.argv[1] if len(sys.argv) > 1 else "ebaz"
XSA_PATH = os.path.abspath(f"./hw_build/{board}/system.xsa")
WORKSPACE = os.path.abspath(f"./vitis_ws")

# Standard clean start
if os.path.exists(WORKSPACE):
    shutil.rmtree(WORKSPACE)

client = vitis.create_client()
time.sleep(2)
client.set_workspace(path=WORKSPACE)

# 1. Create Platform
plat_name = f"{board}_plat"
print(f"🚀 Creating Platform {plat_name}...")
platform = client.create_platform_component(
    name=plat_name,
    hw_design=XSA_PATH,
    os="standalone",
    cpu="ps7_cortexa9_0"
)
time.sleep(2)
platform.build()

# 2. Create Application
app_name = f"{board}_app"
print(f"🚀 Creating Application {app_name}...")
platform_path = os.path.join(WORKSPACE, plat_name, "export", plat_name, f"{plat_name}.xpfm")

app = client.create_app_component(
    name=app_name,
    platform=platform_path,
    domain="standalone_ps7_cortexa9_0"
)

# 3. Standard Folder Import
# Vitis 2025.2 handles this correctly using sw_sources.txt
sw_dirs = []
sources_file = "sw_sources.txt"

if os.path.exists(sources_file):
    with open(sources_file, "r") as f:
        sw_dirs = [os.path.abspath(l.strip()) for l in f if l.strip() and not l.startswith("#")]
else:
    sw_dirs = [os.path.abspath("./sw")]

for src_dir in sw_dirs:
    if os.path.exists(src_dir):
        print(f"📦 Importing {src_dir}")
        app.import_files(from_loc=src_dir, dest_dir_in_cmp="src")

# 4. Build
print(f"🔨 Building {app_name}...")
app.build()
print("✅ Software Build Complete!")
