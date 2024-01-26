---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
-- PROJECT:      ANNIE 
-- FILE:         components.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         Oct 2020         
--
-- DESCRIPTION:  component definitions
--
---------------------------------------------------------------------------------


library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.defs.all;



package components is


component serialTx_buffer is
  port (
    clock      : in  std_logic;
    eth_clk    : in  std_logic;
    din        : in  std_logic_vector(31 downto 0);
    din_txReq  : in  std_logic;
    dout       : out std_logic_vector(7 downto 0);
    dout_txReq : out std_logic;
    dout_txAck : in  std_logic);
end component serialTx_buffer;


component serialRx_buffer is
  port (
    reset        : in  std_logic;
    clock        : in  std_logic;
    eth_clk      : in  std_logic;
    din          : in  std_logic_vector(7 downto 0);
    din_valid    : in  std_logic;
    read_enable  : in  std_logic;
    buffer_empty : out std_logic;
    dataLen      : out std_logic_vector(15 downto 0);
    dout         : out std_logic_vector(15 downto 0)); 
end component serialRx_buffer;


component txFifo is
  port (
    data    : IN  STD_LOGIC_VECTOR (31 DOWNTO 0);
    rdclk   : IN  STD_LOGIC;
    rdreq   : IN  STD_LOGIC;
    wrclk   : IN  STD_LOGIC;
    wrreq   : IN  STD_LOGIC;
    q       : OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
    rdempty : OUT STD_LOGIC;
    wrfull  : OUT STD_LOGIC);
end component txFifo;

		
component trigger is
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
end component;


component pll is
	port (
		refclk   : in  std_logic := '0'; --  refclk.clk
		rst      : in  std_logic := '0'; --   reset.reset
		outclk_0 : out std_logic;        -- outclk0.clk
		outclk_1 : out std_logic;        -- outclk1.clk
		outclk_2 : out std_logic;        -- outclk2.clk
		locked   : out std_logic         --  locked.export
	);
end component;
	
		
component ClockGenerator is
	Port(
        clockIn		: in	clockSource_type;
        reset       : in reset_type;
		clock			: buffer clock_type;
		pps			: in std_logic;
		resetRequest: out std_logic;
		useExtRef	: buffer std_logic;
        phaseUpdate : in std_logic;
        updn     : in std_logic;
        cntsel   : in std_logic_vector(4 downto 0)
	);
end component;
		
      
component LED_driver is
	port (
		clock	      : in std_logic;        
		setup			: in ledSetup_type;
		output      : out std_logic
	);
end component;
     

------------------------------------------		
-- command & data processing components
------------------------------------------

component commandHandler is
  port (
    reset         : in  std_logic;
    clock         : in  clock_type;
    eth_clk       : in  std_logic;
    rx_addr       : in  std_logic_vector (31 downto 0);
    rx_data       : in  std_logic_vector (63 downto 0);
    rx_wren       : in  std_logic;
    tx_data       : out std_logic_vector (63 downto 0);
    tx_rden       : in  std_logic;
    config        : out config_type;
    regs          : in  readback_reg_type;
    extCmd        : out extCmd_type;
    serialRX_data : in  Array_16bit;
    serialRX_rden : out std_logic_vector(7 downto 0);
    -- SFP interfaces
    sfp0_tx_clk        : in  std_logic;
    sfp0_rx_clk        : in  std_logic;
    sfp1_tx_clk        : in  std_logic;
    sfp1_rx_clk        : in  std_logic;
    sfp0_tx_ready : in std_logic;
    sfp0_rx_ready : in std_logic;
    sfp1_tx_ready : in std_logic;
    sfp1_rx_ready : in std_logic;
    sfp0_phy_mgmt_in        : out Avalon_in_type;
    sfp0_phy_mgmt_out       : in  Avalon_out_type;
    sfp0_reconfig_mgmt_in   : out Avalon_in_type;
    sfp0_reconfig_mgmt_out  : in  Avalon_out_type;
    sfp1_phy_mgmt_in        : out Avalon_in_type;
    sfp1_phy_mgmt_out       : in  Avalon_out_type;
    sfp1_reconfig_mgmt_in   : out Avalon_in_type;
    sfp1_reconfig_mgmt_out  : in  Avalon_out_type);
