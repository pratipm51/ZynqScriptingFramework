# ZYNQ VIVADO PROJECT & GUI WORKFLOW

1. CREATE THE PROJECT
- Open Vivado.
- Click "Create Project".
- Set Project Name (e.g., "ebaz_hw") and Project Location (e.g., your "hw_build" folder).
- Select "RTL Project" and check "Do not specify sources at this time".
- Search for the Part Number (e.g., "xc7z010clg400-1") and click Finish.

2. OPEN THE BLOCK DESIGN TOOL
- In the left-hand Flow Navigator, click on IP Integrator.
- Click "Create Block Design".
- Set the design name to "system" and click OK.

3. ADD THE ZYNQ CPU
- Click the Plus (+) icon in the diagram window.
- Search for "ZYNQ".
- Double-click "ZYNQ7 Processing System".

4. APPLY AUTOMATION
- Click the green banner titled "Run Block Automation".
- Ensure all checkboxes are selected and click OK.

5. CONFIGURE THE PROCESSOR
- Double-click the Zynq block to open customization.
- Go to "MIO Configuration" and enable UART 1.
- Go to "DDR Configuration" and select your board's DDR3 part number.
- Go to "Clock Configuration" and set FCLK_CLK0 to 50MHz.
- Click OK.

6. ADD PERIPHERALS AND WIRE THE BUS
- Click the Plus (+) icon to add other IP like "AXI GPIO".
- Click the green banner titled "Run Connection Automation".
- Select "All Automation" and click OK.
- Click the Validate Design icon (Checkmark) to confirm the design is valid.

7. PREPARE FOR COMPILATION
- Go to the "Sources" tab.
- Right-click "system.bd".
- Select "Create HDL Wrapper".
- Choose "Let Vivado manage wrapper" and click OK.

8. SAVE AS SCRIPT FOR GIT
- Go to the Tcl Console at the bottom of the window.
- Type exactly: write_bd_tcl -force ./scripts/ebaz_bd.tcl
- Press Enter.

# END OF WORKFLOW

