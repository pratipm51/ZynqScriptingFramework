#!/bin/bash

# 1. Check if PROJECT_NAME is provided
if [ -z "$1" ]; then
    echo "❌ Error: No project name provided."
    echo "Usage: $0 <project_name>"
    exit 1
fi

PROJECT_NAME=$1

# 2. Create the project directory
if [ -d "$PROJECT_NAME" ]; then
    echo "⚠️ Error: Directory '$PROJECT_NAME' already exists."
    exit 1
fi

echo "🚀 Creating repository structure for: $PROJECT_NAME"
mkdir -p "$PROJECT_NAME"/{src/hdl,src/constr,scripts,docs,sw}

# 3. Move into the directory and initialize Git
cd "$PROJECT_NAME" || exit
git init -q

# 4. Create the Inverted .gitignore (Whitelist Logic)
cat <<EOF > .gitignore
# 1. Ignore everything by default
*
!*/

# 2. Whitelist your core folders
!src/
!scripts/
!docs/
!sw/
!README.md
!.gitignore
!Makefile

# 3. Whitelist specific file types
!*.vhd
!*.vhdl
!*.c
!*.h
!*.py
!*.tcl
!*.xdc

# 4. Explicitly ignore build artifacts
hw_build/
vitis_ws/
.Xil/
*.log
*.jou
EOF

# 5. Create a VHDL placeholder
cat <<EOF > src/hdl/top.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
    Port ( 
        clk : in  STD_LOGIC;
        led : out STD_LOGIC
    );
end top;

architecture Behavioral of top is
    signal counter : unsigned(24 downto 0) := (others => '0');
begin
    process(clk)
    begin
        if rising_edge(clk) then
            counter <= counter + 1;
        end if;
    end process;

    led <= std_logic(counter(24));
end Behavioral;
EOF

# 6. Create a basic README
echo "# $PROJECT_NAME" > README.md
echo "Zynq FPGA project repository with VHDL-first workflow." >> README.md

# 7. Initial commit
git add .
git commit -m "Initial commit: VHDL repository structure"

echo "✅ Success! Your VHDL project is ready at: $(pwd)"
echo "💡 Use 'make' to build hardware and software."
