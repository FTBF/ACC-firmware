---------------------------------------------------------------------------------
-- FILE:         monostable_async_edge.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         May 2021
--
-- DESCRIPTION:  output stays high for set time
--						asynchronous input, edge detect
--						synchronous output
---------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL; 


entity monostable_async_edge is
	port (
		clock	      : in std_logic;        
		len         : in natural;
		trig        : in std_logic;
		output      : out std_logic);
end monostable_async_edge;


architecture vhdl of monostable_async_edge is



signal reset: std_logic;
signal latch: std_logic;
signal trig_sync: std_logic;





begin




INPUT_LATCH: process(reset, trig)
begin
	if (reset = '1') then
		latch <= '0';
	elsif (rising_edge(trig)) then
		latch <= '1';
	end if;
end process;



SYNC: process(clock)
begin
   if (rising_edge(clock)) then
      trig_sync <= latch;				-- trig_sync is a single pulse for each input rising edge
	end if;
end process;


               
								
CLEAR: process(clock)
begin
   if (falling_edge(clock)) then
      reset <= trig_sync;		
	end if;
end process;






MONOSTABLE_PROCESS: process(clock)
variable t: natural:= 0;
begin
   if (rising_edge(clock)) then

		if (trig_sync = '1') then t := len; end if;
      
               
      if (t > 0) then
		
         output <= '1';
			t := t - 1;
      
		else
         
			output <= '0';
      
		end if;
   
	
	end if;
end process;


               
               
			
end vhdl;































