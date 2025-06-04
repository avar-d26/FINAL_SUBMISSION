----------------------------------------------------------------------------
--  Lab 3: Streaming Audio DSP
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Ava Rosenbaum
----------------------------------------------------------------------------
--	Description: Generic FIFO implementation
----------------------------------------------------------------------------
-- Library Declarations
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

----------------------------------------------------------------------------
-- Entity definition
entity fifo is
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
end fifo;

----------------------------------------------------------------------------
-- Architecture Definition 
architecture Behavioral of fifo is
----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------
type mem_type is array (0 to FIFO_DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
signal fifo_buf : mem_type := (others => (others => '0'));

signal read_pointer, write_pointer : integer range 0 to FIFO_DEPTH-1 := 0;
signal data_count : integer range 0 to FIFO_DEPTH-1 := 0;
signal full_sig, empty_sig : std_logic:= '0';
----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------
-- Processes and Logic
----------------------------------------------------------------------------
--  COUNTERS
-- read and write address pointers
counters: process(clk_i)
begin
    if rising_edge(clk_i) then  
        if reset_i = '1' then
            read_pointer <= 0;
            write_pointer <= 0;
            data_count <= 0;
        elsif wr_en_i = '1' and rd_en_i = '1' and full_sig = '0' and empty_sig = '0' then
        
            if read_pointer = FIFO_DEPTH-1 then
                read_pointer <= 0;
            else
                read_pointer <= read_pointer + 1;
            end if;
            
            if write_pointer = FIFO_DEPTH-1 then
                write_pointer <= 0;
            else
                write_pointer <= write_pointer + 1;
            end if;
        elsif full_sig = '0' and wr_en_i = '1' then
            
            if write_pointer = FIFO_DEPTH-1 then
                write_pointer <= 0;
            else
                write_pointer <= write_pointer + 1;
            end if;
            data_count <= data_count + 1;
            
        elsif empty_sig = '0' and rd_en_i = '1' then
            if read_pointer = FIFO_DEPTH-1 then
                read_pointer <= 0;
            else
                read_pointer <= read_pointer + 1;
            end if;
            data_count <= data_count - 1;
            
            
        end if;
        
        
    end if;
end process counters; 

-- Synchronous read/write process
read_write : process(clk_i)
begin
    if rising_edge(clk_i) then
        if rd_en_i = '1' and empty_sig = '0' then
            rd_data_o <= fifo_buf(read_pointer);
        end if;
        
        if wr_en_i = '1' and full_sig = '0' then
            fifo_buf(write_pointer) <= wr_data_i;
        end if;
    end if;
end process read_write;

-- Full/empty flags
full_empty : process(data_count)
begin
    if data_count = FIFO_DEPTH then
        full_sig <= '1';
    else
        full_sig <= '0';
    end if;
    
    if data_count = 0 then
        empty_sig <= '1';
    else
        empty_sig <= '0';
    end if;
end process full_empty;

-- Connect internal signals to outputs
full_o <= full_sig;
empty_o <= empty_sig;


end Behavioral;
