-------------------------------------------------------------------------------
-- Title      : Testbench for design "ACC_main"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : ACC_main_tb.vhd
-- Author     :   <Pastika@ITID20020501N>
-- Company    : 
-- Created    : 2021-10-15
-- Last update: 2022-02-02
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2021 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2021-10-15  1.0      Pastika	Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
USE ieee.numeric_std.ALL; 
use work.defs.all;
use work.components.all;
use work.LibDG.all;	   

library acdc_full_sim;

-------------------------------------------------------------------------------

entity ACC_main_tb is

end entity ACC_main_tb;

-------------------------------------------------------------------------------

architecture sim of ACC_main_tb is

  	-- Component declaration of the "acdc_main(vhdl)" unit defined in
	-- file: "../../../../../ACDC-firmware-master_RevC/ACDC-firmware/src/ACDC_main.vhd"
	component acdc_main
	port(
		clockIn : in acdc_full_sim.defs.CLOCKSOURCE_TYPE;
		jcpll_ctrl : out acdc_full_sim.defs.JCPLL_CTRL_TYPE;
		jcpll_lock : in STD_LOGIC;
		jcpll_spi_miso : in STD_LOGIC;
		LVDS_in : in STD_LOGIC_VECTOR(2 downto 0);
		LVDS_out : out STD_LOGIC_VECTOR(3 downto 0);
		PSEC4_in : in acdc_full_sim.defs.PSEC4_IN_ARRAY_TYPE;
		PSEC4_out : buffer acdc_full_sim.defs.PSEC4_OUT_ARRAY_TYPE;
		PSEC4_freq_sel : out STD_LOGIC;
		PSEC4_trigSign : out STD_LOGIC;
		enableV1p2a : out STD_LOGIC;
		calEnable : inout std_logic_vector(14 downto 0);
		DAC : out acdc_full_sim.defs.DAC_ARRAY_TYPE;
		SMA_J3 : inout std_logic; 
		ledOut : out STD_LOGIC_VECTOR(8 downto 0);
		debug2 : out STD_LOGIC;
		debug3 : out STD_LOGIC
	);
	end component;


  -- constants 
  constant OSC_PERIOD : time := 40 ns;
  constant JCPLL_PERIOD : time := 25 ns;
  constant USB_PERIOD : time := 20.8 ns; 
  constant WR_PERIOD : time := 10 ns; 
  constant ETH_PERIOD : time := 8 ns;

  shared variable ENDSIM : boolean := false; 
  
  -- component ports
  signal clockIn      : clockSource_type;
  signal clockCtrl    : clockCtrl_type;
  signal systemIn     : systemIn_type;
  signal systemOut    : systemOut_type;
  signal LVDS_In      : LVDS_inputArray_type;
  signal LVDS_In_hs_p : LVDS_inputArray_hs_type;
  signal LVDS_In_Hs_n : LVDS_inputArray_hs_type;
  signal LVDS_Out     : LVDS_outputArray_type;
  signal led          : std_logic_vector(2 downto 0);
  signal SMA          : std_logic_vector(1 to 6);
  signal USB_in       : USB_in_type;
  signal USB_out      : USB_out_type;
  signal USB_bus      : USB_bus_type;
  signal ETH_in       : ETH_in_type;
  signal ETH_out      : ETH_out_type;
  signal ETH_mdc      : std_logic;
  signal ETH_mdio     : std_logic;
  signal DIPswitch    : std_logic_vector (9 downto 0);
  
  signal clockIn_ACDC   : acdc_full_sim.defs.CLOCKSOURCE_TYPE;
  signal jcpll_ctrl     : acdc_full_sim.defs.JCPLL_CTRL_TYPE;
  signal jcpll_lock     : STD_LOGIC;
  signal jcpll_spi_miso : STD_LOGIC;
  signal LVDS_in_ACDC   : STD_LOGIC_VECTOR(2 downto 0);
  signal LVDS_out_ACDC  : STD_LOGIC_VECTOR(3 downto 0);
  signal PSEC4_in       : acdc_full_sim.defs.PSEC4_IN_ARRAY_TYPE;
  signal PSEC4_out      : acdc_full_sim.defs.PSEC4_OUT_ARRAY_TYPE;
  signal PSEC4_freq_sel : STD_LOGIC;
  signal PSEC4_trigSign : STD_LOGIC;
  signal enableV1p2a    : STD_LOGIC;
  signal calEnable      : std_logic_vector(14 downto 0);
  signal DAC            : acdc_full_sim.defs.DAC_ARRAY_TYPE;
  signal SMA_J3         : std_logic;
  signal ledOut         : STD_LOGIC_VECTOR(8 downto 0);
  signal debug2         : STD_LOGIC;
  signal debug3         : STD_LOGIC;
  
  signal fastClk      : std_logic;
  signal reset        : std_logic;				  
  signal prbs         : std_logic_vector(15 downto 0); 
  
  signal tmpEthData   : std_logic_vector(4 downto 0);
  
  type trig_type is array (4 downto 0) of std_logic_vector(5 downto 0);
  signal selftrig : trig_type;
  
  procedure sendword
  ( constant word : in std_logic_vector(31 downto 0); 
    signal word_out : out std_logic_vector(15 downto 0);
    signal rx_ready : in std_logic;
	signal SLRD : out std_logic) is
  begin					
  	SLRD <= '1';
	wait until falling_edge(rx_ready);
	word_out <= word(15 downto 0);
	SLRD <= '0';
	wait for 10 ns;
	
	SLRD <= '1';
	wait until falling_edge(rx_ready);
	word_out <= word(31 downto 16);
	SLRD <= '0';
	wait for 10 ns;
	
	--word_out <= "ZZZZZZZZZZZZZZZZ";
  end sendword;	
  
  procedure ethSend
  ( constant word : in std_logic_vector(7 downto 0);
  signal word_out : out std_logic_vector(4 downto 0)) is
  begin
	word_out(4) <= '1';
	word_out(3 downto 0) <= word(3 downto 0);
	wait for ETH_PERIOD / 2;
	
	word_out(4) <= '1';
	word_out(3 downto 0) <= word(7 downto 4);
	wait for ETH_PERIOD / 2;
  end ethSend;


