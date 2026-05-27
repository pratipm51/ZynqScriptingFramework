library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_lite_interconnect is
    generic (
        NUM_SLAVES        : integer := 3;
        AXI_ADDR_WIDTH    : integer := 32;
        AXI_DATA_WIDTH    : integer := 32;
        AXI_STRB_WIDTH    : integer := 4;
        -- Flattened arrays of base addresses and masks for each subordinate slot
        SLAVE_ADDR_BASES  : std_logic_vector(NUM_SLAVES * AXI_ADDR_WIDTH - 1 downto 0);
        SLAVE_ADDR_MASKS  : std_logic_vector(NUM_SLAVES * AXI_ADDR_WIDTH - 1 downto 0)
    );
    port (
        -- Global clock and reset
        aclk              : in  std_logic;
        aresetn           : in  std_logic;

        -- Manager Port (AXI-Lite Slave Interface)
        m_axi_awaddr      : in  std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
        m_axi_awprot      : in  std_logic_vector(2 downto 0);
        m_axi_awvalid     : in  std_logic;
        m_axi_awready     : out std_logic;

        m_axi_wdata       : in  std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
        m_axi_wstrb       : in  std_logic_vector(AXI_STRB_WIDTH-1 downto 0);
        m_axi_wvalid      : in  std_logic;
        m_axi_wready      : out std_logic;

        m_axi_bresp       : out std_logic_vector(1 downto 0);
        m_axi_bvalid      : out std_logic;
        m_axi_bready      : in  std_logic;

        m_axi_araddr      : in  std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
        m_axi_arprot      : in  std_logic_vector(2 downto 0);
        m_axi_arvalid     : in  std_logic;
        m_axi_arready     : out std_logic;

        m_axi_rdata       : out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
        m_axi_rresp       : out std_logic_vector(1 downto 0);
        m_axi_rvalid      : out std_logic;
        m_axi_rready      : in  std_logic;

        -- Flattened Subordinate Ports (AXI-Lite Master Interfaces)
        s_axi_awaddr      : out std_logic_vector(NUM_SLAVES * AXI_ADDR_WIDTH - 1 downto 0);
        s_axi_awprot      : out std_logic_vector(NUM_SLAVES * 3 - 1 downto 0);
        s_axi_awvalid     : out std_logic_vector(NUM_SLAVES - 1 downto 0);
        s_axi_awready     : in  std_logic_vector(NUM_SLAVES - 1 downto 0);

        s_axi_wdata       : out std_logic_vector(NUM_SLAVES * AXI_DATA_WIDTH - 1 downto 0);
        s_axi_wstrb       : out std_logic_vector(NUM_SLAVES * AXI_STRB_WIDTH - 1 downto 0);
        s_axi_wvalid      : out std_logic_vector(NUM_SLAVES - 1 downto 0);
        s_axi_wready      : in  std_logic_vector(NUM_SLAVES - 1 downto 0);

        s_axi_bresp       : in  std_logic_vector(NUM_SLAVES * 2 - 1 downto 0);
        s_axi_bvalid      : in  std_logic_vector(NUM_SLAVES - 1 downto 0);
        s_axi_bready      : out std_logic_vector(NUM_SLAVES - 1 downto 0);

        s_axi_araddr      : out std_logic_vector(NUM_SLAVES * AXI_ADDR_WIDTH - 1 downto 0);
        s_axi_arprot      : out std_logic_vector(NUM_SLAVES * 3 - 1 downto 0);
        s_axi_arvalid     : out std_logic_vector(NUM_SLAVES - 1 downto 0);
        s_axi_arready     : in  std_logic_vector(NUM_SLAVES - 1 downto 0);

        s_axi_rdata       : in  std_logic_vector(NUM_SLAVES * AXI_DATA_WIDTH - 1 downto 0);
        s_axi_rresp       : in  std_logic_vector(NUM_SLAVES * 2 - 1 downto 0);
        s_axi_rvalid      : in  std_logic_vector(NUM_SLAVES - 1 downto 0);
        s_axi_rready      : out std_logic_vector(NUM_SLAVES - 1 downto 0)
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
        s_axi_awaddr((i+1)*AXI_ADDR_WIDTH-1 downto i*AXI_ADDR_WIDTH) <= m_axi_awaddr;
        s_axi_awprot((i+1)*3-1 downto i*3)                           <= m_axi_awprot;
        s_axi_wdata((i+1)*AXI_DATA_WIDTH-1 downto i*AXI_DATA_WIDTH)  <= m_axi_wdata;
        s_axi_wstrb((i+1)*AXI_STRB_WIDTH-1 downto i*AXI_STRB_WIDTH)  <= m_axi_wstrb;
        s_axi_araddr((i+1)*AXI_ADDR_WIDTH-1 downto i*AXI_ADDR_WIDTH) <= m_axi_araddr;
        s_axi_arprot((i+1)*3-1 downto i*3)                           <= m_axi_arprot;
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
                if m_axi_awvalid = '1' and write_sel_reg = -1 then
                    matched_w := get_matched_slave(m_axi_awaddr, SLAVE_ADDR_BASES, SLAVE_ADDR_MASKS);
                    write_sel_reg <= matched_w;
                elsif m_axi_bvalid = '1' and m_axi_bready = '1' then
                    write_sel_reg <= -1; -- Clear selection after transaction completes
                end if;

                -- Read transaction decode
                if m_axi_arvalid = '1' and read_sel_reg = -1 then
                    matched_r := get_matched_slave(m_axi_araddr, SLAVE_ADDR_BASES, SLAVE_ADDR_MASKS);
                    read_sel_reg <= matched_r;
                elsif m_axi_rvalid = '1' and m_axi_rready = '1' then
                    read_sel_reg <= -1; -- Clear selection after transaction completes
                end if;
            end if;
        end if;
    end process;

    -- Master Write Address & Data Router
    process(write_sel_reg, m_axi_awvalid, m_axi_wvalid, s_axi_awready, s_axi_wready)
    begin
        -- Defaults
        m_axi_awready <= '0';
        m_axi_wready  <= '0';
        s_axi_awvalid <= (others => '0');
        s_axi_wvalid  <= (others => '0');

        if write_sel_reg /= -1 then
            s_axi_awvalid(write_sel_reg) <= m_axi_awvalid;
            s_axi_wvalid(write_sel_reg)  <= m_axi_wvalid;
            m_axi_awready                <= s_axi_awready(write_sel_reg);
            m_axi_wready                 <= s_axi_wready(write_sel_reg);
        end if;
    end process;

    -- Master Write Response Router
    process(write_sel_reg, m_axi_bready, s_axi_bvalid, s_axi_bresp)
    begin
        -- Defaults
        m_axi_bvalid  <= '0';
        m_axi_bresp   <= "00";
        s_axi_bready  <= (others => '0');

        if write_sel_reg /= -1 then
            s_axi_bready(write_sel_reg) <= m_axi_bready;
            m_axi_bvalid                <= s_axi_bvalid(write_sel_reg);
            m_axi_bresp                 <= s_axi_bresp((write_sel_reg+1)*2 - 1 downto write_sel_reg*2);
        end if;
    end process;

    -- Master Read Address Router
    process(read_sel_reg, m_axi_arvalid, s_axi_arready)
    begin
        -- Defaults
        m_axi_arready <= '0';
        s_axi_arvalid <= (others => '0');

        if read_sel_reg /= -1 then
            s_axi_arvalid(read_sel_reg) <= m_axi_arvalid;
            m_axi_arready                <= s_axi_arready(read_sel_reg);
        end if;
    end process;

    -- Master Read Data Router
    process(read_sel_reg, m_axi_rready, s_axi_rvalid, s_axi_rdata, s_axi_rresp)
    begin
        -- Defaults
        m_axi_rvalid  <= '0';
        m_axi_rdata   <= (others => '0');
        m_axi_rresp   <= "00";
        s_axi_rready  <= (others => '0');

        if read_sel_reg /= -1 then
            s_axi_rready(read_sel_reg) <= m_axi_rready;
            m_axi_rvalid               <= s_axi_rvalid(read_sel_reg);
            m_axi_rdata                <= s_axi_rdata((read_sel_reg+1)*AXI_DATA_WIDTH - 1 downto read_sel_reg*AXI_DATA_WIDTH);
            m_axi_rresp                <= s_axi_rresp((read_sel_reg+1)*2 - 1 downto read_sel_reg*2);
        end if;
    end process;
end architecture behavioral;
