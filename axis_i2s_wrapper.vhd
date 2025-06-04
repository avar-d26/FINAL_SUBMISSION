----------------------------------------------------------------------------
--  Lab 3: Streaming Audio DSP
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Brandon Zhao and Ava Rosenbaum
----------------------------------------------------------------------------
--	Description: AXI stream wrapper for controlling I2S audio data flow
----------------------------------------------------------------------------
-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;     
use IEEE.STD_LOGIC_UNSIGNED.ALL;                                    
----------------------------------------------------------------------------
-- Entity definition
entity axis_i2s_wrapper is
	generic (
		-- Parameters of Axi Stream Bus Interface S00_AXIS, M00_AXIS
		C_AXI_STREAM_DATA_WIDTH	: integer	:= 32;
		AC_DATA_WIDTH : integer := 24;
	    ----------------------------------------------------------------------------
		-- Users to add parameters here
		DDS_DATA_WIDTH : integer := 24;         -- DDS data width
        	DDS_PHASE_DATA_WIDTH : integer := 12;   -- DDS phase increment data width
        ----------------------------------------------------------------------------

		-- User parameters ends
		-- Do not modify the parameters beyond this line

		-- Parameters of Axi Slave Bus Interface S00_AXI
		C_S00_AXI_DATA_WIDTH	: integer	:= 32;
		C_S00_AXI_ADDR_WIDTH	: integer	:= 4);
    Port ( 
        ----------------------------------------------------------------------------
        -- Fabric clock from Zynq PS
		sysclk_i : in std_logic;	
		
        ----------------------------------------------------------------------------
        -- I2S audio codec ports		
		-- User controls
		--ac_mute_en_i : in STD_LOGIC; -- FOR TASK 2
		--audio_input_sel_i : in STD_LOGIC;
		
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
        lrclk_unbuff_o : out STD_LOGIC;
        
        -- DEBUG ports
--        dbg_left_audio_rx_o : out std_logic_vector(AC_DATA_WIDTH - 1 downto 0);
--        dbg_left_audio_tx_o : out std_logic_vector(AC_DATA_WIDTH - 1 downto 0);
--        dbg_right_audio_rx_o : out std_logic_vector(AC_DATA_WIDTH - 1 downto 0);
--        dbg_right_audio_tx_o : out std_logic_vector(AC_DATA_WIDTH - 1 downto 0);
        
        ----------------------------------------------------------------------------
        -- AXI Stream Interface (Receiver/Responder)
    	-- Ports of Axi Responder Bus Interface S00_AXIS
--		s00_axis_aclk     : in std_logic;
--		s00_axis_aresetn  : in std_logic;
--		s00_axis_tready   : out std_logic;
--		s00_axis_tdata	  : in std_logic_vector(C_AXI_STREAM_DATA_WIDTH-1 downto 0);
--		s00_axis_tstrb    : in std_logic_vector((C_AXI_STREAM_DATA_WIDTH/8)-1 downto 0);
--		s00_axis_tlast    : in std_logic;
--		s00_axis_tvalid   : in std_logic;
		
        -- AXI Stream Interface (Tranmitter/Controller)
		-- Ports of Axi Controller Bus Interface M00_AXIS
		m00_axis_aclk     : in std_logic;
		m00_axis_aresetn  : in std_logic;
		m00_axis_tvalid   : out std_logic;
		m00_axis_tdata    : out std_logic_vector(C_AXI_STREAM_DATA_WIDTH-1 downto 0);
		m00_axis_tstrb    : out std_logic_vector((C_AXI_STREAM_DATA_WIDTH/8)-1 downto 0);
		m00_axis_tlast    : out std_logic;
		m00_axis_tready   : in std_logic

		
		
--		----------------------------------------------------------------------------
--		-- User ports ends
--		-- Do not modify the ports beyond this line

--		-- Ports of Axi Responder/Slave Bus Interface S00_AXI
--		s00_axi_aclk	: in std_logic;
--		s00_axi_aresetn	: in std_logic;
--		s00_axi_awaddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
--		s00_axi_awprot	: in std_logic_vector(2 downto 0);
--		s00_axi_awvalid	: in std_logic;
--		s00_axi_awready	: out std_logic;
--		s00_axi_wdata	: in std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
--		s00_axi_wstrb	: in std_logic_vector((C_S00_AXI_DATA_WIDTH/8)-1 downto 0);
--		s00_axi_wvalid	: in std_logic;
--		s00_axi_wready	: out std_logic;
--		s00_axi_bresp	: out std_logic_vector(1 downto 0);
--		s00_axi_bvalid	: out std_logic;
--		s00_axi_bready	: in std_logic;
--		s00_axi_araddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
--		s00_axi_arprot	: in std_logic_vector(2 downto 0);
--		s00_axi_arvalid	: in std_logic;
--		s00_axi_arready	: out std_logic;
--		s00_axi_rdata	: out std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
--		s00_axi_rresp	: out std_logic_vector(1 downto 0);
--		s00_axi_rvalid	: out std_logic;
--		s00_axi_rready	: in std_logic
		);
