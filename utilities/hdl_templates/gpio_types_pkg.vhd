library ieee;
use ieee.std_logic_1164.all;

package gpio_types_pkg is
    -- Unconstrained 2D array of std_logic_vectors (VHDL-2008 syntax)
    type gpio_array_t is array (natural range <>) of std_logic_vector;
end package gpio_types_pkg;
