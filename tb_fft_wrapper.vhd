----------------------------------------------------------------------------
--  Final Project: Video & Audio Streaming
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Brandon Zhao
----------------------------------------------------------------------------
--	Description: Testbench for I2S-> FFT -> BRAM -> Create 88 key
----------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity tb_fft_wrapper is
end tb_fft_wrapper;

architecture testbench of tb_fft_wrapper is

  -- COMPONENTS
  component axis_i2s_wrapper is
    generic (
      C_AXI_STREAM_DATA_WIDTH : integer := 32;
      AC_DATA_WIDTH           : integer := 24;
      DDS_DATA_WIDTH          : integer := 24;
      DDS_PHASE_DATA_WIDTH    : integer := 12;
      C_S00_AXI_DATA_WIDTH    : integer := 32;
      C_S00_AXI_ADDR_WIDTH    : integer := 4
    );
    port (
      sysclk_i         : in std_logic;
      ac_bclk_o        : out std_logic;
      ac_mclk_o        : out std_logic;
      ac_mute_n_o      : out std_logic;
      ac_dac_data_o    : out std_logic;
      ac_dac_lrclk_o   : out std_logic;
      ac_adc_data_i    : in  std_logic;
      ac_adc_lrclk_o   : out std_logic;
      lrclk_unbuff_o   : out std_logic;

      m00_axis_aclk    : in std_logic;
      m00_axis_aresetn : in std_logic;
      m00_axis_tvalid  : out std_logic;
      m00_axis_tdata   : out std_logic_vector(C_AXI_STREAM_DATA_WIDTH-1 downto 0);
      m00_axis_tstrb   : out std_logic_vector((C_AXI_STREAM_DATA_WIDTH/8)-1 downto 0);
      m00_axis_tlast   : out std_logic;
      m00_axis_tready  : in  std_logic
    );
  end component;

  component axis_fifo1 is
    generic (
      DATA_WIDTH : integer;
      FIFO_DEPTH : integer
    );
    port (
      s00_axis_aclk     : in std_logic;
      s00_axis_aresetn  : in std_logic;
      s00_axis_tready   : out std_logic;
      s00_axis_tdata    : in std_logic_vector(DATA_WIDTH-1 downto 0);
      s00_axis_tstrb    : in std_logic_vector((DATA_WIDTH/8)-1 downto 0);
      s00_axis_tlast    : in std_logic;
      s00_axis_tvalid   : in std_logic;
      m00_axis_aclk     : in std_logic;
      m00_axis_aresetn  : in std_logic;
      fifo_full_o         : out std_logic;
      fifo_empty_o        : out std_logic;
      m00_axis_tvalid   : out std_logic;
      m00_axis_tdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
      m00_axis_tstrb    : out std_logic_vector((DATA_WIDTH/8)-1 downto 0);
      m00_axis_tlast    : out std_logic;
      m00_axis_tready   : in std_logic
    );
  end component;

  component FFT_wrapper is
    generic (
      INPUT_DATA_WIDTH  : integer := 32;
      OUTPUT_DATA_WIDTH : integer := 1;
        FFT_WIDTH           : integer := 1024;
        ADDR_LENGTH         : integer := 512
      
    );
    port (
      s00_axis_aclk     : in std_logic;
      s00_axis_aresetn  : in std_logic;
      s00_axis_tready   : out std_logic;
      s00_axis_tdata    : in std_logic_vector(INPUT_DATA_WIDTH-1 downto 0);
      s00_axis_tstrb    : in std_logic_vector((INPUT_DATA_WIDTH/8)-1 downto 0);
      s00_axis_tlast    : in std_logic;
      s00_axis_tvalid   : in std_logic;
      fifo_full_i         : in std_logic;
      fifo_empty_i        : in std_logic;
      tvalid_o          : out std_logic;
      fft_data_o        : out std_logic;
      fft_done_o        : out std_logic;
      bin_addr_o        : out std_logic_vector(8 downto 0)
    );
  end component;

  component BRAM_wrapper is
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC;
    addra : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
    dina : IN STD_LOGIC;

    clkb : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
    doutb : OUT STD_LOGIC
  );
  end component;

  component create_88key is
    port (
      clkb_i         : in std_logic;
      data_i         : in std_logic;
      en_i           : in std_logic;
      r_addr_o       : out std_logic_vector(8 downto 0);
      paino_data_o   : out std_logic_vector(87 downto 0);
      paino_done_o   : out std_logic
    );
  end component;

  -- CONSTANTS & SIGNALS
  constant AXI_WIDTH      : integer := 32;
  constant CLOCK_PERIOD   : time := 10 ns;
  constant FAST_CLK_PER   : time := 7.46 ns;
  constant AMP            : real := 8388607.0;
  constant FS             : real := 48000.0;

  signal clk_100MHz       : std_logic := '0';
  signal clk_134MHz       : std_logic := '0';
  signal rstn             : std_logic := '0';

  signal bclk             : std_logic := '0';
  signal ac_adc_data_i    : std_logic := '0';

  signal m_axis_tvalid    : std_logic;
  signal m_axis_tdata     : std_logic_vector(31 downto 0);

  signal fifo_empty, fifo_full  : std_logic := '0';
  signal fifo_tvalid      : std_logic;
  signal fifo_tdata       : std_logic_vector(31 downto 0);
  signal fifo_tready      : std_logic;

  signal fft_tready       : std_logic;
  signal fft_valid        : std_logic;
  signal fft_data         : std_logic;
  signal fft_done         : std_logic;
  signal fft_bin_addr     : std_logic_vector(8 downto 0);

  signal bram_doutb       : std_logic;
  signal bram_addrb       : std_logic_vector(8 downto 0);
  signal piano_out        : std_logic_vector(87 downto 0);
  signal piano_done, fifo_tlast       : std_logic;

  signal adc_bit_cnt      : integer := 23;
  signal current_sample   : std_logic_vector(23 downto 0) := (others => '0');
  signal sample_ready     : boolean := false;
  
  signal ac_dac_data_o    : std_logic := '0';
