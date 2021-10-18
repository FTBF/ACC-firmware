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
		DIPswitch		: in   std_logic_vector (9 downto 0)		-- switch reads as a 10-bit binary number msb left (sw1), lsb right (sw10); switch open = logic 1		
	);
end ACC_main;
	
	
	
architecture vhdl of	ACC_main is


	signal	ledSetup				: LEDSetup_type;
	signal	ledSetup_sw			: LEDSetup_type;
	signal	ledSetup_hw			: LEDSetup_type;
	signal	ledPreset			: ledPreset_type;
	signal	clock					: 	clock_type;
	signal	reset					: 	reset_type;
	signal	usb					:	usb_type;
	signal	serialTx				:	serialTx_type;
	signal	serialRx				:	serialRx_type;
	signal	rxBuffer				:	rxBuffer_type;
	signal	trig					:	trigSetup_type;
   signal   localInfo_readReq : std_logic;
   signal   trig_out : std_logic_vector(7 downto 0);
   signal   readChannel : natural range 0 to 15;
	signal	acdcBoardDetect: std_logic_vector(7 downto 0);
	signal	useExtRef: std_logic;
	signal	pps: std_logic;
	signal	hw_trig: std_logic;
	signal	beamgate_trig: std_logic;
	signal	testCmd	: 	testCmd_type;
	signal 	led_trig	: std_logic_vector(8 downto 0);
	signal 	led_mono	: std_logic_vector(8 downto 0);
    signal param_readReq        : std_logic;
    signal param_num            : natural range 0 to 255;
    signal LVDS_In_hs   	: std_logic_vector(2*N-1 downto 0);
    signal LVDS_In_flat_p	: std_logic_vector(2*N-1 downto 0);
    signal LVDS_In_flat_n	: std_logic_vector(2*N-1 downto 0);
    signal error_counts  : DoubleArray_16bit;
    signal count_reset   : std_logic;
    signal delayCommand            : std_logic_vector(11 downto 0);
    signal delayCommandSet         : std_logic;
    signal delayCommandMask        : std_logic_vector(15 downto 0);
    signal io_config_clkena : std_logic_vector(15 downto 0);
    signal io_config_datain : std_logic;
    signal io_config_update : std_logic;
	
	
begin





---------------------------------------------
--	INPUT SOURCE SELECT
---------------------------------------------

systemOut.out0 <= beamgate_trig;


PPS_SELECT: process(SMA, systemIn, testCmd)
begin
	case testCmd.pps_useSMA is
		when '1' => pps <= SMA(3); 
		when '0' => pps <= systemIn.in0;  
		when others => null;
	end case;
end process;


BGT_SELECT: process(SMA, systemIn, testCmd)
begin
	case testCmd.beamgateTrigger_useSMA is
		when '1' => beamgate_trig <= SMA(4); 
		when '0' => beamgate_trig <= systemIn.in1; 
		when others => null;
	end case;
end process;






------------------------------------
--	TRIGGER
------------------------------------

TRIG_MAP: trigger Port map(
		clock		=> clock.sys,
		reset		=> reset.global,
		trig	 	=> trig,
		pps		=> pps,
		hw_trig	=> SMA(6) xor trig.SMA_invert,
		beamGate_trig => beamgate_trig,
		trig_out	=> trig_out
		);

		
		
		
				
------------------------------------
--	RESET
------------------------------------

RESET_PROCESS : process(clock.sys)
variable t: natural := 0;		-- elaspsed time counter
variable r: std_logic;
begin
	if (rising_edge(clock.sys)) then 				
		if (reset.request = '1' or reset.request2 = '1' or clock.altpllLock = '0') then t := 0; end if;   -- restart counter if new reset request					 										
		if (t >= 400) then r := '0'; else r := '1'; t := t + 1; end if;
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
		pps				=> pps,
		resetRequest	=> reset.request2,
		useExtRef 		=> useExtRef
);


------------------------------------
--	LVDS 
------------------------------------
-- There are 4 signals which are connected via an ethernet cable between ACC and ACDC using LVDS signalling:
-- Clock, serial Tx, serial Rx, trigger / gate
LVDS_GEN: process(all)
begin
	for i in N-1 downto 0 loop
		LVDS_Out(i)(0) <=	serialTx.serial(i);
		LVDS_Out(i)(1) <=	trig_out(i);
        LVDS_Out(i)(2) <=	'0';
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
    reset            => reset.global,
    delayCommand     => delayCommand,
    delayCommandSet  => delayCommandSet,
    delayCommandMask => delayCommandMask,
    LVDS_In_hs       => LVDS_In_hs,
    error_counts     => error_counts,
    count_reset      => count_reset,
    io_config_clkena => io_config_clkena,
    io_config_datain => io_config_datain,
    io_config_update => io_config_update);

