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
USE ieee.numeric_std.ALL; 
use work.components.all;
use work.defs.all;
use work.LibDG.all;

use ieee.std_logic_misc.all;


entity trigger is
	Port(
		clock		: in clock_type;
		reset		: in std_logic;
		trig	 	: in trigSetup_type;		
		pps		: in std_logic;
		hw_trig	: in std_logic;
		beamGate_trig: in std_logic;
        self_trig       :  out std_logic;
        selftrig_counts : out Array_32bit;
        cointrig_counts : out Array_32bit;

		trig_out		:  out std_logic_vector(7 downto 0);

        ACDC_triggers   : in std_logic_vector(N-1 downto 0);

        sfp0_tx_clk :   in      std_logic;
        sfp0_rx_clk :   in      std_logic;

        sfp1_tx_clk :   in      std_logic;
        sfp1_rx_clk :   in      std_logic;

        sfp0_tx_ready : in std_logic;
        sfp0_rx_ready : in std_logic;

        sfp1_tx_ready : in std_logic;
        sfp1_rx_ready : in std_logic;
        
        sfp0_tx_triggers  : out std_logic_vector(7 downto 0);
        sfp0_rx_triggers  : in  std_logic_vector(7 downto 0);
        sfp0_delta_t_trig : in  std_logic_vector(7 downto 0);

        sfp1_tx_triggers  : out std_logic_vector(7 downto 0);
        sfp1_rx_triggers  : in  std_logic_vector(7 downto 0);
        sfp1_delta_t_trig : in  std_logic_vector(7 downto 0)
		);
end trigger;


architecture vhdl of trigger is

  signal pulseStretch_count     : naturalArray_16bit;
  signal pulseStretch_signal    : std_logic_vector(7 downto 0);
  signal pulseDelay_sr          : Array_16bit;
  signal coincident_trig_local  : std_logic;
  signal coincident_trig        : std_logic;
  signal coincident_trig_sys    : std_logic;

  signal delaySyncCtr           : std_logic_vector(3 downto 0);
  signal delaySyncCtr_sync      : std_logic_vector(3 downto 0);
  signal sfp1_delta_t_trig_sync : std_logic_vector(7 downto 0);
  signal sfp0_delay             : std_logic_vector(7 downto 0);
  signal sfp1_delay             : std_logic_vector(7 downto 0);
  signal local_wait             : std_logic_vector(7 downto 0);
  signal sfp0_wait              : std_logic_vector(7 downto 0);
  signal sfp1_wait              : std_logic_vector(7 downto 0);

  signal sfp0_trig_sync         : std_logic_vector(7 downto 0);
  signal sfp1_trig_sync         : std_logic_vector(7 downto 0);
  signal sfp0_trig_dly          : std_logic_vector(7 downto 0);
  signal sfp1_trig_dly          : std_logic_vector(7 downto 0);
  signal local_trig             : std_logic_vector(7 downto 0);
  signal local_trig_sync        : std_logic_vector(7 downto 0);
  signal local_trig_dly         : std_logic_vector(7 downto 0);
  signal sfp0_dly_ctr           : naturalArray_16bit;
  signal sfp1_dly_ctr           : naturalArray_16bit;
  signal local_dly_ctr          : naturalArray_16bit;
  signal sfp0_stretch_ctr       : naturalArray_16bit;
  signal sfp1_stretch_ctr       : naturalArray_16bit;
  signal local_stretch_ctr      : naturalArray_16bit;

  signal sfp0_reset_rx_clk      : std_logic;
  signal sfp0_reset_tx_clk      : std_logic;
  signal sfp1_reset_rx_clk      : std_logic;
  signal sfp1_reset_tx_clk      : std_logic;

  signal sfp0_trig_0_sys        : std_logic;
  signal sfp1_trig_0_sys        : std_logic;
  signal remote_trigger         : std_logic;

  signal sfp0_local_trig_out    : std_logic_vector(7 downto 0);
  signal sfp1_local_trig_out    : std_logic_vector(7 downto 0);
  signal sfp0_remote_trigger    : std_logic;
  signal sfp1_remote_trigger    : std_logic;

  signal coincidentTimeoutCnt   : natural range 0 to 511;
  
