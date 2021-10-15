---------------------------------------------------------------------------------
-- FILE:         monostable_sync_edge.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         May 2021
--
-- DESCRIPTION:  output stays high for set time
--                edge detect on input signal
--						synchronous input/output
--
-- 					If a new edge is detected while the output is high,
-- 					the pulse width will be extended to last for the
--						specified length from the latest trigger
---------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL; 


entity monostable_sync_edge is
	port (
		clock	      : in std_logic;        
		len         : in natural;
		trig        : in std_logic;
		output      : out std_logic);
end monostable_sync_edge;


architecture vhdl of monostable_sync_edge is


signal trig_z: std_logic;



begin



MONOSTABLE_PROCESS: process(clock)
variable t: natural:= 0;
begin
   if (rising_edge(clock)) then
	
		trig_z <= trig;
      
		
		if (trig = '1' and trig_z = '0') then 	t := len; end if;		-- rising edge
      
               
      if (t > 0) then 
		
			output <= '1'; 
			t := t - 1;
			
		else 
		
			output <= '0'; 
			
		end if;
         
			
	end if;
end process;


               
               
			
end vhdl;































