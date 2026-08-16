----------------------------------------------------------------------------------
-- Master Top-Level Entity: top (Workflow A: Block Design Integration)
-- 1-to-1 Passthrough wrapper instantiating system_wrapper
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top is
  port (
    DDR_addr            : inout STD_LOGIC_VECTOR ( 14 downto 0 );
    DDR_ba              : inout STD_LOGIC_VECTOR ( 2 downto 0 );
    DDR_cas_n           : inout STD_LOGIC;
    DDR_ck_n            : inout STD_LOGIC;
    DDR_ck_p            : inout STD_LOGIC;
    DDR_cke             : inout STD_LOGIC;
    DDR_cs_n            : inout STD_LOGIC;
    DDR_dm              : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    DDR_dq              : inout STD_LOGIC_VECTOR ( 31 downto 0 );
    DDR_dqs_n           : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    DDR_dqs_p           : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    DDR_odt             : inout STD_LOGIC;
    DDR_ras_n           : inout STD_LOGIC;
    DDR_reset_n         : inout STD_LOGIC;
    DDR_we_n            : inout STD_LOGIC;
    FIXED_IO_ddr_vrn    : inout STD_LOGIC;
    FIXED_IO_ddr_vrp    : inout STD_LOGIC;
    FIXED_IO_mio        : inout STD_LOGIC_VECTOR ( 53 downto 0 );
    FIXED_IO_ps_clk     : inout STD_LOGIC;
    FIXED_IO_ps_porb    : inout STD_LOGIC;
    FIXED_IO_ps_srstb   : inout STD_LOGIC;
    btn                 : in STD_LOGIC_VECTOR ( 3 downto 0 );
    hdmi_out_clk_n      : out STD_LOGIC;
    hdmi_out_clk_p      : out STD_LOGIC;
    hdmi_out_data_n     : out STD_LOGIC_VECTOR ( 2 downto 0 );
    hdmi_out_data_p     : out STD_LOGIC_VECTOR ( 2 downto 0 );
    hdmi_out_ddc_scl_io : inout STD_LOGIC;
    hdmi_out_ddc_sda_io : inout STD_LOGIC;
    led                 : out STD_LOGIC_VECTOR ( 3 downto 0 );
    sw                  : in STD_LOGIC_VECTOR ( 3 downto 0 );
    rgb_led_o           : out STD_LOGIC_VECTOR ( 2 downto 0 )
  );
end top;

architecture STRUCTURE of top is
begin
  -- Instantiate Block Design Subsystem Wrapper (system_wrapper)
  system_i : entity work.system_wrapper
    port map (
      DDR_addr            => DDR_addr,
      DDR_ba              => DDR_ba,
      DDR_cas_n           => DDR_cas_n,
      DDR_ck_n            => DDR_ck_n,
      DDR_ck_p            => DDR_ck_p,
      DDR_cke             => DDR_cke,
      DDR_cs_n            => DDR_cs_n,
      DDR_dm              => DDR_dm,
      DDR_dq              => DDR_dq,
      DDR_dqs_n           => DDR_dqs_n,
      DDR_dqs_p           => DDR_dqs_p,
      DDR_odt             => DDR_odt,
      DDR_ras_n           => DDR_ras_n,
      DDR_reset_n         => DDR_reset_n,
      DDR_we_n            => DDR_we_n,
      FIXED_IO_ddr_vrn    => FIXED_IO_ddr_vrn,
      FIXED_IO_ddr_vrp    => FIXED_IO_ddr_vrp,
      FIXED_IO_mio        => FIXED_IO_mio,
      FIXED_IO_ps_clk     => FIXED_IO_ps_clk,
      FIXED_IO_ps_porb    => FIXED_IO_ps_porb,
      FIXED_IO_ps_srstb   => FIXED_IO_ps_srstb,
      btn                 => btn,
      hdmi_out_clk_n      => hdmi_out_clk_n,
      hdmi_out_clk_p      => hdmi_out_clk_p,
      hdmi_out_data_n     => hdmi_out_data_n,
      hdmi_out_data_p     => hdmi_out_data_p,
      hdmi_out_ddc_scl_io => hdmi_out_ddc_scl_io,
      hdmi_out_ddc_sda_io => hdmi_out_ddc_sda_io,
      led                 => led,
      sw                  => sw,
      rgb_led_o           => rgb_led_o
    );
end STRUCTURE;
