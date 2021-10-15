---------------------------------------------------------------------------------
-- FILE:         pulseGobbler.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         Apr 2021
--
-- DESCRIPTION:  Deletes all pulses except every Nth pulse
--               Like a prescaler but the output pulse width
--						 is identical to input pulse width
--
--
---------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.components.all;
use work.defs.all;
use work.LibDG.fallingEdgeDetect;




entity pulseGobbler is
	Port(
		clock		: in	std_logic;
		input		: in	std_logic;
		N			: in natural;
		output	: out std_logic
		);
end pulseGobbler;


architecture vhdl of pulseGobbler is

	

	
signal	gate: std_logic;







	
begin




output <= input and gate;





PULSE_GOBBLER: process(input)
variable count: natural:= 0;
begin
	if (falling_edge(input)) then
	
		if (N = 0 or count < N) then
			
			gate <= '0';
			
		else
		
			count := 0;
			gate <= '1';
			
		end if;
		
		
		count := cOunt + 1;

		
	end if;
end process;











end vhdl;

		
	
	
	
	
	
	
	
	
	
	
	
	
	
	

