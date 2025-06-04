----------------------------------------------------------------------------
--  Lab 2: AXI Stream FIFO and DMA
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Kendall Farnham
----------------------------------------------------------------------------
--	Description: Testbench for AXI stream interface of I2S controller
----------------------------------------------------------------------------
-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;

----------------------------------------------------------------------------
-- Entity Declaration
entity tb_axis_i2s_wrapper is
end tb_axis_i2s_wrapper;

----------------------------------------------------------------------------
architecture testbench of tb_axis_i2s_wrapper is
----------------------------------------------------------------------------
-- Constants
constant AXIS_DATA_WIDTH : integer := 32;        -- AXI stream data bus
constant CLOCK_PERIOD : time := 8ns;            -- 125 MHz system clock period
constant MCLK_PERIOD : time := 81.38 ns;        -- 12.288 MHz MCLK
constant SAMPLING_FREQ  : real := 48000.00;     -- 48 kHz sampling rate
constant T_SAMPLE : real := 1.0/SAMPLING_FREQ;

-- Input waveform
constant AUDIO_DATA_WIDTH : integer := 24;
constant SINE_FREQ : real := 1000.0;
constant SINE_AMPL  : real := real(2**(AUDIO_DATA_WIDTH-1)-1);

----------------------------------------------------------------------------
-- Signals to hook up to DUT
signal clk : std_logic := '0';
signal mute_en_sw : std_logic;
signal mute_n, bclk, mclk, data_in, data_out, lrclk : std_logic;

----------------------------------------------------------------------------
-- Testbench signals
signal bit_count : integer;
signal sine_data, sine_data_tx : std_logic_vector(AUDIO_DATA_WIDTH-1 downto 0) := (others => '0');
signal reset_n : std_logic := '1';
signal enable_stream : std_logic := '0';
signal test_num : integer := 0;


-- AXI Stream
signal M_AXIS_TDATA, S_AXIS_TDATA : std_logic_vector(AXIS_DATA_WIDTH-1 downto 0);
signal M_AXIS_TSTRB, S_AXIS_TSTRB : std_logic_vector((AXIS_DATA_WIDTH/8)-1 downto 0);
signal M_AXIS_TVALID, S_AXIS_TVALID : std_logic := '0';
signal M_AXIS_TREADY, S_AXIS_TREADY : std_logic := '0';
signal M_AXIS_TLAST, S_AXIS_TLAST : std_logic := '0';

----------------------------------------------------------------------------
-- AXI stream component
component axis_i2s_wrapper is
	generic (
		-- Parameters of Axi Stream Bus Interface S00_AXIS, M00_AXIS
		C_AXI_STREAM_DATA_WIDTH	: integer	:= 32;
		AC_DATA_WIDTH : integer := 24
	);
    Port ( 
        ----------------------------------------------------------------------------
        -- Fabric clock from Zynq PS
		sysclk_i : in  std_logic;	
		
        ----------------------------------------------------------------------------
        -- I2S audio codec ports		
	-- User controls
	ac_mute_en_i : in STD_LOGIC;
		
	-- Audio Codec I2S controls
        ac_bclk_o : out STD_LOGIC;
        ac_mclk_o : out STD_LOGIC;
        ac_mute_n_o : out STD_LOGIC;	-- Active Low
        
        -- Audio Codec DAC (audio out)
        ac_dac_data_o : out STD_LOGIC;
        ac_dac_lrclk_o : out STD_LOGIC;
        
        -- Audio Codec ADC (audio in)
        ac_adc_data_i : in STD_LOGIC;
        ac_adc_lrclk_o : out STD_LOGIC;
        
        ----------------------------------------------------------------------------
        -- AXI Stream Interface (Receiver/Responder)
    	-- Ports of Axi Responder Bus Interface S00_AXIS
		s00_axis_aclk     : in std_logic;
		s00_axis_aresetn  : in std_logic;
		s00_axis_tready   : out std_logic;
		s00_axis_tdata	  : in std_logic_vector(C_AXI_STREAM_DATA_WIDTH-1 downto 0);
		s00_axis_tstrb    : in std_logic_vector((C_AXI_STREAM_DATA_WIDTH/8)-1 downto 0);
		s00_axis_tlast    : in std_logic;
		s00_axis_tvalid   : in std_logic;
		
        -- AXI Stream Interface (Tranmitter/Controller)
		-- Ports of Axi Controller Bus Interface M00_AXIS
		m00_axis_aclk     : in std_logic;
		m00_axis_aresetn  : in std_logic;
		m00_axis_tvalid   : out std_logic;
		m00_axis_tdata    : out std_logic_vector(C_AXI_STREAM_DATA_WIDTH-1 downto 0);
		m00_axis_tstrb    : out std_logic_vector((C_AXI_STREAM_DATA_WIDTH/8)-1 downto 0);
		m00_axis_tlast    : out std_logic;
		m00_axis_tready   : in std_logic);
