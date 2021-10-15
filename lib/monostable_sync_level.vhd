---------------------------------------------------------------------------------
-- FILE:         monostable_sync_level.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         May 2021
--
-- DESCRIPTION:  output stays high for set time
--                level detect on input signal
--						synchronous input/output
---------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL; 


entity monostable_sync_level is
	port (
		clock	      : in std_logic;        
		len         : in natural;
		trig        : in std_logic;
		output      : out std_logic);
end monostable_sync_level;


architecture vhdl of monostable_sync_level is



begin



MONOSTABLE_PROCESS: process(clock)
variable t: natural:= 0;
begin
   if (rising_edge(clock)) then
	
      
		if (trig = '1') then t := len; end if;
      
               
					
      if (t > 0) then
         
			output <= '1';
			t := t - 1;
      
		else
         
			output <= '0';
      
		end if;
   
	
	end if;
end process;


               
               
			
end vhdl;