begin

  -- reset sync
  sfp0_reset_rx_Sync : sync_Bits_Altera
    generic map(
      BITS => 1,        -- number of bit to be synchronized
      INIT => x"00000000",
      SYNC_DEPTH => 2   -- generate SYNC_DEPTH many stages, at least 2
      )
    port map(
      Clock     => sfp0_rx_clk,     -- <Clock>  output clock domain
      Input(0)  => reset or not sfp0_rx_ready, -- @async:  input bits
      Output(0) => sfp0_reset_rx_clk  -- @Clock:  output bits
      );

  sfp0_reset_tx_Sync : sync_Bits_Altera
    generic map(
      BITS => 1,        -- number of bit to be synchronized
      INIT => x"00000000",
      SYNC_DEPTH => 2   -- generate SYNC_DEPTH many stages, at least 2
      )
    port map(
      Clock     => sfp0_tx_clk,     -- <Clock>  output clock domain
      Input(0)  => reset or not sfp0_tx_ready, -- @async:  input bits
      Output(0) => sfp0_reset_tx_clk  -- @Clock:  output bits
      );

  sfp1_reset_rx_Sync : sync_Bits_Altera
    generic map(
      BITS => 1,        -- number of bit to be synchronized
      INIT => x"00000000",
      SYNC_DEPTH => 2   -- generate SYNC_DEPTH many stages, at least 2
      )
    port map(
      Clock     => sfp1_rx_clk,     -- <Clock>  output clock domain
      Input(0)  => reset or not sfp1_rx_ready, -- @async:  input bits
      Output(0) => sfp1_reset_rx_clk  -- @Clock:  output bits
      );

  sfp1_reset_tx_Sync : sync_Bits_Altera
    generic map(
      BITS => 1,        -- number of bit to be synchronized
      INIT => x"00000000",
      SYNC_DEPTH => 2   -- generate SYNC_DEPTH many stages, at least 2
      )
    port map(
      Clock     => sfp1_tx_clk,     -- <Clock>  output clock domain
      Input(0)  => reset or not sfp1_tx_ready, -- @async:  input bits
      Output(0) => sfp1_reset_tx_clk  -- @Clock:  output bits
      );


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

  selfTrigOut : process(All)
    variable tout : std_logic;
  begin
    tout := '0';
    for i in 0 to N-1 loop
      if trig.sw(i) = '1' then
        tout := '1';
      end if;
    end loop;
    self_trig <= tout;
  end process;

  
TRIG_MULTIPLEXER: process(all)
begin
	for i in 0 to N-1 loop
      case trig.source(i) is
        when 0 => trig_out(i) <= '0';				-- off
        when 1 => trig_out(i) <= trig.sw(i);		-- software trigger
        when 2 => trig_out(i) <= hw_trig;		    -- hardware trigger
        when 3 => trig_out(i) <= coincident_trig_local; -- local ACC coincident
        when 4 => trig_out(i) <= coincident_trig_sys;   -- inter-ACC coincident
        when 5 => trig_out(i) <= remote_trigger;    -- trigger from remote ACC 
        when others => trig_out(i) <= '0';
      end case;
	end loop;
end process;


-- external TX trigger multiplexer 
TrigOutMux : process(all)
begin
  if trig.tx_source_sfp0 = '0' then
    sfp0_tx_triggers <= sfp0_local_trig_out; -- send ACDC triggers to external ACC
  else
    sfp0_tx_triggers <= "0000000" & sfp0_remote_trigger; -- send confirmation trigger back to external ACC
  end if;

  if trig.tx_source_sfp1 = '0' then
    sfp1_tx_triggers <= sfp1_local_trig_out; -- send ACDC triggers to external ACC
  else
    sfp1_tx_triggers <= "0000000" & sfp1_remote_trigger; -- send confirmation trigger back to external ACC
  end if;
end process;

-- trig counters
trig_counters: process(clock.sys)
begin
  if rising_edge(clock.sys) then
    for i in 0 to N-1 loop
      if reset = '1' then
        selftrig_counts(i) <= (others => '0');
        cointrig_counts(i) <= (others => '0');
      else
        if trig.sw(i) then
          selftrig_counts(i) <= std_logic_vector(unsigned(selftrig_counts(i)) + 1);
        end if;
        
      end if;
    end loop;
  end if;
end process;

-- ACDC confirm logic

-- fiber delay compensation calculation

-- equalize both delay measurements to the same clock (sfp0_tx_clk)
delaySynctRam : TrigCounterRam
  port map(
    wrclock   => sfp1_tx_clk,
    wraddress => delaySyncCtr,
    data      => sfp1_delta_t_trig,
    wren      => '1',

    rdclock   => sfp0_tx_clk,
    rdaddress => delaySyncCtr_sync,
    q         => sfp1_delta_t_trig_sync
    );

