import os
import shutil
import sys
import glob

# Arguments: app_name, platform_name
app_name = sys.argv[1] if len(sys.argv) > 1 else ""
plat_name = sys.argv[2] if len(sys.argv) > 2 else ""

# Framework root is one level up from scripts/
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
WORKSPACE = os.path.join(ROOT, "vitis_ws")

if not app_name:
    print("❌ Error: App name required.")
    sys.exit(1)

def harvest_app(name):
    vitis_src = os.path.join(WORKSPACE, name, "src")
    dest_dir = os.path.join(ROOT, "sw", "apps", name)

    if not os.path.exists(vitis_src):
        print(f"⚠️  App source not found in Vitis workspace: {vitis_src}")
        return

    os.makedirs(dest_dir, exist_ok=True)
    
    # Sync source and header files
    valid_exts = ('.c', '.h', '.cpp', '.hpp', '.s', '.S', '.ld')
    count = 0
    for f in os.listdir(vitis_src):
        if f.lower().endswith(valid_exts):
            src_file = os.path.join(vitis_src, f)
            dst_file = os.path.join(dest_dir, f)
            
            # Ensure dst is writeable
            if os.path.exists(dst_file):
                import stat
                os.chmod(dst_file, stat.S_IWRITE | stat.S_IREAD | stat.S_IRGRP | stat.S_IWGRP | stat.S_IROTH)
            
            shutil.copy2(src_file, dst_file)
            count += 1
    print(f"   ✅ Synced {count} source files to sw/apps/{name}/")

def harvest_platform(name):
    if not name: return
    
    # Search for bsp.yaml in the platform directory
    plat_root = os.path.join(WORKSPACE, name)
    if not os.path.exists(plat_root):
        print(f"⚠️  Platform not found in Vitis workspace: {plat_root}")
        return

    # Find bsp.yaml (usually in <plat>/<cpu>/<os>/bsp/bsp.yaml)
    yaml_files = glob.glob(os.path.join(plat_root, "**", "bsp.yaml"), recursive=True)
    
    if not yaml_files:
        print(f"⚠️  No bsp.yaml found for platform: {name}")
        return

    # We take the first one found (usually the primary domain)
    src_yaml = yaml_files[0]
    dest_yaml = os.path.join(ROOT, "sw", "platforms", f"{name}.yaml")
    
    os.makedirs(os.path.dirname(dest_yaml), exist_ok=True)
    shutil.copy2(src_yaml, dest_yaml)
    print(f"   ✅ Synced BSP settings to sw/platforms/{name}.yaml")

print(f"--- Harvesting: {app_name} ---")
harvest_app(app_name)
if plat_name:
    harvest_platform(plat_name)
