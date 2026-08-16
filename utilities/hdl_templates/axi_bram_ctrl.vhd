----------------------------------------------------------------------------------
-- Entity Name: axi_bram_ctrl
-- Description: Generic Parametric AXI4-Lite to Block RAM Controller (Standard VHDL-93)
--              Designed for Vivado Block Design Module Reference ("Add Module").
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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

        -- Standard AXI4-Lite Slave Interface
        s_axi_awaddr     : in  std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
        s_axi_awprot     : in  std_logic_vector(2 downto 0);
        s_axi_awvalid    : in  std_logic;
        s_axi_awready    : out std_logic;

        s_axi_wdata      : in  std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
        s_axi_wstrb      : in  std_logic_vector((AXI_DATA_WIDTH/8)-1 downto 0);
        s_axi_wvalid     : in  std_logic;
        s_axi_wready     : out std_logic;

        s_axi_bresp      : out std_logic_vector(1 downto 0);
        s_axi_bvalid     : out std_logic;
        s_axi_bready     : in  std_logic;

        s_axi_araddr     : in  std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
        s_axi_arprot     : in  std_logic_vector(2 downto 0);
        s_axi_arvalid    : in  std_logic;
        s_axi_arready    : out std_logic;

        s_axi_rdata      : out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
        s_axi_rresp      : out std_logic_vector(1 downto 0);
        s_axi_rvalid     : out std_logic;
        s_axi_rready     : in  std_logic;

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
    type state_t is (IDLE, WRITE_RESP, READ_WAIT, READ_RESP);
    signal state : state_t := IDLE;

    signal axi_awready : std_logic := '0';
    signal axi_wready  : std_logic := '0';
    signal axi_bvalid  : std_logic := '0';
    signal axi_arready : std_logic := '0';
    signal axi_rvalid  : std_logic := '0';
    signal axi_rdata   : std_logic_vector(AXI_DATA_WIDTH-1 downto 0) := (others => '0');

    signal bram_en_reg     : std_logic := '0';
    signal bram_we_reg     : std_logic_vector((AXI_DATA_WIDTH/8)-1 downto 0) := (others => '0');
    signal bram_addr_reg   : std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0) := (others => '0');
    signal bram_wrdata_reg : std_logic_vector(AXI_DATA_WIDTH-1 downto 0) := (others => '0');
begin
    bram_clk <= aclk;
    bram_rst <= not aresetn;

    bram_en     <= bram_en_reg;
    bram_we     <= bram_we_reg;
    bram_addr   <= bram_addr_reg;
    bram_wrdata <= bram_wrdata_reg;

    s_axi_awready <= axi_awready;
    s_axi_wready  <= axi_wready;
    s_axi_bresp   <= "00";
    s_axi_bvalid  <= axi_bvalid;
    s_axi_arready <= axi_arready;
    s_axi_rdata   <= bram_rddata when (BRAM_MODE = "READ_WRITE" or BRAM_MODE = "READ_ONLY") else (others => '0');
    s_axi_rresp   <= "00";
    s_axi_rvalid  <= axi_rvalid;

    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                state <= IDLE;
                axi_awready <= '0';
                axi_wready  <= '0';
                axi_bvalid  <= '0';
                axi_arready <= '0';
                axi_rvalid  <= '0';
                axi_rdata   <= (others => '0');
                
                bram_en_reg     <= '0';
                bram_we_reg     <= (others => '0');
                bram_addr_reg   <= (others => '0');
                bram_wrdata_reg <= (others => '0');
            else
                bram_en_reg <= '0';
                bram_we_reg <= (others => '0');
                
                case state is
                    when IDLE =>
                        if s_axi_arvalid = '1' then
                            state <= READ_WAIT;
                            axi_arready   <= '1';
                            bram_addr_reg <= s_axi_araddr(BRAM_ADDR_WIDTH-1 downto 0);
                            bram_en_reg   <= '1';
                        elsif s_axi_awvalid = '1' and s_axi_wvalid = '1' then
                            state <= WRITE_RESP;
                            axi_awready     <= '1';
                            axi_wready      <= '1';
                            bram_addr_reg   <= s_axi_awaddr(BRAM_ADDR_WIDTH-1 downto 0);
                            bram_wrdata_reg <= s_axi_wdata;
                            bram_en_reg     <= '1';
                            if BRAM_MODE = "READ_WRITE" or BRAM_MODE = "WRITE_ONLY" then
                                bram_we_reg <= s_axi_wstrb;
                            else
                                bram_we_reg <= (others => '0');
                            end if;
                        end if;
                        
                    when WRITE_RESP =>
                        axi_awready <= '0';
                        axi_wready  <= '0';
                        axi_bvalid  <= '1';
                        if s_axi_bready = '1' then
                            axi_bvalid <= '0';
                            state <= IDLE;
                        end if;
                        
                    when READ_WAIT =>
                        axi_arready <= '0';
                        state <= READ_RESP;
                        if BRAM_MODE = "READ_WRITE" or BRAM_MODE = "READ_ONLY" then
                            axi_rdata <= bram_rddata;
                        else
                            axi_rdata <= (others => '0');
                        end if;
                        axi_rvalid <= '1';
                        
                    when READ_RESP =>
                        if s_axi_rready = '1' then
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
