library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.bus_types_pkg.all;

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
    
    -- Custom FPGA Hardware Pins
    rgb_led_o           : out STD_LOGIC_VECTOR ( 2 downto 0 )
  );
end top;

architecture STRUCTURE of top is
  -- Internal signals to connect BD subsystem wrapper (system_wrapper) to custom IP (axi_pwm)
  signal pl_clk0         : std_logic;
  signal axil_m2s        : axil_m2s_t;
  signal axil_s2m        : axil_s2m_t;

  -- Vector signals matching BD 1-bit vector ports
  signal axi_arvalid_vec : std_logic_vector(0 to 0);
  signal axi_arready_vec : std_logic_vector(0 to 0);
  signal axi_awvalid_vec : std_logic_vector(0 to 0);
  signal axi_awready_vec : std_logic_vector(0 to 0);
  signal axi_wvalid_vec  : std_logic_vector(0 to 0);
  signal axi_wready_vec  : std_logic_vector(0 to 0);
  signal axi_bvalid_vec  : std_logic_vector(0 to 0);
  signal axi_bready_vec  : std_logic_vector(0 to 0);
  signal axi_rvalid_vec  : std_logic_vector(0 to 0);
  signal axi_rready_vec  : std_logic_vector(0 to 0);
begin
  -- Map BD AXI outputs to record structure
  axil_m2s.arvalid <= axi_arvalid_vec(0);
  axil_m2s.awvalid <= axi_awvalid_vec(0);
  axil_m2s.wvalid  <= axi_wvalid_vec(0);
  axil_m2s.bready  <= axi_bready_vec(0);
  axil_m2s.rready  <= axi_rready_vec(0);

  axi_arready_vec(0) <= axil_s2m.arready;
  axi_awready_vec(0) <= axil_s2m.awready;
  axi_wready_vec(0)  <= axil_s2m.wready;
  axi_bvalid_vec(0)  <= axil_s2m.bvalid;
  axi_rvalid_vec(0)  <= axil_s2m.rvalid;

  -- Instantiate Custom 3-Channel AXI PWM Controller
  inst_rgb_pwm : entity work.axi_pwm
    generic map (
      NUM_CHANNELS => 3,
      PWM_WIDTH    => 16
    )
    port map (
      s_axi_aclk    => pl_clk0,
      s_axi_aresetn => '1',
      s_axi_m2s     => axil_m2s,
      s_axi_s2m     => axil_s2m,
      pwm_o         => rgb_led_o
    );

  -- Instantiate Block Design Subsystem Wrapper
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

      -- Internal AXI bus connection
      M04_AXI_0_araddr    => axil_m2s.araddr,
      M04_AXI_0_arprot    => axil_m2s.arprot,
      M04_AXI_0_arready   => axi_arready_vec,
      M04_AXI_0_arvalid   => axi_arvalid_vec,
      M04_AXI_0_awaddr    => axil_m2s.awaddr,
      M04_AXI_0_awprot    => axil_m2s.awprot,
      M04_AXI_0_awready   => axi_awready_vec,
      M04_AXI_0_awvalid   => axi_awvalid_vec,
      M04_AXI_0_bready    => axi_bready_vec,
      M04_AXI_0_bresp     => axil_s2m.bresp,
      M04_AXI_0_bvalid    => axi_bvalid_vec,
      M04_AXI_0_rdata     => axil_s2m.rdata,
      M04_AXI_0_rready    => axi_rready_vec,
      M04_AXI_0_rresp     => axil_s2m.rresp,
      M04_AXI_0_rvalid    => axi_rvalid_vec,
      M04_AXI_0_wdata     => axil_m2s.wdata,
      M04_AXI_0_wready    => axi_wready_vec,
      M04_AXI_0_wstrb     => axil_m2s.wstrb,
      M04_AXI_0_wvalid    => axi_wvalid_vec,
      pl_clk0             => pl_clk0,

      btn                 => btn,
      hdmi_out_clk_n      => hdmi_out_clk_n,
      hdmi_out_clk_p      => hdmi_out_clk_p,
      hdmi_out_data_n     => hdmi_out_data_n,
      hdmi_out_data_p     => hdmi_out_data_p,
      hdmi_out_ddc_scl_io => hdmi_out_ddc_scl_io,
      hdmi_out_ddc_sda_io => hdmi_out_ddc_sda_io,
      led                 => led,
      sw                  => sw
    );
end STRUCTURE;
