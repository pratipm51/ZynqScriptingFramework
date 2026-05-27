library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.bus_types_pkg.all;

entity wb_bram_ctrl is
    generic (
        BRAM_MODE        : string := "READ_WRITE"; -- Valid values: "READ_WRITE", "READ_ONLY", "WRITE_ONLY"
        WB_ADDR_WIDTH    : integer := 32;
        WB_DATA_WIDTH    : integer := 32;
        BRAM_ADDR_WIDTH  : integer := 12         -- E.g., 12 bits for 4KB byte-addressed space
    );
    port (
        -- Wishbone Clock and Reset (kept separate from transaction records)
        wb_clk_i         : in  std_logic;
        wb_rst_i         : in  std_logic;

        -- Wishbone Record Interface
        wb_m2s           : in  wb_m2s_t;
        wb_s2m           : out wb_s2m_t;

        -- Native BRAM Interface
        bram_clk         : out std_logic;
        bram_rst         : out std_logic;
        bram_en          : out std_logic;
        bram_we          : out std_logic_vector((WB_DATA_WIDTH/8)-1 downto 0);
        bram_addr        : out std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);
        bram_wrdata      : out std_logic_vector(WB_DATA_WIDTH-1 downto 0);
        bram_rddata      : in  std_logic_vector(WB_DATA_WIDTH-1 downto 0)
    );
end entity wb_bram_ctrl;

architecture behavioral of wb_bram_ctrl is
    signal ack_reg : std_logic := '0';
begin
    -- Assign constant control outputs
    bram_clk <= wb_clk_i;
    bram_rst <= wb_rst_i;

    -- Acknowledge port connection
    wb_s2m.ack <= ack_reg;

    -- Combinatorial read data routing (BRAM read data is stable when ack_reg is asserted)
    wb_s2m.dat <= bram_rddata when (BRAM_MODE = "READ_WRITE" or BRAM_MODE = "READ_ONLY") else (others => '0');

    process(wb_clk_i)
    begin
        if rising_edge(wb_clk_i) then
            if wb_rst_i = '1' then
                ack_reg     <= '0';
                bram_en     <= '0';
                bram_we     <= (others => '0');
                bram_addr   <= (others => '0');
                bram_wrdata <= (others => '0');
            else
                -- Default values
                bram_en <= '0';
                bram_we <= (others => '0');

                if wb_m2s.cyc = '1' and wb_m2s.stb = '1' and ack_reg = '0' then
                    ack_reg   <= '1';
                    bram_en   <= '1';
                    bram_addr <= wb_m2s.adr(BRAM_ADDR_WIDTH-1 downto 0);
                    
                    if wb_m2s.we = '1' then
                        bram_wrdata <= wb_m2s.dat;
                        if BRAM_MODE = "READ_WRITE" or BRAM_MODE = "WRITE_ONLY" then
                            bram_we <= wb_m2s.sel;
                        else
                            bram_we <= (others => '0'); -- Read-only mode ignores write
                        end if;
                    end if;
                else
                    ack_reg <= '0';
                end if;
            end if;
        end if;
    end process;
end architecture behavioral;