signal sine_data         : std_logic_vector(23 downto 0) := (others => '0');
signal sine_data_tx      : std_logic_vector(23 downto 0) := (others => '0');
signal data_in           : std_logic := '0';
signal bit_count         : integer := 23;
signal lrclk            : std_logic := '0';

-- Constants for sine wave generation
constant SINE_AMPL       : real := 8388607.0;  -- 2^23-1
constant SINE_FREQ       : real := 1000.0;     -- 1 kHz sine wave
constant T_SAMPLE        : real := 1.0/48000.0; -- Sample period for 48kHz
constant MATH_2_PI       : real := 2.0 * MATH_PI;
constant AUDIO_DATA_WIDTH : integer := 24;

begin

  -- Clocks
  clk_100MHz <= not clk_100MHz after CLOCK_PERIOD/2;
  clk_134MHz <= not clk_134MHz after CLOCK_PERIOD/2;

  -- Reset
  process
  begin
    rstn <= '0';
    wait for 100 ns;
    rstn <= '1';
    wait;
  end process;

  -- I2S Wrapper
  i2s_inst : axis_i2s_wrapper
    generic map (
      C_AXI_STREAM_DATA_WIDTH => AXI_WIDTH,
      AC_DATA_WIDTH           => 24,
      DDS_DATA_WIDTH          => 24,
      DDS_PHASE_DATA_WIDTH    => 12,
      C_S00_AXI_DATA_WIDTH    => 32,
      C_S00_AXI_ADDR_WIDTH    => 4
    )
    port map (
      sysclk_i         => clk_100MHz,
      ac_bclk_o        => bclk,
      ac_mclk_o        => open,
      ac_mute_n_o      => open,
      ac_dac_data_o    => ac_dac_data_o,
      ac_dac_lrclk_o   => open,
      ac_adc_data_i    => data_in,
      ac_adc_lrclk_o   => lrclk,
      lrclk_unbuff_o   => open,
      m00_axis_aclk    => clk_100MHz,
      m00_axis_aresetn => rstn,
      m00_axis_tvalid  => m_axis_tvalid,
      m00_axis_tdata   => m_axis_tdata,
      m00_axis_tstrb   => open,
      m00_axis_tlast   => open,
      m00_axis_tready  => fifo_tready
    );

  -- FIFO
  fifo_inst : axis_fifo1
    generic map (
      DATA_WIDTH => AXI_WIDTH,
      FIFO_DEPTH => 1024
    )
    port map (
      s00_axis_aclk    => clk_100MHz,
      s00_axis_aresetn => rstn,
      s00_axis_tready  => fifo_tready,
      s00_axis_tdata   => m_axis_tdata,
      s00_axis_tstrb   => (others => '1'),
      s00_axis_tlast   => '0',
      s00_axis_tvalid  => m_axis_tvalid,
      fifo_full_o => fifo_full,
      fifo_empty_o => fifo_empty,
      m00_axis_aclk    => clk_100MHz,
      m00_axis_aresetn => rstn,
      m00_axis_tvalid  => fifo_tvalid,
      m00_axis_tdata   => fifo_tdata,
      m00_axis_tstrb   => open,
      m00_axis_tlast   => fifo_tlast,
      m00_axis_tready  => fft_tready
    );

  -- FFT
  fft_inst : FFT_wrapper
    port map (
      s00_axis_aclk    => clk_100MHz,
      s00_axis_aresetn => rstn,
      s00_axis_tready  => fft_tready,
      s00_axis_tdata   => fifo_tdata,
      s00_axis_tstrb   => (others => '1'),
      s00_axis_tlast   => fifo_tlast,
      fifo_full_i => fifo_full,
      fifo_empty_i => fifo_empty,
      s00_axis_tvalid  => fifo_tvalid,
      tvalid_o         => fft_valid,
      fft_data_o       => fft_data,
      fft_done_o       => fft_done,
      bin_addr_o       => fft_bin_addr
    );

  -- BRAM
  bram_inst : BRAM_wrapper
    port map (
      clka   => clk_100MHz,
      wea    => fft_valid,
      addra  => fft_bin_addr,
      dina   => fft_data,
      clkb   => clk_134MHz,
      addrb  => bram_addrb,
      doutb  => bram_doutb
    );

  -- Create88key
  piano_inst : create_88key
    port map (
      clkb_i        => clk_134MHz,
      en_i          => fft_done,
      data_i        => bram_doutb,
      r_addr_o      => bram_addrb,
      paino_data_o  => piano_out,
      paino_done_o  => piano_done
    );

  generate_audio_data: process
    variable t : real := 0.0;
  begin
    -- Loop forever
    loop
      -- Progress one sample through the sine wave:
      sine_data <= std_logic_vector(to_signed(integer(SINE_AMPL*sin(MATH_2_PI*SINE_FREQ*t)), AUDIO_DATA_WIDTH));

      -- Take sample
      wait until lrclk = '1';
      sine_data_tx <= std_logic_vector(unsigned(not(sine_data(AUDIO_DATA_WIDTH-1)) & sine_data(AUDIO_DATA_WIDTH-2 downto 0)));

      -- Transmit sample to right audio channel
      bit_count <= AUDIO_DATA_WIDTH-1;  -- Initialize bit counter, send MSB first
      for i in 0 to AUDIO_DATA_WIDTH-1 loop
        wait until bclk = '0';
        data_in <= sine_data_tx(bit_count-i);  -- Set input data
      end loop;

      data_in <= '0';
      bit_count <= AUDIO_DATA_WIDTH-1;  -- Reset bit counter to MSB

      -- Transmit sample to left audio channel
      wait until lrclk = '0';
      for i in 0 to AUDIO_DATA_WIDTH-1 loop
        wait until bclk = '0';
        data_in <= sine_data_tx(bit_count-i);  -- Set input data
      end loop;
      data_in <= '0';

      -- Increment by one sample
      t := t + T_SAMPLE;
    end loop;
  end process generate_audio_data;


end testbench;
