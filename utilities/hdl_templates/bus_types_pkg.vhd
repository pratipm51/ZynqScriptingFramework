library ieee;
use ieee.std_logic_1164.all;

package bus_types_pkg is
    -- Unconstrained 2D array of std_logic_vectors (VHDL-2008 syntax)
    type gpio_array_t is array (natural range <>) of std_logic_vector;

    -- AXI-Lite Manager to Subordinate (Master to Slave) Channel Signals
    type axil_m2s_t is record
        awaddr  : std_logic_vector(31 downto 0);
        awprot  : std_logic_vector(2 downto 0);
        awvalid : std_logic;
        wdata   : std_logic_vector(31 downto 0);
        wstrb   : std_logic_vector(3 downto 0);
        wvalid  : std_logic;
        bready  : std_logic;
        araddr  : std_logic_vector(31 downto 0);
        arprot  : std_logic_vector(2 downto 0);
        arvalid : std_logic;
        rready  : std_logic;
    end record axil_m2s_t;

    -- AXI-Lite Subordinate to Manager (Slave to Master) Channel Signals
    type axil_s2m_t is record
        awready : std_logic;
        wready  : std_logic;
        bresp   : std_logic_vector(1 downto 0);
        bvalid  : std_logic;
        arready : std_logic;
        rdata   : std_logic_vector(31 downto 0);
        rresp   : std_logic_vector(1 downto 0);
        rvalid  : std_logic;
    end record axil_s2m_t;

    -- Arrays of AXI-Lite Records for N-Port Interconnect / Decoders
    type axil_m2s_array_t is array (natural range <>) of axil_m2s_t;
    type axil_s2m_array_t is array (natural range <>) of axil_s2m_t;

    -- Wishbone Classic Master to Slave Signals
    type wb_m2s_t is record
        adr : std_logic_vector(31 downto 0);
        dat : std_logic_vector(31 downto 0);
        we  : std_logic;
        sel : std_logic_vector(3 downto 0);
        stb : std_logic;
        cyc : std_logic;
    end record wb_m2s_t;

    -- Wishbone Classic Slave to Master Signals
    type wb_s2m_t is record
        dat : std_logic_vector(31 downto 0);
        ack : std_logic;
    end record wb_s2m_t;

    -- Arrays of Wishbone Records for N-Port Interconnect / Decoders
    type wb_m2s_array_t is array (natural range <>) of wb_m2s_t;
    type wb_s2m_array_t is array (natural range <>) of wb_s2m_t;

end package bus_types_pkg;
