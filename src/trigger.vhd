---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    --KICP--
--
-- PROJECT:      ANNIE
-- FILE:         trigger.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         May 2021
--
-- DESCRIPTION:  
--
-- This module selects the signal (trigger or gate) that will be sent to the ACDC 
--	along the LVDS pair, depending on the mode.
--
-- There are 4 options:
-- 	Hardware trigger (SMA input)
--		Software trigger		
--		PPS trigger 	
--		Beam gate (SMA input) / pps trigger [multiplexed signal]
--		
--		The latter option multiplexes the two signals (beam gate and pps trigger) onto one line.
--		pps width is made small (<=50ns) and beam gate is long (>100ns) so they can be disambiguated at the other end
--		
--		Beam gate is not a trigger itself but is a window which defines the period over which 
-- 	a trigger signal will be classed as valid, in modes where beam gate validation is used.
--		
--		Beam gate is derived from the signal 'beam gate trigger' which is input to the SMA connector
--		This input is delayed and then fed to a monostable before being turned into 'beam gate'.
--		The two parameters (window start delay and window length) are settable by the software.
--
--		pps processing includes a pulse gobbler to remove all except every Nth pulse
--		This is to reduce the number of pps triggers which may otherwise burden the system too much.
--
---------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.components.all;
use work.defs.all;
use work.LibDG.all;




entity trigger is
	Port(
		clock		: in clock_type;
		reset		: in std_logic;
		trig	 	: in trigSetup_type;		
		pps		: in std_logic;
		hw_trig	: in std_logic;
		beamGate_trig: in std_logic;
		trig_out		:  out std_logic_vector(7 downto 0)
		);
end trigger;


architecture vhdl of trigger is

  signal pps_pwCtrl: std_logic;
  signal pps_divided: std_logic;
  signal pps_gate: std_logic;
  signal pps_risingEdge: std_logic;
  signal pps_z: std_logic;
  signal safeToEnable_pps: std_logic;
  signal beamGate: std_logic;
  signal beamGate_pps_mux: std_logic;
  signal beamGate_trig_risingEdge: std_logic;

begin


------------------------------------
--	TRIGGER SOURCE SELECT
------------------------------------
-- trigger source is selected for each ACDC board 
--
-- 0 = off (trigger not supplied by ACC)
-- 1 = software
-- 2 = hardware
-- 3 = pps
-- 4 = beam gate / pps multiplexed



TRIG_MULTIPLEXER: process(trig, hw_trig, pps_divided, beamGate_pps_mux)
begin
	for i in 0 to 7 loop
		case trig.source(i) is
			when 0 => trig_out(i) <= '0';				-- off
			when 1 => trig_out(i) <= trig.sw(i);		-- software trigger
			when 2 => trig_out(i) <= hw_trig;		    -- hardware trigger
			when 3 => trig_out(i) <= pps_divided;		-- divided down version of pulse per second trigger 
			when 4 => trig_out(i) <= beamGate_pps_mux;		-- beam gate / pps
			when others => trig_out(i) <= '0';
		end case;
	end loop;
end process;



-----------------------------------
-- PPS PROCESSING
-----------------------------------





-- pulse width controller
-----------------------------------
-- trigger on rising edge of pps input and generate an output pulse with a width of 1 clock + sync time
-- Note a special type of monostable is used which passes the rising edge through immediately, i.e. unclocked
-- output pulse width is 1 clock plus sync time i.e. 25ns to 50ns
--
-- The pulse width is made short deliberately so it can be distinguished from other longer pulses which will be later multilexed onto the same signal line
-- The rising edge must not be clocked as it contains the timing info for the pps pulse
PW_CTRL: monostable_asyncio_edge port map(clock.sys, 1, pps, pps_pwCtrl);	
  




-- pulse gobbler
-----------------------------------
-- not every pps pulse needs to be timestamped
-- this module removes all pulses except for every Nth pulse [N = ppsDivRatio]
-- output pulses are identical width to input pulses and are asynchronous, i.e. not clocked by the system clock
PULSE_GOBBLER: pulseGobbler port map(clock.sys, pps_pwCtrl, trig.ppsDivRatio, pps_divided);