end component commandHandler;


component dataHandler is
  port (
    reset            : in  std_logic;
    clock            : in  std_logic;
    eth_clk          : in  std_logic;
    b_data           : out std_logic_vector (63 downto 0);
    b_data_we        : out std_logic;
    b_data_force     : out std_logic;
    b_enable         : in  std_logic;
    dataFIFO_readReq : in  std_logic;
    dataFIFO_chan    : in  natural range 0 to 15;
    dataFIFO_auto    : in  std_logic;
	 dataFIFO_reset   : in  std_logic;
    data_out         : in  Array_16bit;
    data_occ         : in  Array_16bit;
    data_re          : out std_logic_vector(N-1 downto 0));
end component dataHandler;


component data_readout_auto_controller is
  port (
    reset            : in  std_logic;
    clock            : in  std_logic;
    dataFIFO_readReq : out std_logic;
    dataFIFO_chan    : out natural range 0 to 15;
    dataFIFO_auto    : in  std_logic;
    data_occ         : in  Array_16bit;
    b_enable         : in std_logic;
    data_done        : in  std_logic);
end component data_readout_auto_controller;


component rx_data_ram
	port (
		clock		: IN STD_LOGIC  := '1';
		data		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		rdaddress		: IN STD_LOGIC_VECTOR (14 DOWNTO 0);
		rden		: IN STD_LOGIC  := '1';
		wraddress		: IN STD_LOGIC_VECTOR (14 DOWNTO 0);
		wren		: IN STD_LOGIC  := '0';
		q		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0));
end component;


component usbDriver is
   port ( 		
		clock   					: in		std_logic;
		rxData_in	  	  	 	: in     std_logic_vector (15 downto 0);  --usb data from PHY
		txData_out				: out    std_logic_vector (15 downto 0);  --usb data bus to PHY
      txBufferReady 			: in  	std_logic;		--the tx buffer on the chip is ready to accept data 
      rxDataAvailable  		: in    	std_logic;     --usb data received flag
      busWriteEnable 		: out   	std_logic;     --when high the fpga outputs data onto the usb bus
      PKTEND  					: out 	std_logic;		--usb packet end flag
      SLWR		      	  	: buffer 	std_logic;		--usb slave interface write signal
      SLOE         			: buffer   	std_logic;    	--usb slave interface bus output enable, active low
		SLRD     	   		: buffer   	std_logic;		--usb  slave interface bus read, active low
      FIFOADR  	   		: out   	std_logic_vector (1 downto 0); -- usb endpoint fifo select, essentially selects the tx fifo or rx fifo
		tx_busReq  				: in		std_logic;  -- request to lock the bus in tx mode, preventing any interruptions from usb read
		tx_busAck  				: out		std_logic;  
      txData_in        		: in   	std_logic_vector(15 downto 0);		
      txReq		        		: in   	std_logic;		
      txAck		        		: out   	std_logic;		
      rxData_out       		: out   	std_logic_vector(31 downto 0);
		rxData_valid     		: out		std_logic;
		test						: out		std_logic_vector(15 downto 0)
);
end component;


component iobuf
  port(
    datain		: IN 		STD_LOGIC_VECTOR (15 DOWNTO 0);
    oe				: IN  	STD_LOGIC_VECTOR (15 DOWNTO 0);
    dataio		: INOUT 	STD_LOGIC_VECTOR (15 DOWNTO 0);
    dataout		: OUT 	STD_LOGIC_VECTOR (15 DOWNTO 0));
end component;


component serialRX_iobuf is
  port (
    datain           : IN  STD_LOGIC_VECTOR (15 DOWNTO 0);
    datain_b         : IN  STD_LOGIC_VECTOR (15 DOWNTO 0);
    io_config_clk    : IN  STD_LOGIC;
    io_config_clkena : IN  STD_LOGIC_VECTOR (15 DOWNTO 0);
    io_config_datain : IN  STD_LOGIC;
    io_config_update : IN  STD_LOGIC;
    dataout          : OUT STD_LOGIC_VECTOR (15 DOWNTO 0)); 