------------------------------------
--	COMMAND HANDLER
------------------------------------
CMD_HANDLER_MAP: commandHandler port map (
		reset						=> reset.global,
		clock				      => clock,      
      din		      	   => usb.rxData_out,
      din_valid				=> usb.rxData_valid,
      localInfo_readReq    => localInfo_readReq,
		rxBuffer_resetReq    => rxBuffer.resetReq,
		rxBuffer_readReq    	=> rxBuffer.readReq,
        param_readReq      => param_readReq,
        param_num          => param_num,
		globalResetReq       => reset.request,
      trig		            => trig,
      readChannel          => readChannel,
		ledSetup					=> ledSetup_sw,
		ledPreset				=> LEDPreset,
		extCmd.enable     	=> serialTx.enable,    -- an 8 bit field that selects the board(s) to which the command will be sent
		extCmd.data       	=> serialTx.cmd,
		extCmd.valid         => serialTx.cmd_valid,
		testCmd					=> testCmd,
        delayCommand          => delayCommand,
        delayCommandSet       => delayCommandSet,
        delayCommandMask      => delayCommandMask,
        count_reset           => count_reset
      );

  

  
  
------------------------------------
--	DATA HANDLER
------------------------------------
-- handles data frame transmission over usb
DATA_HANDLER_MAP: dataHandler port map (
		reset			=> reset.global,
		clock			=> clock.sys,
		serialRx		=> serialRx,
		pllLock		=> clock.altPllLock,
		trig			=> trig,
		channel    	=> readChannel,		
      ramReadEnable  => rxBuffer.ramReadEn,
      ramAddress     => rxBuffer.ramAddress,
      ramData        => rxBuffer.ramDataOut,
      rxDataLen		=> rxBuffer.dataLen,
		frame_received	=> rxBuffer.frame_received,
      bufferReadoutDone => rxBuffer.ramReadDone,  -- byte wide, one bit for each channel
        param_readReq      => param_readReq,
        param_num          => param_num,
		dout 		         => usb.txData_in,
		txReq					=> usb.txReq,
      txAck             => usb.txAck,
      txLockReq         => usb.tx_busReq,
      txLockAck         => usb.tx_busAck,
      rxBuffer_readReq	=> rxBuffer.readReq,
		localInfo_readRequest=> localInfo_readReq,    
      acdcBoardDetect     	=> acdcBoardDetect,
		useExtRef		=> useExtRef,
        error_counts    => error_counts
);
	

 
	 	 
	 
	 
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
	tx_buffer_map: serialTx_buffer port map (
		clock				=> clock.sys,	 
      din				=> serialTx.cmd,
		din_txReq		=> serialTx.cmd_valid and serialTx.enable(i),
		din_txAck		=> open,			-- no flow control on writing to tx buffer, but it is unlikely to overflow because there is a large fifo
		dout				=> serialTx.byte(i),
		dout_txReq		=> serialTx.byte_txReq(i),
		dout_txAck		=> serialTx.byte_txAck(i)
	);	
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
     

		
		

------------------------------------
--	SERIAL RX BUFFER
------------------------------------
-- stores a burst of received data in ram
rxBuffer_gen	:	 for i in N-1 downto 0 generate
	rxBuffer_map : serialRx_buffer
	port map (
		reset				=> rxBuffer.reset(i),-- need to get this signal from data handler
		clock				=> clock.sys,	--system clock		 
		din				=> serialRx.data(i), --data in, 16 bits
		din_valid		=> serialRx.valid(i) and (not serialRx.kout(i)),	-- only valid data is received, not control codes	 
		read_enable		=> rxBuffer.ramReadEn(i), 	--enable reading from RAM block
		read_address	=> rxBuffer.ramAddress,--ram address
		buffer_empty 	=> rxBuffer.empty(i),
		frame_received	=> rxBuffer.frame_received(i),
		dataLen		   => rxBuffer.dataLen(i), -- length of data stored in ram
		dout				=> rxBuffer.ramDataOut(i)--data out
		);	
end generate;


