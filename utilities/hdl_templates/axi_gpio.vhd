----------------------------------------------------------------------------------
-- Entity Name: axi_gpio
-- Description: Generic Parametric AXI4-Lite GPIO Core (Standard VHDL-93)
--              Designed for Vivado Block Design Module Reference ("Add Module").
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_gpio is
    generic (
        NUM_INPUT_REGS   : integer := 2;
        NUM_OUTPUT_REGS  : integer := 2;
        GPIO_WIDTH       : integer := 32;
        AXI_ADDR_WIDTH   : integer := 32;
        AXI_DATA_WIDTH   : integer := 32
    );
    port (
        -- Global clock and reset
        s_axi_aclk       : in  std_logic;
        s_axi_aresetn    : in  std_logic;

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

        -- Parallel GPIO ports (flattened vectors for Block Design compatibility)
        inputs_i         : in  std_logic_vector(NUM_INPUT_REGS*GPIO_WIDTH-1 downto 0);
        outputs_o        : out std_logic_vector(NUM_OUTPUT_REGS*GPIO_WIDTH-1 downto 0)
    );
end entity axi_gpio;

architecture behavioral of axi_gpio is
    constant ADDR_LSB : integer := 2; -- For 32-bit registers, bottom 2 bits are byte offset

    type reg_array_t is array (0 to NUM_OUTPUT_REGS-1) of std_logic_vector(GPIO_WIDTH-1 downto 0);
    signal reg_outputs : reg_array_t := (others => (others => '0'));

    signal axi_awready : std_logic;
    signal axi_wready  : std_logic;
    signal axi_bvalid  : std_logic;
    signal axi_arready : std_logic;
    signal axi_rdata   : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
    signal axi_rvalid  : std_logic;

    signal awaddr_reg  : std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
    signal araddr_reg  : std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
begin
    s_axi_awready <= axi_awready;
    s_axi_wready  <= axi_wready;
    s_axi_bvalid  <= axi_bvalid;
    s_axi_bresp   <= "00"; -- OKAY
    s_axi_arready <= axi_arready;
    s_axi_rdata   <= axi_rdata;
    s_axi_rresp   <= "00"; -- OKAY
    s_axi_rvalid  <= axi_rvalid;

    -- Drive flattened output vector from internal array
    gen_outputs: for i in 0 to NUM_OUTPUT_REGS-1 generate
        outputs_o((i+1)*GPIO_WIDTH-1 downto i*GPIO_WIDTH) <= reg_outputs(i);
    end generate gen_outputs;

    -- Write address handshake
    process(s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_awready <= '0';
                awaddr_reg  <= (others => '0');
            else
                if axi_awready = '0' and s_axi_awvalid = '1' and s_axi_wvalid = '1' then
                    axi_awready <= '1';
                    awaddr_reg  <= s_axi_awaddr;
                else
                    axi_awready <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Write data handshake
    process(s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_wready <= '0';
            else
                if axi_wready = '0' and s_axi_wvalid = '1' and s_axi_awvalid = '1' then
                    axi_wready <= '1';
                else
                    axi_wready <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Write transaction
    process(s_axi_aclk)
        variable reg_idx : integer;
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                reg_outputs <= (others => (others => '0'));
            else
                if axi_awready = '0' and axi_wready = '0' and s_axi_awvalid = '1' and s_axi_wvalid = '1' then
                    reg_idx := to_integer(unsigned(s_axi_awaddr(11 downto ADDR_LSB)));
                    if reg_idx >= NUM_INPUT_REGS and reg_idx < (NUM_INPUT_REGS + NUM_OUTPUT_REGS) then
                        for bit_idx in 0 to GPIO_WIDTH-1 loop
                            if s_axi_wstrb(bit_idx/8) = '1' then
                                reg_outputs(reg_idx - NUM_INPUT_REGS)(bit_idx) <= s_axi_wdata(bit_idx);
                            end if;
                        end loop;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Write response logic
    process(s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_bvalid <= '0';
            else
                if axi_awready = '1' and axi_wready = '1' and axi_bvalid = '0' then
                    axi_bvalid <= '1';
                elsif s_axi_bready = '1' and axi_bvalid = '1' then
                    axi_bvalid <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Read address handshake
    process(s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_arready <= '0';
                araddr_reg  <= (others => '0');
            else
                if axi_arready = '0' and s_axi_arvalid = '1' then
                    axi_arready <= '1';
                    araddr_reg  <= s_axi_araddr;
                else
                    axi_arready <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Read data & valid logic
    process(s_axi_aclk)
        variable reg_idx : integer;
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_rvalid <= '0';
                axi_rdata  <= (others => '0');
            else
                if axi_arready = '1' and axi_rvalid = '0' then
                    axi_rvalid <= '1';
                    reg_idx    := to_integer(unsigned(araddr_reg(11 downto ADDR_LSB)));
                    axi_rdata  <= (others => '0');
                    
                    if reg_idx >= 0 and reg_idx < NUM_INPUT_REGS then
                        axi_rdata(GPIO_WIDTH-1 downto 0) <= inputs_i((reg_idx+1)*GPIO_WIDTH-1 downto reg_idx*GPIO_WIDTH);
                    elsif reg_idx >= NUM_INPUT_REGS and reg_idx < (NUM_INPUT_REGS + NUM_OUTPUT_REGS) then
                        axi_rdata(GPIO_WIDTH-1 downto 0) <= reg_outputs(reg_idx - NUM_INPUT_REGS);
                    end if;
                elsif s_axi_rready = '1' and axi_rvalid = '1' then
                    axi_rvalid <= '0';
                end if;
            end if;
        end if;
    end process;
end architecture behavioral;