end component serialRX_iobuf;


component serialRX_ddr is
  port (
    aclr      : IN  STD_LOGIC;
    datain    : IN  STD_LOGIC_VECTOR (0 DOWNTO 0);
    inclock   : IN  STD_LOGIC;
    dataout_h : OUT STD_LOGIC_VECTOR (0 DOWNTO 0);
    dataout_l : OUT STD_LOGIC_VECTOR (0 DOWNTO 0));
end component serialRX_ddr;

   
component prbsChecker is
  port (
    clk          : in  std_logic;
    reset        : in  std_logic;
    data         : in  serialRx_hs_8bit_array;
    error_counts : out DoubleArray_16bit;
    count_reset  : in std_logic); 
end component prbsChecker;


component pll_serial is
  port (
    refclk   : in  std_logic := '0';
    rst      : in  std_logic := '0';
    outclk_0 : out std_logic;
    outclk_1 : out std_logic;
    locked   : out std_logic); 
end component pll_serial;


component pll_dpa is
  port (
    refclk     : in  std_logic                    := '0';
    rst        : in  std_logic                    := '0';
    outclk_0   : out std_logic;
    outclk_1   : out std_logic;
    outclk_2   : out std_logic;
    outclk_3   : out std_logic;
    outclk_4   : out std_logic;
    outclk_5   : out std_logic;
    outclk_6   : out std_logic;
    outclk_7   : out std_logic;
    locked     : out std_logic;
    phase_en   : in  std_logic                    := '0';
    scanclk    : in  std_logic                    := '0';
    updn       : in  std_logic                    := '0';
    cntsel     : in  std_logic_vector(4 downto 0) := (others => '0');
    phase_done : out std_logic);
end component pll_dpa;


component io_delay_ctrl is
  port (
    clk              : in  std_logic;
    reset            : in  std_logic;
    delayCommand     : in  std_logic_vector(11 downto 0);
    delayCommandSet  : in  std_logic;
    delayCommandMask : in  std_logic_vector(15 downto 0);
    io_config_clkena : out std_logic_vector(15 downto 0);
    io_config_datain : out std_logic;
    io_config_update : out std_logic);
end component io_delay_ctrl;


component serialRx_dataBuffer is
  port (
    clock                  : in  clock_type;
    reset                  : in  reset_type;
    eth_clk                : in  std_logic;
    rxFIFO_resetReq        : in  std_logic_vector(N-1 downto 0);
    delayCommand           : in  std_logic_vector(11 downto 0);
    delayCommandSet        : in  std_logic;
    delayCommandMask       : in  std_logic_vector(15 downto 0);
    LVDS_In_hs             : in  std_logic_vector(2*N-1 downto 0);
    data_out               : out Array_16bit;
    data_occ               : out Array_16bit;
    data_re                : in  std_logic_vector(N-1 downto 0);
    byte_fifo_occ          : out DoubleArray_16bit;
    prbs_error_counts      : out DoubleArray_16bit;
    symbol_error_counts    : out DoubleArray_16bit;
    parity_error_counts    : out DoubleArray_16bit;
    backpressure_threshold : in  std_logic_vector(11 downto 0);
    backpressure_out       : out std_logic_vector(N-1 downto 0);
    count_reset            : in  std_logic;
    trig_out               : out std_logic_vector(N-1 downto 0);
    ACDC_backpressure_out  : out std_logic_vector(N-1 downto 0);
    io_config_clkena       : out std_logic_vector(15 downto 0);
    io_config_datain       : out std_logic;
    io_config_update       : out std_logic);
end component serialRx_dataBuffer;


