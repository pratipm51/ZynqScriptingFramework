## EBAZ4205 Zynq-7000 XDC Constraints
## Board: EBAZ4205 (Zynq-7010)

# Disconnected external clock (N18) for now as we use PS clock
# set_property -dict {PACKAGE_PIN N18 IOSTANDARD LVCMOS33} [get_ports clk_ext]

# Onboard LEDs
# LED Green (active-low) - Mapping to 'led' in top.vhd
set_property -dict {PACKAGE_PIN W13 IOSTANDARD LVCMOS33} [get_ports led]

# LED Red (Mapping it to a dummy pin or just defining it)
set_property -dict {PACKAGE_PIN W14 IOSTANDARD LVCMOS33} [get_ports {GPIO_0_0_tri_io[0]}]

# Dummy Constraints for EMIO GPIO (mapped to DATA2 header)
set_property -dict {PACKAGE_PIN G19 IOSTANDARD LVCMOS33} [get_ports {GPIO_0_0_tri_io[1]}]
set_property -dict {PACKAGE_PIN G20 IOSTANDARD LVCMOS33} [get_ports {GPIO_0_0_tri_io[2]}]
set_property -dict {PACKAGE_PIN H18 IOSTANDARD LVCMOS33} [get_ports {GPIO_0_0_tri_io[3]}]
set_property -dict {PACKAGE_PIN J18 IOSTANDARD LVCMOS33} [get_ports {GPIO_0_0_tri_io[4]}]
set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVCMOS33} [get_ports {GPIO_0_0_tri_io[5]}]
set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVCMOS33} [get_ports {GPIO_0_0_tri_io[6]}]
set_property -dict {PACKAGE_PIN L19 IOSTANDARD LVCMOS33} [get_ports {GPIO_0_0_tri_io[7]}]

# Dummy Constraint for Ethernet PHY Clock Output
set_property -dict {PACKAGE_PIN M19 IOSTANDARD LVCMOS33} [get_ports enet0_phy_clk]
