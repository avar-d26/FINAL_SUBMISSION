----------------------------------------------------------------------------
--  Lab 3: Streaming Audio DSP
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Brandon Zhao and Ava Rosenbaum
----------------------------------------------------------------------------
--	Description: Clock generator system for Lab 3, producing mclk, bclk, and lrclk
----------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity i2s_clk_gen is
    Port ( 
        -- System clock in
		sysclk_125MHz_i   : in  std_logic;	
		--mclk_i            : in std_logic;
		
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
end i2s_clk_gen;

architecture Behavioral of i2s_clk_gen is

----------------------------------------------------------------------------
-- Component Declarations
---------------------------------------------------------------------------- 
-- LR Clock Divider

component clock_divider is
Generic (CLK_DIV_RATIO : integer );
    Port (  fast_clk_i : in STD_LOGIC;		  
            slow_clk_o : out STD_LOGIC;
            slow_clk_unbuff_o : out STD_LOGIC); 
end component;
---------------------------------------------------------------------------- 
---------------------------------------------------------------------------- 
-- B Clock Divider

component bclk_divider is
Generic (CLK_DIV_RATIO : integer );
    Port (  fast_clk_i : in STD_LOGIC;		  
            slow_clk_o : out STD_LOGIC;
            slow_clk_unbuff_o : out STD_LOGIC); 
end component;
---------------------------------------------------------------------------- 

-- MMCM
component clk_wiz_01 is
port( sysclk : in std_logic;
      mclk   : out std_logic);
end component;

----------------------------------------------------------------------------
-- Signal Declarations
---------------------------------------------------------------------------- 
signal bclk_sig, mclk_sig : STD_LOGIC := '0';
signal lrclk_sig : STD_LOGIC := '0';
signal lrclk_unbuff_sig : STD_LOGIC := '0';

signal locked : STD_LOGIC := '0';


begin

----------------------------------------------------------------------------
-- Component instantiations
---------------------------------------------------------------------------- 
-- ODDR Instantiations

mclk_forward_oddr : ODDR
    generic map(
            DDR_CLK_EDGE => "SAME_EDGE", -- "OPPOSITE_EDGE" or "SAME_EDGE"
            INIT => '0', -- Initial value for Q port ('1' or '0')
            SRTYPE => "SYNC") -- Reset Type ("ASYNC" or "SYNC")
    port map (
            Q => mclk_fwd_o,     -- 1-bit DDR output
            C => mclk_sig,     -- 1-bit clock input
            CE => '1', -- 1-bit clock enable input
            D1 => '1', -- 1-bit data input (positive edge)
            D2 => '0', -- 1-bit data input (negative edge)
            R => '0', -- 1-bit reset input
            S => '0'); -- 1-bit set input

bclk_forward_oddr : ODDR
    generic map(
            DDR_CLK_EDGE => "SAME_EDGE", -- "OPPOSITE_EDGE" or "SAME_EDGE"
            INIT => '0', -- Initial value for Q port ('1' or '0')
            SRTYPE => "SYNC") -- Reset Type ("ASYNC" or "SYNC")
    port map (
            Q => bclk_fwd_o,     -- 1-bit DDR output
            C => bclk_sig,     -- 1-bit clock input
            CE => '1', -- 1-bit clock enable input
            D1 => '1', -- 1-bit data input (positive edge)
            D2 => '0', -- 1-bit data input (negative edge)
            R => '0', -- 1-bit reset input
            S => '0'); -- 1-bit set input

lrclk_adc_forward_oddr : ODDR
    generic map(    
            DDR_CLK_EDGE => "SAME_EDGE", -- "OPPOSITE_EDGE" or "SAME_EDGE"
            INIT => '0', -- Initial value for Q port ('1' or '0')
            SRTYPE => "SYNC") -- Reset Type ("ASYNC" or "SYNC")
    port map (
            Q => adc_lrclk_fwd_o,     -- 1-bit DDR output
            C => lrclk_sig,     -- 1-bit clock input
            CE => '1', -- 1-bit clock enable input
            D1 => '1', -- 1-bit data input (positive edge)
            D2 => '0', -- 1-bit data input (negative edge)
            R => '0', -- 1-bit reset input
            S => '0'); -- 1-bit set input
            
lrclk_dac_forward_oddr : ODDR
    generic map(    
            DDR_CLK_EDGE => "SAME_EDGE", -- "OPPOSITE_EDGE" or "SAME_EDGE"
            INIT => '0', -- Initial value for Q port ('1' or '0')
            SRTYPE => "SYNC") -- Reset Type ("ASYNC" or "SYNC")
    port map (
            Q => dac_lrclk_fwd_o,     -- 1-bit DDR output
            C => lrclk_sig,     -- 1-bit clock input
            CE => '1', -- 1-bit clock enable input
            D1 => '1', -- 1-bit data input (positive edge)
            D2 => '0', -- 1-bit data input (negative edge)
            R => '0', -- 1-bit reset input
            S => '0'); -- 1-bit set input
---------------------------------------------------------------------------- 
-- Clock Divider Instantiations
bclock_divider : bclk_divider 
    generic map (CLK_DIV_RATIO => 4)
    port map  (
            fast_clk_i => mclk_sig,		  
            slow_clk_o => bclk_sig,
            slow_clk_unbuff_o => open); 
            
lrclock_divider : clock_divider 
    generic map (CLK_DIV_RATIO => 64)
    port map  (
            fast_clk_i => bclk_sig,		  
            slow_clk_o => lrclk_sig,
            slow_clk_unbuff_o => lrclk_unbuff_sig ); 
            

clock_wiz : clk_wiz_01 PORT MAP(
    sysclk => sysclk_125MHz_i,
    mclk => mclk_sig);
      
-- Clocks for I2S components
lrclk_o <= lrclk_sig;
mclk_o <= mclk_sig;
bclk_o <= bclk_sig;
lrclk_unbuff_o <= lrclk_unbuff_sig;

end Behavioral;
