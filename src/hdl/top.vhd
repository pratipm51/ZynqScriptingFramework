library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
    Port ( 
        -- Zynq Fixed Ports
        DDR_addr : inout STD_LOGIC_VECTOR ( 14 downto 0 );
        DDR_ba : inout STD_LOGIC_VECTOR ( 2 downto 0 );
        DDR_cas_n : inout STD_LOGIC;
        DDR_ck_n : inout STD_LOGIC;
        DDR_ck_p : inout STD_LOGIC;
        DDR_cke : inout STD_LOGIC;
        DDR_cs_n : inout STD_LOGIC;
        DDR_dm : inout STD_LOGIC_VECTOR ( 1 downto 0 );
        DDR_dq : inout STD_LOGIC_VECTOR ( 15 downto 0 );
        DDR_dqs_n : inout STD_LOGIC_VECTOR ( 1 downto 0 );
        DDR_dqs_p : inout STD_LOGIC_VECTOR ( 1 downto 0 );
        DDR_odt : inout STD_LOGIC;
        DDR_ras_n : inout STD_LOGIC;
        DDR_reset_n : inout STD_LOGIC;
        DDR_we_n : inout STD_LOGIC;
        FIXED_IO_ddr_vrn : inout STD_LOGIC;
        FIXED_IO_ddr_vrp : inout STD_LOGIC;
        FIXED_IO_mio : inout STD_LOGIC_VECTOR ( 31 downto 0 );
        FIXED_IO_ps_clk : inout STD_LOGIC;
        FIXED_IO_ps_porb : inout STD_LOGIC;
        FIXED_IO_ps_srstb : inout STD_LOGIC;
        
        -- GPIO and Other Ports from BD
        GPIO_0_0_tri_io : inout STD_LOGIC_VECTOR ( 7 downto 0 );
        enet0_phy_clk : out STD_LOGIC;

        -- Custom PL Ports
        led : out STD_LOGIC
    );
end top;

architecture Behavioral of top is
    component system_wrapper is
        port (
            DDR_addr : inout STD_LOGIC_VECTOR ( 14 downto 0 );
            DDR_ba : inout STD_LOGIC_VECTOR ( 2 downto 0 );
            DDR_cas_n : inout STD_LOGIC;
            DDR_ck_n : inout STD_LOGIC;
            DDR_ck_p : inout STD_LOGIC;
            DDR_cke : inout STD_LOGIC;
            DDR_cs_n : inout STD_LOGIC;
            DDR_dm : inout STD_LOGIC_VECTOR ( 1 downto 0 );
            DDR_dq : inout STD_LOGIC_VECTOR ( 15 downto 0 );
            DDR_dqs_n : inout STD_LOGIC_VECTOR ( 1 downto 0 );
            DDR_dqs_p : inout STD_LOGIC_VECTOR ( 1 downto 0 );
            DDR_odt : inout STD_LOGIC;
            DDR_ras_n : inout STD_LOGIC;
            DDR_reset_n : inout STD_LOGIC;
            DDR_we_n : inout STD_LOGIC;
            FIXED_IO_ddr_vrn : inout STD_LOGIC;
            FIXED_IO_ddr_vrp : inout STD_LOGIC;
            FIXED_IO_mio : inout STD_LOGIC_VECTOR ( 31 downto 0 );
            FIXED_IO_ps_clk : inout STD_LOGIC;
            FIXED_IO_ps_porb : inout STD_LOGIC;
            FIXED_IO_ps_srstb : inout STD_LOGIC;
            GPIO_0_0_tri_io : inout STD_LOGIC_VECTOR ( 7 downto 0 );
            enet0_phy_clk : out STD_LOGIC
        );
    end component;

    signal counter : unsigned(24 downto 0) := (others => '0');
    signal fclk_internal : std_logic;

begin
    -- Instantiate Zynq System
    sys_i: system_wrapper
        port map (
            DDR_addr => DDR_addr,
            DDR_ba => DDR_ba,
            DDR_cas_n => DDR_cas_n,
            DDR_ck_n => DDR_ck_n,
            DDR_ck_p => DDR_ck_p,
            DDR_cke => DDR_cke,
            DDR_cs_n => DDR_cs_n,
            DDR_dm => DDR_dm,
            DDR_dq => DDR_dq,
            DDR_dqs_n => DDR_dqs_n,
            DDR_dqs_p => DDR_dqs_p,
            DDR_odt => DDR_odt,
            DDR_ras_n => DDR_ras_n,
            DDR_reset_n => DDR_reset_n,
            DDR_we_n => DDR_we_n,
            FIXED_IO_ddr_vrn => FIXED_IO_ddr_vrn,
            FIXED_IO_ddr_vrp => FIXED_IO_ddr_vrp,
            FIXED_IO_mio => FIXED_IO_mio,
            FIXED_IO_ps_clk => FIXED_IO_ps_clk,
            FIXED_IO_ps_porb => FIXED_IO_ps_porb,
            FIXED_IO_ps_srstb => FIXED_IO_ps_srstb,
            GPIO_0_0_tri_io => GPIO_0_0_tri_io,
            enet0_phy_clk => fclk_internal -- Clock from PS (FCLK_CLK1, ~25MHz)
        );

    -- Drive external port to satisfy top-level entity
    enet0_phy_clk <= fclk_internal;

    -- Blinker Logic
    process(fclk_internal)
    begin
        if rising_edge(fclk_internal) then
            counter <= counter + 1;
        end if;
    end process;

    -- EBAZ LEDs are active-low. Toggle at ~0.75Hz if clk is 25MHz.
    led <= not std_logic(counter(24));
end Behavioral;
