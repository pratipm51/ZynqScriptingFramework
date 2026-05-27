library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.bus_types_pkg.all;

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

        -- AXI-Lite Record Interface
        s_axi_m2s        : in  axil_m2s_t;
        s_axi_s2m        : out axil_s2m_t;

        -- Parallel GPIO ports (2D unconstrained arrays)
        inputs_i         : in  gpio_array_t(0 to NUM_INPUT_REGS-1)(GPIO_WIDTH-1 downto 0);
        outputs_o        : out gpio_array_t(0 to NUM_OUTPUT_REGS-1)(GPIO_WIDTH-1 downto 0)
    );
end entity axi_gpio;

architecture behavioral of axi_gpio is
    -- Address decoding constants
    constant ADDR_LSB : integer := 2; -- For 32-bit registers, bottom 2 bits are byte offset

    -- Internal registers arrays (same size as outputs port)
    signal reg_outputs : gpio_array_t(0 to NUM_OUTPUT_REGS-1)(GPIO_WIDTH-1 downto 0) := (others => (others => '0'));

    -- AXI internal state
    signal axi_awready : std_logic;
    signal axi_wready  : std_logic;
    signal axi_bvalid  : std_logic;
    signal axi_arready : std_logic;
    signal axi_rdata   : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
    signal axi_rvalid  : std_logic;

    signal awaddr_reg  : std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
    signal araddr_reg  : std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
begin
    -- Assign outputs to the subordinate-to-manager record
    s_axi_s2m.awready <= axi_awready;
    s_axi_s2m.wready  <= axi_wready;
    s_axi_s2m.bvalid  <= axi_bvalid;
    s_axi_s2m.bresp   <= "00"; -- OKAY response
    s_axi_s2m.arready <= axi_arready;
    s_axi_s2m.rdata   <= axi_rdata;
    s_axi_s2m.rresp   <= "00"; -- OKAY response
    s_axi_s2m.rvalid  <= axi_rvalid;

    -- Directly connect outputs port to registers
    outputs_o <= reg_outputs;

    -- Write address handshake and register address
    process(s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_awready <= '0';
                awaddr_reg <= (others => '0');
            else
                if axi_awready = '0' and s_axi_m2s.awvalid = '1' and s_axi_m2s.wvalid = '1' then
                    axi_awready <= '1';
                    awaddr_reg <= s_axi_m2s.awaddr;
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
                if axi_wready = '0' and s_axi_m2s.wvalid = '1' and s_axi_m2s.awvalid = '1' then
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
                if axi_awready = '1' and axi_wready = '1' then
                    reg_idx := to_integer(unsigned(awaddr_reg(AXI_ADDR_WIDTH-1 downto ADDR_LSB)));
                    -- Write only to output register offsets
                    if reg_idx >= NUM_INPUT_REGS and reg_idx < (NUM_INPUT_REGS + NUM_OUTPUT_REGS) then
                        for bit_idx in 0 to GPIO_WIDTH-1 loop
                            if s_axi_m2s.wstrb(bit_idx/8) = '1' then
                                reg_outputs(reg_idx - NUM_INPUT_REGS)(bit_idx) <= s_axi_m2s.wdata(bit_idx);
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
                elsif s_axi_m2s.bready = '1' and axi_bvalid = '1' then
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
                if axi_arready = '0' and s_axi_m2s.arvalid = '1' then
                    axi_arready <= '1';
                    araddr_reg  <= s_axi_m2s.araddr;
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
                if axi_arready = '1' and s_axi_m2s.arvalid = '1' and axi_rvalid = '0' then
                    axi_rvalid <= '1';
                    reg_idx := to_integer(unsigned(araddr_reg(AXI_ADDR_WIDTH-1 downto ADDR_LSB)));
                    
                    axi_rdata <= (others => '0'); -- Default return value
                    
                    if reg_idx >= 0 and reg_idx < NUM_INPUT_REGS then
                        axi_rdata(GPIO_WIDTH-1 downto 0) <= inputs_i(reg_idx);
                    elsif reg_idx >= NUM_INPUT_REGS and reg_idx < (NUM_INPUT_REGS + NUM_OUTPUT_REGS) then
                        axi_rdata(GPIO_WIDTH-1 downto 0) <= reg_outputs(reg_idx - NUM_INPUT_REGS);
                    end if;
                elsif s_axi_m2s.rready = '1' and axi_rvalid = '1' then
                    axi_rvalid <= '0';
                end if;
            end if;
        end if;
    end process;
end architecture behavioral;