end axis_i2s_wrapper;
----------------------------------------------------------------------------
architecture Behavioral of axis_i2s_wrapper is

----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------
signal mclk, bclk, lrclk, lrclk_unbuff : std_logic := '0';
signal left_audio_data_sig, right_audio_data_sig, LADS_rx, RADS_rx : std_logic_vector(AC_DATA_WIDTH - 1 downto 0) := (others => '0');
signal left_audio_data_tx_reg, right_audio_data_tx_reg : std_logic_vector(AC_DATA_WIDTH - 1 downto 0) := (others => '0');
signal ac_mute_sig : std_logic := '1';
signal ac_dac_data_o_sig, ac_adc_lrclk_o_sig, ac_bclk_o_sig, ac_dac_lrclk_o_sig, ac_mclk_o_sig : std_logic := '0';

signal m00_axis_tvalid_sig, m00_axis_tlast_sig, s00_axis_tready_sig, m00_axis_tready_sig: std_logic := '0';
signal m00_axis_tdata_sig : std_logic_vector(C_AXI_STREAM_DATA_WIDTH-1 downto 0) := (others => '0');
signal m00_axis_tstrb_sig : std_logic_vector((C_AXI_STREAM_DATA_WIDTH/8)-1 downto 0) := (others => '0');


signal left_audio_data_valid_o_sig, right_audio_data_valid_o_sig : std_logic := '0';

----------------------------------------------------------------------------
-- Component declarations
----------------------------------------------------------------------------
-- ++++ Update/modify the component declarations to match your entities ++++
-- Clock generation
component i2s_clk_gen is
    Port (

        -- System clock in
		sysclk_125MHz_i   : in  std_logic;	
		--mclk_i    : in std_logic;
		
		-- Forwarded clocks
		mclk_fwd_o		  : out std_logic;	
		bclk_fwd_o        : out std_logic;
		adc_lrclk_fwd_o   : out std_logic;
		dac_lrclk_fwd_o   : out std_logic;

        -- Clocks for I2S components
		mclk_o		      : out std_logic;	
		bclk_o            : out std_logic;
		lrclk_o           : out std_logic;
		lrclk_unbuff_o    : out std_logic);  

end component;

----------------------------------------------------------------------------------
--I2S receiver -- COMMENT OUT FOR TASK 1 , UNCOMMENT FOR TASK 2
component i2s_receiver is
    Generic (AC_DATA_WIDTH : integer := AC_DATA_WIDTH);
    Port (

        -- Timing
		mclk_i    : in std_logic;	
		bclk_i    : in std_logic;	
		lrclk_i   : in std_logic;
		
		-- Data
		left_audio_data_o     : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		right_audio_data_o    : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		adc_serial_data_i     : in std_logic);  
end component; 

