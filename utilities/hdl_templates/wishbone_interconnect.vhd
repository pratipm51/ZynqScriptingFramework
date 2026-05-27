library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.bus_types_pkg.all;

entity wishbone_interconnect is
    generic (
        NUM_SLAVES        : integer := 3;
        WB_ADDR_WIDTH     : integer := 32;
        -- Flattened arrays of base addresses and masks for each subordinate slot
        SLAVE_ADDR_BASES  : std_logic_vector(NUM_SLAVES * WB_ADDR_WIDTH - 1 downto 0);
        SLAVE_ADDR_MASKS  : std_logic_vector(NUM_SLAVES * WB_ADDR_WIDTH - 1 downto 0)
    );
    port (
        -- Wishbone Clock and Reset (kept separate from transaction records)
        wb_clk_i          : in  std_logic;
        wb_rst_i          : in  std_logic;

        -- Wishbone Master Port (input from master)
        m_wb_m2s          : in  wb_m2s_t;
        m_wb_s2m          : out wb_s2m_t;

        -- Wishbone Slave Ports (outputs to slaves as record arrays)
        s_wb_m2s          : out wb_m2s_array_t(0 to NUM_SLAVES-1);
        s_wb_s2m          : in  wb_s2m_array_t(0 to NUM_SLAVES-1)
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
    process(m_wb_m2s)
    begin
        if m_wb_m2s.cyc = '1' and m_wb_m2s.stb = '1' then
            slave_sel <= get_matched_slave(m_wb_m2s.adr, SLAVE_ADDR_BASES, SLAVE_ADDR_MASKS);
        else
            slave_sel <= -1;
        end if;
    end process;

    -- Route Master Control signals to target slave (broadcast address/data/control)
    gen_slave_broadcast: for i in 0 to NUM_SLAVES-1 generate
        s_wb_m2s(i).adr <= m_wb_m2s.adr;
        s_wb_m2s(i).dat <= m_wb_m2s.dat;
        s_wb_m2s(i).we  <= m_wb_m2s.we;
        s_wb_m2s(i).sel <= m_wb_m2s.sel;
    end generate gen_slave_broadcast;

    -- Strobe and Cycle Routing
    process(slave_sel, m_wb_m2s)
    begin
        for i in 0 to NUM_SLAVES-1 loop
            s_wb_m2s(i).stb <= '0';
            s_wb_m2s(i).cyc <= '0';
        end loop;
        if slave_sel /= -1 then
            s_wb_m2s(slave_sel).stb <= m_wb_m2s.stb;
            s_wb_m2s(slave_sel).cyc <= m_wb_m2s.cyc;
        end if;
    end process;

    -- Route target slave data & ack back to master
    process(slave_sel, s_wb_s2m)
    begin
        m_wb_s2m.dat <= (others => '0');
        m_wb_s2m.ack <= '0';
        if slave_sel /= -1 then
            m_wb_s2m.dat <= s_wb_s2m(slave_sel).dat;
            m_wb_s2m.ack <= s_wb_s2m(slave_sel).ack;
        end if;
    end process;
end architecture behavioral;