component serialRX_dpa_fifo is
  port (
    aclr    : IN  STD_LOGIC := '0';
    data    : IN  STD_LOGIC_VECTOR (1 DOWNTO 0);
    rdclk   : IN  STD_LOGIC;
    rdreq   : IN  STD_LOGIC;
    wrclk   : IN  STD_LOGIC;
    wrreq   : IN  STD_LOGIC;
    q       : OUT STD_LOGIC_VECTOR (1 DOWNTO 0);
    rdempty : OUT STD_LOGIC;
    wrfull  : OUT STD_LOGIC); 
end component serialRX_dpa_fifo;


component clkBuf is
  port (
    inclk  : in  std_logic := 'X'; -- inclk
    outclk : out std_logic         -- outclk
    );
end component clkBuf;


component serialRX_InterByteAlign_fifo is
  port (
    clock : IN  STD_LOGIC;
    data  : IN  STD_LOGIC_VECTOR (7 DOWNTO 0);
    rdreq : IN  STD_LOGIC;
    sclr  : IN  STD_LOGIC;
    wrreq : IN  STD_LOGIC;
    empty : OUT STD_LOGIC;
    full  : OUT STD_LOGIC;
    q     : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
    usedw : OUT STD_LOGIC_VECTOR (3 DOWNTO 0));
end component serialRX_InterByteAlign_fifo;


component serialRX_data_fifo is
  port (
    aclr    : IN  STD_LOGIC := '0';
    data    : IN  STD_LOGIC_VECTOR (15 DOWNTO 0);
    rdclk   : IN  STD_LOGIC;
    rdreq   : IN  STD_LOGIC;
    wrclk   : IN  STD_LOGIC;
    wrreq   : IN  STD_LOGIC;
    q       : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
    rdempty : OUT STD_LOGIC;
    rdusedw : OUT STD_LOGIC_VECTOR (14 DOWNTO 0);
    wrfull  : OUT STD_LOGIC);
end component serialRX_data_fifo;


component ethernet_adapter is
  port (
    clock        : in    clock_type;
    reset        : in    std_logic;
    ETH_in       : in    ETH_in_type;
    ETH_out      : out   ETH_out_type;
    ETH_mdc      : inout std_logic;
    ETH_mdio     : inout std_logic;
    user_addr	 : in    std_logic_vector (7 downto 0);
    eth_clk      : out   std_logic;
    rx_addr      : out   std_logic_vector (31 downto 0);
    rx_data      : out   std_logic_vector (63 downto 0);
    rx_wren      : out   std_logic;
    tx_data      : in    std_logic_vector (63 downto 0);
    tx_rden      : out   std_logic;
    b_data       : in    std_logic_vector (63 downto 0);
    b_data_we    : in    std_logic;
    b_data_force : in    std_logic;
    b_enable     : out   std_logic); 
end component ethernet_adapter;


component ETH_pll is
  port (
    refclk   : in  std_logic := '0';
    rst      : in  std_logic := '0';
    outclk_0 : out std_logic;
    outclk_1 : out std_logic;
    locked   : out std_logic);
end component ETH_pll;


component ETH_out_pll is
  port (
    refclk   : in  std_logic := '0';
    rst      : in  std_logic := '0';
    outclk_0 : out std_logic;
    locked   : out std_logic);
end component ETH_out_pll;

component eth_clk_ctrl is
  port (
    inclk  : in  std_logic := '0'; --  altclkctrl_input.inclk
    outclk : out std_logic         -- altclkctrl_output.outclk
	);
end component eth_clk_ctrl;

component IOBuf_openCollector_iobuf_bidir_cfo is
  port (
    datain  : IN    STD_LOGIC_VECTOR (0 DOWNTO 0);
    dataio  : INOUT STD_LOGIC_VECTOR (0 DOWNTO 0);
    dataout : OUT   STD_LOGIC_VECTOR (0 DOWNTO 0);
    oe      : IN    STD_LOGIC_VECTOR (0 DOWNTO 0));
end component IOBuf_openCollector_iobuf_bidir_cfo;

