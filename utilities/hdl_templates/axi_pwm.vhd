----------------------------------------------------------------------------------
-- Entity Name: axi_pwm
-- Description: Generic Parametric AXI-Lite Multi-Channel PWM Controller (VHDL-2008)
--              Designed for driving Tri-Color RGB LEDs, Motors, or Servos.
--
-- Features:
--   - Parametric number of PWM output channels (NUM_CHANNELS, default 3 for RGB)
--   - Configurable register bit-width (PWM_WIDTH, default 16 bits)
--   - AXI-Lite Record Interface (axil_m2s_t / axil_s2m_t) from bus_types_pkg
--   - Global Enable & Polarity Inversion Control
--   - Hardware Clock Prescaler (prescaler_reg) for adjustable PWM frequency
--   - Variable PWM Period (period_reg) for arbitrary resolution (8-bit, 10-bit, 16-bit, etc.)
--   - Individual Duty Cycle registers for each PWM channel
--
-- Register Map:
--   Offset 0x00 : Control Register (CTRL)
--                 Bit 0: Enable PWM Generator (1 = Enabled, 0 = Disabled)
--                 Bit 1: Invert Polarity (1 = Active Low, 0 = Active High)
--   Offset 0x04 : Prescaler Register (PRESCALER)
--                 Divides s_axi_aclk by (PRESCALER + 1)
--   Offset 0x08 : Period Register (PERIOD)
--                 PWM counter counts from 0 up to PERIOD (e.g., 255 for 8-bit, 65535 for 16-bit)
--   Offset 0x0C + i*4 : Duty Cycle Register for Channel i (DUTY_CHi)
--                 0x0C = Channel 0 Duty Cycle (e.g., Red)
--                 0x10 = Channel 1 Duty Cycle (e.g., Green)
--                 0x14 = Channel 2 Duty Cycle (e.g., Blue)
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.bus_types_pkg.all;

entity axi_pwm is
    generic (
        NUM_CHANNELS   : integer := 3;  -- Default 3 channels for RGB Tri-Color LED
        PWM_WIDTH      : integer := 16; -- Resolution of prescaler, period, and duty counters
        AXI_ADDR_WIDTH : integer := 32;
        AXI_DATA_WIDTH : integer := 32
    );
    port (
        -- Global clock and reset
        s_axi_aclk    : in  std_logic;
        s_axi_aresetn : in  std_logic;

        -- AXI-Lite Record Interface (from bus_types_pkg)
        s_axi_m2s     : in  axil_m2s_t;
        s_axi_s2m     : out axil_s2m_t;

        -- PWM Output Signals (Channel 0..NUM_CHANNELS-1)
        pwm_o         : out std_logic_vector(NUM_CHANNELS-1 downto 0)
    );
end entity axi_pwm;

architecture behavioral of axi_pwm is
    constant ADDR_LSB : integer := 2; -- 32-bit registers -> bottom 2 bits are byte offsets

    -- Array type for channel duty cycle registers
    type duty_array_t is array (0 to NUM_CHANNELS-1) of std_logic_vector(PWM_WIDTH-1 downto 0);

    -- Control registers
    signal reg_ctrl      : std_logic_vector(1 downto 0) := (others => '0'); -- Bit 0: Enable, Bit 1: Invert Polarity
    signal reg_prescaler : std_logic_vector(PWM_WIDTH-1 downto 0) := (others => '0');
    signal reg_period    : std_logic_vector(PWM_WIDTH-1 downto 0) := (others => '1'); -- Default to max resolution
    signal reg_duty      : duty_array_t := (others => (others => '0'));

    -- PWM generator internal state
    signal prescale_cnt  : unsigned(PWM_WIDTH-1 downto 0) := (others => '0');
    signal pwm_cnt       : unsigned(PWM_WIDTH-1 downto 0) := (others => '0');
    signal pwm_raw       : std_logic_vector(NUM_CHANNELS-1 downto 0) := (others => '0');

    -- AXI-Lite internal signals
    signal axi_awready   : std_logic;
    signal axi_wready    : std_logic;
    signal axi_bvalid    : std_logic;
    signal axi_arready   : std_logic;
    signal axi_rdata     : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
    signal axi_rvalid    : std_logic;

    signal awaddr_reg    : std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
    signal araddr_reg    : std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
