----------------------------------------------------------------------------
--  Lab 3: Streaming Audio DSP
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Ava Rosenbaum
----------------------------------------------------------------------------
--	Description: I2S receiver for SSM2603 audio codec
----------------------------------------------------------------------------
-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
----------------------------------------------------------------------------
-- Entity definition
entity i2s_receiver is
    Generic (AC_DATA_WIDTH : integer := 24);
    Port (

        -- Timing
		mclk_i    : in std_logic;	
		bclk_i    : in std_logic;	
		lrclk_i   : in std_logic;
		
		-- Data
		left_audio_data_o     : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		right_audio_data_o    : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		adc_serial_data_i     : in std_logic);  
end i2s_receiver;
----------------------------------------------------------------------------
architecture Behavioral of i2s_receiver is
----------------------------------------------------------------------------
-- Define constants, signals, and declare sub-components
----------------------------------------------------------------------------
signal shift_en, left_save_en, right_save_en : std_logic := '0';
signal counter_tc, counter_reset : std_logic := '0';
-- ++++ Add additional signals needed for internal logic here ++++
----------------------------------------------------------------------------
-- FSM states
type state_type is (IdleState1, readLeft, IdleState2, ReadRight);	
signal curr_state, next_state : state_type := IdleState1;
signal shift_reg : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal left_audio_reg : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal right_audio_reg : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');

----------------------------------------------------------------------------
-- Component declarations
----------------------------------------------------------------------------
-- Counter
component counter is
    Generic ( MAX_COUNT : integer := 25);  -- set max to entity DATA_WIDTH+1
    Port (  clk_i       : in STD_LOGIC;			
            reset_i     : in STD_LOGIC;		
            enable_i    : in STD_LOGIC;				
            tc_o        : out STD_LOGIC);
end component;
----------------------------------------------------------------------------
begin

----------------------------------------------------------------------------
-- Component instantiations
----------------------------------------------------------------------------    
  
-- Counter instance
bit_counter : counter 
    port map (
        clk_i => bclk_i,
        reset_i => counter_reset,
        enable_i => '1',            -- always enabled
        tc_o => counter_tc);

----------------------------------------------------------------------------
-- State machine
----------------------------------------------------------------------------
-- FSM Next State Logic (asynchronous, no clock)
-- Include all state change triggering signals in the sensitivity list
-- The only signal getting assigned in this process should be next_state
	
next_state_logic : process(curr_state, lrclk_i, counter_tc)
-- ++++ Add necessary signals to the sensitivity list above ++++
-- ++++ Modify next state logic to match your paper design ++++
begin

	-- Default conditions
	next_state <= curr_state; 	-- default is to stay in the same state

	-- Use a case statement to switch between states
	case curr_state is	
	
		when IdleState1 =>
			if (lrclk_i = '0') then     -- wait until unbuffered lrclk goes low   
		        	next_state <= ReadLeft;
			end if;
				
		when ReadLeft =>
			if (counter_tc = '1') then		
				next_state <= IdleState2;
			end if;	
		when IdleState2 =>
			if (lrclk_i = '1') then		
				next_state <= ReadRight;
			end if;
		when ReadRight =>
			if (counter_tc = '1') then		
				next_state <= IdleState1;
			end if;
		when others => -- this is like the "else" part of an if/else statement, but shouldn't reached
			next_state <= IdleState1;
			
	end case;					-- end of case statement
end process next_state_logic;

----------------------------------------------------------------------------
-- FSM Output Logic Process (asynchronous, no clock)
-- Only the current state signal (curr_state) should be in the sensitivity list
-- FSM "outputs" are simply signals or ports that are assigned by the FSM state logic
fsm_output_logic : process(curr_state) 
begin
    right_save_en <= '0';
    left_save_en <= '0';
    counter_reset <= '0';
    shift_en <= '0';
    
    case curr_state is 
        when IdleState1 => 
	    		counter_reset <= '1';
			right_save_en <= '1';
	when ReadLeft => shift_en <= '1';
        when IdleState2 => 
			counter_reset <= '1';
			left_save_en <= '1';
        when ReadRight => shift_en <= '1';
        when others => counter_reset <= '0';
    end case;
end process fsm_output_logic;

----------------------------------------------------------------------------
-- FSM State Update Process (synchronous, clocked)
state_update : process (bclk_i)
begin
	if (rising_edge(bclk_i)) then
		curr_state <= next_state; 		-- update current state on rising edge of the clock
	end if;
end process state_update;


----------------------------------------------------------------------------
-- Shift Register Updates (synchronous, clocked)
shift_register : process (bclk_i)
begin
	if rising_edge(bclk_i) then
		if shift_en = '1' then
			shift_reg <= shift_reg(AC_DATA_WIDTH-2 downto 0) & adc_serial_data_i;
		end if;
		
		if left_save_en = '1' then
			left_audio_reg <= shift_reg;	
		end if;

		if right_save_en = '1' then
			right_audio_reg <= shift_reg;
		end if;
	end if;
end process shift_register;

left_audio_data_o <= left_audio_reg;
right_audio_data_o <= right_audio_reg;
		
---------------------------------------------------------------------------- 
end Behavioral;
