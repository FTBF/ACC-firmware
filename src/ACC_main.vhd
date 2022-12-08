---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
--
-- PROJECT:      ANNIE 
-- FILE:         ACC_main.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         June 2021
--
-- DESCRIPTION:  top-level firmware module for ACC
--
---------------------------------------------------------------------------------


library IEEE; 
use ieee.std_logic_1164.all;
USE ieee.numeric_std.ALL; 
use work.defs.all;
use work.components.all;
use work.LibDG.all;



entity ACC_main is
	port(		
		clockIn			: in	clockSource_type;
		clockCtrl		: out	clockCtrl_type;
		systemIn			: in 	systemIn_type;	-- common lvds connetions 2x digital input (single RJ45 connector)
		systemOut		: out systemOut_type; -- common lvds connetions 1x digital output (single RJ45 connector)
		LVDS_In     		: in	LVDS_inputArray_type;
        LVDS_In_hs_p		: in	LVDS_inputArray_hs_type;
        LVDS_In_Hs_n		: in	LVDS_inputArray_hs_type;
		LVDS_Out			: out LVDS_outputArray_type;		
		led            : out	std_logic_vector(2 downto 0); -- red(2), yellow(1), green(0)				
		SMA				: inout	std_logic_vector(1 to 6);	
		USB_in			: in USB_in_type;
		USB_out			: out USB_out_type;
		USB_bus			: inout USB_bus_type;
        ETH_in          : in  ETH_in_type;
        ETH_out         : out ETH_out_type;
        ETH_mdc         : inout std_logic;
        ETH_mdio        : inout std_logic;
		DIPswitch		: in   std_logic_vector (9 downto 0)		-- switch reads as a 10-bit binary number msb left (sw1), lsb right (sw10); switch open = logic 1		
	);
end ACC_main;
	
	
	
architecture vhdl of	ACC_main is

	signal	clock					: 	clock_type;
	signal	reset					: 	reset_type;
	signal	serialTx				:	serialTx_type;
	signal	serialRx				:	serialRx_type;
	signal	rxBuffer				:	rxBuffer_type;
    signal   trig_out : std_logic_vector(7 downto 0);
    signal   trig_out_manchester : std_logic_vector(7 downto 0);
	signal	acdcBoardDetect: std_logic_vector(7 downto 0);
	signal	useExtRef: std_logic;
	signal	pps: std_logic;
	signal	hw_trig: std_logic;
	signal	beamgate_trig: std_logic;
    signal LVDS_In_hs   	: std_logic_vector(2*N-1 downto 0);
    signal LVDS_In_flat_p	: std_logic_vector(2*N-1 downto 0);
    signal LVDS_In_flat_n	: std_logic_vector(2*N-1 downto 0);
    signal prbs_error_counts  : DoubleArray_16bit;
    signal symbol_error_counts  : DoubleArray_16bit;
    signal io_config_clkena : std_logic_vector(15 downto 0);
    signal io_config_datain : std_logic;
    signal io_config_update : std_logic;
    signal data_out        : Array_16bit;
    signal data_occ        : Array_16bit;
    signal data_re         : std_logic_vector(N-1 downto 0);
    signal byte_fifo_occ   : DoubleArray_16bit;
    signal backpressure_out : std_logic_vector(N-1 downto 0);
    signal backpressure_out_man : std_logic_vector(N-1 downto 0);
    signal ACDC_triggers          : std_logic_vector(N-1 downto 0);
    signal ACDC_backpressure      : std_logic_vector(N-1 downto 0);
    signal rxFIFO_resetReq        : std_logic_vector(N-1 downto 0);
    signal self_trig       :  std_logic;
    signal selftrig_counts : Array_32bit;
    signal cointrig_counts : Array_32bit;

    signal eth_clk : std_logic;
    signal rx_addr : std_logic_vector (31 downto 0);
    signal rx_data : std_logic_vector (63 downto 0);
    signal rx_wren : std_logic;
    signal tx_data : std_logic_vector (63 downto 0);
    signal tx_rden : std_logic;
    signal config  : config_type;
    signal regs    : readback_reg_type;
    
    signal b_data       : std_logic_vector (63 downto 0);
    signal b_data_we    : std_logic;
    signal b_data_force : std_logic;
    signal b_enable     : std_logic; 