uart_rxBuffer_reset_gen: 
process(reset.global, rxBuffer)
begin
	for i in N-1 downto 0 loop
		rxBuffer.reset(i) <= reset.global or rxBuffer.resetReq(i) or rxBuffer.ramReadDone(i);
	end loop;
end process;
	
	
	
	
------------------------------------
--	USB DRIVER 
------------------------------------
usbDriver_gen: usbDriver port map (
	clock   					=> clock.sys,
	rxData_in  	  	 		=> usb.rxData_in,
	txData_out				=> usb.txData_out,
   txBufferReady 			=> usb.txBufferReady,
   rxDataAvailable	  	=> usb.rxDataAvailable, -- FLAG A      (note this flag is on usb clock)
   busWriteEnable 		=> usb.busWriteEnable,     --when high the fpga outputs data onto the usb bus
   PKTEND  					=> usb.PKTEND,	--usb packet end flag
   SLWR		        		=> usb.SLWR,	--usb slave interface write signal
   SLOE         			=> usb.SLOE,   	--usb slave interface bus output enable, active low
   SLRD     	   		=> usb.SLRD,		--usb  slave interface bus read, active low
   FIFOADR  	   		=> usb.FIFOADR, -- usb endpoint fifo select, essentially selects the tx fifo or rx fifo
	tx_busReq  				=> usb.tx_busReq,  -- request to lock the bus in tx mode, preventing any interruptions from usb read
	tx_busAck  				=> usb.tx_busAck,  
   txData_in       		=> usb.txData_in,		
   txReq		        		=> usb.txReq,
   txAck		        		=> usb.txAck,		
   rxData_out      		=> usb.rxData_out,
	rxData_valid     		=> usb.rxData_valid,
	test						=> usb.test
);
        
        
		  
-- signals from usb chip
usb.txBufferReady <= usb_in.CTL(2); -- usb flag c meaning the usb chip is ready to accept tx data  (note this flag is on usb clock)  	
usb.rxDataAvailable <= usb_in.CTL(0);

-- signals to usb chip
usb_bus.PA(7) <= '0';		-- SLCS signal, the slave chip select (Permanently enabled)
usb_bus.PA(6) <= usb.PKTEND;
usb_out.RDY(1) <= usb.SLWR;     
usb_out.RDY(0) <= usb.SLRD;
usb_bus.PA(2) <= usb.SLOE;
usb_bus.PA(5 downto 4) <= usb.FIFOADR;





       
         
------------------------------------
--	USB BUS CONTROL
------------------------------------
-- tristate control of the usb bus for reading and writing
usb_io_buffer	: iobuf
	port map(
		datain	=>	usb.txData_out,	-- tx data to the usb chip bus
		oe			=> usb.busWriteEnable_vec,	-- low = read from bus, high = write to bus
		dataio	=> usb_bus.FD,	         -- the 16-bit wide bidirectional data bus of the Cypress chip
		dataout	=> usb.rxData_in); -- data from the usb chip
      
usb_bus_oe: process(usb)
begin
	for i in 15 downto 0 loop usb.busWriteEnable_vec(i) <= usb.busWriteEnable; end loop;
end process;

         
      





------------------------------------
--	LED DRIVER
------------------------------------
-- led index:	red:2, yellow:1, green:0
--
-- Each led's function is determined by a 16 bit setup word:
-- [7:0] = signal source select , [11:8] = channel select, [12] = invert, [13] = flash, [15:14] = not used

LED_MUX: process(all)
variable ch: natural;
variable sig: std_logic;
begin
	for i in 0 to 2 loop
		-- determine the signal that will drive the led, according to the setup word
		ch := to_integer(unsigned(ledSetup(i)(11 downto 8)));
		case ledSetup(i)(7 downto 0) is				
-- basic
			when x"00" => sig := '0';
			when x"01" => sig := '1';			
-- serial 
			when x"10" => sig := serialRx.symbol_align_error(ch);
			when x"11" => sig := serialRx.symbol_code_error(ch);
			when x"12" => sig := serialRx.disparity_error(ch);
			when x"13" => sig := serialRx.rx_clock_fail(ch);
			when x"14" => sig := serialRx.kout(ch);
			when x"15" => sig := serialRx.valid(ch);
			when x"16" => sig := serialRx.valid(ch) and (not serialRx.kout(ch));
			when x"17" => sig := serialRx.valid(ch) and serialRx.kout(ch);
			when x"18" => sig := serialTx.byte_txReq(ch);
			when x"19" => sig := serialTx.byte_txAck(ch);
			when x"1A" => sig := serialTx.cmd_valid;
			when x"1B" => sig := serialTx.enable(ch);