delaySyncCtr2 : GrayCounter
  generic map (N => 4)
  port map (
    Clk    => sfp1_tx_clk,
    Rst    => '0',
    En     => '1',
    output => delaySyncCtr
    );

delayCntSync : sync_Bits_Altera
  generic map(
    BITS => 4,        -- number of bit to be synchronized
    INIT => x"00000000",
    SYNC_DEPTH => 2   -- generate SYNC_DEPTH many stages, at least 2
    )
  port map(
    Clock    => sfp0_tx_clk,       -- <Clock>  output clock domain
    Input    => delaySyncCtr,      -- @async:  input bits
    Output   => delaySyncCtr_sync  -- @Clock:  output bits
    );

-- calculate the one way delays
-- subtract CDC delay and devide by 2 for 1 way delays 
sfp0_delay <= std_logic_vector(shift_right(unsigned(sfp0_delta_t_trig     ) - natural(4), 1));
sfp1_delay <= std_logic_vector(shift_right(unsigned(sfp1_delta_t_trig_sync) - natural(4), 1));
-- calculate delays to line up trigger sigals 
calcWaits: process(all)
begin
  if sfp1_delta_t_trig_sync = x"00" and sfp0_delta_t_trig = x"00" then
    local_wait <= x"00";
    sfp0_wait <= x"00";
    sfp1_wait <= x"00";
  elsif sfp1_delta_t_trig_sync = x"00" then
    local_wait <= sfp0_delay;
    sfp0_wait <= x"00";
    sfp1_wait <= x"00";
  elsif sfp0_delta_t_trig = x"00" then
    local_wait <= sfp1_delay;
    sfp0_wait <= x"00";
    sfp1_wait <= x"00";
  elsif sfp1_delta_t_trig_sync > sfp0_delta_t_trig then
    local_wait <= sfp1_delay;
    sfp0_wait <= std_logic_vector(unsigned(sfp1_delay) - unsigned(sfp0_delay));
    sfp1_wait <= x"00";
  else
    local_wait <= sfp0_delay;
    sfp0_wait <= x"00";
    sfp1_wait <= std_logic_vector(unsigned(sfp0_delay) - unsigned(sfp1_delay));
  end if;
end process;

-- sync all triggers to same clock domain for coincident trigger processing
trig_sync : for i in 0 to 7 generate
  sfp0_trigSync : pulseSync2_lowlatency
    port map(
      src_clk      => sfp0_rx_clk,
      src_pulse    => sfp0_rx_triggers(i),
      src_aresetn  => not sfp0_reset_rx_clk,

      dest_clk     => sfp0_tx_clk,
      dest_pulse   => sfp0_trig_sync(i),
      dest_aresetn => not sfp0_reset_tx_clk);

  sfp1_trigSync : pulseSync2_lowlatency
    port map(
      src_clk      => sfp1_rx_clk,
      src_pulse    => sfp1_rx_triggers(i),
      src_aresetn  => not sfp1_reset_rx_clk,

      dest_clk     => sfp0_tx_clk,
      dest_pulse   => sfp1_trig_sync(i),
      dest_aresetn => not sfp0_reset_tx_clk);

  local_trigSync : pulseSync2_lowlatency
    port map(
      src_clk      => clock.sys,
      src_pulse    => local_trig(i),
      src_aresetn  => not reset,

      dest_clk     => sfp0_tx_clk,
      dest_pulse   => local_trig_sync(i),
      dest_aresetn => not sfp0_reset_tx_clk);
end generate trig_sync;