-----------------------------------
-- PPS / BEAM GATE MULTIPLEXING
-----------------------------------
-- In certain modes beam gate and pps are multiplexed onto one signal so that when beam gate is low 
-- and the signal trigger inactive, pps pulses can be used as a trigger to get a timestamp.
--
-- The processes below must ensure that there are no small glitches which could cause problems
-- - any low periods must be at least a clock cycle.
--
-- If the pps occurs just before or during the beam gate high period, the two will merge and it becomes just a beam gate pulse
--
-- The pps and beamgate pulses are differentiated by the pulse width.
--
-- pps  <= 50ns
-- beam gate >= 100ns
--


-- combiner
beamGate_pps_mux <= (pps_divided and pps_gate) or beamGate;



BEAMGATE_EDGE: risingEdgeDetect port map(clock.sys, beamGate_trig, beamGate_trig_risingEdge);        


PPS_MUX: process(clock.sys)
variable state: natural:= 0;
variable t: natural:= 0;

-- M is the number of cycles required to detect beamgate at the other end
-- hence need to shorten the delay time and also extend the pulse width by this amount to compensate 
constant M: natural:= 4;	
variable windowStart: natural;
variable windowLen: natural;

begin
	if (rising_edge(clock.sys)) then

	
		pps_z <= pps_divided;
		
		
		-- limit minimum window length
		if (trig.windowLen < 8) then 
			windowLen := 8 + M; 
		else 
			windowLen := trig.windowLen + M; 
		end if;

        if trig.windowStart >= M then
          windowStart := trig.windowStart - M;
        else
          windowStart := 0;
        end if;
	
		case state is 
		
			
			when 0 =>		-- IDLE state
			
				beamGate <= '0';

				if (safeToEnable_pps = '1' and trig.ppsMux_enable = '1') then
				
					-- pps signal re-enabled at a safe time, i.e. a pps is not expected at the moment
					-- if pps gate were enabled while pps is high, this would ruin the timing of pps as it would miss the original rising edge
					pps_gate <= '1';		
					
				end if;
				
				
				if (beamGate_trig_risingEdge = '1') then 
					
					t := 0; 
					state := 1;
				
				end if;
				
				
				
			when 1 =>		-- WINDOW START DELAY
		
				t := t + 1;
				if (t >= windowStart) then
					
					t := 0;
					state := 2;
					
				end if;
				
				
				
			when 2 =>		-- CHECK PPS PULSE NOT IN PROGRESS
				
				-- if pps was detected high, holdoff for a few clocks to give a gap between end of pps and start of beam gate
				if (pps_z = '1') then 
				
					t := 4; 	
				
				elsif (t = 0) then
				
					-- it is important to set the output high in the same clock that pps_z is detected as being zero
					-- otherwise pps pulse may occur between pps_z being read as zero and setting beam gate high (as pps pulse is very short and is asynchronous)
					-- This could create a very small 'low' glitch 
					beamGate <= '1';				
					state := 3;
					
				else
				
					t := t - 1;
				
				end if;
				
				
				
			when 3 =>		-- WINDOW OUTPUT HIGH PERIOD
			
				t := t + 1;
				if (t >= windowLen) then
				
					-- it is safe to disable pps here because mux output is high anyway so will not change value
					-- hence no possibility of beam gate going low for a fraction of a ns and then high if a pps suddenly comes in,
					-- which could cause a very narrow glitch to logic 0 for a brief period, which would upset things
					pps_gate <= '0';		
					t := 0;
					state := 4;
					
				end if;
				
				
				
			when 4 =>		-- HOLD OUTPUT LOW FOR A FEW CLOCKS
								-- this gives a clean gap between beam gate low and possible next pps edge
								-- which helps the ACDC demultiplexer to decode the signal
					beamGate <= '0';
					t := t + 1;
					if (t > 10) then state := 0; end if;
				
		
		
			when others =>
			
				state := 0;
				
				
				
			
		
		end case;
				
		
	end if;
end process;







PPS_EDGE: risingEdgeDetect port map(clock.sys, pps, pps_risingEdge);        



SAFE_TO_SWITCH: process(clock.sys)
variable t: natural:= 0;
begin
	if (rising_edge(clock.sys)) then
		
		if (pps_risingEdge = '1') then		-- rising edge of pps
		
			t := 0;	-- restart timing reference

		end if;
		
		
		if (t >= 40000 and t <= 39960000) then		-- from 1ms after the rising edge to 1ms before the next one
			
			safeToEnable_pps <= '1';
			
		else
		
			safeToEnable_pps <= '0';
			
		end if;
		
		t := t + 1;
		
	
	end if;
end process;
	
	
	

end vhdl;

		
	
	
	
	
	
	
	
	
	
	
	
	
	
	