component commandSync is
  port (
    reset     : in  std_logic;
    clock     : in  clock_type;
    eth_clk   : in  std_logic;
    eth_reset : in  std_logic;
    sfp0_tx_clk :   in std_logic;
    sfp0_rx_clk :   in std_logic;
    sfp1_tx_clk :   in std_logic;
    sfp1_rx_clk :   in std_logic;
    sfp0_tx_ready : in std_logic;
    sfp0_rx_ready : in std_logic;
    sfp1_tx_ready : in std_logic;
    sfp1_rx_ready : in std_logic;
    config_z  : in  config_type;
    config    : out config_type;
    reg       : in  readback_reg_type;
    reg_z     : out readback_reg_type);
end component commandSync;


component rx_data_fifo is
  port (
    aclr    : IN  STD_LOGIC := '0';
    data    : IN  STD_LOGIC_VECTOR (15 DOWNTO 0);
    rdclk   : IN  STD_LOGIC;
    rdreq   : IN  STD_LOGIC;
    wrclk   : IN  STD_LOGIC;
    wrreq   : IN  STD_LOGIC;
    q       : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
    rdempty : OUT STD_LOGIC;
    rdusedw : OUT STD_LOGIC_VECTOR (8 DOWNTO 0);
    wrfull  : OUT STD_LOGIC);
end component rx_data_fifo;

component dcFIFO_dataBuffer is
  port (
    aclr    : IN  STD_LOGIC := '0';
    data    : IN  STD_LOGIC_VECTOR (15 DOWNTO 0);
    rdclk   : IN  STD_LOGIC;
    rdreq   : IN  STD_LOGIC;
    wrclk   : IN  STD_LOGIC;
    wrreq   : IN  STD_LOGIC;
    q       : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
    rdempty : OUT STD_LOGIC;
    rdusedw : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
    wrfull  : OUT STD_LOGIC;
    wrusedw : OUT STD_LOGIC_VECTOR (15 DOWNTO 0));
end component dcFIFO_dataBuffer;

component Trig_phy is
	port (
		phy_mgmt_clk                : in  std_logic                      := '0';             --                phy_mgmt_clk.clk
		phy_mgmt_clk_reset          : in  std_logic                      := '0';             --          phy_mgmt_clk_reset.reset
		phy_mgmt_address            : in  std_logic_vector(8 downto 0)   := (others => '0'); --                    phy_mgmt.address
		phy_mgmt_read               : in  std_logic                      := '0';             --                            .read
		phy_mgmt_readdata           : out std_logic_vector(31 downto 0);                     --                            .readdata
		phy_mgmt_waitrequest        : out std_logic;                                         --                            .waitrequest
		phy_mgmt_write              : in  std_logic                      := '0';             --                            .write
		phy_mgmt_writedata          : in  std_logic_vector(31 downto 0)  := (others => '0'); --                            .writedata
		tx_ready                    : out std_logic;                                         --                    tx_ready.export
		rx_ready                    : out std_logic;                                         --                    rx_ready.export
		pll_ref_clk                 : in  std_logic_vector(0 downto 0)   := (others => '0'); --                 pll_ref_clk.clk
		tx_serial_data              : out std_logic_vector(0 downto 0);                      --              tx_serial_data.export
		pll_locked                  : out std_logic_vector(0 downto 0);                      --                  pll_locked.export
		rx_serial_data              : in  std_logic_vector(0 downto 0)   := (others => '0'); --              rx_serial_data.export
		rx_runningdisp              : out std_logic_vector(1 downto 0);                      --              rx_runningdisp.export
		rx_disperr                  : out std_logic_vector(1 downto 0);                      --                  rx_disperr.export
		rx_errdetect                : out std_logic_vector(1 downto 0);                      --                rx_errdetect.export
		rx_is_lockedtoref           : out std_logic_vector(0 downto 0);                      --           rx_is_lockedtoref.export
		rx_is_lockedtodata          : out std_logic_vector(0 downto 0);                      --          rx_is_lockedtodata.export
		rx_signaldetect             : out std_logic_vector(0 downto 0);                      --             rx_signaldetect.export
		rx_patterndetect            : out std_logic_vector(1 downto 0);                      --            rx_patterndetect.export
		rx_syncstatus               : out std_logic_vector(1 downto 0);                      --               rx_syncstatus.export
		rx_bitslipboundaryselectout : out std_logic_vector(4 downto 0);                      -- rx_bitslipboundaryselectout.export
		tx_clkout                   : out std_logic_vector(0 downto 0);                      --                   tx_clkout.export
		rx_clkout                   : out std_logic_vector(0 downto 0);                      --                   rx_clkout.export
		tx_parallel_data            : in  std_logic_vector(15 downto 0)  := (others => '0'); --            tx_parallel_data.export
		tx_datak                    : in  std_logic_vector(1 downto 0)   := (others => '0'); --                    tx_datak.export
		rx_parallel_data            : out std_logic_vector(15 downto 0);                     --            rx_parallel_data.export
		rx_datak                    : out std_logic_vector(1 downto 0);                      --                    rx_datak.export
		reconfig_from_xcvr          : out std_logic_vector(91 downto 0);                     --          reconfig_from_xcvr.reconfig_from_xcvr
		reconfig_to_xcvr            : in  std_logic_vector(139 downto 0) := (others => '0')  --            reconfig_to_xcvr.reconfig_to_xcvr
	);