--delay and stretch triggers to align all trigger signals
interACCDelay : process(sfp0_tx_clk)
begin
  if rising_edge(sfp0_tx_clk) then
    if(sfp0_reset_tx_clk = '1') then
      for i in 0 to 7 loop
        sfp0_dly_ctr(i) <= 0;
        sfp1_dly_ctr(i) <= 0;
        local_dly_ctr(i) <= 0;
      end loop;
    else
      for i in 0 to 7 loop
        if sfp0_dly_ctr(i) > 0 then
          sfp0_dly_ctr(i) <= sfp0_dly_ctr(i) - 1;
        elsif sfp0_trig_sync(i) = '1' then
          sfp0_dly_ctr(i) <= to_integer(unsigned(sfp0_wait)) + trig.coincidentStretch;
        end if;

        if sfp1_dly_ctr(i) > 0 then
          sfp1_dly_ctr(i) <= sfp1_dly_ctr(i) - 1;
        elsif sfp1_trig_sync(i) = '1' then
          sfp1_dly_ctr(i) <= to_integer(unsigned(sfp1_wait)) + trig.coincidentStretch;
        end if;
        
        if local_dly_ctr(i) > 0 then
          local_dly_ctr(i) <= local_dly_ctr(i) - 1;
        elsif local_trig_sync(i) = '1' then
          local_dly_ctr(i) <= to_integer(unsigned(local_wait)) + 1 + trig.coincidentStretch;
        end if;

      end loop;      
    end if;
  end if;
end process;

stretch_mux : process(all)
begin
  for i in 0 to 7 loop
    if sfp0_dly_ctr(i) >= 1 and sfp0_dly_ctr(i) <= trig.coincidentStretch then
      sfp0_trig_dly(i) <= '1';
    else
      sfp0_trig_dly(i) <= '0';
    end if;

    if sfp1_dly_ctr(i) >= 1 and sfp1_dly_ctr(i) <= trig.coincidentStretch then
      sfp1_trig_dly(i) <= '1';
    else
      sfp1_trig_dly(i) <= '0';
    end if;

    if local_dly_ctr(i) >= 1 and local_dly_ctr(i) <= trig.coincidentStretch then
      local_trig_dly(i) <= '1';
    else
      local_trig_dly(i) <= '0';
    end if;
  end loop;
end process;

-- coincident logic


-- pulse delays for local ACDC triggers
local_trig(0) <= pulseDelay_sr(0)(0);
local_trig(1) <= pulseDelay_sr(1)(0);
local_trig(2) <= pulseDelay_sr(2)(0);
local_trig(3) <= pulseDelay_sr(3)(0);
local_trig(4) <= pulseDelay_sr(4)(0);
local_trig(5) <= pulseDelay_sr(5)(0);
local_trig(6) <= pulseDelay_sr(6)(0);
local_trig(7) <= pulseDelay_sr(7)(0);
pulse_stretch: process(clock.sys)
begin
  if rising_edge(clock.sys) then
    if reset = '1' then
      for i in 0 to N-1 loop
        pulseDelay_sr(i) <= x"0000";
      end loop;      
    else
      for i in 0 to N-1 loop
        pulseDelay_sr(i)(15) <= '0';
        for j in 0 to 14 loop
          if j = trig.coincidentDelay(i) then
            pulseDelay_sr(i)(j) <= ACDC_triggers(i);
          else
            pulseDelay_sr(i)(j) <= pulseDelay_sr(i)(j+1);
          end if;
        end loop;
      end loop;
    end if;
  end if;
end process;

trigger_timeout_counter: process(sfp0_tx_clk)
begin
  if rising_edge(sfp0_tx_clk) then
    if sfp0_reset_tx_clk = '1' then
      coincidentTimeoutCnt <= 0;
    else
      if coincident_trig = '1' then
        coincidentTimeoutCnt <= 2*trig.coincidentStretch;
      elsif coincidentTimeoutCnt > 0 then
        coincidentTimeoutCnt <= coincidentTimeoutCnt - 1;
      end if;
    end if;
  end if;
end process;

coincident_trig_logic: process(all)
  variable trigs : std_logic_vector(2 downto 0);
begin
  if or_reduce(trig.sfp0RxMask and sfp0_trig_dly) then
    trigs(0) := '1';
  else
    trigs(0) := '0';
  end if;
  if or_reduce(trig.sfp1RxMask and sfp1_trig_dly) then
    trigs(1) := '1';
  else
    trigs(1) := '0';
  end if;
  if or_reduce(trig.localMask  and local_trig_dly) then
    trigs(2) := '1';
  else
    trigs(2) := '0';
  end if;
  
  if (coincidentTimeoutCnt = 0) and (and_reduce((not trig.coincidentMask_interstation) or trigs) = '1') then
    coincident_trig <= '1';
  else
    coincident_trig <= '0';
  end if;
end process;

coincident_trig_local <= '1' when (and_reduce((not trig.coincidentMask) or local_trig)) else '0';

