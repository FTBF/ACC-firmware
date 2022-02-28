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
        reset       : in reset_type;
		pps			: in std_logic;
		resetRequest: out std_logic;
		useExtRef	:  buffer std_logic;
        phaseUpdate : in std_logic;
        updn     : in std_logic;
        cntsel   : in std_logic_vector(4 downto 0)
		);
end ClockGenerator;


architecture vhdl of ClockGenerator is
	
  signal useExtRef_z: std_logic:= '0';	-- 0=int, 1=ext
  signal useExtRef_x: std_logic:= '0';	-- 0=int, 1=ext
  signal useExtRef_x2: std_logic:= '0';	-- 0=int, 1=ext
  signal pps_risingEdgeDetect: std_logic;

  signal phase_en_low  : std_logic;
  signal phase_en_up   : std_logic;
  signal updn_z     : std_logic;
  signal cntsel_z   : std_logic_vector(4 downto 0);
  signal phase_done_low : std_logic;
  signal phase_done_up  : std_logic;

  signal reset_sync25_1 : std_logic;
  signal reset_sync25_2 : std_logic;

  signal clockInput : std_logic;
  --signal localOscGlobal : std_logic;
begin


--clkBuf_input: clkBuf
--  port map (
--    inclk  => ,
--    outclk => localOscGlobal);

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
    refclk     => clockIn.localOsc,
    rst        => reset.global,
    outclk_0   => clock.serial25,
    outclk_1   => clock.serial125,
    locked     => clock.serialpllLock);

pll_dpa_1: pll_dpa
  port map (
    refclk     => clock.serial125,
    rst        => reset.global or not clock.serialpllLock,
    outclk_0   => clock.serial125_ps(0),
    outclk_1   => clock.serial125_ps(1),
    outclk_2   => clock.serial125_ps(2),
    outclk_3   => clock.serial125_ps(3),
    outclk_4   => clock.serial125_ps(4),
    outclk_5   => clock.serial125_ps(5),
    outclk_6   => clock.serial125_ps(6),
    outclk_7   => clock.serial125_ps(7),
    locked     => clock.dpa1pllLock,
    phase_en   => phase_en_low,
    scanclk    => clock.sys,
    updn       => updn_z,
    cntsel     => cntsel_z,
    phase_done => phase_done_low);

pll_dpa_2: pll_dpa
  port map (
    refclk     => clock.serial125,
    rst        => reset.global or not clock.serialpllLock,
    outclk_0   => clock.serial125_ps(8),
    outclk_1   => clock.serial125_ps(9),
    outclk_2   => clock.serial125_ps(10),
    outclk_3   => clock.serial125_ps(11),
    outclk_4   => clock.serial125_ps(12),
    outclk_5   => clock.serial125_ps(13),
    outclk_6   => clock.serial125_ps(14),
    outclk_7   => clock.serial125_ps(15),
    locked     => clock.dpa2pllLock,
    phase_en   => phase_en_up,
    scanclk    => clock.sys,
    updn       => updn_z,
    cntsel     => cntsel_z,
    phase_done => phase_done_up);

-- state machine to control dynamic phase shifting
dpa_control : process(clock.sys)
  type STATE_TYPE is ( IDLE, DELAY1, DELAY2, UPDATE, WAITING);
  variable state : STATE_TYPE;
  variable low_up : std_logic;
begin
  if rising_edge(clock.sys) then
    if reset.global = '1' then
      phase_en_low <= '0';
      phase_en_up <= '0';
      updn_z <= '0';
      cntsel_z <= "00000";
      low_up := '0';
    else
      case state is
        when IDLE =>
          phase_en_low <= '0';
          phase_en_up <= '0';
          if phaseUpdate = '1' then
            updn_z <= updn;
            cntsel_z <= "00" & cntsel(2 downto 0);
            low_up := cntsel(3);
            state := DELAY1;
          else
            updn_z <= updn_z;
            cntsel_z <= cntsel_z;
            low_up := low_up;
            state := state;
          end if;
        when DELAY1 =>
          state := DELAY2;
        when DELAY2 =>
          state := UPDATE;
        when UPDATE =>
          phase_en_low <= not low_up;
          phase_en_up <= low_up;
          state := WAITING;
        when WAITING =>
          if phase_done_low = '1' or phase_done_up = '1' then
            state := IDLE;
          else
            state := state;
          end if;
      end case;
    end if;
  end if;
end process;

	
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


--EDGE_DET: risingEdgeDetect port map(clock.sys, pps, pps_risingEdgeDetect);
--
--
--PPS_PROCESS: process(clock.sys)
--variable count: natural:= 0;
--variable t: natural:= 0;
--begin
--	if (rising_edge(clock.sys)) then
--		
--		-- pps detect
--		if (t < 100000000) then 	-- 2.5 sec timer
--			if (pps_risingEdgeDetect = '1') then count := count + 1; end if;
--			t := t + 1;
--		else
--			if (count >= 2) then
--				useExtRef_z <= '1';
--			end if;
--		end if;
--		
--		
--		useExtRef_x <= useEXtRef_z or useExtRef_x;		-- latch. Once high it stays high
--		useExtRef_x2 <= useExtRef_x;
--		resetRequest <= useExtRef_x2 xor useExtRef_x;	-- reset pulse
--
--	end if;
--end process;
resetRequest <= '0';





		
end vhdl;

		
	
	
	
	
	
	
	
	
	
	
	
	
	
	