begin

    ------------------------------------------------------------------------------
    -- AXI-Lite Signal Assignments
    ------------------------------------------------------------------------------
    s_axi_s2m.awready <= axi_awready;
    s_axi_s2m.wready  <= axi_wready;
    s_axi_s2m.bvalid  <= axi_bvalid;
    s_axi_s2m.bresp   <= "00"; -- OKAY
    s_axi_s2m.arready <= axi_arready;
    s_axi_s2m.rdata   <= axi_rdata;
    s_axi_s2m.rresp   <= "00"; -- OKAY
    s_axi_s2m.rvalid  <= axi_rvalid;

    ------------------------------------------------------------------------------
    -- AXI-Lite Write Address Handshake
    ------------------------------------------------------------------------------
    process(s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_awready <= '0';
                awaddr_reg  <= (others => '0');
            else
                if axi_awready = '0' and s_axi_m2s.awvalid = '1' and s_axi_m2s.wvalid = '1' then
                    axi_awready <= '1';
                    awaddr_reg  <= s_axi_m2s.awaddr;
                else
                    axi_awready <= '0';
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------------
    -- AXI-Lite Write Data Handshake
    ------------------------------------------------------------------------------
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

    ------------------------------------------------------------------------------
    -- AXI-Lite Register Write Transaction
    ------------------------------------------------------------------------------
    process(s_axi_aclk)
        variable reg_idx : integer;
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                reg_ctrl      <= (others => '0');
                reg_prescaler <= (others => '0');
                reg_period    <= (others => '1');
                reg_duty      <= (others => (others => '0'));
            else
                if axi_awready = '0' and axi_wready = '0' and s_axi_m2s.awvalid = '1' and s_axi_m2s.wvalid = '1' then
                    reg_idx := to_integer(unsigned(s_axi_m2s.awaddr(11 downto ADDR_LSB)));

                    case reg_idx is
                        when 0 => -- 0x00: CTRL
                            if s_axi_m2s.wstrb(0) = '1' then
                                reg_ctrl <= s_axi_m2s.wdata(1 downto 0);
                            end if;

                        when 1 => -- 0x04: PRESCALER
                            for b in 0 to (PWM_WIDTH-1)/8 loop
                                if s_axi_m2s.wstrb(b) = '1' then
                                    reg_prescaler((b+1)*8-1 downto b*8) <= s_axi_m2s.wdata((b+1)*8-1 downto b*8);
                                end if;
                            end loop;

                        when 2 => -- 0x08: PERIOD
                            for b in 0 to (PWM_WIDTH-1)/8 loop
                                if s_axi_m2s.wstrb(b) = '1' then
                                    reg_period((b+1)*8-1 downto b*8) <= s_axi_m2s.wdata((b+1)*8-1 downto b*8);
                                end if;
                            end loop;

                        when others => -- 0x0C + i*4: DUTY_CHi
                            if reg_idx >= 3 and reg_idx < (3 + NUM_CHANNELS) then
                                for b in 0 to (PWM_WIDTH-1)/8 loop
                                    if s_axi_m2s.wstrb(b) = '1' then
                                        reg_duty(reg_idx - 3)((b+1)*8-1 downto b*8) <= s_axi_m2s.wdata((b+1)*8-1 downto b*8);
                                    end if;
                                end loop;
                            end if;
                    end case;
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------------
    -- AXI-Lite Write Response Logic
    ------------------------------------------------------------------------------
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

    ------------------------------------------------------------------------------
    -- AXI-Lite Read Address Handshake
    ------------------------------------------------------------------------------
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

    ------------------------------------------------------------------------------
    -- AXI-Lite Read Data & Valid Logic
    ------------------------------------------------------------------------------
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
                    axi_rdata  <= (others => '0'); -- Default zero return

                    case reg_idx is
                        when 0 => -- 0x00: CTRL
                            axi_rdata(1 downto 0) <= reg_ctrl;

                        when 1 => -- 0x04: PRESCALER
                            axi_rdata(PWM_WIDTH-1 downto 0) <= reg_prescaler;

                        when 2 => -- 0x08: PERIOD
                            axi_rdata(PWM_WIDTH-1 downto 0) <= reg_period;

                        when others => -- 0x0C + i*4: DUTY_CHi
                            if reg_idx >= 3 and reg_idx < (3 + NUM_CHANNELS) then
                                axi_rdata(PWM_WIDTH-1 downto 0) <= reg_duty(reg_idx - 3);
                            end if;
                    end case;
                elsif s_axi_m2s.rready = '1' and axi_rvalid = '1' then
                    axi_rvalid <= '0';
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------------
    -- Hardware PWM Counter & Signal Generator Engine
    ------------------------------------------------------------------------------
    process(s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                prescale_cnt <= (others => '0');
                pwm_cnt      <= (others => '0');
                pwm_raw      <= (others => '0');
            else
                if reg_ctrl(0) = '1' then -- Enable = 1
                    -- Clock Prescaler Counter
                    if prescale_cnt >= unsigned(reg_prescaler) then
                        prescale_cnt <= (others => '0');

                        -- PWM Cycle Counter
                        if pwm_cnt >= unsigned(reg_period) then
                            pwm_cnt <= (others => '0');
                        else
                            pwm_cnt <= pwm_cnt + 1;
                        end if;
                    else
                        prescale_cnt <= prescale_cnt + 1;
                    end if;

                    -- PWM Output Channels Comparison
                    for i in 0 to NUM_CHANNELS-1 loop
                        if pwm_cnt < unsigned(reg_duty(i)) then
                            pwm_raw(i) <= '1';
                        else
                            pwm_raw(i) <= '0';
                        end if;
                    end loop;
                else
                    prescale_cnt <= (others => '0');
                    pwm_cnt      <= (others => '0');
                    pwm_raw      <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------------
    -- Output Polarity Inversion (Bit 1 of reg_ctrl)
    ------------------------------------------------------------------------------
    gen_outputs: for i in 0 to NUM_CHANNELS-1 generate
        pwm_o(i) <= not pwm_raw(i) when reg_ctrl(1) = '1' else pwm_raw(i);
    end generate gen_outputs;

end architecture behavioral;
