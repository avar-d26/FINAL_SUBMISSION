----------------------------------------------------------------------------
--  Lab 3: Streaming Audio DSP
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Ava Rosenbaum
----------------------------------------------------------------------------
--	Description: AXI stream transmitter interface
----------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity axis_transmitter_interface is
Generic (
    FIFO_DEPTH : integer := 1024;
    I2S_DATA_WIDTH : integer := 24;
    DATA_WIDTH : integer := 32);
Port ( 
    -- I2S receiver signals
    left_audio_data_i : in std_logic_vector(I2S_DATA_WIDTH-1 downto 0);
    right_audio_data_i : in std_logic_vector(I2S_DATA_WIDTH-1 downto 0);
    lrclk_i       : in std_logic;
    
    -- Ports of Axi Controller Bus Interface M00_AXIS inputs
    m00_axis_aclk_i     : in std_logic;
    m00_axis_aresetn_i     : in std_logic;
    m00_axis_tready_i     : in std_logic;
    
    -- Ports of Axi Controller Bus Interface M00_AXISouputs
    m00_axis_tdata_o    : out std_logic_vector(DATA_WIDTH-1 downto 0);
    m00_axis_tlast_o    : out std_logic;
    m00_axis_tsrb_o    : out std_logic_vector(3 downto 0);
    m00_axis_tvalid_o    : out std_logic);   
end axis_transmitter_interface;

architecture Behavioral of axis_transmitter_interface is

-- FSM states
type state_type is (IdleState1, SampleLeft, IdleState2, SampleRight);	
signal curr_state, next_state : state_type := IdleState1;
signal sample_right, sample_left : std_logic := '0';
signal lad1, left_audio_data_sync, rad1, right_audio_data_sync : std_logic_vector(I2S_DATA_WIDTH-1 downto 0) := (others => '0');
signal lrc, lrclk_sync : std_logic := '0';

begin

----------------------------------------------------------------------------
-- DOUBLE FLOPPER
----------------------------------------------------------------------------
big_floppa : process(m00_axis_aclk_i) begin
if rising_edge(m00_axis_aclk_i) then
    lad1 <= left_audio_data_i;
    left_audio_data_sync <= lad1;
    
    rad1 <= right_audio_data_i;
    right_audio_data_sync <= rad1;
    
    lrc <= lrclk_i;
    lrclk_sync <= lrc;
end if;
end process;



-- State machine
----------------------------------------------------------------------------
-- FSM Next State Logic (asynchronous, no clock)
-- Include all state change triggering signals in the sensitivity list
-- The only signal getting assigned in this process should be next_state
	
next_state_logic : process(curr_state, lrclk_sync)
-- ++++ Add necessary signals to the sensitivity list above ++++
-- ++++ Modify next state logic to match your paper design ++++
begin

	-- Default conditions
	next_state <= curr_state; 	-- default is to stay in the same state

	-- Use a case statement to switch between states
	case curr_state is	
	
		when IdleState1 =>
			if (lrclk_sync = '0') then     -- wait until unbuffered lrclk goes low   
		        	next_state <= SampleLeft;
			end if;
	
		when SampleLeft =>
	
			next_state <= IdleState2;
		when IdleState2 =>
			if (lrclk_sync = '1') then		
				next_state <= SampleRight;
			end if;
		when SampleRight =>
			next_state <= IdleState1;
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
    m00_axis_tvalid_o <= '0';
    sample_right <= '0';
    sample_left <= '0';
    
    case curr_state is 
        when IdleState1 => 
m00_axis_tvalid_o <= '0';
	    when SampleLeft => 
	       m00_axis_tvalid_o <= '1';
	       sample_right <= '1';
        when IdleState2 => 
m00_axis_tvalid_o <= '0';
        when SampleRight => 
            m00_axis_tvalid_o <= '1';
            sample_left <= '1';
        when others => m00_axis_tvalid_o <= '0';
    end case;
end process fsm_output_logic;

----------------------------------------------------------------------------
-- FSM State Update Process (synchronous, clocked)
state_update : process (m00_axis_aclk_i)
begin
	if (rising_edge(m00_axis_aclk_i)) then
		curr_state <= next_state; 		-- update current state on rising edge of the clock
	end if;
end process state_update;

-- update 32 bit output
m00_data_update : process (m00_axis_aclk_i)
begin 
    if (rising_edge(m00_axis_aclk_i)) then
        if sample_left = '1' then
            m00_axis_tdata_o <= '1' & left_audio_data_sync & "0000000"; -- MSB = 1 means sending left
        elsif sample_right = '1' then
            m00_axis_tdata_o <= '0' & right_audio_data_sync & "0000000"; -- MSB = 0 means sending right
        end if;
    end if;
end process m00_data_update; 
end Behavioral;