end component;


----------------------------------------------------------------------------------
begin
----------------------------------------------------------------------------------
-- Instantiate dut
dut: axis_i2s_wrapper
port map (

    sysclk_i => clk,
    ac_mute_en_i => mute_en_sw,
    ac_bclk_o => bclk,
    ac_mclk_o => mclk,
    ac_mute_n_o => mute_n,
    ac_dac_data_o => data_out,
    ac_dac_lrclk_o => open,
    ac_adc_data_i => data_in,
    ac_adc_lrclk_o => lrclk,
    
    s00_axis_aclk => clk,
    s00_axis_aresetn => reset_n,
    s00_axis_tready => S_AXIS_TREADY,
    s00_axis_tdata => S_AXIS_TDATA,
    s00_axis_tstrb => S_AXIS_TSTRB,
    s00_axis_tlast => S_AXIS_TLAST,
    s00_axis_tvalid => S_AXIS_TVALID, 

    m00_axis_aclk => clk,
    m00_axis_aresetn => reset_n,
    m00_axis_tvalid => M_AXIS_TVALID,
    m00_axis_tdata => M_AXIS_TDATA,
    m00_axis_tstrb => M_AXIS_TSTRB,
    m00_axis_tlast => M_AXIS_TLAST,
    m00_axis_tready => M_AXIS_TREADY);

----------------------------------------------------------------------------  
-- Hook up transmitter interface to receiver (passthrough test)   
S_AXIS_TDATA <= M_AXIS_TDATA;
S_AXIS_TSTRB <= M_AXIS_TSTRB;
S_AXIS_TLAST <= M_AXIS_TLAST;
S_AXIS_TVALID <= M_AXIS_TVALID;
M_AXIS_TREADY <= S_AXIS_TREADY;
----------------------------------------------------------------------------   
-- Processes
----------------------------------------------------------------------------   
-- Generate clock        
clock_gen_process : process
begin
	clk <= '0';				-- start low
	wait for CLOCK_PERIOD/2;		-- wait for half a clock period
	loop							-- toggle, and loop
	     clk <= not(clk);
	  wait for CLOCK_PERIOD/2;
	end loop;
end process clock_gen_process;

----------------------------------------------------------------------------
-- Disable mute
mute_en_sw <= '0';

----------------------------------------------------------------------------
-- Generate input data (stimulus)
----------------------------------------------------------------------------
generate_audio_data: process
    variable t : real := 0.0;
begin		
----------------------------------------------------------------------------
-- Loop forever	
loop	
----------------------------------------------------------------------------
-- Progress one sample through the sine wave:
sine_data <= std_logic_vector(to_signed(integer(SINE_AMPL*sin(math_2_pi*SINE_FREQ*t) ), AUDIO_DATA_WIDTH));

----------------------------------------------------------------------------
-- Take sample
wait until lrclk = '1';
sine_data_tx <= std_logic_vector(unsigned(not(sine_data(AUDIO_DATA_WIDTH-1)) & sine_data(AUDIO_DATA_WIDTH-2 downto 0)));

----------------------------------------------------------------------------
-- Transmit sample to right audio channel
----------------------------------------------------------------------------
bit_count <= AUDIO_DATA_WIDTH-1;            -- Initialize bit counter, send MSB first
for i in 0 to AUDIO_DATA_WIDTH-1 loop
    wait until bclk = '0';
    data_in <= sine_data_tx(bit_count-i);     -- Set input data
end loop;

data_in <= '0';
bit_count <= AUDIO_DATA_WIDTH-1;            -- Reset bit counter to MSB

----------------------------------------------------------------------------
--Transmit sample to left audio channel
----------------------------------------------------------------------------
wait until lrclk = '0';
for i in 0 to AUDIO_DATA_WIDTH-1 loop
    wait until bclk = '0';
    data_in <= sine_data_tx(bit_count-i);     -- Set input data
end loop;
data_in <= '0';

----------------------------------------------------------------------------						
--Increment by one sample
t := t + T_SAMPLE;
end loop;
    
end process generate_audio_data;

----------------------------------------------------------------------------

end testbench;