sfp0_trigSync_remoteTrig : pulseSync2_lowlatency
  port map(
    src_clk      => sfp0_tx_clk,
    src_pulse    => coincident_trig,
    src_aresetn  => not sfp0_reset_tx_clk,

    dest_clk     => sfp0_tx_clk,
    dest_pulse   => sfp0_remote_trigger,
    dest_aresetn => not sfp0_reset_tx_clk);

sfp1_trigSync_remoteTrig : pulseSync2_lowlatency
  port map(
    src_clk      => sfp0_tx_clk,
    src_pulse    => coincident_trig,
    src_aresetn  => not sfp0_reset_tx_clk,

    dest_clk     => sfp1_tx_clk,
    dest_pulse   => sfp1_remote_trigger,
    dest_aresetn => not sfp1_reset_tx_clk);

local_trigSync_remoteTrig : pulseSync2_lowlatency
  port map(
    src_clk      => sfp0_tx_clk,
    src_pulse    => coincident_trig,
    src_aresetn  => not sfp0_reset_tx_clk,

    dest_clk     => clock.sys,
    dest_pulse   => coincident_trig_sys,
    dest_aresetn => not reset);


-- sync input triggers to clock.sys for remote trigger signal 
sfp0_trigSync_sys : pulseSync2_lowlatency
  port map(
    src_clk      => sfp0_tx_clk,
    src_pulse    => sfp0_rx_triggers(0),
    src_aresetn  => not sfp0_reset_tx_clk,

    dest_clk     => clock.sys,
    dest_pulse   => sfp0_trig_0_sys,
    dest_aresetn => not reset);

sfp1_trigSync_sys : pulseSync2_lowlatency
  port map(
    src_clk      => sfp1_tx_clk,
    src_pulse    => sfp1_rx_triggers(0),
    src_aresetn  => not sfp1_reset_tx_clk,

    dest_clk     => clock.sys,
    dest_pulse   => sfp1_trig_0_sys,
    dest_aresetn => not reset);

remote_trigger <= (trig.remoteTrigMask(0) and sfp0_trig_0_sys) or (trig.remoteTrigMask(1) and sfp1_trig_0_sys);

-- sync trigger signals to output SFP clocks 
trigSync_ext: for i in 0 to 7 generate
  sfp0_trigSync_Ext : pulseSync2_lowlatency
    port map(
      src_clk      => clock.sys,
      src_pulse    => local_trig(i),
      src_aresetn  => not reset,

      dest_clk     => sfp0_tx_clk,
      dest_pulse   => sfp0_local_trig_out(i),
      dest_aresetn => not sfp0_reset_tx_clk);

  sfp1_trigSync_Ext : pulseSync2_lowlatency
    port map(
      src_clk      => clock.sys,
      src_pulse    => local_trig(i),
      src_aresetn  => not reset,

      dest_clk     => sfp1_tx_clk,
      dest_pulse   => sfp1_local_trig_out(i),
      dest_aresetn => not sfp1_reset_tx_clk);
end generate;



--pulse_stretch: process(clock.sys)
--begin
--  if rising_edge(clock.sys) then
--    if reset = '1' then
--      for i in 0 to N-1 loop
--        pulseDelay_sr(i) <= x"0000";
--        pulseStretch_count(i) <= 0;
--        pulseStretch_signal(i) <= '0';
--      end loop;      
--    else
--      for i in 0 to N-1 loop
--        pulseDelay_sr(i)(15) <= '0';
--        for j in 0 to 14 loop
--          if j = trig.coincidentDelay(i) then
--            pulseDelay_sr(i)(j) <= ACDC_triggers(i);
--          else
--            pulseDelay_sr(i)(j) <= pulseDelay_sr(i)(j+1);
--          end if;
--        end loop;
--      end loop;
--
--      for i in 0 to N-1 loop
--        if(pulseDelay_sr(i)(0) = '1') then
--          pulseStretch_signal(i) <= '1';
--          pulseStretch_count(i) <= trig.coincidentStretch(i);
--        elsif(pulseStretch_count(i) > 0) then
--          pulseStretch_signal(i) <= '1';
--          pulseStretch_count(i) <= pulseStretch_count(i) - 1;
--        else
--          pulseStretch_signal(i) <= '0';
--        end if;
--      end loop;
--    end if;
--  end if;
--end process;

-- coincidence logic
--coincident_trig <= '1' when (and_reduce((not trig.coincidentMask) or pulseStretch_signal)) else '0';

end vhdl;
