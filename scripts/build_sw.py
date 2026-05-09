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

print("🚀 Starting Vitis Client...")
client = vitis.create_client()
time.sleep(2) # Give the server a moment to settle
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
time.sleep(2) # Wait for platform analysis to finish

# 2. Build the platform (with robust retry)
print(f"🔨 Building Platform {plat_name}...")
max_retries = 2
for attempt in range(max_retries):
    try:
        platform.build()
        break
    except Exception as e:
        if attempt < max_retries - 1:
            print(f"⚠️ Attempt {attempt+1} failed: {e}. Retrying...")
            time.sleep(5)
        else:
            print(f"❌ Platform build failed after {max_retries} attempts.")
            raise

# 3. Create Application Component
app_name = f"{board}_app"
print(f"🚀 Creating Application {app_name}...")
platform_path = os.path.join(WORKSPACE, plat_name, "export", plat_name, f"{plat_name}.xpfm")

app = client.create_app_component(
    name=app_name,
    platform=platform_path,
    domain="standalone_ps7_cortexa9_0"
)

# 4. Import and Build source code from multiple directories
print(f"🔨 Importing sources and building {app_name}...")

# Get directories from environment variable
sw_dirs_raw = os.environ.get("USER_SW_DIRS", "./sw")
sw_dirs = [d.strip() for d in sw_dirs_raw.split(",")]

for src_dir in sw_dirs:
    if os.path.exists(src_dir):
        print(f"📦 Importing files from: {src_dir}")
        app.import_files(
            from_loc=os.path.abspath(src_dir),
            dest_dir_in_cmp="src"
        )
    else:
        print(f"⚠️ Warning: Software directory not found: {src_dir}")

app.build()

print("✅ Software Build Complete!")
