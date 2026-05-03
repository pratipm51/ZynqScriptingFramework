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
