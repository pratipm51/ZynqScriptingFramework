library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wishbone_interconnect is
    generic (
        NUM_SLAVES        : integer := 3;
        WB_ADDR_WIDTH     : integer := 32;
        WB_DATA_WIDTH     : integer := 32;
        -- Flattened arrays of base addresses and masks for each subordinate slot
        SLAVE_ADDR_BASES  : std_logic_vector(NUM_SLAVES * WB_ADDR_WIDTH - 1 downto 0);
        SLAVE_ADDR_MASKS  : std_logic_vector(NUM_SLAVES * WB_ADDR_WIDTH - 1 downto 0)
    );
    port (
        -- Wishbone Clock and Reset
        wb_clk_i          : in  std_logic;
        wb_rst_i          : in  std_logic;

        -- Wishbone Master Port (input from master)
        m_wb_adr_i        : in  std_logic_vector(WB_ADDR_WIDTH-1 downto 0);
        m_wb_dat_i        : in  std_logic_vector(WB_DATA_WIDTH-1 downto 0);
        m_wb_dat_o        : out std_logic_vector(WB_DATA_WIDTH-1 downto 0);
        m_wb_we_i         : in  std_logic;
        m_wb_sel_i        : in  std_logic_vector((WB_DATA_WIDTH/8)-1 downto 0);
        m_wb_stb_i        : in  std_logic;
        m_wb_cyc_i        : in  std_logic;
        m_wb_ack_o        : out std_logic;

        -- Flattened Wishbone Slave Ports (outputs to slaves)
        s_wb_adr_o        : out std_logic_vector(NUM_SLAVES * WB_ADDR_WIDTH - 1 downto 0);
        s_wb_dat_o        : out std_logic_vector(NUM_SLAVES * WB_DATA_WIDTH - 1 downto 0);
        s_wb_dat_i        : in  std_logic_vector(NUM_SLAVES * WB_DATA_WIDTH - 1 downto 0);
        s_wb_we_o         : out std_logic_vector(NUM_SLAVES - 1 downto 0);
        s_wb_sel_o        : out std_logic_vector(NUM_SLAVES * (WB_DATA_WIDTH/8) - 1 downto 0);
        s_wb_stb_o        : out std_logic_vector(NUM_SLAVES - 1 downto 0);
        s_wb_cyc_o        : out std_logic_vector(NUM_SLAVES - 1 downto 0);
        s_wb_ack_i        : in  std_logic_vector(NUM_SLAVES - 1 downto 0)
    );
end entity wishbone_interconnect;

architecture behavioral of wishbone_interconnect is
    -- Address match decode logic helper
    function get_matched_slave(
        addr       : std_logic_vector(WB_ADDR_WIDTH-1 downto 0);
        bases      : std_logic_vector(NUM_SLAVES * WB_ADDR_WIDTH - 1 downto 0);
        masks      : std_logic_vector(NUM_SLAVES * WB_ADDR_WIDTH - 1 downto 0)
    ) return integer is
        variable base_addr : std_logic_vector(WB_ADDR_WIDTH-1 downto 0);
        variable addr_mask : std_logic_vector(WB_ADDR_WIDTH-1 downto 0);
    begin
        for i in 0 to NUM_SLAVES-1 loop
            base_addr := bases((i+1)*WB_ADDR_WIDTH - 1 downto i*WB_ADDR_WIDTH);
            addr_mask := masks((i+1)*WB_ADDR_WIDTH - 1 downto i*WB_ADDR_WIDTH);
            if (addr and addr_mask) = (base_addr and addr_mask) then
                return i;
            end if;
        end loop;
        return -1; -- No match
    end function;

    signal slave_sel : integer range -1 to NUM_SLAVES-1 := -1;
begin
    -- Decode active transaction address combinatorially
    process(m_wb_adr_i, m_wb_cyc_i, m_wb_stb_i)
    begin
        if m_wb_cyc_i = '1' and m_wb_stb_i = '1' then
            slave_sel <= get_matched_slave(m_wb_adr_i, SLAVE_ADDR_BASES, SLAVE_ADDR_MASKS);
        else
            slave_sel <= -1;
        end if;
    end process;

    -- Route Master Control signals to target slave (broadcast address/data/control)
    gen_slave_broadcast: for i in 0 to NUM_SLAVES-1 generate
        s_wb_adr_o((i+1)*WB_ADDR_WIDTH-1 downto i*WB_ADDR_WIDTH) <= m_wb_adr_i;
        s_wb_dat_o((i+1)*WB_DATA_WIDTH-1 downto i*WB_DATA_WIDTH) <= m_wb_dat_i;
        s_wb_we_o(i)                                             <= m_wb_we_i;
        s_wb_sel_o((i+1)*(WB_DATA_WIDTH/8)-1 downto i*(WB_DATA_WIDTH/8)) <= m_wb_sel_i;
    end generate gen_slave_broadcast;

    -- Strobe and Cycle Routing
    process(slave_sel, m_wb_stb_i, m_wb_cyc_i)
    begin
        s_wb_stb_o <= (others => '0');
        s_wb_cyc_o <= (others => '0');
        if slave_sel /= -1 then
            s_wb_stb_o(slave_sel) <= m_wb_stb_i;
            s_wb_cyc_o(slave_sel) <= m_wb_cyc_i;
        end if;
    end process;

    -- Route target slave data & ack back to master
    process(slave_sel, s_wb_dat_i, s_wb_ack_i)
    begin
        m_wb_dat_o <= (others => '0');
        m_wb_ack_o <= '0';
        if slave_sel /= -1 then
            m_wb_dat_o <= s_wb_dat_i((slave_sel+1)*WB_DATA_WIDTH - 1 downto slave_sel*WB_DATA_WIDTH);
            m_wb_ack_o <= s_wb_ack_i(slave_sel);
        end if;
    end process;
end architecture behavioral;
