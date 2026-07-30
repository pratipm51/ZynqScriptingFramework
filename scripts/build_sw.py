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

    print(f"🔄 Merging BSP configuration from {saved_yaml}...")
    import yaml
    with open(saved_yaml, "r") as f:
        saved_data = yaml.safe_load(f)

    # Find where Vitis put the new bsp.yaml
    plat_dir = os.path.join(WORKSPACE, plat_name)
    target_yamls = glob.glob(os.path.join(plat_dir, "**", "bsp.yaml"), recursive=True)
    
    if target_yamls:
        for target in target_yamls:
            if "zynq_fsbl" in target or "export" in target:
                continue
            print(f"   -> Merging library configuration into {target}")
            with open(target, "r") as f:
                target_data = yaml.safe_load(f)
            
            if target_data is None:
                target_data = {}

            # Merge lib_info
            if "lib_info" in saved_data and saved_data["lib_info"]:
                if "lib_info" not in target_data or target_data["lib_info"] is None:
                    target_data["lib_info"] = {}
                for lib_name, lib_val in saved_data["lib_info"].items():
                    target_data["lib_info"][lib_name] = lib_val
                    print(f"      + Enabled library: {lib_name}")

            # Merge lib_config
            if "lib_config" in saved_data and saved_data["lib_config"]:
                if "lib_config" not in target_data or target_data["lib_config"] is None:
                    target_data["lib_config"] = {}
                for lib_name, lib_conf in saved_data["lib_config"].items():
                    target_data["lib_config"][lib_name] = lib_conf
                    print(f"      + Merged config for library: {lib_name}")
            
            # Merge os_config if needed (stdin/stdout settings)
            if "os_config" in saved_data and saved_data["os_config"]:
                if "os_config" not in target_data or target_data["os_config"] is None:
                    target_data["os_config"] = {}
                for os_name, os_conf in saved_data["os_config"].items():
                    if os_name in target_data["os_config"]:
                        if target_data["os_config"][os_name] is None:
                            target_data["os_config"][os_name] = {}
                        for param_name, param_val in os_conf.items():
                            target_data["os_config"][os_name][param_name] = param_val
                    else:
                        target_data["os_config"][os_name] = os_conf
                    print(f"      + Merged os_config for: {os_name}")

            with open(target, "w") as f:
                yaml.safe_dump(target_data, f)

            # Regenerate the domain BSP to apply the merged settings
            try:
                domain_name = f"{os_type}_ps7_cortexa9_0"
                print(f"🔄 Regenerating domain BSP '{domain_name}' to apply library settings...")
                domain = platform.get_domain(name=domain_name)
                domain.regenerate()
            except Exception as e:
                print(f"   ⚠️  Warning: Failed to regenerate domain via API: {e}")

            # Apply custom xemacpsif_physpeed.c patch if it exists
            patch_src = os.path.abspath("./sw/patches/xemacpsif_physpeed.c")
            if os.path.exists(patch_src):
                patch_dest = os.path.join(WORKSPACE, plat_name, "ps7_cortexa9_0", f"{os_type}_ps7_cortexa9_0", "bsp", "libsrc", "lwip220", "src", "lwip-2.2.0", "contrib", "ports", "xilinx", "netif", "xemacpsif_physpeed.c")
                if os.path.exists(os.path.dirname(patch_dest)):
                    print(f"   🩹 Applying custom Realtek RTL8211F PHY speed patch to {patch_dest}...")
                    shutil.copy2(patch_src, patch_dest)
                else:
                    print(f"   ⚠️  Warning: Destination directory for patch does not exist: {os.path.dirname(patch_dest)}")
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
if not app_name:
    print("ℹ️  No app specified - platform-only mode. Skipping application creation.")
    print("   Create/import an app in the Vitis GUI, or run 'make sw APP=<name>' later.")
    print("✅ Vitis Build Process Complete!")
    sys.exit(0)

is_templated = False
template_name = None

if app_name == "lwip_echo":
    spec_dir1 = os.path.abspath(f"./sw/zynq_ps/{app_name}")
    spec_dir2 = os.path.abspath(f"./sw/{app_name}")
    if not os.path.exists(spec_dir1) and not os.path.exists(spec_dir2):
        is_templated = True
        template_name = "lwip_echo_server"
        src_dir = spec_dir1
    else:
        src_dir = spec_dir1 if os.path.exists(spec_dir1) else spec_dir2
else:
    if app_name == "zynq_app":
        src_dir = os.path.abspath("./sw/zynq_ps")
    else:
        src_dir = os.path.abspath(f"./sw/zynq_ps/{app_name}")
        if not os.path.exists(src_dir):
            src_dir = os.path.abspath(f"./sw/{app_name}")
        # Fallback to base zynq_ps folder if app-specific directory does not exist
        if not os.path.exists(src_dir):
            src_dir = os.path.abspath("./sw/zynq_ps")

if is_templated or os.path.exists(src_dir):
    if not os.path.exists(os.path.join(WORKSPACE, app_name)):
        print(f"🚀 Creating Vitis Application {app_name} on platform {plat_name}...")
        if is_templated:
            print(f"   -> Using template: {template_name}")
            app = client.create_app_component(
                name=app_name,
                platform=platform_path,
                domain=f"{os_type}_ps7_cortexa9_0",
                template=template_name
            )
        else:
            app = client.create_app_component(
                name=app_name,
                platform=platform_path,
                domain=f"{os_type}_ps7_cortexa9_0"
            )
    else:
        print(f"✅ Application {app_name} already exists. Syncing sources...")
        app = client.get_component(name=app_name)
    
    if not is_templated:
        print(f"   -> Importing sources from {src_dir}")
        app.import_files(from_loc=src_dir, dest_dir_in_cmp="src")
    
    print(f"🔨 Building {app_name}...")
    app.build()
else:
    print(f"ℹ️  Source directory for '{app_name}' not found.")
    print(f"   To start a new project, use 'make edit-sw' and create the component in the GUI.")

print("✅ Vitis Build Process Complete!")
