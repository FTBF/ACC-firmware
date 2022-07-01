---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
-- PROJECT:      ANNIE 
-- FILE:         defs.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         May 2021
--
-- DESCRIPTION:  definitions
--
---------------------------------------------------------------------------------


library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

package defs is


	
type firmwareVersion_type is record
	number : std_logic_vector(15 downto 0);
	year : std_logic_vector(15 downto 0);
	MMDD:	std_logic_vector(15 downto 0);
end record;



-----------------------------------------------------
-- VERSION INFO
--
-- Please update this section when changes are made!!
--
-----------------------------------------------------
-- numbers are bcd format (i.e. 0 to 9 only)
--
constant firwareVersion: firmwareVersion_type:= (
	
	number => 	    x"0504", 
	year => 		x"2022",	
	MMDD => 		x"0531"		-- month, date		
	
);
--
--
-- Revision history

-- V0301 2021/6/14 Synchronous comms now uses a two-byte sync word for tx and rx to prevent locking to a false sync;
--						Rewritten usb driver now running off sys clock using async timing specs from usb chip data sheet; modified led test commands
-- v0300 2021/6/3	Synchronous comms running at 40Mbps instead of uart running at 20Mbps
-- v0201 2 Jun 2021 Added test command to select an SMA socket for the pps input and/or beamgate input for test purposes
-- v0200 16 May 2021 Major structural changes to trigger mechanism. 
--							Added pps divider & pps multiplexing with beam gate
--							Also variable length frames from acdc and 'frame received' bit field
-- V0102 12 Apr 2021 Added synchronization to the pps input to prevent it giving a false rising edge (and hence false trigger) in the case of switching to pps mode
--                   while the pps signal is high.
-- V0101 12 Feb 2021 Added new mode, mode 9 which triggers from the pps signal on the 'system' lvds connector
-- V0100 31 Jan 2021 Added auto-detect ext clock option
-- V0017 15 Oct 2020 Initial version

--------------------------------






constant N	:	natural := 8; --number of front-end boards (either 4 or 8, depending on RJ45 port installation)

--RAM specifiers for uart receiver buffer
constant	transceiver_mem_depth	:	integer := 15; --ram address size
constant	transceiver_mem_width	:	integer := 16; --data size


--type definitions
type rx_ram_data_type is array(N-1 downto 0) of	std_logic_vector(transceiver_mem_width-1 downto 0);
type LVDS_inputArray_type is array(N-1 downto 0) of std_logic_vector(1 downto 0);
type LVDS_inputArray_hs_type is array(N-1 downto 0) of std_logic_vector(1 downto 0);
type LVDS_outputArray_type is array(N-1 downto 0) of std_logic_vector(2 downto 0);
type Array_8bit is array(N-1 downto 0) of std_logic_vector(7 downto 0);
type Array_16bit is array(N-1 downto 0) of std_logic_vector(15 downto 0);
type frameData_type is array(31 downto 0) of std_logic_vector(15 downto 0);
type naturalArray_16bit is array(N-1 downto 0) of natural range 0 to 65535;
type natArray2 is array(N-1 downto 0) of natural range 0 to 3;	-- 2 bit natural array
type natArray3 is array(N-1 downto 0) of natural range 0 to 7; -- 3 bit natural array
type DoubleArray_16bit is array(2*N-1 downto 0) of std_logic_vector(15 downto 0);
type serialRx_hs_array is array(2*N-1 downto 0) of std_logic_vector(1 downto 0);
type serialRx_hs_23bit_array is array(2*N-1 downto 0) of std_logic_vector(22 downto 0);
type serialRx_hs_10bit_array is array(2*N-1 downto 0) of std_logic_vector(9 downto 0);
type serialRx_hs_8bit_array is array(2*N-1 downto 0) of std_logic_vector(7 downto 0);

	
	
------------------------------------
--	CLOCKS
------------------------------------

type clockCtrl_type is record
	clockSourceSelect	:	std_logic;
end record;



