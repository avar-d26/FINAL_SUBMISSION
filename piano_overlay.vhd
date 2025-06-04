----------------------------------------------------------------------------
--  Final Project: Video & Audio Streaming
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Ava Rosenbaum
----------------------------------------------------------------------------
--	Description: Active Key Piano Overlay Display
----------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity piano_overlay is
  Generic (
    KEY_NUM : integer := 88;
    DATA_WIDTH : integer := 24;
    COLUMN_WIDTH : integer := 6); -- for 7 pixel width
  Port (
    resetn_i            : in  std_logic; -- active low reset
    
    pixel_clk_i         : in std_logic; -- run on the pixel clock

    -- Video timing
    active_video_i   : in  std_logic;
    hblank_i         : in  std_logic;
    hsync_i          : in  std_logic;
    vblank_i         : in  std_logic;
    vsync_i          : in  std_logic;
    fsync_i          : in std_logic_vector (0 downto 0);

    -- Key frame input
    key_state_i      : in  std_logic_vector(KEY_NUM-1 downto 0);

    RGB_data_o   : out std_logic_vector(DATA_WIDTH-1 downto 0);
    
    -- debug signals);
    key_counter_tc_dbg_o : out std_logic;
    col_counter_tc_dbg_o : out std_logic;
    output_en_dbg_o : out std_logic;
    key_state_dbg_o : out std_logic_vector(KEY_NUM-1 downto 0);
    hsync_dbg_o : out std_logic;
    current_keys_dbg_o : out std_logic_vector(KEY_NUM-1 downto 0)
    );
end piano_overlay;
  
architecture Behavioral of piano_overlay is

  
-- Internal Signals
signal current_keys  : std_logic_vector(KEY_NUM - 1 downto 0);
signal horizontal_pos: integer := 0; -- horizontal position counter

signal column_index  : integer range 0 to KEY_NUM - 1;
signal key_length : unsigned(3 downto 0) := (others => '0');
signal key_counter_tc, key_count_en, col_counter_tc : std_logic := '0';
signal RGB_data_sig   :  std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
signal output_en, incr_col_index : std_logic := '0';
signal pianokey_1, key_state_sig : std_logic_vector(KEY_NUM - 1 downto 0) := (others => '0');


-- FSM signals
type statetype is (Idle, Blank1, ActiveRow, IncrKey, Blank2);
signal curr_state, next_state : statetype := Idle;

begin
-- double flopper
floppa : process(pixel_clk_i) begin
if rising_edge(pixel_clk_i) then
    pianokey_1 <= key_state_i;
    key_state_sig <= pianokey_1;
end if;
end process;

----------------------------------------------------------------------------
-- State machine
----------------------------------------------------------------------------
  
-- FSM Next State Logic (asynchronous, no clock)
-- Include all state change triggering signals in the sensitivity list
-- The only signal getting assigned in this process should be next_state
next_state_logic : process(curr_state, fsync_i, col_counter_tc, active_video_i, hsync_i, key_counter_tc)
-- ++++ Add necessary signals to the sensitivity list above ++++
-- ++++ Modify next state logic to match your paper design ++++
begin

	-- Default conditions
	next_state <= curr_state; 	-- default is to stay in the same state

	-- Use a case statement to switch between states
	case curr_state is	
        when Idle =>
            if (fsync_i = "1") then     -- wait until start of new frame
                next_state <= Blank1;
            end if;
        when Blank1 =>
            if (active_video_i = '1') then     -- wait until video is active
                next_state <= ActiveRow;
            end if;
        when ActiveRow =>    
            if (active_video_i = '0') then     -- if no more active video
                next_state <= Blank2;
            elsif (key_counter_tc = '1') then
                next_state <= IncrKey;
            end if;
        when IncrKey =>
            if (col_counter_tc = '1') then     -- if done displaying all 88 keys
                next_state <= Blank2;
            else next_state <= ActiveRow;
            end if;
        when Blank2 =>
            if (hsync_i = '0') then     -- wait until start of new frame (hsync is active low on the lab computers)
                next_state <= Blank1;
            end if; 
        when others => -- this is like the "else" part of an if/else statement, but shouldn't reached
            next_state <= Idle;
	end case;					-- end of case statement
end process next_state_logic;

----------------------------------------------------------------------------
-- FSM Output Logic Process (asynchronous, no clock)
-- Only the current state signal (curr_state) should be in the sensitivity list
-- FSM "outputs" are simply signals or ports that are assigned by the FSM state logic
fsm_output_logic : process(curr_state) 
begin

incr_col_index <= '0';
output_en <= '0';
key_count_en <= '0';

case curr_state is	
        when Idle => output_en <= '0';
        when Blank1 => output_en <= '0';
        when ActiveRow => output_en <= '1';
                          key_count_en <= '1';
        when IncrKey => incr_col_index <= '1';
                        output_en <= '1';
        when Blank2 => output_en <= '0';
        when others => output_en <= '0';
	end case;					-- end of case statement

end process fsm_output_logic;

----------------------------------------------------------------------------
-- FSM State Update Process (synchronous, clocked)
state_update : process (pixel_clk_i)
begin
	if (rising_edge(pixel_clk_i)) then
		curr_state <= next_state; 		-- update current state on rising edge of the clock
	end if;
end process state_update;


-- Latch key_state on vsync
current_keys_reg : process(pixel_clk_i)
begin
  if rising_edge(pixel_clk_i) then
    if resetn_i = '0' then
      current_keys <= (others => '0');
    elsif (fsync_i = "1") then
      current_keys <= key_state_sig;
    end if;
  end if;
end process current_keys_reg;

-- Column Index Counter
column_index_counter : process(pixel_clk_i)
begin
  if rising_edge(pixel_clk_i) then
    if resetn_i = '0' then
      column_index <= 0;   -- reset
    elsif incr_col_index = '1' then
      if col_counter_tc = '1' then
        column_index <= 0;
      else 
        column_index <= column_index + 1; -- increment
      end if;
    end if;
  end if;
end process column_index_counter;

-- Key Length Counter
key_length_counter : process(pixel_clk_i)
begin
  if rising_edge(pixel_clk_i) then
    if resetn_i = '0' then
      key_length <= (others => '0');   -- reset
    elsif key_counter_tc = '1' then
      key_length <= (others => '0');   -- set back to 0 after done counting
    elsif key_count_en = '1' then
      key_length <= key_length + 1; -- increment
    end if;
  end if;
end process key_length_counter;

key_counter_tc <='1' when key_length = COLUMN_WIDTH - 1 else '0';
col_counter_tc <='1' when column_index = KEY_NUM - 1 else '0';

-- Key Override Process to output red instead of default key color (black or white)
key_override : process (current_keys, column_index, output_en)
begin
  if output_en = '1' then
    if current_keys(column_index) = '1' then
      RGB_data_sig <= x"FF0000";  -- Pure red (R=255, G=0, B=0)
    else RGB_data_sig <= x"FFFFFF"; -- white as default
    end if;
  else RGB_data_sig <= x"FFFFFF"; -- white as default;
  end if;
end process key_override;


RGB_data_o <= RGB_data_sig;

-- debug signals
key_counter_tc_dbg_o <= key_counter_tc; 
col_counter_tc_dbg_o <= col_counter_tc;
output_en_dbg_o <= output_en;
key_state_dbg_o <= key_state_sig;
current_keys_dbg_o <= current_keys;
hsync_dbg_o <= hsync_i;

end Behavioral;
