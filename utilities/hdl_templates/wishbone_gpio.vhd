library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wishbone_gpio is
    generic (
        NUM_INPUT_REGS   : integer := 2;
        NUM_OUTPUT_REGS  : integer := 2;
        REG_WIDTH        : integer := 32;
        WB_ADDR_WIDTH    : integer := 32;
        WB_DATA_WIDTH    : integer := 32
    );
    port (
        -- Wishbone Clock and Reset
        wb_clk_i         : in  std_logic;
        wb_rst_i         : in  std_logic;

        -- Wishbone Slave Port
        wb_adr_i         : in  std_logic_vector(WB_ADDR_WIDTH-1 downto 0);
        wb_dat_i         : in  std_logic_vector(WB_DATA_WIDTH-1 downto 0);
        wb_dat_o         : out std_logic_vector(WB_DATA_WIDTH-1 downto 0);
        wb_we_i          : in  std_logic;
        wb_sel_i         : in  std_logic_vector((WB_DATA_WIDTH/8)-1 downto 0);
        wb_stb_i         : in  std_logic;
        wb_cyc_i         : in  std_logic;
        wb_ack_o         : out std_logic;

        -- Parallel GPIO ports (flattened 1D arrays)
        inputs_i         : in  std_logic_vector(NUM_INPUT_REGS * REG_WIDTH - 1 downto 0);
        outputs_o        : out std_logic_vector(NUM_OUTPUT_REGS * REG_WIDTH - 1 downto 0)
    );
end entity wishbone_gpio;

architecture behavioral of wishbone_gpio is
    -- Internal register arrays
    type outputs_array_t is array (0 to NUM_OUTPUT_REGS-1) of std_logic_vector(REG_WIDTH-1 downto 0);
    signal reg_outputs : outputs_array_t := (others => (others => '0'));

    type inputs_array_t is array (0 to NUM_INPUT_REGS-1) of std_logic_vector(REG_WIDTH-1 downto 0);
    signal reg_inputs : inputs_array_t;

    signal ack_reg : std_logic := '0';
begin
    wb_ack_o <= ack_reg;

    -- Map flattened inputs to array
    gen_inputs: for i in 0 to NUM_INPUT_REGS-1 generate
        reg_inputs(i) <= inputs_i((i+1)*REG_WIDTH - 1 downto i*REG_WIDTH);
    end generate gen_inputs;

    -- Map array outputs to flattened vector
    gen_outputs: for i in 0 to NUM_OUTPUT_REGS-1 generate
        outputs_o((i+1)*REG_WIDTH - 1 downto i*REG_WIDTH) <= reg_outputs(i);
    end generate gen_outputs;

    -- Wishbone write/read transactions and ACK logic
    process(wb_clk_i)
        variable reg_idx : integer;
    begin
        if rising_edge(wb_clk_i) then
            if wb_rst_i = '1' then
                reg_outputs <= (others => (others => '0'));
                ack_reg     <= '0';
                wb_dat_o    <= (others => '0');
            else
                -- Generate single-cycle registered ACK
                if wb_cyc_i = '1' and wb_stb_i = '1' and ack_reg = '0' then
                    ack_reg <= '1';
                    reg_idx := to_integer(unsigned(wb_adr_i));
                    
                    -- Read operation
                    if wb_we_i = '0' then
                        wb_dat_o <= (others => '0');
                        if reg_idx >= 0 and reg_idx < NUM_INPUT_REGS then
                            wb_dat_o(REG_WIDTH-1 downto 0) <= reg_inputs(reg_idx);
                        elsif reg_idx >= NUM_INPUT_REGS and reg_idx < (NUM_INPUT_REGS + NUM_OUTPUT_REGS) then
                            wb_dat_o(REG_WIDTH-1 downto 0) <= reg_outputs(reg_idx - NUM_INPUT_REGS);
                        end if;
                    -- Write operation
                    else
                        if reg_idx >= NUM_INPUT_REGS and reg_idx < (NUM_INPUT_REGS + NUM_OUTPUT_REGS) then
                            for byte_idx in 0 to (REG_WIDTH/8)-1 loop
                                if wb_sel_i(byte_idx) = '1' then
                                    reg_outputs(reg_idx - NUM_INPUT_REGS)((byte_idx+1)*8 - 1 downto byte_idx*8) <= 
                                        wb_dat_i((byte_idx+1)*8 - 1 downto byte_idx*8);
                                end if;
                            end loop;
                        end if;
                    end if;
                else
                    ack_reg <= '0';
                end if;
            end if;
        end if;
    end process;
end architecture behavioral;