type clockSource_type is record
  localOsc		:	std_logic;
	usb_IFCLK	:	std_logic;	-- 48MHz
end record;

type clock_type is record
  sys			:	std_logic;
  x4	        :	std_logic;
  x8	        :	std_logic;
  serial25      :   std_logic;
  serial125     :   std_logic;
  serial125_ps  :   std_logic_vector(2*N-1 downto 0);
--   usb         :	std_logic;  
--	timer			:	std_logic;
  altpllLock  :	std_logic;
  serialpllLock : Std_logic;
  dpa1pllLock : std_logic;
  dpa2pllLock : std_logic;
end record;





------------------------------------
--	SYSTEM IO (lvds)
------------------------------------

type systemIn_type is record
	in0	:	std_logic;
	in1	:	std_logic;
end record;

type systemOut_type is record
	out0	:	std_logic;
end record;






------------------------------------
--	EXTERNAL COMMAND
------------------------------------

type extCmd_type is record
	enable     : 	std_logic_vector(7 downto 0);
	data       : 	std_logic_vector(31 downto 0);
	valid		  : 	std_logic;
end record;



	
------------------------------------
--	LEDS
------------------------------------
type LEDSetup_type is array (2 downto 0) of std_logic_vector(15 downto 0);
type LEDPreset_type is array (0 to 15) of LEDSetup_type;






	
------------------------------------
--	RESET
------------------------------------
type reset_type is record
	global		:	std_logic;
	request		:	std_logic;
	request2		:	std_logic;
end record;





------------------------------------
--	TRIGGER
------------------------------------
type trigSetup_type is record
	source		: natArray3;
	ppsMux_enable: std_logic;
	ppsDivRatio: natural;
	windowStart: natural;
	windowLen: natural;
	SMA_invert: std_logic;
	sw:		std_logic_vector(N-1 downto 0);
end record;






------------------------------------
--	SERIAL TX
------------------------------------
type serialTx_type is record
	cmd				:	std_logic_vector(31 downto 0);
	cmd_valid		:	std_logic;
	byte				:	Array_8bit;
	byte_txReq		:	std_logic_vector(N-1 downto 0);
	byte_txAck		:	std_logic_vector(N-1 downto 0);
	enable			:	std_logic_vector(N-1 downto 0);
	serial			:	std_logic_vector(N-1 downto 0);
   txReady       	:	std_logic_vector(N-1 downto 0);
end record;





------------------------------------
--	SERIAL RX
------------------------------------
type serialRx_type is record
	serial					:	std_logic_vector(N-1 downto 0);
	data						:	Array_8bit;
	kout						:	std_logic_vector(N-1 downto 0);
	valid						:	std_logic_vector(N-1 downto 0);
	rx_clock_fail			:	std_logic_vector(N-1 downto 0);
   symbol_align_error	:	std_logic_vector(N-1 downto 0);
   symbol_code_error		:	std_logic_vector(N-1 downto 0);
   disparity_error		:	std_logic_vector(N-1 downto 0);
end record;









------------------------------------
--	RX BUFFER
------------------------------------
type rxBuffer_type is record
	dataLen    	   : Array_16bit;
	reset		   : std_logic_vector(N-1 downto 0);
	readReq		   : std_logic;
	resetReq	   : std_logic_vector(N-1 downto 0);
	empty		   : std_logic_vector(N-1 downto 0);
	frame_received : std_logic_vector(N-1 downto 0);
	fifoReadEn 	   : std_logic_vector(N-1 downto 0);
	fifoDataOut	   : Array_16bit;
end record;






------------------------------------
--	TEST COMMAND
------------------------------------
type testCmd_type is record
	pps_useSMA						:	std_logic;
	beamgateTrigger_useSMA		:	std_logic;
	channel    		:	natural;
end record;



------------------------------------
--	Ethernet 
------------------------------------

type ETH_in_type is record
  rx_clk : std_logic;
  rx_ctl : std_logic;
  rx_dat : std_logic_vector(3 downto 0);
end record;