-- Keeping for testing
---- DDS AXI
--component engs128_axi_dds is 
--	generic (
--	    ----------------------------------------------------------------------------
--		-- Users to add parameters here
--		DDS_DATA_WIDTH : integer := 24;         -- DDS data width
--        DDS_PHASE_DATA_WIDTH : integer := 12;   -- DDS phase increment data width
--        ----------------------------------------------------------------------------

--		-- User parameters ends
--		-- Do not modify the parameters beyond this line

--		-- Parameters of Axi Slave Bus Interface S00_AXI
--		C_S00_AXI_DATA_WIDTH	: integer	:= 32;
--		C_S00_AXI_ADDR_WIDTH	: integer	:= 4
--	);
--	port (
--	    ----------------------------------------------------------------------------
--		-- Users to add ports here
--		dds_clk_i     : in std_logic;
--		dds_enable_i  : in std_logic;
--		dds_reset_i   : in std_logic;
--		left_dds_data_o    : out std_logic_vector(DDS_DATA_WIDTH-1 downto 0);
--		right_dds_data_o    : out std_logic_vector(DDS_DATA_WIDTH-1 downto 0);
		
--		-- Debug ports to send to ILA
--		left_dds_phase_inc_dbg_o : out std_logic_vector(DDS_PHASE_DATA_WIDTH-1 downto 0);   
--		right_dds_phase_inc_dbg_o : out std_logic_vector(DDS_PHASE_DATA_WIDTH-1 downto 0);   
		
--		----------------------------------------------------------------------------
--		-- User ports ends
--		-- Do not modify the ports beyond this line

--		-- Ports of Axi Responder/Slave Bus Interface S00_AXI
--		s00_axi_aclk	: in std_logic;
--		s00_axi_aresetn	: in std_logic;
--		s00_axi_awaddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
--		s00_axi_awprot	: in std_logic_vector(2 downto 0);
--		s00_axi_awvalid	: in std_logic;
--		s00_axi_awready	: out std_logic;
--		s00_axi_wdata	: in std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
--		s00_axi_wstrb	: in std_logic_vector((C_S00_AXI_DATA_WIDTH/8)-1 downto 0);
--		s00_axi_wvalid	: in std_logic;
--		s00_axi_wready	: out std_logic;
--		s00_axi_bresp	: out std_logic_vector(1 downto 0);
--		s00_axi_bvalid	: out std_logic;
--		s00_axi_bready	: in std_logic;
--		s00_axi_araddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
--		s00_axi_arprot	: in std_logic_vector(2 downto 0);
--		s00_axi_arvalid	: in std_logic;
--		s00_axi_arready	: out std_logic;
--		s00_axi_rdata	: out std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
--		s00_axi_rresp	: out std_logic_vector(1 downto 0);
--		s00_axi_rvalid	: out std_logic;
--		s00_axi_rready	: in std_logic
--	);
--end component;
------------------------------------------------------------------------------------
-- I2S transmitter
component i2s_transmitter is
    Generic (AC_DATA_WIDTH : integer := AC_DATA_WIDTH);
    Port (

        -- Timing
		mclk_i    : in std_logic;	
		bclk_i    : in std_logic;	
		lrclk_i   : in std_logic;
		
		-- Data
		left_audio_data_i     : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		right_audio_data_i    : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		dac_serial_data_o     : out std_logic);  
end component; 


---------------------------------------------------------------------------- 
-- AXI stream transmitter
component axis_transmitter_interface is
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
end component;

    
---------------------------------------------------------------------------- 
-- AXI stream receiver

