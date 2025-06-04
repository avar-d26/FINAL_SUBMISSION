----------------------------------------------------------------------------
--  Final Project: Video & Audio Streaming
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Brandon Zhao
----------------------------------------------------------------------------
--	Description: RTL Wrapper for BRAM IP Core, handles typecasting
----------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity BRAM_wrapper is
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC;
    addra : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
    dina : IN STD_LOGIC;
    clkb : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
    doutb : OUT STD_LOGIC
  );
end BRAM_wrapper;

architecture Behavioral of BRAM_wrapper is

  component blk_mem_gen_0
    PORT (
      clka : IN STD_LOGIC;
      wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      addra : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
      dina : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      clkb : IN STD_LOGIC;
      addrb : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
      doutb : OUT STD_LOGIC_VECTOR(0 DOWNTO 0)
    );
  end component;
  
  signal dina_v, doutb_v, wea_v : std_logic_vector(0 downto 0);

begin
  -- cast STD LOGIC VECTOR to STD_LOGIC
  
  dina_v(0) <= dina;
  doutb <= doutb_v(0);
  wea_v(0) <= wea;

  bram_inst : blk_mem_gen_0
    PORT MAP (
      clka   => clka,
      wea    => wea_v,
      addra  => addra,
      dina   => dina_v,
      clkb   => clkb,
      addrb  => addrb,
      doutb  => doutb_v
    );

end Behavioral;
