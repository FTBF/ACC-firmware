---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    --KICP--
--
-- PROJECT:      ANNIE/LAPPD
-- FILE:         clockGenerator.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         June 2021
--
-- DESCRIPTION:  clock generator
--
---------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.components.all;
use work.defs.all;
use work.LibDG.all;



entity ClockGenerator is
	Port(
		clockIn		: in	clockSource_type;
		clock			: buffer clock_type;
		pps			: in std_logic;
		resetRequest: out std_logic;
		useExtRef	:  buffer std_logic
		);
end ClockGenerator;


architecture vhdl of ClockGenerator is


	
signal useExtRef_z: std_logic:= '0';	-- 0=int, 1=ext
signal useExtRef_x: std_logic:= '0';	-- 0=int, 1=ext
signal useExtRef_x2: std_logic:= '0';	-- 0=int, 1=ext
signal pps_risingEdgeDetect: std_logic;

	
begin





-- system clock generator pll
PLL_MAP : pll port map			
(
	refclk	=>	clockIn.localOsc,	-- ref freq set to 125MHz 
	rst		=> '0',
	outclk_0	=>	clock.sys, 		-- 40MHz
	outclk_1	=>	clock.x4,		-- 160MHz
	outclk_2	=>	clock.x8,		-- 320MHz
	locked	=>	clock.altpllLock	-- pll lock indicator
);


pll_serial_inst: pll_serial
  port map (
    refclk   => clockIn.localOsc,
    rst      => '0',
    outclk_0 => clock.serial25,
    outclk_1 => clock.serial125,
    outclk_2 => clock.serial500,
    locked   => clock.serialpllLock);
	
---------------------------------------
-- EXTERNAL REFERENCE SELECT
---------------------------------------
--  Controls the hardware clock 2:1 multiplexer which selects between local xtal osc and ext ref clock
--
--  		        At power-up the clock is set to local osc
--               If a pps pulse is detected within about 2s of power-on the multiplexer is switched to ext clock
--			       
--               This switch is one way, i.e. it cannot go from ext to int clock again.
--               Only a power cycle will make it go back to int clock.
--               The external clock can only be selected at power-up. If applied later it will have no effect and
--               the local oscillator will continue to be selected until a power-cycle.
--
--               After the clock multiplexer changes this will possibly introduce a glitch that can 
--               potentially upset the system that is driven by system clock and its derivatives.
--				
--               To get around this problem once the new clock source is selected, a long reset pulse is applied
--               so that it is effective once the new clock settles, thus everything starts in the correct state.
--

	


useExtRef <= useExtRef_x;


EDGE_DET: risingEdgeDetect port map(clock.sys, pps, pps_risingEdgeDetect);


PPS_PROCESS: process(clock.sys)
variable count: natural:= 0;
variable t: natural:= 0;
begin
	if (rising_edge(clock.sys)) then
		
		-- pps detect
		if (t < 100000000) then 	-- 2.5 sec timer
			if (pps_risingEdgeDetect = '1') then count := count + 1; end if;
			t := t + 1;
		else
			if (count >= 2) then
				useExtRef_z <= '1';
			end if;
		end if;
		
		
		useExtRef_x <= useEXtRef_z or useExtRef_x;		-- latch. Once high it stays high
		useExtRef_x2 <= useExtRef_x;
		resetRequest <= useExtRef_x2 xor useExtRef_x;	-- reset pulse

	end if;
end process;






		
end vhdl;

		
	
	
	
	
	
	
	
	
	
	
	
	
	
	

