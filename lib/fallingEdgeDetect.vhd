---------------------------------------------------------------------------------
-- FILE:         fallingEdgeDetect.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         May 2021
--
-- DESCRIPTION:  gives a single synchronous output pulse when input falls
---------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL; 


entity fallingEdgeDetect is
	port (
		clock	      : in std_logic;        
		input        : in std_logic;
		output      : buffer std_logic);
end fallingEdgeDetect;


architecture vhdl of fallingEdgeDetect is



signal	reset: std_logic;
signal	latch: std_logic;






begin




INPUT_LATCH: process(reset, input)
begin
	if (reset = '1') then
		latch <= '0';
	elsif (falling_edge(input)) then
		latch <= '1';
	end if;
end process;



SYNC: process(clock)
begin
   if (rising_edge(clock)) then
      output <= latch;		
	end if;
end process;


               
								
CLEAR: process(clock)
begin
   if (falling_edge(clock)) then
      reset <= output;		
	end if;
end process;


					
               
			
end vhdl;































