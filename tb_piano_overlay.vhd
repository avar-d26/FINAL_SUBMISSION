----------------------------------------------------------------------------
--  Lab 4: Video & Audio Streaming
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Ava Rosenbaum
----------------------------------------------------------------------------
--	Description: Testing Video Timing Controller --> piano_overlay logic
----------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity tb_piano_overlay is
end tb_piano_overlay;

architecture testbench of tb_piano_overlay is


----------------------------------------------------------------------------
-- Constants
constant DATA_WIDTH : integer := 24;        -- 24-bit video RGB data 
constant KEY_NUM : integer := 88;         -- number of keys on piano
constant COLUMN_WIDTH : integer := 14;       -- number of pixels in each key column
constant CLOCK_PERIOD   : time := 7.463ns;          -- 134 MHz clock


----------------------------------------------------------------------------
-- Signals
signal clk, resetn_en : std_logic := '0';
signal key_state_sig : std_logic_vector(KEY_NUM-1 downto 0); -- 88-bit piano key status of which keys are active 

-- Video Timing Signals
signal sof_state_sig, active_video_sig, hsync_sig, vsync_sig, vblank_sig, hblank_sig : std_logic := '0';
signal fsync_sig : std_logic_vector (0 downto 0) := (others => '0');


-- AXI Stream Signals
signal M_AXIS_TDATA, S_AXIS_TDATA : std_logic_vector(DATA_WIDTH-1 downto 0);
signal M_AXIS_TUSER, S_AXIS_TUSER : std_logic_vector(0 downto 0) := (others => '0');
signal M_AXIS_TVALID, S_AXIS_TVALID, S_AXIS_TREADY : std_logic := '0';
signal M_AXIS_TREADY : std_logic := '1';
signal M_AXIS_TLAST, S_AXIS_TLAST : std_logic := '0';

----------------------------------------------------------------------------
-- Component Declarations

-- piano overlay logic component
component piano_overlay is
  Generic (
    KEY_NUM : integer := 88;
    DATA_WIDTH : integer := 24;
    COLUMN_WIDTH : integer := 13);
  Port (
    resetn_i            : in  std_logic; -- active low reset
    
    --pixel_clk_i         : in std_logic;

    -- Video timing
    vid_io_in_active_video   : in  std_logic;
    vid_io_in_hblank         : in  std_logic;
    vid_io_in_hsync          : in  std_logic;
    vid_io_in_vblank         : in  std_logic;
    vid_io_in_vsync          : in  std_logic;
    vid_io_in_fsync          : in std_logic_vector (0 downto 0);

    -- Key frame input
    key_state_i      : in  std_logic_vector(KEY_NUM-1 downto 0);

    -- AXI-Stream video slave
    s_axis_aclk    : in std_logic;
    s_axis_tdata   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    s_axis_tvalid  : in  std_logic;
    s_axis_tuser   : in  std_logic_vector(0 downto 0);
    s_axis_tlast   : in  std_logic;
    s_axis_tready  : out std_logic;

    -- AXI-Stream video master
    m_axis_aclk    : in std_logic;
    m_axis_tdata   : out std_logic_vector(DATA_WIDTH-1 downto 0);
    m_axis_tvalid  : out std_logic;
    m_axis_tuser   : out std_logic_vector(0 downto 0);
    m_axis_tlast   : out std_logic;
    m_axis_tready  : in  std_logic;
    
    -- debug signals
    m_axis_tdata_dbg_o: out std_logic_vector(DATA_WIDTH-1 downto 0);
    m_axis_tvalid_dbg_o : out std_logic;
    s_axis_tready_dbg_o : out std_logic;
    output_en_dbg_o : out std_logic;
    incr_col_index_dgb_o : out std_logic
    );
end component;

-- Video Timing Controller IP
component v_tc_0 is
  port (
    clk : IN STD_LOGIC;
    clken : IN STD_LOGIC;
    gen_clken : IN STD_LOGIC;
    sof_state : IN STD_LOGIC;
    hsync_out : OUT STD_LOGIC;
    hblank_out : OUT STD_LOGIC;
    vsync_out : OUT STD_LOGIC;
    vblank_out : OUT STD_LOGIC;
    active_video_out : OUT STD_LOGIC;
    resetn : IN STD_LOGIC;
    fsync_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0)
  );
end component;

begin

----------------------------------------------------------------------------
-- Clock generation
clock_gen_process : process
begin
	clk <= '0';				    -- start low
	wait for CLOCK_PERIOD;	    -- wait for one CLOCK_PERIOD
	
	loop							-- toggle, wait half a clock period, and loop
	  clk <= not(clk);
	  wait for CLOCK_PERIOD/2;
	end loop;
end process clock_gen_process;

----------------------------------------------------------------------------
-- Component Instantiations
-- piano overlay logic
piano_overlay_dut: piano_overlay
  port map (
    resetn_i => resetn_en,

    -- Video timing
    vid_io_in_active_video => active_video_sig,
    vid_io_in_hblank => hblank_sig,
    vid_io_in_hsync => hsync_sig,
    vid_io_in_vblank => vblank_sig,
    vid_io_in_vsync => vsync_sig,
    
    
    vid_io_in_fsync => fsync_sig,

    -- Key frame input
    key_state_i => key_state_sig,

    -- AXI-Stream video slave
    s_axis_aclk => clk,
    s_axis_tdata => S_AXIS_TDATA,
    s_axis_tvalid => S_AXIS_TVALID,
    s_axis_tuser => S_AXIS_TUSER,
    s_axis_tlast => S_AXIS_TLAST,
    s_axis_tready => S_AXIS_TREADY,

    -- AXI-Stream video master
    m_axis_aclk => clk,
    m_axis_tdata => M_AXIS_TDATA,
    m_axis_tvalid  => M_AXIS_TVALID,
    m_axis_tuser => M_AXIS_TUSER,
    m_axis_tlast => M_AXIS_TLAST,
    m_axis_tready => M_AXIS_TREADY
  );

-- Video Timing Controller Signals
video_timing_controller: v_tc_0
  port map (
    clk => clk,
    clken => '1',
    gen_clken => '1',
    sof_state => sof_state_sig,
    hsync_out => hsync_sig,
    hblank_out => hblank_sig,
    vsync_out => vsync_sig,
    vblank_out => vblank_sig,
    active_video_out => active_video_sig,
    resetn => resetn_en,
    fsync_out => fsync_sig);


----------------------------------------------------------------------------
-- Test Sequence
stim_proc: process
begin
  -- Initialize
  resetn_en <= '0';
  wait for 50 ns;
  
  -- Release reset
  resetn_en <= '1';

  -- Simulate AXI Stream input to piano overlay (sending default RGB of all white)
  
  -- Set keys 0, 30-36, and 87 as pressed
  key_state_sig <= (others => '0');
  key_state_sig(0) <= '1';
  key_state_sig(36 downto 30) <= (others => '1');
  key_state_sig(87) <= '1';


  S_AXIS_TDATA <= x"FFFFFF";     -- White pixel (24-bit RGB)
  S_AXIS_TVALID <= '1';
  
  wait for 10 ms;
  
  -- Set keys 12-17, 70-75, and 87 as pressed
  key_state_sig <= (others => '0');
  key_state_sig(17 downto 12) <= (others => '1');
  key_state_sig(75 downto 70) <= (others => '1');
  key_state_sig(87) <= '1';
  wait;  -- Wait indefinitely
  
end process;

end testbench;
