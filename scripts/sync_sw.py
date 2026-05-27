import os
import shutil
import sys

# Arguments: app_name (optional)
app_name = sys.argv[1] if len(sys.argv) > 1 else ""

# Framework root is one level up from scripts/
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
WORKSPACE = os.path.join(ROOT, "vitis_ws")

if not os.path.exists(WORKSPACE):
    print(f"❌ Error: Workspace not found at {WORKSPACE}")
    sys.exit(1)

# List of components in workspace that have a 'src' directory
components = [d for d in os.listdir(WORKSPACE) if os.path.isdir(os.path.join(WORKSPACE, d, "src"))]

# Filter components based on app_name if provided
if app_name:
    if app_name in components:
        components = [app_name]
    else:
        print(f"❌ Error: Application component '{app_name}' not found in workspace.")
        sys.exit(1)

print("🔄 Syncing changes from Vitis GUI back to Framework...")

for comp in components:
    # Skip platform components
    if comp.endswith("_plat"):
        continue

    vitis_src = os.path.join(WORKSPACE, comp, "src")
    
    # Destination directory: sw/<comp>
    # Special case for legacy 'zynq_app' if no directory exists yet
    dest_dir = os.path.join(ROOT, "sw", comp)
    
    # Handle legacy 'sw/arm' if comp is 'zynq_app' and 'sw/arm' already exists
    if comp == "zynq_app" and os.path.exists(os.path.join(ROOT, "sw/arm")):
        dest_dir = os.path.join(ROOT, "sw/arm")

    if not os.path.exists(dest_dir):
        print(f"🌱 Creating new directory: {dest_dir}")
        os.makedirs(dest_dir)

    print(f"📂 Harvesting sources from {comp} -> {dest_dir}...")
    
    # Copy files back (only source and header files) recursively
    valid_exts = ('.c', '.h', '.cpp', '.hpp', '.s', '.S', '.ld')
    count = 0
    for root_dir, dirs, files in os.walk(vitis_src):
        for f in files:
            if f.lower().endswith(valid_exts):
                src_file = os.path.join(root_dir, f)
                # Compute relative path from vitis_src
                rel_path = os.path.relpath(src_file, vitis_src)
                dst_file = os.path.join(dest_dir, rel_path)
                
                # Ensure destination subdirectory exists
                os.makedirs(os.path.dirname(dst_file), exist_ok=True)
                
                # Ensure dst is writeable if it exists
                if os.path.exists(dst_file):
                    import stat
                    os.chmod(dst_file, stat.S_IWRITE | stat.S_IREAD | stat.S_IRGRP | stat.S_IWGRP | stat.S_IROTH)
                
                shutil.copy2(src_file, dst_file)
                count += 1

    print(f"   -> Synced {count} files.")

print("✅ Synchronization Complete! Use 'git status' to see the changes.")
