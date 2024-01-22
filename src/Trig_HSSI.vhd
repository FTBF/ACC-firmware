---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
--
-- PROJECT:      FTBF-LAPPD
-- FILE:         Trig_HSSI.vhd
-- AUTHOR:       J. PAstika
-- DATE:         December 2022
--
-- DESCRIPTION:  top-level HSSI interface for trigger links 
--
---------------------------------------------------------------------------------


library IEEE; 
use ieee.std_logic_1164.all;
USE ieee.numeric_std.ALL;
use ieee.std_logic_misc.all;
use work.defs.all;
use work.components.all;
use work.LibDG.all;



entity Trig_HSSI is
  port(		
    tx_serial_data  : out std_logic;
    rx_serial_data  : in  std_logic;
    SFP_ref_clk    : in  std_logic;

    tx_clkout       : out std_logic;
    rx_clkout       : out std_logic;

	reset			: in  reset_type;
    config          : in  config_type;

    counter_feedback : in  std_logic;

    pll_locked                  : out std_logic;
    rx_bitslipboundaryselectout : out std_logic_vector(4 downto 0);
    delta_t_trig                : out std_logic_vector(7 downto 0);
    tx_ready                    : out std_logic;
    rx_ready                    : out std_logic;
    symbolErrors                : out std_logic_vector(31 downto 0);
    disparityErrors             : out std_logic_vector(31 downto 0);

    eth_clk         : in  std_logic;
    eth_resetn      : in  std_logic;

    phy_mgmt_in          : in  Avalon_in_type;
    phy_mgmt_out         : out Avalon_out_type;

    reconfig_mgmt_in     : in  Avalon_in_type;
    reconfig_mgmt_out    : out Avalon_out_type;

    tx_triggers          : in  std_logic_vector(7 downto 0);
    rx_triggers          : out std_logic_vector(7 downto 0)

);
end Trig_HSSI;


architecture vhdl of Trig_HSSI is

  signal phy_mgmt_clk                : std_logic;
  signal phy_mgmt_clk_reset          : std_logic;
  signal pll_ref_clk                 : std_logic_vector(0 downto 0);
  signal tx_parallel_data            : std_logic_vector(15 downto 0);
  signal rx_parallel_data            : std_logic_vector(15 downto 0);                     --            rx_parallel_data.export
  signal rx_parallel_data_tmp        : std_logic_vector(31 downto 0);                     --            rx_parallel_data.export
  signal rx_runningdisp              : std_logic_vector(1 downto 0);                      --              rx_runningdisp.export
  signal rx_disperr                  : std_logic_vector(1 downto 0);                      --                  rx_disperr.export
  signal rx_errdetect                : std_logic_vector(1 downto 0);                      --                rx_errdetect.export
  signal rx_disperr_z                : std_logic_vector(1 downto 0);                      --                  rx_disperr.export
  signal rx_errdetect_z              : std_logic_vector(1 downto 0);                      --                rx_errdetect.export
  signal tx_datak                    : std_logic_vector(1 downto 0); --                    tx_datak.export
  signal rx_datak                    : std_logic_vector(1 downto 0);                      --                    rx_datak.export
  signal rx_datak_tmp                : std_logic_vector(3 downto 0);                      --                    rx_datak.export
  signal reconfig_from_xcvr          : std_logic_vector(91 downto 0);                     --          reconfig_from_xcvr.reconfig_from_xcvr
  signal reconfig_to_xcvr            : std_logic_vector(139 downto 0);
  signal rx_align_state              : std_logic;
  signal rx_count_txsync             : std_logic_vector(7 downto 0);
  signal trigRamCtr_txClk            : std_logic_vector(3 downto 0);
  signal trigRamCtr_rxClk            : std_logic_vector(3 downto 0);
  signal reset_rx_clk                : std_logic;
  signal reset_tx_clk                : std_logic;

  signal tx_clkout_loc               : std_logic;
  signal rx_clkout_loc               : std_logic;
  
  signal reconfig_busy               : std_logic;
  signal reconfig_mgmt_clk           : std_logic;
  signal reconfig_mgmt_clk_reset     : std_logic;

  
