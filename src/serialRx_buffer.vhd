---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
-- PROJECT:      ANNIE 
-- FILE:         uart_rxBuffer.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         June 2021
--
-- DESCRIPTION:  recevies bytes from the serial port and pairs them into 16 bit words
--						stores 16 bit words into the ram buffer
--
---------------------------------------------------------------------------------

library IEEE; 
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL; 
use work.components.rx_data_fifo;
use work.defs.all;


entity serialRx_buffer is
  port(
    reset		   : in	 std_logic;	--buffer reset and/or global reset
    clock		   : in	 std_logic;	--system clock
    eth_clk        : in  std_logic; --ethernet clock 
    din			   : in	 std_logic_vector(7 downto 0);--input data 8 bits
    din_valid	   : in	 std_logic;		 
    read_enable	   : in	 std_logic; 	--enable reading from RAM block
    buffer_empty   : out std_logic;
    dataLen		   : out std_logic_vector(15 downto 0);
    dout		   : out std_logic_vector(15 downto 0)--ram data out
    );	
		
end serialRx_buffer;

architecture vhdl of serialRx_buffer is

  constant buffer_size : natural := 16384;

  signal word:	std_logic_vector(15 downto 0);
  signal word_valid: std_logic;

  -- Rx input rate is 40Mbit/s = data rate of 4Mbyte/s = 2Mword/sec @16bits

begin

-- convert input bytes into 16-bit words
WORD_GEN: process(clock)
variable t: natural:=0;
variable byte_count: natural:=0;
variable reg: std_logic_vector(15 downto 0);

begin
  if (rising_edge(clock)) then
    if (din_valid = '1') then
      t := 0;		-- time since byte received
      case byte_count is
        when 0 => reg(15 downto 8) := din;		-- high byte received first
        when 1 => reg(7 downto 0) := din;
        when others => null;
      end case;
      
      byte_count := byte_count + 1;
      
      if (byte_count >=  2) then
        word_valid <= '1';
        word <= reg;
        byte_count := 0;
      else
        word_valid <= '0';
      end if;
    else
      word_valid <= '0';
    end if;
    
    -- timeout timer for incomplete words
    if (t < 40000) then 
      t := t + 1;
    else 
      byte_count := 0; 
    end if;
  end if;
end process;

rx_fifo_map: rx_data_fifo
  port map (
    aclr    => reset,

    wrclk   => clock,
    data    => word,
    wrreq   => word_valid,
    wrfull  => open,

    rdclk   => eth_clk,
    rdreq   => read_enable,
    q       => dout,
    rdempty => buffer_empty,
    rdusedw => dataLen(8 downto 0)
    );
dataLen(15 downto 9) <= (others => '0');

end vhdl;
