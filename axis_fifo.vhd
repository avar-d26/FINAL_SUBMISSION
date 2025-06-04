----------------------------------------------------------------------------
--  Final Project: Video & Audio Streaming
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Ava Rosenbaum
----------------------------------------------------------------------------
--	Description: AXI Stream FIFO Wrapper
----------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity axis_fifo is
	generic (
		DATA_WIDTH	: integer	:= 32;
		FIFO_DEPTH	: integer	:= 1024
	);
	port (
	
		-- Ports of Axi Responder Bus Interface S00_AXIS -- Receiver
		s00_axis_aclk     :  in std_logic; --
		s00_axis_aresetn  :  in std_logic; --
		s00_axis_tready   : out std_logic; --
		s00_axis_tdata	  :  in std_logic_vector(DATA_WIDTH-1 downto 0); -- our data
		s00_axis_tstrb    :  in std_logic_vector((DATA_WIDTH/8)-1 downto 0); -- dont care
		s00_axis_tlast    :  in std_logic;
		s00_axis_tvalid   :  in std_logic;
		
		fifo_full_o         : out std_logic;
		fifo_empty_o        : out std_logic;

		-- Ports of Axi Controller Bus Interface M00_AXIS -- Transmitter
		m00_axis_aclk     :  in std_logic; -- dont care
		m00_axis_aresetn  :  in std_logic; -- dont care
		m00_axis_tvalid   : out std_logic; 
		m00_axis_tdata    : out std_logic_vector(DATA_WIDTH-1 downto 0); -- our data
		m00_axis_tstrb    : out std_logic_vector((DATA_WIDTH/8)-1 downto 0); -- dont care
		m00_axis_tlast    : out std_logic;
		m00_axis_tready   :  in std_logic -- the problemmm
	);
end axis_fifo;
architecture Behavioral of axis_fifo is

signal write_enable, read_enable, full, empty, reset : std_logic := '0';
signal m00_tvalid_sig, s00_tready_sig : std_logic := '0';
signal m00_tdata_sig : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
signal empty_reg: std_logic := '0';

component fifo is

Generic (
    FIFO_DEPTH : integer := 1024;
    DATA_WIDTH : integer := 32);
Port ( 
    clk_i       : in std_logic;
    reset_i     : in std_logic;
    
    -- Write channel
    wr_en_i     : in std_logic;
    wr_data_i   : in std_logic_vector(DATA_WIDTH-1 downto 0);
    
    -- Read channel
    rd_en_i     : in std_logic;
    rd_data_o   : out std_logic_vector(DATA_WIDTH-1 downto 0);
    
    -- Status flags
    empty_o         : out std_logic;
    full_o          : out std_logic);   
end component;



begin

-- wire the strobe passthru
m00_axis_tstrb <= s00_axis_tstrb;
-- reset active low
reset <= not s00_axis_aresetn;
-- connect outputs to signals
s00_axis_tready <= s00_tready_sig;
m00_axis_tdata <= m00_tdata_sig;
m00_axis_tvalid <= m00_tvalid_sig;




uut: fifo PORT MAP(
    clk_i => s00_axis_aclk,
    reset_i => reset,
    wr_en_i => write_enable,
    wr_data_i => s00_axis_tdata,
    rd_en_i => read_enable,
    rd_data_o => m00_tdata_sig,
    empty_o => empty,
    full_o => full);
    
    
-------------------------
-- handle tlast logic
--------------------------
transmitter_tlast: process(empty, m00_tvalid_sig, empty_reg) begin
m00_axis_tlast <= '0';
if ((empty and (not empty_reg)) = '1') then
    m00_axis_tlast <= '1';    
end if;
end process;

-- handles the Valid and Ready signals
-- produces write enable

s00_tready_sig <= (not full) and s00_axis_aresetn;
write_enable <= (not full) and s00_axis_tvalid and s00_axis_aresetn;

read_enable <= (not empty) and m00_axis_tready and s00_axis_aresetn;

-- Valid signal delayed by a clock cycle to meet proper timing
m00_tvalid_sig <= (not empty_reg) and s00_axis_aresetn;

process (s00_axis_aclk) begin
if rising_edge(s00_axis_aclk) then
    empty_reg <= empty;
end if;
end process;

fifo_full_o <= full;
fifo_empty_o <= empty;

    
end Behavioral;