begin



---------------------------------------------
--	INPUT SOURCE SELECT
---------------------------------------------

systemOut.out0 <= beamgate_trig;


pps <= SMA(3); 
beamgate_trig <= SMA(4); 
SMA(5) <= self_trig;


------------------------------------
--	TRIGGER
------------------------------------

TRIG_MAP: trigger Port map(
		clock		=> clock,
		reset		=> reset.global,
		trig	 	=> config.trig,
		pps		=> pps,
		hw_trig	=> SMA(6) xor config.trig.SMA_invert,
		beamGate_trig => beamgate_trig,
        ACDC_triggers => ACDC_triggers,
		trig_out	=> trig_out,
        self_trig   => self_trig,
        selftrig_counts => selftrig_counts,
        cointrig_counts => cointrig_counts
		);
regs.selftrig_counts <= selftrig_counts;
regs.cointrig_counts <= cointrig_counts;

				
------------------------------------
--	RESET
------------------------------------

RESET_PROCESS : process(clock.sys)
variable t: natural := 0;		-- elaspsed time counter
variable r: std_logic;
begin
	if (rising_edge(clock.sys)) then 				
		if (reset.request = '1' or reset.request2 = '1' or clock.altpllLock = '0') then t := 0; end if;   -- restart counter if new reset request					 										
		if (t >= 40) then r := '0'; else r := '1'; t := t + 1; end if;
		reset.global <= r;
	end if;
end process;

      
------------------------------------
--	CLOCKS
------------------------------------

clockCtrl.clockSourceSelect <= not useExtRef;		-- clock source multiplexer control

clockGen_map: ClockGenerator Port map(
		clockIn			=> clockIn,		-- clock sources into the fpga
		clock				=> clock,			-- the generated clocks for use by the rest of the firmware
        reset           => reset,
		pps				=> pps,
		resetRequest	=> reset.request2,
		useExtRef 		=> useExtRef,
        phaseUpdate      => config.phaseUpdate,
        updn             => config.updn,
        cntsel           => config.cntsel
);
regs.pllLock <= clock.dpa2pllLock & clock.dpa1pllLock & clock.serialpllLock & clock.altpllLock;


------------------------------------
--	LVDS 
------------------------------------
-- There are 4 signals which are connected via an ethernet cable between ACC and ACDC using LVDS signalling:
-- Clock, serial Tx, serial Rx, trigger / gate
LVDS_GEN: process(all)
begin
	for i in N-1 downto 0 loop
		LVDS_Out(i)(0) <=	serialTx.serial(i);
		LVDS_Out(i)(1) <=	trig_out_manchester(i);
        LVDS_Out(i)(2) <=	backpressure_out_man(i);
        -- select low speed LVDS RX pair (slow control line)
        serialRx.serial(i)  <= LVDS_In(i)(0);
        --serialRx.serial(i)  <= LVDS_In(i)(0);
        -- LVDS_In_p/n(1) is a dedicated clock line and is unused 

        -- remap structured input into flat vector for iobuf
        LVDS_In_flat_p(2*i + 0) <= LVDS_In_hs_p(i)(0);
        LVDS_In_flat_p(2*i + 1) <= LVDS_In_hs_p(i)(1);
        LVDS_In_flat_n(2*i + 0) <= LVDS_In_hs_n(i)(0);
        LVDS_In_flat_n(2*i + 1) <= LVDS_In_hs_n(i)(1);
	end loop;
end process;

-- add layer of manchster encoding to pass DC signals through the AC coupled path
manchesterEncoders : for i in 0 to N-1 generate
  signal backpressure_out_z : std_logic;