type ETH_out_type is record
  resetn : std_logic;
  tx_clk : std_logic;
  tx_ctl : std_logic;
  tx_dat : std_logic_vector(3 downto 0);
end record;

	
------------------------------------
--	USB 
------------------------------------

type USB_in_type is record			-- note: usb IFCLK input is covered by 'clockSource' type
	CTL		: std_logic_vector(2 downto 0);
	CLKOUT	: std_logic;
	WAKEUP	: std_logic;
end record;


type USB_out_type is record
	RDY	: std_logic_vector(1 downto 0);
end record;


type USB_bus_type is record
	FD	: std_logic_vector(15 downto 0);
	PA	: std_logic_vector(7 downto 0);
end record;

	
		
------------------------------------
--	USB 
------------------------------------
type usb_type is record
   busWriteEnable 	:  std_logic;     --when high the fpga outputs data onto the usb bus
   busWriteEnable_vec:  std_logic_vector(15 downto 0);     --when high the fpga outputs data onto the usb bus
	tx_busReq			:	std_logic;
	tx_busAck			:	std_logic;
   txBufferReady 		: 	std_logic;		--the tx buffer on the chip is ready to accept data 
   rxDataAvailable  	: 	std_logic;     --usb data received flag
	rxData_in			:	std_logic_vector(15 downto 0);
	rxData_out			:	std_logic_vector(31 downto 0);
	txData_in			:	std_logic_vector(15 downto 0);
	txData_out			:	std_logic_vector(15 downto 0);
	txReq					:	std_logic;
	txAck					:	std_logic;
   rxData_valid	   :	std_logic;
	dataTransferDone	:	std_logic;
   PKTEND  				: 	std_logic;		--usb packet end flag
   SLWR		        	: 	std_logic;		--usb slave interface write signal
   SLOE         		: 	std_logic;    	--usb slave interface bus output enable, active low
   SLRD     	   	: 	std_logic;		--usb  slave interface bus read, active low
   FIFOADR  	   	: 	std_logic_vector (1 downto 0); -- usb endpoint fifo select, essentially selects the tx fifo or rx fifo
	test					:	std_logic_vector(15 downto 0);
end record;

		
------------------------------------
--	config regesters
------------------------------------
type config_type is record
    localInfo_readReq      : std_logic;
    rxBuffer_resetReq      : std_logic_vector(7 downto 0);
    rxBuffer_readReq	   : std_logic;
    dataFIFO_readReq       : std_logic;
    globalResetReq         : std_logic;
    trig		           : trigSetup_type;
    readChannel            : natural range 0 to 15;
    ledSetup			   : LEDSetup_type;
    ledPreset			   : LEDPreset_type;
    extCmd                 : extCmd_type;
    testCmd				   : testCmd_type;
    delayCommand           : std_logic_vector(11 downto 0);
    delayCommandSet        : std_logic;
    delayCommandMask       : std_logic_vector(15 downto 0);
    count_reset            : std_logic;
    phaseUpdate            : std_logic;
    updn                   : std_logic;
    cntsel                 : std_logic_vector(4 downto 0);
    train_manchester_links : std_logic;
    backpressure_threshold : std_logic_vector(11 downto 0);
    rxFIFO_resetReq        : std_logic_vector(N-1 downto 0);
end record;

type readback_reg_type is record
  byte_fifo_occ                 : DoubleArray_16bit;
  prbs_error_counts             : DoubleArray_16bit;
  symbol_error_counts           : DoubleArray_16bit;
  data_occ                      : Array_16bit;
  rxDataLen	                    : Array_16bit;
  serialRX_rx_clock_fail        : std_logic_vector(N-1 downto 0);
  serialRX_symbol_align_error   : std_logic_vector(N-1 downto 0);
  serialRX_symbol_code_error    : std_logic_vector(N-1 downto 0);
  serialRX_disparity_error      : std_logic_vector(N-1 downto 0);
  pllLock                       : std_logic_Vector(3 downto 0);
end record;


end defs;