--component axis_receiver_interface is
--Generic (
--    FIFO_DEPTH : integer := 1024;
--    I2S_DATA_WIDTH : integer := 24;
--    DATA_WIDTH : integer := 32);
--Port ( 
    -- i2s LRCLK signal
--    lrclk_i       : in std_logic;
    
    -- Ports of Axi Controller Bus Interface M00_AXIS
--    s00_axis_aclk_i     : in std_logic;
--    s00_axis_aresetn_i     : in std_logic;
--    s00_axis_tdata_i    : in std_logic_vector(DATA_WIDTH-1 downto 0);
--    s00_axis_tlast_i    : in std_logic;
--    s00_axis_tsrb_i    : in std_logic_vector(3 downto 0);
--    s00_axis_tvalid_i    : in std_logic;
    
    -- I2S transmitter signals
--    left_audio_data_o : out std_logic_vector(I2S_DATA_WIDTH-1 downto 0);
--    right_audio_data_o : out std_logic_vector(I2S_DATA_WIDTH-1 downto 0);
--    left_audio_data_valid_o : out std_logic;
--    right_audio_data_valid_o : out std_logic;   
--    s00_axis_tready_o : out std_logic);
--end component;
----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------
-- Component instantiations
----------------------------------------------------------------------------    
the_clock_generator : i2s_clk_gen PORT MAP(
    sysclk_125MHz_i => sysclk_i,
    mclk_fwd_o => ac_mclk_o_sig,
    bclk_fwd_o => ac_bclk_o_sig,
    adc_lrclk_fwd_o => ac_adc_lrclk_o_sig,
    dac_lrclk_fwd_o => ac_dac_lrclk_o_sig,
    mclk_o => mclk,
    bclk_o => bclk,
    lrclk_o => lrclk,
    lrclk_unbuff_o => lrclk_unbuff);

---------------------------------------------------------------------------- 
-- I2S receiver
the_i2s_receiver : i2s_receiver PORT MAP(
    mclk_i => mclk,
    bclk_i => bclk,
    lrclk_i => lrclk_unbuff, 
    left_audio_data_o => left_audio_data_sig,
    right_audio_data_o => right_audio_data_sig,
    adc_serial_data_i => ac_adc_data_i);
---------------------------------------------------------------------------- 
-- I2S transmitter
the_i2s_transmitter : i2s_transmitter PORT MAP(
    mclk_i => mclk,
    bclk_i => bclk,
    lrclk_i => lrclk_unbuff,
    left_audio_data_i => left_audio_data_sig,
    right_audio_data_i => right_audio_data_sig,
    dac_serial_data_o => ac_dac_data_o_sig);


---------------------------------------------------------------------------- 
-- AXI stream transmitter
axis_trans : axis_transmitter_interface PORT MAP(
    left_audio_data_i => left_audio_data_sig,  -- 
    right_audio_data_i => right_audio_data_sig, -- 
    lrclk_i => lrclk,
    m00_axis_aclk_i => m00_axis_aclk,
    m00_axis_aresetn_i => m00_axis_aresetn,
    m00_axis_tready_i => m00_axis_tready_sig,
    m00_axis_tdata_o => m00_axis_tdata_sig,
    m00_axis_tlast_o => m00_axis_tlast_sig,
    m00_axis_tsrb_o => m00_axis_tstrb_sig,
    m00_axis_tvalid_o => m00_axis_tvalid_sig);


---------------------------------------------------------------------------- 
-- Logic
---------------------------------------------------------------------------- 
-- mute inverter
ac_mute_n_o <= '1'; -- TASK 2, always unmuted



--wire signals to outputs
m00_axis_tdata <= m00_axis_tdata_sig;
m00_axis_tlast <= m00_axis_tlast_sig;
m00_axis_tstrb <= m00_axis_tstrb_sig;
m00_axis_tvalid <= m00_axis_tvalid_sig;


m00_axis_tready_sig <= m00_axis_tready;

--s00_axis_tready <= s00_axis_tready_sig;

ac_adc_lrclk_o <= ac_adc_lrclk_o_sig;
ac_bclk_o <= ac_bclk_o_sig;
ac_dac_lrclk_o <= ac_dac_lrclk_o_sig;
ac_mclk_o <= ac_mclk_o_sig;
ac_dac_data_o <= ac_dac_data_o_sig;

lrclk_unbuff_o <= lrclk_unbuff;


end Behavioral;