begin

  manchester_encoder_trig: manchester_encoder
    port map (
      clock     => clock.sys,
      reset     => reset.global,
      trainTrig => config.train_manchester_links,
      sig_in    => trig_out(i),
      sig_out   => trig_out_manchester(i));

  sync_backpressure: sync_Bits_Altera
    generic map (
      BITS       => 1,
      INIT       => x"00000000",
      SYNC_DEPTH => 2)
    port map (
      Clock  => clock.sys,
      Input(0)  => backpressure_out(i),
      Output(0) => backpressure_out_z);
  
  manchester_encoder_backpressure: manchester_encoder
    port map (
      clock     => clock.sys,
      reset     => reset.global,
      trainTrig => config.train_manchester_links,
      sig_in    => backpressure_out_z,
      sig_out   => backpressure_out_man(i));
  
end generate;


serialRX_iobuf_inst: serialRX_iobuf
  port map (
    datain           => LVDS_In_flat_p,
    datain_b         => LVDS_In_flat_n,
    io_config_clk    => clock.serial25,
    io_config_clkena => io_config_clkena,
    io_config_datain => io_config_datain,
    io_config_update => io_config_update,
    dataout          => LVDS_In_hs);


------------------------------------
--	High speed serial RX
------------------------------------
serialRx_dataBuffer_inst: serialRx_dataBuffer
  port map (
    clock            => clock,
    reset            => reset,
    eth_clk          => eth_clk,
    rxFIFO_resetReq  => config.rxFIFO_resetReq,
    delayCommand     => config.delayCommand,
    delayCommandSet  => config.delayCommandSet,
    delayCommandMask => config.delayCommandMask,
    LVDS_In_hs       => LVDS_In_hs,
    data_out         => data_out,
    data_occ         => data_occ,
    data_re          => data_re,
    byte_fifo_occ    => regs.byte_fifo_occ,
    prbs_error_counts     => regs.prbs_error_counts,
    symbol_error_counts   => regs.symbol_error_counts,
    parity_error_counts   => regs.parity_error_counts,
    backpressure_threshold => config.backpressure_threshold,
    backpressure_out => backpressure_out,
    count_reset      => config.count_reset,
    trig_out         => ACDC_triggers,
    ACDC_backpressure_out => ACDC_backpressure,
    io_config_clkena => io_config_clkena,
    io_config_datain => io_config_datain,
    io_config_update => io_config_update
    );
regs.data_occ <= data_occ;

------------------------------------
--	COMMAND HANDLER
------------------------------------
CMD_HANDLER_MAP: commandHandler
  port map (
    reset         => reset.global,
    clock         => clock,
    eth_clk       => eth_clk,
    rx_addr       => rx_addr,
    rx_data       => rx_data,
    rx_wren       => rx_wren,
    tx_data       => tx_data,
    tx_rden       => tx_rden,
    config        => config,
    extCmd.data   => serialTx.cmd,
    extCmd.enable => serialTx.enable,
    extCmd.valid  => serialTx.cmd_valid,
    regs          => regs,
    serialRX_data => rxBuffer.fifoDataOut,
    serialRX_rden => rxBuffer.fifoReadEn
    );

rxBuffer.resetReq <= config.rxBuffer_resetReq;
rxBuffer.readReq <= config.rxBuffer_readReq;
reset.request <= config.globalResetReq;
                     
  
  
------------------------------------
--	DATA HANDLER
------------------------------------
dataHandler_inst: dataHandler
  port map (
    reset            => reset.global,
    clock            => clock.serial25,
    eth_clk          => eth_clk,
    b_data           => b_data,
    b_data_we        => b_data_we,
    b_data_force     => b_data_force,
    b_enable         => b_enable,
    dataFIFO_readReq => config.dataFIFO_readReq,
    dataFIFO_chan    => config.readChannel,
    dataFIFO_auto    => config.dataFIFO_auto,
    data_out         => data_out,
    data_occ         => data_occ,
    data_re          => data_re);
	 	 
	 
	 
------------------------------------
--	ACDC BOARD DETECT
------------------------------------
 -- check the comms link to see if the receiver is locked in
ACDC_Detect_process: process(clock.sys)
begin
	if (rising_edge(clock.sys)) then
		for i in 0 to N-1 loop 
			acdcBoardDetect(i) <= not serialRx.symbol_align_error(i);
		end loop;
	end if;
end process;	
 
 
 
  
 
