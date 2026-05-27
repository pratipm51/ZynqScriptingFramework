library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.bus_types_pkg.all;

entity axi_lite_interconnect is
    generic (
        NUM_SLAVES        : integer := 3;
        AXI_ADDR_WIDTH    : integer := 32;
        AXI_DATA_WIDTH    : integer := 32;
        -- Flattened arrays of base addresses and masks for each subordinate slot
        SLAVE_ADDR_BASES  : std_logic_vector(NUM_SLAVES * AXI_ADDR_WIDTH - 1 downto 0);
        SLAVE_ADDR_MASKS  : std_logic_vector(NUM_SLAVES * AXI_ADDR_WIDTH - 1 downto 0)
    );
    port (
        -- Global clock and reset
        aclk              : in  std_logic;
        aresetn           : in  std_logic;

        -- Manager Port (AXI-Lite Slave Interface)
        m_axi_m2s         : in  axil_m2s_t;
        m_axi_s2m         : out axil_s2m_t;

        -- Subordinate Ports (AXI-Lite Master Interfaces as record arrays)
        s_axi_m2s         : out axil_m2s_array_t(0 to NUM_SLAVES-1);
        s_axi_s2m         : in  axil_s2m_array_t(0 to NUM_SLAVES-1)
    );
end entity axi_lite_interconnect;

architecture behavioral of axi_lite_interconnect is
    -- Address match decode logic helper
    function get_matched_slave(
        addr       : std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
        bases      : std_logic_vector(NUM_SLAVES * AXI_ADDR_WIDTH - 1 downto 0);
        masks      : std_logic_vector(NUM_SLAVES * AXI_ADDR_WIDTH - 1 downto 0)
    ) return integer is
        variable base_addr : std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
        variable addr_mask : std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
    begin
        for i in 0 to NUM_SLAVES-1 loop
            base_addr := bases((i+1)*AXI_ADDR_WIDTH - 1 downto i*AXI_ADDR_WIDTH);
            addr_mask := masks((i+1)*AXI_ADDR_WIDTH - 1 downto i*AXI_ADDR_WIDTH);
            if (addr and addr_mask) = (base_addr and addr_mask) then
                return i;
            end if;
        end loop;
        return -1; -- No match
    end function;

    -- Selected slave register indices
    signal write_sel_reg : integer range -1 to NUM_SLAVES-1 := -1;
    signal read_sel_reg  : integer range -1 to NUM_SLAVES-1 := -1;
begin
    -- Assign address and control lines to all subordinates (broadcast address/data)
    gen_sub_ports: for i in 0 to NUM_SLAVES-1 generate
        s_axi_m2s(i).awaddr  <= m_axi_m2s.awaddr;
        s_axi_m2s(i).awprot  <= m_axi_m2s.awprot;
        s_axi_m2s(i).wdata   <= m_axi_m2s.wdata;
        s_axi_m2s(i).wstrb   <= m_axi_m2s.wstrb;
        s_axi_m2s(i).araddr  <= m_axi_m2s.araddr;
        s_axi_m2s(i).arprot  <= m_axi_m2s.arprot;
    end generate gen_sub_ports;

    -- Routing process and address decoding
    process(aclk)
        variable matched_w : integer;
        variable matched_r : integer;
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                write_sel_reg <= -1;
                read_sel_reg  <= -1;
            else
                -- Write transaction decode
                if m_axi_m2s.awvalid = '1' and write_sel_reg = -1 then
                    matched_w := get_matched_slave(m_axi_m2s.awaddr, SLAVE_ADDR_BASES, SLAVE_ADDR_MASKS);
                    write_sel_reg <= matched_w;
                elsif m_axi_s2m.bvalid = '1' and m_axi_m2s.bready = '1' then
                    write_sel_reg <= -1; -- Clear selection after transaction completes
                end if;

                -- Read transaction decode
                if m_axi_m2s.arvalid = '1' and read_sel_reg = -1 then
                    matched_r := get_matched_slave(m_axi_m2s.araddr, SLAVE_ADDR_BASES, SLAVE_ADDR_MASKS);
                    read_sel_reg <= matched_r;
                elsif m_axi_s2m.rvalid = '1' and m_axi_m2s.rready = '1' then
                    read_sel_reg <= -1; -- Clear selection after transaction completes
                end if;
            end if;
        end if;
    end process;

    -- Master Write Address & Data Router
    process(write_sel_reg, m_axi_m2s, s_axi_s2m)
    begin
        -- Defaults for Manager response
        m_axi_s2m.awready <= '0';
        m_axi_s2m.wready  <= '0';
        
        -- Defaults for Subordinates
        for i in 0 to NUM_SLAVES-1 loop
            s_axi_m2s(i).awvalid <= '0';
            s_axi_m2s(i).wvalid  <= '0';
        end loop;

        if write_sel_reg /= -1 then
            s_axi_m2s(write_sel_reg).awvalid <= m_axi_m2s.awvalid;
            s_axi_m2s(write_sel_reg).wvalid  <= m_axi_m2s.wvalid;
            m_axi_s2m.awready                <= s_axi_s2m(write_sel_reg).awready;
            m_axi_s2m.wready                 <= s_axi_s2m(write_sel_reg).wready;
        end if;
    end process;

    -- Master Write Response Router
    process(write_sel_reg, m_axi_m2s, s_axi_s2m)
    begin
        -- Defaults for Manager response
        m_axi_s2m.bvalid <= '0';
        m_axi_s2m.bresp  <= "00";
        
        -- Defaults for Subordinates
        for i in 0 to NUM_SLAVES-1 loop
            s_axi_m2s(i).bready <= '0';
        end loop;

        if write_sel_reg /= -1 then
            s_axi_m2s(write_sel_reg).bready <= m_axi_m2s.bready;
            m_axi_s2m.bvalid                <= s_axi_s2m(write_sel_reg).bvalid;
            m_axi_s2m.bresp                 <= s_axi_s2m(write_sel_reg).bresp;
        end if;
    end process;

    -- Master Read Address Router
    process(read_sel_reg, m_axi_m2s, s_axi_s2m)
    begin
        -- Defaults for Manager response
        m_axi_s2m.arready <= '0';
        
        -- Defaults for Subordinates
        for i in 0 to NUM_SLAVES-1 loop
            s_axi_m2s(i).arvalid <= '0';
        end loop;

        if read_sel_reg /= -1 then
            s_axi_m2s(read_sel_reg).arvalid <= m_axi_m2s.arvalid;
            m_axi_s2m.arready                <= s_axi_s2m(read_sel_reg).arready;
        end if;
    end process;

    -- Master Read Data Router
    process(read_sel_reg, m_axi_m2s, s_axi_s2m)
    begin
        -- Defaults for Manager response
        m_axi_s2m.rvalid <= '0';
        m_axi_s2m.rdata  <= (others => '0');
        m_axi_s2m.rresp  <= "00";
        
        -- Defaults for Subordinates
        for i in 0 to NUM_SLAVES-1 loop
            s_axi_m2s(i).rready <= '0';
        end loop;

        if read_sel_reg /= -1 then
            s_axi_m2s(read_sel_reg).rready <= m_axi_m2s.rready;
            m_axi_s2m.rvalid               <= s_axi_s2m(read_sel_reg).rvalid;
            m_axi_s2m.rdata                <= s_axi_s2m(read_sel_reg).rdata;
            m_axi_s2m.rresp                <= s_axi_s2m(read_sel_reg).rresp;
        end if;
    end process;
end architecture behavioral;