-- lvds
			when x"20" => sig := '0';
			when x"21" => sig := '0';
			when x"22" => sig := '0';
			when x"23" => sig := '0';
-- usb
			when x"30" => sig := usb.rxData_valid;
			when x"31" => sig := usb.txReq;
			when x"32" => sig := usb.txAck;
			when x"33" => sig := usb.tx_busReq;
			when x"34" => sig := usb.tx_busAck;
			when x"35" => sig := usb.rxData_valid or usb.txAck;
			when x"36" => sig := usb.test(1);	
-- ctrl
			when x"40" => sig := reset.request;
			when x"41" => sig := rxbuffer.empty(ch);
			when x"42" => sig := useExtRef;
			when x"43" => sig := reset.request2;
			when x"44" => sig := '0';
			when x"45" => sig := localInfo_readReq;
			when x"46" => sig := rxBuffer.reset(ch);
			when x"47" => sig := acdcBoardDetect(ch);
			when x"48" => sig := rxBuffer.readReq;			
-- trig
			when x"50" => sig := trig_out(ch);
			when x"51" => sig := trig.sw;			
-- input
			when x"60" => sig := pps;
			when x"61" => sig := SMA(ch);
			when x"62" => sig := systemIn.in0;
			when x"63" => sig := systemIn.in1;			
-- others
			when others => sig := '0';			
		end case;
				
		led_trig(i) <= sig xor ledSetup(i)(12);			-- invert option	
	end loop;
end process;

LED_SIG_DETECT: for i in 0 to 2 generate
	LED_MONOSTABLE: monostable_async_level port map (clock.sys, 4000000, led_trig(i), led_mono(i));
end generate;


LED_CTRL: process(clock.sys)
variable t_flash: natural:= 0;
variable flash_state: std_logic;
begin
	if (rising_edge(clock.sys)) then
		for i in 0 to 2 loop
			case ledSetup(i)(13) is
				when '1' =>	led(i) <= not (led_trig(i) and flash_state);			-- flash option
				when '0' => led(i) <= not led_mono(i);		-- monostable option  
				when others => null;
			end case;			
			t_flash := t_flash + 1;
			if (t_flash >= 20000000) then t_flash := 0; end if;
			if (t_flash >= 10000000) then flash_state := '0'; else flash_state := '1'; end if;
		end loop;
	end if;
end process;
			



ledPreset(0) <= (x"0035", x"0042", x"0147"); -- usb rx or tx; use ext ref; board detect 1
ledPreset(1) <= (x"0110", x"0112", x"0113");	-- symbol align error(1); disparity error(1); rx clock fail(1)
ledPreset(2) <= (x"0361", x"0261", x"0161"); -- SMA(3); SMA(2); SMA(1)
ledPreset(3) <= (x"0661", x"0561", x"0461"); -- SMA(6); SMA(5); SMA(4)
ledPreset(4) <= (x"0063", x"0062", x"0060"); -- systemIn.in1; systemIn.in0; pps
ledPreset(5) <= (x"0031", x"0030", x"001A");	-- usb tx; usb rx; serialTx.cmd_valid
ledPreset(6) <= (x"0051", x"0045", x"001A");	-- trig.sw; localInfo_readReq; serialTx.cmd_valid
ledPreset(7) <= (x"0247", x"0147", x"0047");	-- acdcBoardDetect(2,1,0)
ledPreset(8) <= (x"0547", x"0447", x"0347");	-- acdcBoardDetect(5,4,3)
ledPreset(9) <= (x"0000", x"0747", x"0647");	-- acdcBoardDetect(7,6)
ledPreset(10) <= (x"0001", x"0001", x"0001");	--	all on
ledPreset(11) <= (x"0000", x"0000", x"0000");	--	all off



LED_PRESET_CTRL: process(all)
begin
	if (DIPswitch(9) = '0') then		-- dip switch 1 (left) is ON = use dipswitch to choose led preset signal mappings
		ledSetup <= ledSetup_hw;	-- use hardware setting from dip switch
	else
		ledSetup <= ledSetup_sw;	-- use software setting from command handler
	end if;
end process;



ledSetup_hw <= ledPreset(to_integer(unsigned(not DIPswitch(3 downto 0))));		-- dip switch 7 to 10 (right)  = bit [3:0] of led preset select
 

 
end vhdl;
