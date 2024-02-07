---------------------------------------------------------------------------------
--
-- PROJECT:      ACC
-- FILE:         commandHandler.vhd
-- AUTHOR:       Joe Pastika
-- DATE:         March 2022
--
-- DESCRIPTION:  Synchronize all signals between ETH clock and target clock 
--
---------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
use work.defs.all;
use work.LibDG.all;


entity commandSync is
  port (
    -- control signals
    reset		: 	in   	std_logic;
    clock		: 	in		clock_type;
    eth_clk     :   in      std_logic;
    eth_reset   :   in      std_logic;
    sfp0_tx_clk :   in      std_logic;
    sfp0_rx_clk :   in      std_logic;
    sfp1_tx_clk :   in      std_logic;
    sfp1_rx_clk :   in      std_logic;
    sfp0_tx_ready : in std_logic;
    sfp0_rx_ready : in std_logic;
    sfp1_tx_ready : in std_logic;
    sfp1_rx_ready : in std_logic;
    
    -- registers
    config_z          : in  config_type;
    config            : out config_type;

    reg               : in  readback_reg_type;
    reg_z             : out readback_reg_type
    );
end commandSync;


architecture vhdl of commandSync is

  signal nreset : std_logic;
  signal nreset_sync0 : std_logic;
  signal nreset_sync1 : std_logic;
  signal nreset_sync2 : std_logic;

  signal trig_src_z : std_logic_vector(3*N-1 downto 0);
  signal trig_src   : std_logic_vector(3*N-1 downto 0);

  signal readChannel_z : std_logic_vector(15 downto 0);
  signal readChannel   : std_logic_vector(15 downto 0);

  signal trigWindow_z :  std_logic_vector(31 downto 0);
  signal trigWindow   :  std_logic_vector(31 downto 0);

  signal SFP0_reset_tx : std_logic;
  signal SFP0_reset_rx : std_logic;
  signal SFP1_reset_tx : std_logic;
  signal SFP1_reset_rx : std_logic;

  signal coincidentStretch_z : std_logic_vector(15 downto 0);
  
