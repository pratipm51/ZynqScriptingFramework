import os
import shutil
import sys

# Framework root is one level up from scripts/
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
WORKSPACE = os.path.join(ROOT, "vitis_ws")

if not os.path.exists(WORKSPACE):
    print(f"❌ Error: Workspace not found at {WORKSPACE}")
    sys.exit(1)

def get_arm_dest():
    """Determine where to save ARM sources based on arm_sources.txt."""
    manifest = os.path.join(ROOT, "arm_sources.txt")
    if os.path.exists(manifest):
        with open(manifest, "r") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    return os.path.join(ROOT, line)
    return os.path.join(ROOT, "sw/arm")

# Determine destinations
ARM_DEST = get_arm_dest()
SW_DEST = os.path.join(ROOT, "sw")

# Detect components in workspace
components = [d for d in os.listdir(WORKSPACE) if os.path.isdir(os.path.join(WORKSPACE, d, "src"))]

print("🔄 Syncing changes from Vitis GUI back to Framework...")

for comp in components:
    # Skip platform components (they are generated/read-only in our flow)
    if comp.endswith("_plat"):
        continue

    vitis_src = os.path.join(WORKSPACE, comp, "src")
    
    # Map component to destination
    if comp == "zynq_app":
        dest_dir = ARM_DEST
    else:
        # For default board app or custom apps
        dest_dir = SW_DEST

    if not os.path.exists(dest_dir):
        os.makedirs(dest_dir)

    print(f"📂 Harvesting sources from {comp} -> {dest_dir}...")
    
    # Copy files back (only source and header files)
    valid_exts = ('.c', '.h', '.cpp', '.hpp', '.s', '.S', '.ld')
    count = 0
    for f in os.listdir(vitis_src):
        if f.lower().endswith(valid_exts):
            shutil.copy2(os.path.join(vitis_src, f), os.path.join(dest_dir, f))
            count += 1

    print(f"   -> Synced {count} files.")

print("✅ Synchronization Complete! Use 'git status' to see the changes.")