begin

  tx_clkout <= tx_clkout_loc;
  rx_clkout <= rx_clkout_loc;

  -- reset sync
  sfp0_reset_rx_Sync : sync_Bits_Altera
    generic map(
      BITS => 1,        -- number of bit to be synchronized
      INIT => x"00000000",
      SYNC_DEPTH => 2   -- generate SYNC_DEPTH many stages, at least 2
      )
    port map(
      Clock     => rx_clkout_loc,     -- <Clock>  output clock domain
      Input(0)  => reset.global or reconfig_busy, -- @async:  input bits
      Output(0) => reset_rx_clk  -- @Clock:  output bits
      );

  sfp0_reset_tx_Sync : sync_Bits_Altera
    generic map(
      BITS => 1,        -- number of bit to be synchronized
      INIT => x"00000000",
      SYNC_DEPTH => 2   -- generate SYNC_DEPTH many stages, at least 2
      )
    port map(
      Clock      => tx_clkout_loc,     -- <Clock>  output clock domain
      Input(0)  => reset.global or reconfig_busy, -- @async:  input bits
      Output(0) => reset_tx_clk  -- @Clock:  output bits
      );

  pll_ref_clk(0) <= SFP_ref_clk;
  phy_mgmt_clk            <= eth_clk;
  reconfig_mgmt_clk       <= eth_clk;
  phy_mgmt_clk_reset      <= not eth_resetn;
  reconfig_mgmt_clk_reset <= not eth_resetn;

  --tx logic 
  prep_sfp0_data : process(tx_clkout_loc, reset_tx_clk)
    variable count : unsigned(7 downto 0);
  begin
    if reset_tx_clk = '1' then
      tx_parallel_data <= x"0000";
      count            := x"00";
      tx_datak         <= "00";
    else    
      if rising_edge(tx_clkout_loc) then
        if config.resync_SFP0 = '1' then
          tx_parallel_data <= x"56bc";
          count            := x"00";
          tx_datak         <= "01";
        else
          if counter_feedback = '1' then
            tx_parallel_data <= rx_count_txsync         & tx_triggers;
          else
            tx_parallel_data <= std_logic_vector(count) & tx_triggers;
          end if;
          count            := count + 1;
          tx_datak         <= "00";
        end if;
      end if;
    end if;
  end process;

  -- error counters
  sfp0_rx_errCnt : process(rx_clkout_loc, config.SFP0_resetErrCtr, reset_rx_clk)
  begin
    if reset_rx_clk = '1' or config.SFP0_resetErrCtr = '1' then
      disparityErrors <= x"00000000";
      symbolErrors    <= x"00000000";
      rx_disperr_z  <= "00";
      rx_errdetect_z <= "00";
    else
      if rising_edge(rx_clkout_loc) then
        rx_disperr_z <= rx_disperr;
        rx_errdetect_z <= rx_errdetect;
        if or_reduce(rx_disperr_z) = '1' then
          disparityErrors <= std_logic_vector(unsigned(disparityErrors) + 1);
        end if;
        if or_reduce(rx_errdetect_z) = '1' then
          symbolErrors <= std_logic_vector(unsigned(symbolErrors) + 1);
        end if;
      end if;
    end if;
  end process;

  -- word aligner logic
  sfp0_rx_sr : process(rx_clkout_loc)
  begin
    if rising_edge(rx_clkout_loc) then
      rx_parallel_data_tmp(15 downto 0) <= rx_parallel_data_tmp(31 downto 16);
      rx_datak_tmp(1 downto 0)          <= rx_datak_tmp(3 downto 2);

      if   (rx_parallel_data_tmp(23 downto 16) = x"bc" and rx_datak_tmp(2) = '1') then
        rx_align_state <= '0';
      elsif(rx_parallel_data_tmp(31 downto 24) = x"bc" and rx_datak_tmp(3) = '1') then
        rx_align_state <= '1';
      end if;
    end if;
  end process;

  rx_triggers <= rx_parallel_data(7 downto 0);
  sfp_rx_wordalign : process(all)
  begin
    if(rx_align_state = '0') then
      rx_parallel_data <= rx_parallel_data_tmp(15 downto 0);
      rx_datak         <= rx_datak_tmp(1 downto 0);
    else
      rx_parallel_data <= rx_parallel_data_tmp(23 downto 8);
      rx_datak         <= rx_datak_tmp(2 downto 1);
    end if;
  end process;

  -- counter sync logic 
  trigCountRam : TrigCounterRam
    port map(
      wrclock   => rx_clkout_loc,
      wraddress => trigRamCtr_rxClk,
      data      => rx_parallel_data(15 downto 8),
      wren      => '1',

      rdclock   => tx_clkout_loc,
      rdaddress => trigRamCtr_txClk,
      q         => rx_count_txsync
      );

  trigRamCtr : GrayCounter
    generic map (N => 4)
    port map (
      Clk    => rx_clkout_loc,
      Rst    => reset_rx_clk,
      En     => '1',
      output => trigRamCtr_rxClk
      );

  TrigCounterSync : sync_Bits_Altera
    generic map(
      BITS => 4,        -- number of bit to be synchronized
      INIT => x"00000000",
      SYNC_DEPTH => 2   -- generate SYNC_DEPTH many stages, at least 2
      )
    port map(
      Clock    => tx_clkout_loc,     -- <Clock>  output clock domain
      Input    => trigRamCtr_rxClk, -- @async:  input bits
      Output   => trigRamCtr_txClk  -- @Clock:  output bits
      );

  calc_deltat : process(tx_clkout_loc)
  begin
    if rising_edge(tx_clkout_loc) then
      delta_t_trig <= std_logic_vector(unsigned(tx_parallel_data(15 downto 8)) - unsigned(rx_count_txsync));
    end if;
  end process;

  -- trigger link phy
  trigPhy : Trig_phy
	port map (
      phy_mgmt_clk                => phy_mgmt_clk,
      phy_mgmt_clk_reset          => phy_mgmt_clk_reset,
      phy_mgmt_address            => phy_mgmt_in.address,
      phy_mgmt_read               => phy_mgmt_in.read,
      phy_mgmt_readdata           => phy_mgmt_out.readdata,
      phy_mgmt_waitrequest        => phy_mgmt_out.waitrequest,
      phy_mgmt_write              => phy_mgmt_in.write,
      phy_mgmt_writedata          => phy_mgmt_in.writedata,

      tx_ready                    => tx_ready,
      rx_ready                    => rx_ready,

      pll_ref_clk                 => pll_ref_clk,
      pll_locked(0)               => pll_locked,
      tx_serial_data(0)           => tx_serial_data,

      rx_serial_data(0)           => rx_serial_data,

      tx_clkout(0)                => tx_clkout_loc,
      tx_parallel_data            => tx_parallel_data,
      tx_datak                    => tx_datak,

      rx_clkout(0)                => rx_clkout_loc,
      rx_parallel_data            => rx_parallel_data_tmp(31 downto 16),
      rx_datak                    => rx_datak_tmp(3 downto 2),
      rx_runningdisp              => rx_runningdisp,
      rx_disperr                  => rx_disperr,
      rx_errdetect                => rx_errdetect,
      rx_bitslipboundaryselectout => rx_bitslipboundaryselectout,

      rx_is_lockedtoref           => open,
      rx_is_lockedtodata          => open,
      rx_signaldetect             => open,
      rx_patterndetect            => open,
      rx_syncstatus               => open,

      reconfig_from_xcvr          => reconfig_from_xcvr,
      reconfig_to_xcvr            => reconfig_to_xcvr
      );

  triglinkreconf : trigLinkReconfig
	port map (
      reconfig_busy             => reconfig_busy,
      mgmt_clk_clk              => reconfig_mgmt_clk,
      mgmt_rst_reset            => reconfig_mgmt_clk_reset,
      reconfig_mgmt_address     => reconfig_mgmt_in.address(6 downto 0),
      reconfig_mgmt_read        => reconfig_mgmt_in.read,
      reconfig_mgmt_readdata    => reconfig_mgmt_out.readdata,
      reconfig_mgmt_waitrequest => reconfig_mgmt_out.waitrequest,
      reconfig_mgmt_write       => reconfig_mgmt_in.write,
      reconfig_mgmt_writedata   => reconfig_mgmt_in.writedata,
      reconfig_to_xcvr          => reconfig_to_xcvr,
      reconfig_from_xcvr        => reconfig_from_xcvr
      );

end vhdl;
