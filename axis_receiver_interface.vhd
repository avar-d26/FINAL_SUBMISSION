----------------------------------------------------------------------------
--  Lab 3: Streaming Audio DSP
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Brandon Zhao and Ava Rosenbaum
----------------------------------------------------------------------------
--	Description: AXI Stream Data Receiver
------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity axis_receiver_interface is
Generic (
    FIFO_DEPTH : integer := 1024;
    I2S_DATA_WIDTH : integer := 24;
    DATA_WIDTH : integer := 32);
Port ( 
    -- i2s LRCLK signal
    lrclk_i       : in std_logic;
    
    -- Ports of Axi Controller Bus Interface M00_AXIS
    s00_axis_aclk_i     : in std_logic;
    s00_axis_aresetn_i     : in std_logic;
    s00_axis_tdata_i    : in std_logic_vector(DATA_WIDTH-1 downto 0);
    s00_axis_tlast_i    : in std_logic;
    s00_axis_tsrb_i    : in std_logic_vector(3 downto 0);
    s00_axis_tvalid_i    : in std_logic;
    
    -- I2S transmitter signals
    left_audio_data_o : out std_logic_vector(I2S_DATA_WIDTH-1 downto 0);
    right_audio_data_o : out std_logic_vector(I2S_DATA_WIDTH-1 downto 0);
    left_audio_data_valid_o : out std_logic;
    right_audio_data_valid_o : out std_logic;
    s00_axis_tready_o : out std_logic);
end axis_receiver_interface;

architecture Behavioral of axis_receiver_interface is


type statetype is (IdleState1, Send1, Wait1, IdleState2, Send2, Wait2);
signal curr_state, next_state : statetype := IdleState1;
signal send_right, send_left : std_logic := '0';
signal lrclk_reg, lrclk_main : std_logic := '0';
signal s00_axis_tready_sig, left_audio_data_valid_sig, right_audio_data_valid_sig : std_logic := '0';

begin

-- DOUBLE FLOPPER
floppa: process(s00_axis_aclk_i) begin
    lrclk_reg <= lrclk_i;
    lrclk_main <= lrclk_reg;
end process;
----------------------------------------------------------------------------
-- State machine
----------------------------------------------------------------------------
-- FSM Next State Logic (asynchronous, no clock)
-- Include all state change triggering signals in the sensitivity list
-- The only signal getting assigned in this process should be next_state


next_state_logic : process(curr_state, lrclk_main)
-- ++++ Add necessary signals to the sensitivity list above ++++
-- ++++ Modify next state logic to match your paper design ++++
begin

	-- Default conditions
	next_state <= curr_state; 	-- default is to stay in the same state

	-- Use a case statement to switch between states
	case curr_state is	
	
        when IdleState1 =>
            if (lrclk_main = '0') then     -- wait until unbuffered lrclk goes low   
                next_state <= Send1;
            end if;
    
        when Send1 =>
            next_state <= Wait1;
        
        when Wait1 =>    
            next_state <= IdleState2; 
       
        when IdleState2 =>
            if (lrclk_main = '1') then		
                next_state <= Send2;
            end if;
            
        when Send2 =>
            next_state <= Wait2;
        
        when Wait2 =>    
            next_state <= IdleState1; 
            
        when others => -- this is like the "else" part of an if/else statement, but shouldn't reached
            next_state <= IdleState1;
	end case;					-- end of case statement
end process next_state_logic;

----------------------------------------------------------------------------
-- FSM Output Logic Process (asynchronous, no clock)
-- Only the current state signal (curr_state) should be in the sensitivity list
-- FSM "outputs" are simply signals or ports that are assigned by the FSM state logic
fsm_output_logic : process(curr_state, s00_axis_tdata_i) 
begin

send_right <= '0';
send_left <= '0';
s00_axis_tready_sig <= '0';

    case curr_state is 
        when IdleState1 => 
            
        when Send1 => 
        
            if (s00_axis_tdata_i(DATA_WIDTH - 1) = '1') then
                send_left <= '1';
            else
                send_right <= '1';
            end if;   
        
        when Wait1 => 
            s00_axis_tready_sig <= '1';
        
        when IdleState2 => 
            
        when Send2 => 
        
            if (s00_axis_tdata_i(DATA_WIDTH - 1) = '1') then
                send_left <= '1';
            else
                send_right <= '1';
            end if;      
        when Wait2 => 
            s00_axis_tready_sig <= '1';    
        when others => 
        
    end case;


end process fsm_output_logic;

----------------------------------------------------------------------------
-- FSM State Update Process (synchronous, clocked)
state_update : process (s00_axis_aclk_i)
begin
	if (rising_edge(s00_axis_aclk_i)) then
		curr_state <= next_state; 		-- update current state on rising edge of the clock
	end if;
end process state_update;

-- update 24 bit output
s00_data_update : process (s00_axis_aclk_i)
begin 
    if (rising_edge(s00_axis_aclk_i)) then
        if send_left = '1' then
            left_audio_data_o <= s00_axis_tdata_i(I2S_DATA_WIDTH + 6 downto 7); -- 30 downto 7
        elsif send_right = '1' then
            right_audio_data_o <= s00_axis_tdata_i(I2S_DATA_WIDTH + 6 downto 7); -- 30 downto 7
        end if;

    end if;
end process s00_data_update; 

-- update tvalid and treadys
valid_tready_updates : process (send_left, send_right)
begin 
    left_audio_data_valid_sig <= '0';
    right_audio_data_valid_sig <= '0';
    
    if send_left = '1' then
        left_audio_data_valid_sig <= '1';
    elsif send_right = '1' then
        right_audio_data_valid_sig <= '1';
    end if;

end process valid_tready_updates; 

-- register for tready and tvalids
tready_tvalid_regs : process (s00_axis_aclk_i)
begin 
    if (rising_edge(s00_axis_aclk_i)) then
        s00_axis_tready_o <= s00_axis_tready_sig;
        right_audio_data_valid_o <= right_audio_data_valid_sig; 
        left_audio_data_valid_o <= left_audio_data_valid_sig;
    end if;
end process tready_tvalid_regs; 

end Behavioral;
