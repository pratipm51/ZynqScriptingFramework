library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gpio_types_pkg.all;

entity wishbone_gpio is
    generic (
        NUM_INPUT_REGS   : integer := 2;
        NUM_OUTPUT_REGS  : integer := 2;
        GPIO_WIDTH       : integer := 32;
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

        -- Parallel GPIO ports (2D unconstrained arrays)
        inputs_i         : in  gpio_array_t(0 to NUM_INPUT_REGS-1)(GPIO_WIDTH-1 downto 0);
        outputs_o        : out gpio_array_t(0 to NUM_OUTPUT_REGS-1)(GPIO_WIDTH-1 downto 0)
    );
end entity wishbone_gpio;

architecture behavioral of wishbone_gpio is
    -- Internal registers arrays (same size as outputs port)
    signal reg_outputs : gpio_array_t(0 to NUM_OUTPUT_REGS-1)(GPIO_WIDTH-1 downto 0) := (others => (others => '0'));

    signal ack_reg : std_logic := '0';
begin
    wb_ack_o <= ack_reg;

    -- Directly connect outputs port to registers
    outputs_o <= reg_outputs;

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
                            wb_dat_o(GPIO_WIDTH-1 downto 0) <= inputs_i(reg_idx);
                        elsif reg_idx >= NUM_INPUT_REGS and reg_idx < (NUM_INPUT_REGS + NUM_OUTPUT_REGS) then
                            wb_dat_o(GPIO_WIDTH-1 downto 0) <= reg_outputs(reg_idx - NUM_INPUT_REGS);
                        end if;
                    -- Write operation
                    else
                        if reg_idx >= NUM_INPUT_REGS and reg_idx < (NUM_INPUT_REGS + NUM_OUTPUT_REGS) then
                            for bit_idx in 0 to GPIO_WIDTH-1 loop
                                if wb_sel_i(bit_idx/8) = '1' then
                                    reg_outputs(reg_idx - NUM_INPUT_REGS)(bit_idx) <= wb_dat_i(bit_idx);
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
