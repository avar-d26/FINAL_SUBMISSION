----------------------------------------------------------------------------
-- 	ENGS 128 Spring 2025
--	Author: Ava Rosenbaum & Brandon Zhao
----------------------------------------------------------------------------
--	Description: Shift register with parallel load and serial output for left and right audio inputs
----------------------------------------------------------------------------
-- Add libraries
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

----------------------------------------------------------------------------
-- Entity definition
entity shift_register is
    Generic ( DATA_WIDTH : integer := 16);
    Port ( 
      clk_i         : in std_logic;
      left_audio_data_i : in std_logic_vector(DATA_WIDTH-1 downto 0);
      right_audio_data_i : in std_logic_vector(DATA_WIDTH-1 downto 0);
      right_load_en_i     : in std_logic;
      left_load_en_i     : in std_logic;
      shift_en_i    : in std_logic;
      
      dac_serial_data_o        : out std_logic);
end shift_register;
----------------------------------------------------------------------------
architecture Behavioral of shift_register is
----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------
-- ++++ Add internal signals here ++++

signal shift_registerr : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------
-- ++++ Describe the behavior using processes ++++
----------------------------------------------------------------------------     
shift_reg_synch : process(clk_i)
begin

    if falling_edge (clk_i) then
        if left_load_en_i = '1' then
            shift_registerr <= left_audio_data_i;
        elsif right_load_en_i = '1' then 
            shift_registerr <= right_audio_data_i;
        elsif shift_en_i = '1' then
            shift_registerr <= shift_registerr(DATA_WIDTH-2 downto 0) & shift_registerr(DATA_WIDTH-1);
        end if;
    end if;

end process shift_reg_synch; 

dac_serial_data_o <= shift_registerr(DATA_WIDTH-1);


----------------------------------------------------------------------------   
end Behavioral;
