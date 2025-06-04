----------------------------------------------------------------------------
--  Lab 3: Streaming Audio DSP
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Ava Rosenbaum
----------------------------------------------------------------------------
--	Description: I2S transmitter for SSM2603 audio codec
----------------------------------------------------------------------------
-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
----------------------------------------------------------------------------
-- Entity definition
entity i2s_transmitter is
    Generic (AC_DATA_WIDTH : integer := 24);
    Port (

        -- Timing
		mclk_i    : in std_logic;	
		bclk_i    : in std_logic;	
		lrclk_i   : in std_logic; -- use unbuffered version of lrclk
		
		-- Data
		left_audio_data_i     : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		right_audio_data_i    : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		dac_serial_data_o     : out std_logic);  
end i2s_transmitter;
----------------------------------------------------------------------------
architecture Behavioral of i2s_transmitter is
----------------------------------------------------------------------------
-- Define constants, signals, and declare sub-components
----------------------------------------------------------------------------

-- Signals to hook up to datapath components
signal right_load_en, left_load_en, shift_en : std_logic := '0';
signal counter_tc, counter_reset : std_logic := '0';

-- ++++ Add additional signals needed for internal logic here ++++
----------------------------------------------------------------------------
-- FSM states
type state_type is (IdleState1, LoadLeftRegister, ShiftLeftData, IdleState2, LoadRightRegister, ShiftRightData);	
signal curr_state, next_state : state_type := IdleState1;

----------------------------------------------------------------------------
-- Component declarations
----------------------------------------------------------------------------
-- Shift register
component shift_register is
    Generic ( DATA_WIDTH        : integer := AC_DATA_WIDTH);  -- tie to entity DATA_WIDTH
    Port (	clk_i               : in std_logic;
      		left_audio_data_i   : in std_logic_vector(DATA_WIDTH-1 downto 0);
      		right_audio_data_i  : in std_logic_vector(DATA_WIDTH-1 downto 0);
      		right_load_en_i     : in std_logic;
      		left_load_en_i      : in std_logic;
      		shift_en_i          : in std_logic;
      
      		dac_serial_data_o        : out std_logic);
end component;

----------------------------------------------------------------------------
-- Counter
component counter is
    Generic ( MAX_COUNT : integer := AC_DATA_WIDTH);  -- set max to entity DATA_WIDTH
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
-- ++++ Port map your shift register component ++++
shift_reg : shift_register
    port map (
            clk_i => bclk_i,
            left_audio_data_i => left_audio_data_i,
	        right_audio_data_i=> right_audio_data_i,
            right_load_en_i => right_load_en,
	        left_load_en_i => left_load_en,
            shift_en_i => shift_en,
        
            dac_serial_data_o => dac_serial_data_o);
        
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
			if (lrclk_i = '1') then     -- wait until unbuffered lrclk goes low   
		        	next_state <= LoadRightRegister;
			end if;

		when LoadRightRegister =>
			next_state <= ShiftRightData;     -- stay here for one clock cycle
					
		when ShiftRightData =>
			if (counter_tc = '1') then		
				next_state <= IdleState2;
			end if;
			
		when IdleState2 =>
		    if (lrclk_i = '0') then     -- wait until unbuffered lrclk goes low   
		        	next_state <= LoadLeftRegister;
			end if;
			
		when LoadLeftRegister =>
			next_state <= ShiftLeftData;     -- stay here for one clock cycle
					
		when ShiftLeftData =>
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
    right_load_en <= '0';
    left_load_en <= '0';
    counter_reset <= '0';
    shift_en <= '0';
    
    case curr_state is 
        when IdleState1 => counter_reset <= '1';
	    when LoadLeftRegister => counter_reset <= '1';
                                left_load_en <= '1';
        when ShiftLeftData => shift_en <= '1';
        when IdleState2 => counter_reset <= '1';
        when LoadRightRegister => counter_reset <= '1';
                                right_load_en <= '1';
        when ShiftRightData => shift_en <= '1';
        when others => counter_reset <= '1';
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
end Behavioral;
