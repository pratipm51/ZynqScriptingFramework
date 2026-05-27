library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.bus_types_pkg.all;

entity axi_bram_ctrl is
    generic (
        BRAM_MODE        : string := "READ_WRITE"; -- Valid values: "READ_WRITE", "READ_ONLY", "WRITE_ONLY"
        AXI_ADDR_WIDTH   : integer := 32;
        AXI_DATA_WIDTH   : integer := 32;
        BRAM_ADDR_WIDTH  : integer := 12         -- E.g., 12 bits for 4KB byte-addressed space
    );
    port (
        -- Global Clock and Reset
        aclk             : in  std_logic;
        aresetn          : in  std_logic;

        -- AXI-Lite Record Interface
        s_axi_m2s        : in  axil_m2s_t;
        s_axi_s2m        : out axil_s2m_t;

        -- Native BRAM Interface
        bram_clk         : out std_logic;
        bram_rst         : out std_logic;
        bram_en          : out std_logic;
        bram_we          : out std_logic_vector((AXI_DATA_WIDTH/8)-1 downto 0);
        bram_addr        : out std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);
        bram_wrdata      : out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
        bram_rddata      : in  std_logic_vector(AXI_DATA_WIDTH-1 downto 0)
    );
end entity axi_bram_ctrl;

architecture behavioral of axi_bram_ctrl is
    -- Unified state machine for BRAM access control
    type state_t is (IDLE, WRITE_RESP, READ_WAIT, READ_RESP);
    signal state : state_t := IDLE;

    -- AXI response registers
    signal axi_awready : std_logic := '0';
    signal axi_wready  : std_logic := '0';
    signal axi_bvalid  : std_logic := '0';
    signal axi_arready : std_logic := '0';
    signal axi_rvalid  : std_logic := '0';
    signal axi_rdata   : std_logic_vector(AXI_DATA_WIDTH-1 downto 0) := (others => '0');

    -- BRAM interface registers
    signal bram_en_reg     : std_logic := '0';
    signal bram_we_reg     : std_logic_vector((AXI_DATA_WIDTH/8)-1 downto 0) := (others => '0');
    signal bram_addr_reg   : std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0) := (others => '0');
    signal bram_wrdata_reg : std_logic_vector(AXI_DATA_WIDTH-1 downto 0) := (others => '0');
begin
    -- Assign constant control outputs
    bram_clk <= aclk;
    bram_rst <= not aresetn; -- Active-high reset for standard block RAM

    -- Assign BRAM port outputs
    bram_en     <= bram_en_reg;
    bram_we     <= bram_we_reg;
    bram_addr   <= bram_addr_reg;
    bram_wrdata <= bram_wrdata_reg;

    -- Assign AXI slave response outputs
    s_axi_s2m.awready <= axi_awready;
    s_axi_s2m.wready  <= axi_wready;
    s_axi_s2m.bresp   <= "00"; -- OKAY response
    s_axi_s2m.bvalid  <= axi_bvalid;
    s_axi_s2m.arready <= axi_arready;
    s_axi_s2m.rdata   <= axi_rdata;
    s_axi_s2m.rresp   <= "00"; -- OKAY response
    s_axi_s2m.rvalid  <= axi_rvalid;

    -- AXI transaction control process
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                state <= IDLE;
                axi_awready <= '0';
                axi_wready <= '0';
                axi_bvalid <= '0';
                axi_arready <= '0';
                axi_rvalid <= '0';
                axi_rdata <= (others => '0');
                
                bram_en_reg <= '0';
                bram_we_reg <= (others => '0');
                bram_addr_reg <= (others => '0');
                bram_wrdata_reg <= (others => '0');
            else
                -- Default values for single-cycle assertions
                bram_en_reg <= '0';
                bram_we_reg <= (others => '0');
                
                case state is
                    when IDLE =>
                        -- Prioritize reads over writes (standard convention)
                        if s_axi_m2s.arvalid = '1' then
                            state <= READ_WAIT;
                            axi_arready <= '1';
                            bram_addr_reg <= s_axi_m2s.araddr(BRAM_ADDR_WIDTH-1 downto 0);
                            bram_en_reg <= '1';
                        elsif s_axi_m2s.awvalid = '1' and s_axi_m2s.wvalid = '1' then
                            state <= WRITE_RESP;
                            axi_awready <= '1';
                            axi_wready <= '1';
                            bram_addr_reg <= s_axi_m2s.awaddr(BRAM_ADDR_WIDTH-1 downto 0);
                            bram_wrdata_reg <= s_axi_m2s.wdata;
                            bram_en_reg <= '1';
                            if BRAM_MODE = "READ_WRITE" or BRAM_MODE = "WRITE_ONLY" then
                                bram_we_reg <= s_axi_m2s.wstrb;
                            else
                                bram_we_reg <= (others => '0'); -- Read-only mode ignores write
                            end if;
                        end if;
                        
                    when WRITE_RESP =>
                        axi_awready <= '0';
                        axi_wready <= '0';
                        axi_bvalid <= '1';
                        if s_axi_m2s.bready = '1' then
                            axi_bvalid <= '0';
                            state <= IDLE;
                        end if;
                        
                    when READ_WAIT =>
                        axi_arready <= '0';
                        state <= READ_RESP;
                        -- BRAM read data is latched and available on this clock edge
                        if BRAM_MODE = "READ_WRITE" or BRAM_MODE = "READ_ONLY" then
                            axi_rdata <= bram_rddata;
                        else
                            axi_rdata <= (others => '0'); -- Write-only mode returns all zeroes
                        end if;
                        axi_rvalid <= '1';
                        
                    when READ_RESP =>
                        if s_axi_m2s.rready = '1' then
                            axi_rvalid <= '0';
                            state <= IDLE;
                        end if;
                        
                    when others =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;
end architecture behavioral;
