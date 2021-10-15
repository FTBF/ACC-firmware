---------------------------------------------------------------------------------
-- FILE:         monostable_asyncio_edge.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         May 2021
--
-- DESCRIPTION:  A monostable with asynchronous input & output
--						the rising edge will be immediately passed to the output asynchronously, i.e. unclocked
--						The output stays high for N clocks plus the time between 
--						the input rising edge and the first system clock rising edge
---------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL; 


entity monostable_asyncio_edge is
	port (
		clock	      : in std_logic;        
		len         : in natural;
		trig        : in std_logic;
		output      : buffer std_logic);
end monostable_asyncio_edge;


architecture vhdl of monostable_asyncio_edge is



signal trigLatch: std_logic;
signal trigLatch_z: std_logic;
signal set: std_logic;
signal reset: std_logic;
signal output_z: std_logic;
signal output_z2: std_logic;




begin



-- INPUT LATCH
-- latch a rising edge on the input
INPUT_LATCH: process(trig, trigLatch_z)
begin
	if (trigLatch_z = '1') then 	-- reset the latch because the edge has been detected already
		trigLatch <= '0';
	elsif (rising_edge(trig)) then
		trigLatch <= '1';
	end if;
end process;



-- EDGE_DETECT
-- generate a sychronous, single clock pulse for each rising edge of the input
EDGE_DETECT: process(clock)
begin
	if (falling_edge(clock)) then 
		trigLatch_z <= trigLatch;
	end if;
end process;

		

-- OUTPUT LATCH
-- a set-reset latch for the output signal
OUTPUT_LATCH: process(set, reset)
begin
	if (set = '1') then 
		output <= '1';
	elsif (reset = '1') then
		output <= '0';
	end if;
end process;



set <= trigLatch;




MONOSTABLE_PROCESS: process(clock)
variable t: natural:= 0;		-- the remaining time for the monostable to be high before it goes low
begin
   if (rising_edge(clock)) then
      
		-- sync
		output_z <= output;		-- synchronized version of output
		output_z2 <= output_z;	-- delayed version of sync output 
		
		
		-- restart monostable timer if new input pulse, or if monostable was started
		if (trigLatch_z = '1') then t := len; end if; -- trigger rising edge detect
		if (output_z = '1' and output_z2 = '0') then t := len; end if; -- rising edge on output  (i.e. monostable started)
		

		-- count down the monostable time remaining
		if (t > 0) then t := t - 1; end if;
      
               
      -- check for end of count then apply a reset pulse 
		if (t > 0) then 
		
			reset <= '0'; 
			
		elsif (output_z = '1') then 		-- output is high so reset it
		
			reset <= '1'; 
			
		else
		
			reset <= '0';
      
		end if;
   
	
	end if;
end process;


               
               
			
end vhdl;































