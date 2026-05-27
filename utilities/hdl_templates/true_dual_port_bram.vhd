library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity true_dual_port_bram is
    generic (
        DATA_WIDTH : integer := 32;
        ADDR_WIDTH : integer := 10  -- Depth = 2^ADDR_WIDTH (default 10 => 1024 depth)
    );
    port (
        -- Port A Interface
        clk_a  : in  std_logic;
        en_a   : in  std_logic;
        we_a   : in  std_logic_vector((DATA_WIDTH/8)-1 downto 0); -- Byte write enable
        addr_a : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        din_a  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        dout_a : out std_logic_vector(DATA_WIDTH-1 downto 0);

        -- Port B Interface
        clk_b  : in  std_logic;
        en_b   : in  std_logic;
        we_b   : in  std_logic_vector((DATA_WIDTH/8)-1 downto 0); -- Byte write enable
        addr_b : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        din_b  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        dout_b : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity true_dual_port_bram;

architecture behavioral of true_dual_port_bram is
    -- Define BRAM memory array type
    type ram_type is array (0 to (2**ADDR_WIDTH)-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal ram : ram_type := (others => (others => '0'));
begin
    -- Port A Process (Write-First logic)
    process(clk_a)
        variable temp_word : std_logic_vector(DATA_WIDTH-1 downto 0);
    begin
        if rising_edge(clk_a) then
            if en_a = '1' then
                temp_word := ram(to_integer(unsigned(addr_a)));
                for i in 0 to (DATA_WIDTH/8)-1 loop
                    if we_a(i) = '1' then
                        temp_word((i+1)*8-1 downto i*8) := din_a((i+1)*8-1 downto i*8);
                        ram(to_integer(unsigned(addr_a)))((i+1)*8-1 downto i*8) <= din_a((i+1)*8-1 downto i*8);
                    end if;
                end loop;
                dout_a <= temp_word;
            end if;
        end if;
    end process;

    -- Port B Process (Write-First logic)
    process(clk_b)
        variable temp_word : std_logic_vector(DATA_WIDTH-1 downto 0);
    begin
        if rising_edge(clk_b) then
            if en_b = '1' then
                temp_word := ram(to_integer(unsigned(addr_b)));
                for i in 0 to (DATA_WIDTH/8)-1 loop
                    if we_b(i) = '1' then
                        temp_word((i+1)*8-1 downto i*8) := din_b((i+1)*8-1 downto i*8);
                        ram(to_integer(unsigned(addr_b)))((i+1)*8-1 downto i*8) <= din_b((i+1)*8-1 downto i*8);
                    end if;
                end loop;
                dout_b <= temp_word;
            end if;
        end if;
    end process;
end architecture behavioral;