------------------------------------
--	SERIAL TX BUFFER
------------------------------------
-- fifo & frame writer for commands to ACDC
tx_buffer_gen	:	 for i in N-1 downto 0 generate
  serialTx_buffer_map: serialTx_buffer
    port map (
      clock      => clock.sys,
      eth_clk    => eth_clk,
      din        => serialTx.cmd,
      din_txReq  => serialTx.cmd_valid and serialTx.enable(i),
      dout       => serialTx.byte(i),
      dout_txReq => serialTx.byte_txReq(i),
      dout_txAck => serialTx.byte_txAck(i));
end generate;
	
	
	
	
	
------------------------------------
--	SERIAL TX
------------------------------------
-- serial comms to the acdc
tx_comms_gen	:	 for i in N-1 downto 0 generate
	tx_comms_map : synchronousTx_8b10b port map (
		clock 		=> clock.sys,
		rd_reset		=> reset.global,
		din 			=> serialTx.byte(i),
		txReq			=> serialTx.byte_txReq(i),
		txAck			=>	serialTx.byte_txAck(i),
		dout 			=> serialTx.serial(i)		-- serial bitstream out		 			
	);
end generate;






------------------------------------
--	SERIAL RX
------------------------------------
-- serial comms from the acdc
rx_comms_gen	:	 for i in N-1 downto 0 generate
	rx_comms_map : synchronousRx_8b10b port map (
		clock_sys 				=> clock.sys,
		clock_x4					=> clock.x4,
		clock_x8					=> clock.x8,
		din						=> serialRx.serial(i),
		rx_clock_fail			=> serialRx.rx_clock_fail(i),
		symbol_align_error	=> serialRx.symbol_align_error(i),
		symbol_code_error		=> serialRx.symbol_code_error(i),
		disparity_error		=> serialRx.disparity_error(i),
		dout 						=> serialRx.data(i),
		kout						=> serialRx.kout(i),
		dout_valid				=> serialRx.valid(i)
	);
end generate;
regs.serialRX_rx_clock_fail      <= serialRx.rx_clock_fail;
regs.serialRX_symbol_align_error <= serialRx.symbol_align_error;
regs.serialRX_symbol_code_error  <= serialRx.symbol_code_error;
regs.serialRX_disparity_error    <= serialRx.disparity_error;
		
		

------------------------------------
--	SERIAL RX BUFFER
------------------------------------
-- stores a burst of received data in ram
rxBuffer_gen	:	 for i in N-1 downto 0 generate
begin
  rxBuffer_map: serialRx_buffer
    port map (
      reset        => rxBuffer.reset(i),
      clock        => clock.sys,
      eth_clk      => eth_clk,
      din          => serialRx.data(i),
      din_valid    => serialRx.valid(i) and (not serialRx.kout(i)),	-- only valid data is received, not control codes	 
      read_enable  => rxBuffer.fifoReadEn(i),
      buffer_empty => rxBuffer.empty(i),
      dataLen      => rxBuffer.dataLen(i),
      dout         => rxBuffer.fifoDataOut(i));
end generate;                     
regs.rxDataLen <= rxBuffer.dataLen;

                     ---- fix timing here 
uart_rxBuffer_reset_gen: 
process(reset.global, rxBuffer)
begin
	for i in N-1 downto 0 loop
		rxBuffer.reset(i) <= reset.global or rxBuffer.resetReq(i);
	end loop;
end process;
	
	
------------------------------------
--	Ethernet interface
------------------------------------

ethernet_adapter_inst: ethernet_adapter
  port map (
    clock    => clock,
    reset    => reset.global,
    ETH_in   => ETH_in,
    ETH_out  => ETH_out,
    ETH_mdc  => ETH_mdc,
    ETH_mdio => ETH_mdio,
    user_addr    => DIPswitch(7 downto 0),
    eth_clk      => eth_clk,
    rx_addr      => rx_addr,
    rx_data      => rx_data,
    rx_wren      => rx_wren,
    tx_data      => tx_data,
    tx_rden      => tx_rden,
    b_data       => b_data,
    b_data_we    => b_data_we,
    b_data_force => b_data_force,
    b_enable     => b_enable);


 
end vhdl;
