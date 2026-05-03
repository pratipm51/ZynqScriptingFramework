import vitis
import sys
import os

# Get board name from Makefile
board = sys.argv[1] if len(sys.argv) > 1 else "ebaz"
XSA_PATH = f"./hw_build/{board}/system.xsa"
WORKSPACE = f"./vitis_ws/{board}"

client = vitis.create_client()
client.set_workspace(path=WORKSPACE)

# 1. Create Platform Component
platform = client.create_platform_component(
    name=f"{board}_plat",
    hw=XSA_PATH,
    os="standalone",
    cpu="ps7_cortexa9_0"
)
platform.build()

# 2. Create Application Component
app = client.create_app_component(
    name=f"{board}_app",
    platform=f"{board}_plat",
    domain="standalone_ps7_cortexa9_0",
    template="empty_application"
)

# 3. Link Git-tracked source code
app.import_sources(from_loc="./sw", target_loc="src", soft_link=True)
app.build()