begin

  config.dataFIFO_auto <= config_z.dataFIFO_auto;
  
  -- synchronizers
  nreset <= not reset;
  reset_sync : process(clock.serial25, clock.serialpllLock)
  begin
    if clock.serialpllLock = '0' then
      nreset_sync0 <= '0';
      nreset_sync1 <= '0';
      nreset_sync2 <= '0';
    else
      if rising_edge(clock.serial25) then
        nreset_sync0 <= nreset;
        nreset_sync1 <= nreset_sync0;
        nreset_sync2 <= nreset_sync1;
      end if;
    end if;
  end process;

  sfp0_reset_tx_sync : sync_Bits_Altera
    generic map (
      BITS       => 1,
      INIT       => "1",
      SYNC_DEPTH => 2)
    port map(
      Clock     => sfp0_tx_clk,
      Input(0)  => reset,-- or not sfp0_tx_ready,
      Output(0) => SFP0_reset_tx
      );

  sfp0_reset_rx_sync : sync_Bits_Altera
    generic map (
      BITS       => 1,
      INIT       => "1",
      SYNC_DEPTH => 2)
    port map(
      Clock     => sfp0_rx_clk,
      Input(0)  => reset,-- or not sfp0_rx_ready,
      Output(0) => SFP0_reset_rx
      );

  sfp1_reset_tx_sync : sync_Bits_Altera
    generic map (
      BITS       => 1,
      INIT       => "1",
      SYNC_DEPTH => 2)
    port map(
      Clock     => sfp1_tx_clk,
      Input(0)  => reset,-- or not sfp1_tx_ready,
      Output(0) => SFP1_reset_tx
      );

  sfp1_reset_rx_sync : sync_Bits_Altera
    generic map (
      BITS       => 1,
      INIT       => "1",
      SYNC_DEPTH => 2)
    port map(
      Clock     => sfp1_rx_clk,
      Input(0)  => reset,-- or not sfp1_rx_ready,
      Output(0) => SFP1_reset_rx
      );


  -- sync to serial25 clock
  pulseSync2_delaySet: pulseSync2
    port map (
      src_clk      => eth_clk,
      src_pulse    => config_z.delayCommandSet,
      src_aresetn  => eth_reset,
      dest_clk     => clock.serial25,
      dest_pulse   => config.delayCommandSet,
      dest_aresetn => nreset_sync2);

  pulseSync2_countReset: pulseSync2
    port map (
      src_clk      => eth_clk,
      src_pulse    => config_z.count_reset,
      src_aresetn  => eth_reset,
      dest_clk     => clock.serial25,
      dest_pulse   => config.count_reset,
      dest_aresetn => nreset_sync2);

  pulseSync2_manchesterTrain: pulseSync2
    port map (
      src_clk      => eth_clk,
      src_pulse    => config_z.train_manchester_links,
      src_aresetn  => eth_reset,
      dest_clk     => clock.sys,
      dest_pulse   => config.train_manchester_links,
      dest_aresetn => nreset);

  param_handshake_delayCmd: param_handshake_sync
    generic map (
      WIDTH => config_z.delayCommand'length)
    port map (
      src_clk      => eth_clk,
      src_params   => config_z.delayCommand,
      src_aresetn  => eth_reset,
      dest_clk     => clock.serial25,
      dest_params  => config.delayCommand,
      dest_aresetn => nreset_sync2);

  param_handshake_delayMask: param_handshake_sync
    generic map (
      WIDTH => config_z.delayCommandMask'length)
    port map (
      src_clk      => eth_clk,
      src_params   => config_z.delayCommandMask,
      src_aresetn  => eth_reset,
      dest_clk     => clock.serial25,
      dest_params  => config.delayCommandMask,
      dest_aresetn => nreset_sync2);

  param_handshake_backpressureThresh: param_handshake_sync
    generic map (
      WIDTH => config_z.backpressure_threshold'length)
    port map (
      src_clk      => eth_clk,
      src_params   => config_z.backpressure_threshold,
      src_aresetn  => eth_reset,
      dest_clk     => clock.serial25,
      dest_params  => config.backpressure_threshold,
      dest_aresetn => nreset_sync2);

  pulseSync2_globalResetReq: pulseSync2
    port map (
      src_clk      => eth_clk,
      src_pulse    => config_z.globalResetReq,
      src_aresetn  => eth_reset,
      dest_clk     => clock.sys,
      dest_pulse   => config.globalResetReq,
      dest_aresetn => nreset);

  param_handshake_coincidentMask: param_handshake_sync
    generic map (
      WIDTH => config_z.trig.coincidentMask'length)
    port map (
      src_clk      => eth_clk,
      src_params   => config_z.trig.coincidentMask,
      src_aresetn  => eth_reset,
      dest_clk     => clock.sys,
      dest_params  => config.trig.coincidentMask,
      dest_aresetn => nreset);

  param_handshake_coincidentMask_interstation: param_handshake_sync
    generic map (
      WIDTH => config_z.trig.coincidentMask_interstation'length)
    port map (
      src_clk      => eth_clk,
      src_params   => config_z.trig.coincidentMask_interstation,
      src_aresetn  => eth_reset,
      dest_clk     => sfp0_tx_clk,
      dest_params  => config.trig.coincidentMask_interstation,
      dest_aresetn => not SFP0_reset_tx);

  param_handshake_coincidentStretch: param_handshake_sync
    generic map (
      WIDTH => 16)
    port map (
      src_clk      => eth_clk,
      src_params   => std_logic_vector(to_unsigned(config_z.trig.coincidentStretch, 16)),
      src_aresetn  => eth_reset,
      dest_clk     => sfp0_tx_clk,
      dest_params  => coincidentStretch_z,
      dest_aresetn => not SFP0_reset_tx);
  config.trig.coincidentStretch <= to_integer(unsigned(coincidentStretch_z));

  param_handshake_remoteTrigMask: param_handshake_sync
    generic map (
      WIDTH => config_z.trig.remoteTrigMask'length)
    port map (
      src_clk      => eth_clk,
      src_params   => config_z.trig.remoteTrigMask,
      src_aresetn  => eth_reset,
      dest_clk     => clock.sys,
      dest_params  => config.trig.remoteTrigMask,
      dest_aresetn => nreset);
  
  param_handshake_coincidentTrigMasks: param_handshake_sync
    generic map (
      WIDTH => 24)
    port map (
      src_clk      => eth_clk,
      src_params   => config_z.trig.sfp1RxMask & config_z.trig.sfp0RxMask & config_z.trig.localMask,
      src_aresetn  => eth_reset,
      dest_clk     => sfp0_tx_clk,
      dest_params(7 downto 0)   => config.trig.localMask,
      dest_params(15 downto 8)  => config.trig.sfp0RxMask,
      dest_params(23 downto 16) => config.trig.sfp1RxMask,
      dest_aresetn => not SFP0_reset_tx);
  
  param_handshake_sfp0_tx_source: param_handshake_sync
    generic map (
      WIDTH => 1)
    port map (
      src_clk         => eth_clk,
      src_params(0)   => config_z.trig.tx_source_sfp0,
      src_aresetn     => eth_reset,
      dest_clk        => sfp0_tx_clk,
      dest_params(0)  => config.trig.tx_source_sfp0,
      dest_aresetn    => not SFP0_reset_tx);

  param_handshake_sfp1_tx_source: param_handshake_sync
    generic map (
      WIDTH => 1)
    port map (
      src_clk         => eth_clk,
      src_params(0)   => config_z.trig.tx_source_sfp1,
      src_aresetn     => eth_reset,
      dest_clk        => sfp1_tx_clk,
      dest_params(0)  => config.trig.tx_source_sfp1,
      dest_aresetn    => not SFP1_reset_tx);

  loop_gen : for i in 0 to N-1 generate
    signal coincidentDelay_z : std_logic_vector(15 downto 0);
    --signal coincidentStretch_z : std_logic_vector(15 downto 0);
    signal rxFIFO_resetReq : std_logic;
    signal rxFIFO_resetReq_count : unsigned(4 downto 0);
  begin
    pulseSync2_rxFIFOResetReq: pulseSync2
      port map (
        src_clk      => eth_clk,
        src_pulse    => config_z.rxFIFO_resetReq(i),
        src_aresetn  => eth_reset,
        dest_clk     => clock.serial25,
        dest_pulse   => rxFIFO_resetReq,
        dest_aresetn => nreset_sync2);

    rxFIFO_resetReq_stretch : process(clock.serial25, nreset_sync2, rxFIFO_resetReq)
    begin
      if(nreset_sync2 = '0' or rxFIFO_resetReq = '1') then
        rxFIFO_resetReq_count <= "10000";
        config.rxFIFO_resetReq(i) <= '1';
      else
        if rising_edge(clock.serial25) then
          if(rxFIFO_resetReq_count > "00000") then
            config.rxFIFO_resetReq(i) <= '1';
            rxFIFO_resetReq_count <= rxFIFO_resetReq_count - 1;
          else
            rxFIFO_resetReq_count <= "00000";
            config.rxFIFO_resetReq(i) <= '0';
          end if;
        end if;
      end if;
    end process;
    

    param_handshake_coincientDelay: param_handshake_sync
      generic map (
        WIDTH => 16)
      port map (
        src_clk      => eth_clk,
        src_params   => std_logic_vector(to_unsigned(config_z.trig.coincidentDelay(i), 16)),
        src_aresetn  => eth_reset,
        dest_clk     => clock.sys,
        dest_params  => coincidentDelay_z,
        dest_aresetn => nreset);
    config.trig.coincidentDelay(i) <= to_integer(unsigned(coincidentDelay_z));
      
    pulseSync2_rxBuffer_resetReq: pulseSync2
      port map (
        src_clk      => eth_clk,
        src_pulse    => config_z.rxBuffer_resetReq(i),
        src_aresetn  => eth_reset,
        dest_clk     => clock.sys,
        dest_pulse   => config.rxBuffer_resetReq(i),
        dest_aresetn => nreset);

    pulseSync2_trigsw: pulseSync2
      port map (
        src_clk      => eth_clk,
        src_pulse    => config_z.trig.sw(i),
        src_aresetn  => eth_reset,
        dest_clk     => clock.sys,
        dest_pulse   => config.trig.sw(i),
        dest_aresetn => nreset);
  end generate;

  pulseSync2_localInfo_readReq: pulseSync2
    port map (
      src_clk      => eth_clk,
      src_pulse    => config_z.localInfo_readReq,
      src_aresetn  => eth_reset,
      dest_clk     => clock.sys,
      dest_pulse   => config.localInfo_readReq,
      dest_aresetn => nreset);

  pulseSync2_rxBuffer_readReq: pulseSync2
    port map (
      src_clk      => eth_clk,
      src_pulse    => config_z.rxBuffer_readReq,
      src_aresetn  => eth_reset,
      dest_clk     => clock.sys,
      dest_pulse   => config.rxBuffer_readReq,
      dest_aresetn => nreset);

  config.dataFIFO_readReq <= config_z.dataFIFO_readReq;
  config.readChannel <= config_z.readChannel;

  pulseSync2_phaseUpdate: pulseSync2
    port map (
      src_clk      => eth_clk,
      src_pulse    => config_z.phaseUpdate,
      src_aresetn  => eth_reset,
      dest_clk     => clock.sys,
      dest_pulse   => config.phaseUpdate,
      dest_aresetn => nreset);

  param_handshake_phaseCtrls: param_handshake_sync
    generic map (
      WIDTH => 6)
    port map (
      src_clk      => eth_clk,
      src_params   => config_z.updn & config_z.cntsel,
      src_aresetn  => eth_reset,
      dest_clk     => clock.sys,
      dest_params(5) => config.updn,
      dest_params(4 downto 0) => config.cntsel,
      dest_aresetn => nreset);

  trig_src_gen : for i in 0 to N-1 generate
    trig_src_z(3*i+2 downto 3*i) <= std_logic_vector(to_unsigned(config_z.trig.source(i), 3));
    config.trig.source(i) <= to_integer(unsigned(trig_src(3*i+2 downto 3*i)));
  end generate;
  
  param_handshake_trig_src: param_handshake_sync
    generic map (
      WIDTH => 3*N)
    port map (
      src_clk      => eth_clk,
      src_params   => trig_src_z,
      src_aresetn  => eth_reset,
      dest_clk     => clock.sys,
      dest_params  => trig_src,
      dest_aresetn => nreset);

  trigWindow_z <= std_logic_vector(to_unsigned(config_z.trig.windowStart, 16)) & std_logic_vector(to_unsigned(config_z.trig.windowLen, 16));
  config.trig.windowStart <= to_integer(unsigned(trigWindow(31 downto 16)));
  config.trig.windowLen   <= to_integer(unsigned(trigWindow(15 downto 0)));
  param_handshake_trigOther: param_handshake_sync
    generic map (
      WIDTH => 33)
    port map (
      src_clk      => eth_clk,
      src_params   => config_z.trig.SMA_invert & trigWindow_z,
      src_aresetn  => eth_reset,
      dest_clk     => clock.sys,
      dest_params(32)  => config.trig.SMA_invert,
      dest_params(31 downto 0) => trigWindow,
      dest_aresetn => nreset);

  pulseSync2_resync_SFP0: pulseSync2
    port map (
      src_clk      => eth_clk,
      src_pulse    => config_z.resync_SFP0,
      src_aresetn  => eth_reset,
      dest_clk     => sfp0_tx_clk,
      dest_pulse   => config.resync_SFP0,
      dest_aresetn => not SFP0_reset_tx);

  pulseSync2_SFP0_resetErrCtr: pulseSync2
    port map (
      src_clk      => eth_clk,
      src_pulse    => config_z.SFP0_resetErrCtr,
      src_aresetn  => eth_reset,
      dest_clk     => sfp0_rx_clk,
      dest_pulse   => config.SFP0_resetErrCtr,
      dest_aresetn => not SFP0_reset_rx);

  param_handshake_trigHSSI_SFP0: param_handshake_sync
    generic map (
      WIDTH => 1)
    port map (
      src_clk       => eth_clk,
      src_params(0) => config_z.SFP0_cntLoopback,
      src_aresetn   => eth_reset,
      dest_clk      => sfp0_tx_clk,
      dest_params(0)=> config.SFP0_cntLoopback,
      dest_aresetn  => not SFP0_reset_tx);

  param_handshake_trigHSSI_SFP1: param_handshake_sync
    generic map (
      WIDTH => 1)
    port map (
      src_clk       => eth_clk,
      src_params(0) => config_z.SFP1_cntLoopback,
      src_aresetn   => eth_reset,
      dest_clk      => sfp1_tx_clk,
      dest_params(0)=> config.SFP1_cntLoopback,
      dest_aresetn  => not SFP1_reset_tx);

  config.SFP0_tx_disable <= config_z.SFP0_tx_disable;
  config.SFP1_tx_disable <= config_z.SFP1_tx_disable;
  config.SFP0_rs0 <= config_z.SFP0_rs0;
  config.SFP1_rs0 <= config_z.SFP1_rs0;
  config.SFP0_rs1 <= config_z.SFP0_rs1;
  config.SFP1_rs1 <= config_z.SFP1_rs1;

  -- readout register syncronization 
  reg_readback_by16 : for i in 0 to 2*N-1 generate
    param_handshake_countRegs: param_handshake_sync
      generic map (
        WIDTH => 16*4)
      port map (
        src_clk      => clock.serial25,
        src_params   => reg.parity_error_counts(i) & reg.byte_fifo_occ(i) & reg.prbs_error_counts(i) & reg.symbol_error_counts(i),
        src_aresetn  => nreset_sync2,
        dest_clk     => eth_clk,
        dest_params(63 downto 48) => reg_z.parity_error_counts(i),
        dest_params(47 downto 32) => reg_z.byte_fifo_occ(i),
        dest_params(31 downto 16) => reg_z.prbs_error_counts(i),
        dest_params(15 downto 0)  => reg_z.symbol_error_counts(i),
        dest_aresetn => eth_reset);
  end generate;

  reg_readback_by8 : for i in 0 to N-1 generate
  begin
    -- already in the eth_clk domain
    reg_z.data_occ(i)  <= reg.data_occ(i);
    reg_z.rxDataLen(i) <= reg.rxDataLen(i);

    param_handshake_countRegs: param_handshake_sync
      generic map (
        WIDTH => 32*2)
      port map (
        src_clk      => clock.sys,
        src_params   => reg.selftrig_counts(i) & reg.cointrig_counts(i),
        src_aresetn  => nreset,
        dest_clk     => eth_clk,
        dest_params(63 downto 32) => reg_z.selftrig_counts(i),
        dest_params(31 downto 0)  => reg_z.cointrig_counts(i),
        dest_aresetn => eth_reset);
  end generate;
  
  param_handshake_seriaRX_occ: param_handshake_sync
    generic map (
      WIDTH => 4*8)
    port map (
      src_clk      => clock.sys,
      src_params   => reg.serialRX_rx_clock_fail & reg.serialRX_symbol_align_error & reg.serialRX_symbol_code_error & reg.serialRX_disparity_error,
      src_aresetn  => nreset,
      dest_clk     => eth_clk,
      dest_params(31 downto 24) => reg_z.serialRX_rx_clock_fail,
      dest_params(23 downto 16) => reg_z.serialRX_symbol_align_error,
      dest_params(15 downto 8)  => reg_z.serialRX_symbol_code_error,
      dest_params(7  downto 0)  => reg_z.serialRX_disparity_error,
      dest_aresetn => eth_reset);

  param_handshake_pllLock: param_handshake_sync
    generic map (
      WIDTH => 4)
    port map (
      src_clk      => clock.sys,
      src_params   => reg.pllLock,
      src_aresetn  => nreset,
      dest_clk     => eth_clk,
      dest_params  => reg_z.pllLock,
      dest_aresetn => eth_reset);

  param_handshake_sfp0_pll_ready_bsb_latency: param_handshake_sync
    generic map (
      WIDTH => 14)
    port map (
      src_clk      => sfp0_rx_clk,
      src_params   => reg.sfp0_pllLock & reg.sfp0_bitSlipBoundary & reg.sfp0_latency,
      src_aresetn  => not SFP0_reset_rx,
      dest_clk     => eth_clk,
      dest_params(13) => reg_z.sfp0_pllLock,
      dest_params(12 downto 8) => reg_z.sfp0_bitSlipBoundary,
      dest_params(7 downto 0) => reg_z.sfp0_latency,
      dest_aresetn => eth_reset);

  -- already in eth clock domain
  reg_z.sfp0_ready <= reg.sfp0_ready;
  -- signals directly from SPF modules
  reg_z.sfp0_mod_abs <= reg.sfp0_mod_abs;
  reg_z.sfp0_rx_los <= reg.sfp0_rx_los;
  reg_z.sfp0_tx_fault <= reg.sfp0_tx_fault;
    
  param_handshake_sfp0_dispErr: param_handshake_sync
    generic map (
      WIDTH => 32)
    port map (
      src_clk      => sfp0_rx_clk,
      src_params   => reg.sfp0_dispErr,
      src_aresetn  => not SFP0_reset_rx,
      dest_clk     => eth_clk,
      dest_params  => reg_z.sfp0_dispErr,
      dest_aresetn => eth_reset);

  param_handshake_sfp0_symbolErr: param_handshake_sync
    generic map (
      WIDTH => 32)
    port map (
      src_clk      => sfp0_rx_clk,
      src_params   => reg.sfp0_symbolErr,
      src_aresetn  => not SFP0_reset_rx,
      dest_clk     => eth_clk,
      dest_params  => reg_z.sfp0_symbolErr,
      dest_aresetn => eth_reset);

  param_handshake_sfp1_pll_ready_bsb_latency: param_handshake_sync
    generic map (
      WIDTH => 14)
    port map (
      src_clk      => sfp1_rx_clk,
      src_params   => reg.sfp1_pllLock & reg.sfp1_bitSlipBoundary & reg.sfp1_latency,
      src_aresetn  => not SFP1_reset_rx,
      dest_clk     => eth_clk,
      dest_params(13) => reg_z.sfp1_pllLock,
      dest_params(12 downto 8) => reg_z.sfp1_bitSlipBoundary,
      dest_params(7 downto 0) => reg_z.sfp1_latency,
      dest_aresetn => eth_reset);

  -- already in eth clock domain
  reg_z.sfp1_ready <= reg.sfp1_ready;
  -- signals directly from SPF modules
  reg_z.sfp1_mod_abs <= reg.sfp1_mod_abs;
  reg_z.sfp1_rx_los <= reg.sfp1_rx_los;
  reg_z.sfp1_tx_fault <= reg.sfp1_tx_fault;
    
  param_handshake_sfp1_dispErr: param_handshake_sync
    generic map (
      WIDTH => 32)
    port map (
      src_clk      => sfp1_rx_clk,
      src_params   => reg.sfp1_dispErr,
      src_aresetn  => not SFP1_reset_rx,
      dest_clk     => eth_clk,
      dest_params  => reg_z.sfp1_dispErr,
      dest_aresetn => eth_reset);

  param_handshake_sfp1_symbolErr: param_handshake_sync
    generic map (
      WIDTH => 32)
    port map (
      src_clk      => sfp1_rx_clk,
      src_params   => reg.sfp1_symbolErr,
      src_aresetn  => not SFP1_reset_rx,
      dest_clk     => eth_clk,
      dest_params  => reg_z.sfp1_symbolErr,
      dest_aresetn => eth_reset);

end vhdl;