end component Trig_phy;

component trigLinkReconfig is
	port (
		reconfig_busy             : out std_logic;                                         --      reconfig_busy.reconfig_busy
		mgmt_clk_clk              : in  std_logic                      := '0';             --       mgmt_clk_clk.clk
		mgmt_rst_reset            : in  std_logic                      := '0';             --     mgmt_rst_reset.reset
		reconfig_mgmt_address     : in  std_logic_vector(6 downto 0)   := (others => '0'); --      reconfig_mgmt.address
		reconfig_mgmt_read        : in  std_logic                      := '0';             --                   .read
		reconfig_mgmt_readdata    : out std_logic_vector(31 downto 0);                     --                   .readdata
		reconfig_mgmt_waitrequest : out std_logic;                                         --                   .waitrequest
		reconfig_mgmt_write       : in  std_logic                      := '0';             --                   .write
		reconfig_mgmt_writedata   : in  std_logic_vector(31 downto 0)  := (others => '0'); --                   .writedata
		reconfig_to_xcvr          : out std_logic_vector(139 downto 0);                    --   reconfig_to_xcvr.reconfig_to_xcvr
		reconfig_from_xcvr        : in  std_logic_vector(91 downto 0)  := (others => '0')  -- reconfig_from_xcvr.reconfig_from_xcvr
	);
end component trigLinkReconfig;

component TrigCounterRam IS
	PORT
	(
		data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		rdaddress		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
		rdclock		: IN STD_LOGIC ;
		wraddress		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
		wrclock		: IN STD_LOGIC  := '1';
		wren		: IN STD_LOGIC  := '0';
		q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
END component TrigCounterRam;

component Trig_HSSI is
  port(		
    tx_serial_data  : out std_logic;
    rx_serial_data  : in  std_logic;
    SFP_ref_clk    : in  std_logic;

    tx_clkout       : out std_logic;
    rx_clkout       : out std_logic;

	reset			: in  reset_type;
    config          : in  config_type;

    eth_clk         : in  std_logic;
    eth_resetn      : in  std_logic;

    counter_feedback : in  std_logic;

    pll_locked                  : out std_logic;
    rx_bitslipboundaryselectout : out std_logic_vector(4 downto 0);
    delta_t_trig                : out std_logic_vector(7 downto 0);
    tx_ready                    : out std_logic;
    rx_ready                    : out std_logic;
    symbolErrors                : out std_logic_vector(31 downto 0);
    disparityErrors             : out std_logic_vector(31 downto 0);

    phy_mgmt_in          : in  Avalon_in_type;
    phy_mgmt_out         : out Avalon_out_type;

    reconfig_mgmt_in     : in  Avalon_in_type;
    reconfig_mgmt_out    : out Avalon_out_type;

    tx_triggers          : in  std_logic_vector(7 downto 0);
    rx_triggers          : out std_logic_vector(7 downto 0)
);
end component Trig_HSSI;

end components;