begin  -- architecture sim

  -- component instantiation
  DUT: entity work.ACC_main
    port map (
      clockIn      => clockIn,
      clockCtrl    => clockCtrl,
      systemIn     => systemIn,
      systemOut    => systemOut,
      LVDS_In      => LVDS_In,
      LVDS_In_hs_p => LVDS_In_hs_p,
      LVDS_In_Hs_n => LVDS_In_Hs_n,
      LVDS_Out     => LVDS_Out,
      led          => led,
      SMA          => SMA,
      USB_in       => USB_in,
      USB_out      => USB_out,
      USB_bus      => USB_bus,
	  ETH_in       => ETH_in,
	  ETH_out      => ETH_out,
      ETH_mdc  	   => ETH_mdc,
	  ETH_mdio 	   => ETH_mdio,
	  DIPswitch    => DIPswitch);
	  
  acdc_inst : acdc_main
	port map(
		clockIn => clockIn_ACDC,
		jcpll_ctrl => jcpll_ctrl,
		jcpll_lock => jcpll_lock,
		jcpll_spi_miso => jcpll_spi_miso,
		LVDS_in => LVDS_in_ACDC,
		LVDS_out => LVDS_out_ACDC,
		PSEC4_in => PSEC4_in,
		PSEC4_out => PSEC4_out,
		PSEC4_freq_sel => PSEC4_freq_sel,
		PSEC4_trigSign => PSEC4_trigSign,
		enableV1p2a => enableV1p2a,
		calEnable => calEnable,
		DAC => DAC,
		SMA_J3 => SMA_J3,	
		ledOut => ledOut,
		debug2 => debug2,
		debug3 => debug3
	);
	
  LVDS_in_ACDC <= transport LVDS_out(0) after 4 ns;
  LVDS_in(0) <= transport LVDS_out_ACDC(1 downto 0) after 1 ns;
  LVDS_In_hs_p(0) <= LVDS_out_ACDC(3) & not LVDS_out_ACDC(2);
  LVDS_In_hs_n(0) <= not LVDS_out_ACDC(3) & LVDS_out_ACDC(2);
	  
  prbsGen : prbsGenerator
  Generic map(
    ITERATIONS => 1,
    POLY       => X"6000"
    )
  Port map(
    clk    => fastClk,
    reset  => reset,
    input  => prbs,
    output => prbs
    );
	
  hs_mapping : for i in 2 to 15 generate
	LVDS_In_hs_p(i/2)(i mod 2) <= prbs(0);  
	LVDS_In_hs_n(i/2)(i mod 2) <= not prbs(0);
  end generate;

  -- clock generation
  ACC_OSC_GEN_PROC : process 
  begin
    if ENDSIM = false then
      clockIn.localOsc <= '0';
	  clockIn_ACDC.accOsc <= '0';
      wait for OSC_PERIOD / 2;
      clockIn.localOsc <= '1';
	  clockIn_ACDC.accOsc <= '1';
      wait for OSC_PERIOD / 2;
    else 
      wait;
    end if;
  end process;
  
  
  JCPLL_OSC_GEN_PROC : process 
  begin
    if ENDSIM = false then
	  clockIn_ACDC.jcpll <= '0';
      wait for JCPLL_PERIOD / 2;
	  clockIn_ACDC.jcpll <= '1';
      wait for JCPLL_PERIOD / 2;
    else 
      wait;
    end if;
  end process;
  		   
  WR_CLK_GEN_PROC : process 
  begin
    if ENDSIM = false then
      clockIn_ACDC.wr100 <= '0';
      wait for WR_PERIOD / 2;
      clockIn_ACDC.wr100 <= '1';
      wait for WR_PERIOD / 2;
    else 
      wait;
    end if;
  end process;
  
  USB_CLK_GEN_PROC : process 
  begin
    if ENDSIM = false then
      clockIn.usb_IFCLK <= '0';
      wait for USB_PERIOD / 2;
      clockIn.usb_IFCLK <= '1';
      wait for USB_PERIOD / 2;
    else 
      wait;
    end if;
  end process;
  
  FAST_CLK_GEN_PROC : process 
  begin
    if ENDSIM = false then
      fastClk <= '0';
      wait for OSC_PERIOD / 20;
      fastClk <= '1';
      wait for OSC_PERIOD / 20;
    else 
      wait;
    end if;
  end process;
  
  ETH_CLK_GEN_PROC : process 
  begin
    if ENDSIM = false then
      ETH_in.rx_clk <= '0';
      wait for ETH_PERIOD / 2;
      ETH_in.rx_clk <= '1';
      wait for ETH_PERIOD / 2;
    else 
      wait;
    end if;
  end process;
  
  fakeData : for i in 0 to 4 generate
	PSEC4_in(i).trig <= selftrig(i);
	PSEC4_in(i).overflow <= '0';
	  
  	PSEC4_process : process(PSEC4_out(i).readClock, reset)
	  variable partialNumber : std_logic_vector(11 downto 0);
  	begin
      if reset = '1' then
        PSEC4_in(i).data <= X"fff";
        --partialNumber := "0000"&X"00";
      else 
        if rising_edge(PSEC4_out(i).readClock) then
          if PSEC4_out(i).TokDecode /= "101" and PSEC4_out(i).TokIn = "00" then
            --partialNumber := std_logic_vector((unsigned(PSEC4_in(i).data) + 1));
            PSEC4_in(i).data <= std_logic_vector((unsigned(PSEC4_in(i).data) + 1));
          end if;
        end if;
      end if;
    end process;
  end generate;
  
  ETH_in.rx_dat <= transport tmpEthData(3 downto 0) after 6 ns;	
  ETH_in.rx_ctl <= transport tmpEthData(4) after 6 ns;
  
  eth_process : process
  begin
	tmpEthData <= "0" & X"d";
	
	wait for 50 us;	

	ethSend(X"55", tmpEthData);
	ethSend(X"55", tmpEthData);
	ethSend(X"55", tmpEthData);
	ethSend(X"55", tmpEthData);
	ethSend(X"55", tmpEthData);
	ethSend(X"55", tmpEthData);
	ethSend(X"55", tmpEthData);
	
	ethSend(X"D5", tmpEthData);
	
	ethSend(X"FF", tmpEthData);
	ethSend(X"FF", tmpEthData);
	ethSend(X"FF", tmpEthData);
	ethSend(X"FF", tmpEthData);
	ethSend(X"FF", tmpEthData);
	ethSend(X"FF", tmpEthData);
	
	ethSend(X"DC", tmpEthData);
	ethSend(X"A6", tmpEthData);
	ethSend(X"32", tmpEthData);
	ethSend(X"78", tmpEthData);
	ethSend(X"07", tmpEthData);
	ethSend(X"B4", tmpEthData);
	
	ethSend(X"08", tmpEthData);
	ethSend(X"06", tmpEthData);
	
	ethSend(X"00", tmpEthData);
	ethSend(X"01", tmpEthData);
	ethSend(X"08", tmpEthData);
	ethSend(X"00", tmpEthData);
	ethSend(X"06", tmpEthData);
	ethSend(X"04", tmpEthData);
	ethSend(X"00", tmpEthData);
	ethSend(X"01", tmpEthData);
	
	ethSend(X"DC", tmpEthData);
	ethSend(X"A6", tmpEthData);
	ethSend(X"32", tmpEthData);
	ethSend(X"78", tmpEthData);
	ethSend(X"07", tmpEthData);
	ethSend(X"B4", tmpEthData);
	
	ethSend(X"C0", tmpEthData);
	ethSend(X"A8", tmpEthData);
	ethSend(X"85", tmpEthData);
	ethSend(X"16", tmpEthData);
	
	ethSend(X"00", tmpEthData);
	ethSend(X"00", tmpEthData);
	ethSend(X"00", tmpEthData);
	ethSend(X"00", tmpEthData);
	ethSend(X"00", tmpEthData);
	ethSend(X"00", tmpEthData);
	
	ethSend(X"C0", tmpEthData);
	ethSend(X"A8", tmpEthData);
	ethSend(X"01", tmpEthData);
	ethSend(X"01", tmpEthData);
	
	ethSend(X"00", tmpEthData);
	ethSend(X"00", tmpEthData);
	ethSend(X"00", tmpEthData);
	ethSend(X"00", tmpEthData);
	ethSend(X"00", tmpEthData);
	ethSend(X"00", tmpEthData);
	ethSend(X"00", tmpEthData);
	ethSend(X"00", tmpEthData);
	ethSend(X"00", tmpEthData);
	ethSend(X"00", tmpEthData);
	ethSend(X"00", tmpEthData);
	ethSend(X"00", tmpEthData);
	ethSend(X"00", tmpEthData);
	ethSend(X"00", tmpEthData);
	ethSend(X"00", tmpEthData);
	ethSend(X"00", tmpEthData);
	ethSend(X"00", tmpEthData);
	ethSend(X"00", tmpEthData);
	
	ethSend(X"D6", tmpEthData);
	ethSend(X"EF", tmpEthData);
	ethSend(X"F9", tmpEthData);
	ethSend(X"B6", tmpEthData);
	
	tmpEthData <= "0" & X"d";
	
	wait;
	
  end process;
  
  
  -- waveform generation
  WaveGen_Proc: process
  begin
    -- insert signal assignments here  
	USB_in.CTL <= "100";
	USB_bus.FD <= X"0000";
	SMA_J3 <= '0';
	
	for i in 0 to 4 loop
		selftrig(i) <= "000000";
	end loop;
	
	reset <= '0';
	wait for 200 ns;
	reset <= '1';
	wait for 200 ns;
	reset <= '0';
	wait for 200 ns; 
	
	wait for 50 us;
	
	sendword(X"00600000", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) );
	sendword(X"005200ff", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) );
	sendword(X"0051001f", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) );
	sendword(X"00500000", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) );
	sendword(X"0054ffff", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) );
	
	sendword(X"ffA00000", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) );
	
	--wait for 10 us;
	
	--sendword(X"fff60000", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) ); 
	
	wait for 5 us;

	sendword(X"fff60003", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) );
	wait for 5 us;
	sendword(X"00300ff1", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) );
	--wait for 5 us;
	--sendword(X"00100000", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) );	
	
	--wait for 5 us;
	--sendword(X"FFD00000", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) );	  
	
	--wait for 10 us;
	--sendword(X"00230000", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) );	

	sendword(X"FFB20040", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) );
	sendword(X"FFB1003f", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) );
	sendword(X"FFB00003", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) ); 
	
	wait for 10 us;
	
	selftrig(0) <= "001000";
	wait for 50 ns;
	selftrig(0) <= "000000";
	wait for 500 ns;
	sendword(X"00100000", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) );
	
	wait for 200 us;
	selftrig(0) <= "001000";
	wait for 50 ns;
	selftrig(0) <= "000000";
	wait for 500 ns;
	--sendword(X"00100000", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) );
	--sendword(X"fff60002", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) );
	--sendword(X"fff60003", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) );
	wait for 200 us;
	sendword(X"00220000", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) );
	--sendword(X"00010001", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) );
	
	
--	
--	wait for 5 us;
--	sendword(X"00530000", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) ); 
--	sendword(X"00540000", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) );
--	
--	for j in 0 to 15 loop
--		sendword(std_logic_vector(unsigned(X"00550002") + j), USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) );
--		for i in 0 to j loop
--			sendword(X"00560000", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) ); 
--		end loop;
--	end loop;	 
--	
--	sendword(X"00000000", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) );
--	
--	wait for 10 us;
	
	--sendword(X"FFD00000", USB_bus.FD, usb_out.RDY(0), USB_in.CTL(0) ); 
    
    wait;
  end process WaveGen_Proc;

  

end architecture sim;

-------------------------------------------------------------------------------

--configuration ACC_main_tb_sim_cfg of ACC_main_tb is
--  for sim
--  end for;
--end ACC_main_tb_sim_cfg;

-------------------------------------------------------------------------------
