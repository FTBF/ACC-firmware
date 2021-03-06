-- megafunction wizard: %ALTIOBUF%
-- GENERATION: STANDARD
-- VERSION: WM1.0
-- MODULE: altiobuf_in 

-- ============================================================
-- File Name: serialRX_iobuf.vhd
-- Megafunction Name(s):
-- 			altiobuf_in
--
-- Simulation Library Files(s):
-- 			arriav
-- ============================================================
-- ************************************************************
-- THIS IS A WIZARD-GENERATED FILE. DO NOT EDIT THIS FILE!
--
-- 19.1.0 Build 670 09/22/2019 SJ Standard Edition
-- ************************************************************


--Copyright (C) 2019  Intel Corporation. All rights reserved.
--Your use of Intel Corporation's design tools, logic functions 
--and other software and tools, and any partner logic 
--functions, and any output files from any of the foregoing 
--(including device programming or simulation files), and any 
--associated documentation or information are expressly subject 
--to the terms and conditions of the Intel Program License 
--Subscription Agreement, the Intel Quartus Prime License Agreement,
--the Intel FPGA IP License Agreement, or other applicable license
--agreement, including, without limitation, that your use is for
--the sole purpose of programming logic devices manufactured by
--Intel and sold by Intel or its authorized distributors.  Please
--refer to the applicable agreement for further details, at
--https://fpgasoftware.intel.com/eula.


--altiobuf_in CBX_AUTO_BLACKBOX="ALL" DEVICE_FAMILY="Arria V" ENABLE_BUS_HOLD="FALSE" NUMBER_OF_CHANNELS=16 USE_DIFFERENTIAL_MODE="TRUE" USE_DYNAMIC_TERMINATION_CONTROL="FALSE" USE_IN_DYNAMIC_DELAY_CHAIN="TRUE" datain datain_b dataout io_config_clk io_config_clkena io_config_datain io_config_update
--VERSION_BEGIN 19.1 cbx_altiobuf_in 2019:09:22:11:00:28:SJ cbx_mgl 2019:09:22:11:02:15:SJ cbx_stratixiii 2019:09:22:11:00:28:SJ cbx_stratixv 2019:09:22:11:00:28:SJ  VERSION_END

 LIBRARY arriav;
 USE arriav.all;

--synthesis_resources = arriav_delay_chain 16 arriav_io_config 16 arriav_io_ibuf 16 
 LIBRARY ieee;
 USE ieee.std_logic_1164.all;

 ENTITY  serialRX_iobuf_iobuf_in_26s IS 
	 PORT 
	 ( 
		 datain	:	IN  STD_LOGIC_VECTOR (15 DOWNTO 0);
		 datain_b	:	IN  STD_LOGIC_VECTOR (15 DOWNTO 0) := (OTHERS => '0');
		 dataout	:	OUT  STD_LOGIC_VECTOR (15 DOWNTO 0);
		 io_config_clk	:	IN  STD_LOGIC := '0';
		 io_config_clkena	:	IN  STD_LOGIC_VECTOR (15 DOWNTO 0) := (OTHERS => '0');
		 io_config_datain	:	IN  STD_LOGIC := '0';
		 io_config_update	:	IN  STD_LOGIC := '0'
	 ); 
 END serialRX_iobuf_iobuf_in_26s;

 ARCHITECTURE RTL OF serialRX_iobuf_iobuf_in_26s IS

	 SIGNAL  wire_sd1_dataout	:	STD_LOGIC;
	 SIGNAL  wire_sd1_delayctrlin	:	STD_LOGIC_VECTOR (4 DOWNTO 0);
	 SIGNAL  wire_sd10_dataout	:	STD_LOGIC;
	 SIGNAL  wire_sd10_delayctrlin	:	STD_LOGIC_VECTOR (4 DOWNTO 0);
	 SIGNAL  wire_sd11_dataout	:	STD_LOGIC;
	 SIGNAL  wire_sd11_delayctrlin	:	STD_LOGIC_VECTOR (4 DOWNTO 0);
	 SIGNAL  wire_sd12_dataout	:	STD_LOGIC;
	 SIGNAL  wire_sd12_delayctrlin	:	STD_LOGIC_VECTOR (4 DOWNTO 0);
	 SIGNAL  wire_sd13_dataout	:	STD_LOGIC;
	 SIGNAL  wire_sd13_delayctrlin	:	STD_LOGIC_VECTOR (4 DOWNTO 0);
	 SIGNAL  wire_sd14_dataout	:	STD_LOGIC;
	 SIGNAL  wire_sd14_delayctrlin	:	STD_LOGIC_VECTOR (4 DOWNTO 0);
	 SIGNAL  wire_sd15_dataout	:	STD_LOGIC;
	 SIGNAL  wire_sd15_delayctrlin	:	STD_LOGIC_VECTOR (4 DOWNTO 0);
	 SIGNAL  wire_sd16_dataout	:	STD_LOGIC;
	 SIGNAL  wire_sd16_delayctrlin	:	STD_LOGIC_VECTOR (4 DOWNTO 0);
	 SIGNAL  wire_sd2_dataout	:	STD_LOGIC;
	 SIGNAL  wire_sd2_delayctrlin	:	STD_LOGIC_VECTOR (4 DOWNTO 0);
	 SIGNAL  wire_sd3_dataout	:	STD_LOGIC;
	 SIGNAL  wire_sd3_delayctrlin	:	STD_LOGIC_VECTOR (4 DOWNTO 0);
	 SIGNAL  wire_sd4_dataout	:	STD_LOGIC;
	 SIGNAL  wire_sd4_delayctrlin	:	STD_LOGIC_VECTOR (4 DOWNTO 0);
	 SIGNAL  wire_sd5_dataout	:	STD_LOGIC;
	 SIGNAL  wire_sd5_delayctrlin	:	STD_LOGIC_VECTOR (4 DOWNTO 0);
	 SIGNAL  wire_sd6_dataout	:	STD_LOGIC;
	 SIGNAL  wire_sd6_delayctrlin	:	STD_LOGIC_VECTOR (4 DOWNTO 0);
	 SIGNAL  wire_sd7_dataout	:	STD_LOGIC;
	 SIGNAL  wire_sd7_delayctrlin	:	STD_LOGIC_VECTOR (4 DOWNTO 0);
	 SIGNAL  wire_sd8_dataout	:	STD_LOGIC;
	 SIGNAL  wire_sd8_delayctrlin	:	STD_LOGIC_VECTOR (4 DOWNTO 0);
	 SIGNAL  wire_sd9_dataout	:	STD_LOGIC;
	 SIGNAL  wire_sd9_delayctrlin	:	STD_LOGIC_VECTOR (4 DOWNTO 0);
	 SIGNAL  wire_ioconfiga_ena	:	STD_LOGIC_VECTOR (15 DOWNTO 0);
	 SIGNAL  wire_ioconfiga_padtoinputregisterdelaysetting	:	STD_LOGIC_VECTOR (79 DOWNTO 0);
	 SIGNAL  wire_ibufa_i	:	STD_LOGIC_VECTOR (15 DOWNTO 0);
	 SIGNAL  wire_ibufa_ibar	:	STD_LOGIC_VECTOR (15 DOWNTO 0);
	 SIGNAL  wire_ibufa_o	:	STD_LOGIC_VECTOR (15 DOWNTO 0);
	 COMPONENT  arriav_delay_chain
	 GENERIC 
	 (
		sim_falling_delay_increment	:	NATURAL := 10;
		sim_intrinsic_falling_delay	:	NATURAL := 200;
		sim_intrinsic_rising_delay	:	NATURAL := 200;
		sim_rising_delay_increment	:	NATURAL := 10;
		lpm_type	:	STRING := "arriav_delay_chain"
	 );
	 PORT
	 ( 
		datain	:	IN STD_LOGIC := '0';
		dataout	:	OUT STD_LOGIC;
		delayctrlin	:	IN STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0')
	 ); 
	 END COMPONENT;
	 COMPONENT  arriav_io_config
	 GENERIC 
	 (
--		enhanced_mode	:	STRING := "false";
		lpm_type	:	STRING := "arriav_io_config"
	 );
	 PORT
	 ( 
		clk	:	IN STD_LOGIC := '0';
		datain	:	IN STD_LOGIC := '0';
		dataout	:	OUT STD_LOGIC;
--		dutycycledelaysettings	:	OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
		ena	:	IN STD_LOGIC := '0';
		outputenabledelaysetting	:	OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
--		outputfinedelaysetting1	:	OUT STD_LOGIC;
--		outputfinedelaysetting2	:	OUT STD_LOGIC;
		outputhalfratebypass	:	OUT STD_LOGIC;
--		outputonlydelaysetting2	:	OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
--		outputonlyfinedelaysetting2	:	OUT STD_LOGIC;
--		outputregdelaysetting	:	OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
		padtoinputregisterdelaysetting	:	OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
--		padtoinputregisterfinedelaysetting	:	OUT STD_LOGIC;
		readfifomode	:	OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
		readfiforeadclockselect	:	OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
		update	:	IN STD_LOGIC := '0'
	 ); 
	 END COMPONENT;
	 COMPONENT  arriav_io_ibuf
	 GENERIC 
	 (
		bus_hold	:	STRING := "false";
		differential_mode	:	STRING := "false";
		simulate_z_as	:	STRING := "z";
		lpm_type	:	STRING := "arriav_io_ibuf"
	 );
	 PORT
	 ( 
		dynamicterminationcontrol	:	IN STD_LOGIC := '0';
		i	:	IN STD_LOGIC := '0';
		ibar	:	IN STD_LOGIC := '0';
		o	:	OUT STD_LOGIC
	 ); 
	 END COMPONENT;
 BEGIN

	dataout <= ( wire_sd16_dataout & wire_sd15_dataout & wire_sd14_dataout & wire_sd13_dataout & wire_sd12_dataout & wire_sd11_dataout & wire_sd10_dataout & wire_sd9_dataout & wire_sd8_dataout & wire_sd7_dataout & wire_sd6_dataout & wire_sd5_dataout & wire_sd4_dataout & wire_sd3_dataout & wire_sd2_dataout & wire_sd1_dataout);
	wire_sd1_delayctrlin <= ( wire_ioconfiga_padtoinputregisterdelaysetting(4 DOWNTO 0));
	sd1 :  arriav_delay_chain
	  PORT MAP ( 
		datain => wire_ibufa_o(0),
		dataout => wire_sd1_dataout,
		delayctrlin => wire_sd1_delayctrlin
	  );
	wire_sd10_delayctrlin <= ( wire_ioconfiga_padtoinputregisterdelaysetting(49 DOWNTO 45));
	sd10 :  arriav_delay_chain
	  PORT MAP ( 
		datain => wire_ibufa_o(9),
		dataout => wire_sd10_dataout,
		delayctrlin => wire_sd10_delayctrlin
	  );
	wire_sd11_delayctrlin <= ( wire_ioconfiga_padtoinputregisterdelaysetting(54 DOWNTO 50));
	sd11 :  arriav_delay_chain
	  PORT MAP ( 
		datain => wire_ibufa_o(10),
		dataout => wire_sd11_dataout,
		delayctrlin => wire_sd11_delayctrlin
	  );
	wire_sd12_delayctrlin <= ( wire_ioconfiga_padtoinputregisterdelaysetting(59 DOWNTO 55));
	sd12 :  arriav_delay_chain
	  PORT MAP ( 
		datain => wire_ibufa_o(11),
		dataout => wire_sd12_dataout,
		delayctrlin => wire_sd12_delayctrlin
	  );
	wire_sd13_delayctrlin <= ( wire_ioconfiga_padtoinputregisterdelaysetting(64 DOWNTO 60));
	sd13 :  arriav_delay_chain
	  PORT MAP ( 
		datain => wire_ibufa_o(12),
		dataout => wire_sd13_dataout,
		delayctrlin => wire_sd13_delayctrlin
	  );
	wire_sd14_delayctrlin <= ( wire_ioconfiga_padtoinputregisterdelaysetting(69 DOWNTO 65));
	sd14 :  arriav_delay_chain
	  PORT MAP ( 
		datain => wire_ibufa_o(13),
		dataout => wire_sd14_dataout,
		delayctrlin => wire_sd14_delayctrlin
	  );
	wire_sd15_delayctrlin <= ( wire_ioconfiga_padtoinputregisterdelaysetting(74 DOWNTO 70));
	sd15 :  arriav_delay_chain
	  PORT MAP ( 
		datain => wire_ibufa_o(14),
		dataout => wire_sd15_dataout,
		delayctrlin => wire_sd15_delayctrlin
	  );
	wire_sd16_delayctrlin <= ( wire_ioconfiga_padtoinputregisterdelaysetting(79 DOWNTO 75));
	sd16 :  arriav_delay_chain
	  PORT MAP ( 
		datain => wire_ibufa_o(15),
		dataout => wire_sd16_dataout,
		delayctrlin => wire_sd16_delayctrlin
	  );
	wire_sd2_delayctrlin <= ( wire_ioconfiga_padtoinputregisterdelaysetting(9 DOWNTO 5));
	sd2 :  arriav_delay_chain
	  PORT MAP ( 
		datain => wire_ibufa_o(1),
		dataout => wire_sd2_dataout,
		delayctrlin => wire_sd2_delayctrlin
	  );
	wire_sd3_delayctrlin <= ( wire_ioconfiga_padtoinputregisterdelaysetting(14 DOWNTO 10));
	sd3 :  arriav_delay_chain
	  PORT MAP ( 
		datain => wire_ibufa_o(2),
		dataout => wire_sd3_dataout,
		delayctrlin => wire_sd3_delayctrlin
	  );
	wire_sd4_delayctrlin <= ( wire_ioconfiga_padtoinputregisterdelaysetting(19 DOWNTO 15));
	sd4 :  arriav_delay_chain
	  PORT MAP ( 
		datain => wire_ibufa_o(3),
		dataout => wire_sd4_dataout,
		delayctrlin => wire_sd4_delayctrlin
	  );
	wire_sd5_delayctrlin <= ( wire_ioconfiga_padtoinputregisterdelaysetting(24 DOWNTO 20));
	sd5 :  arriav_delay_chain
	  PORT MAP ( 
		datain => wire_ibufa_o(4),
		dataout => wire_sd5_dataout,
		delayctrlin => wire_sd5_delayctrlin
	  );
	wire_sd6_delayctrlin <= ( wire_ioconfiga_padtoinputregisterdelaysetting(29 DOWNTO 25));
	sd6 :  arriav_delay_chain
	  PORT MAP ( 
		datain => wire_ibufa_o(5),
		dataout => wire_sd6_dataout,
		delayctrlin => wire_sd6_delayctrlin
	  );
	wire_sd7_delayctrlin <= ( wire_ioconfiga_padtoinputregisterdelaysetting(34 DOWNTO 30));
	sd7 :  arriav_delay_chain
	  PORT MAP ( 
		datain => wire_ibufa_o(6),
		dataout => wire_sd7_dataout,
		delayctrlin => wire_sd7_delayctrlin
	  );
	wire_sd8_delayctrlin <= ( wire_ioconfiga_padtoinputregisterdelaysetting(39 DOWNTO 35));
	sd8 :  arriav_delay_chain
	  PORT MAP ( 
		datain => wire_ibufa_o(7),
		dataout => wire_sd8_dataout,
		delayctrlin => wire_sd8_delayctrlin
	  );
	wire_sd9_delayctrlin <= ( wire_ioconfiga_padtoinputregisterdelaysetting(44 DOWNTO 40));
	sd9 :  arriav_delay_chain
	  PORT MAP ( 
		datain => wire_ibufa_o(8),
		dataout => wire_sd9_dataout,
		delayctrlin => wire_sd9_delayctrlin
	  );
	wire_ioconfiga_ena <= io_config_clkena;
	loop0 : FOR i IN 0 TO 15 GENERATE 
	  ioconfiga :  arriav_io_config
	  PORT MAP ( 
		clk => io_config_clk,
		datain => io_config_datain,
		ena => wire_ioconfiga_ena(i),
		padtoinputregisterdelaysetting => wire_ioconfiga_padtoinputregisterdelaysetting(i*5+4 DOWNTO i*5),
		update => io_config_update
	  );
	END GENERATE loop0;
	wire_ibufa_i <= datain;
	wire_ibufa_ibar <= datain_b;
	loop1 : FOR i IN 0 TO 15 GENERATE 
	  ibufa :  arriav_io_ibuf
	  GENERIC MAP (
		bus_hold => "false",
		differential_mode => "true"
	  )
	  PORT MAP ( 
		i => wire_ibufa_i(i),
		ibar => wire_ibufa_ibar(i),
		o => wire_ibufa_o(i)
	  );
	END GENERATE loop1;

 END RTL; --serialRX_iobuf_iobuf_in_26s
--VALID FILE


LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY serialRX_iobuf IS
	PORT
	(
		datain		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		datain_b		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		io_config_clk		: IN STD_LOGIC ;
		io_config_clkena		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		io_config_datain		: IN STD_LOGIC ;
		io_config_update		: IN STD_LOGIC ;
		dataout		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
END serialRX_iobuf;


ARCHITECTURE RTL OF serialrx_iobuf IS

	SIGNAL sub_wire0	: STD_LOGIC_VECTOR (15 DOWNTO 0);



	COMPONENT serialRX_iobuf_iobuf_in_26s
	PORT (
			datain	: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			datain_b	: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			io_config_clk	: IN STD_LOGIC ;
			io_config_clkena	: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			io_config_datain	: IN STD_LOGIC ;
			io_config_update	: IN STD_LOGIC ;
			dataout	: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
	END COMPONENT;

BEGIN
	dataout    <= sub_wire0(15 DOWNTO 0);

	serialRX_iobuf_iobuf_in_26s_component : serialRX_iobuf_iobuf_in_26s
	PORT MAP (
		datain => datain,
		datain_b => datain_b,
		io_config_clk => io_config_clk,
		io_config_clkena => io_config_clkena,
		io_config_datain => io_config_datain,
		io_config_update => io_config_update,
		dataout => sub_wire0
	);



END RTL;

-- ============================================================
-- CNX file retrieval info
-- ============================================================
-- Retrieval info: PRIVATE: INTENDED_DEVICE_FAMILY STRING "Arria V"
-- Retrieval info: PRIVATE: SYNTH_WRAPPER_GEN_POSTFIX STRING "0"
-- Retrieval info: LIBRARY: altera_mf altera_mf.altera_mf_components.all
-- Retrieval info: CONSTANT: INTENDED_DEVICE_FAMILY STRING "Arria V"
-- Retrieval info: CONSTANT: enable_bus_hold STRING "FALSE"
-- Retrieval info: CONSTANT: number_of_channels NUMERIC "16"
-- Retrieval info: CONSTANT: use_differential_mode STRING "TRUE"
-- Retrieval info: CONSTANT: use_dynamic_termination_control STRING "FALSE"
-- Retrieval info: CONSTANT: use_in_dynamic_delay_chain STRING "TRUE"
-- Retrieval info: USED_PORT: datain 0 0 16 0 INPUT NODEFVAL "datain[15..0]"
-- Retrieval info: USED_PORT: datain_b 0 0 16 0 INPUT NODEFVAL "datain_b[15..0]"
-- Retrieval info: USED_PORT: dataout 0 0 16 0 OUTPUT NODEFVAL "dataout[15..0]"
-- Retrieval info: USED_PORT: io_config_clk 0 0 0 0 INPUT NODEFVAL "io_config_clk"
-- Retrieval info: USED_PORT: io_config_clkena 0 0 16 0 INPUT NODEFVAL "io_config_clkena[15..0]"
-- Retrieval info: USED_PORT: io_config_datain 0 0 0 0 INPUT NODEFVAL "io_config_datain"
-- Retrieval info: USED_PORT: io_config_update 0 0 0 0 INPUT NODEFVAL "io_config_update"
-- Retrieval info: CONNECT: @datain 0 0 16 0 datain 0 0 16 0
-- Retrieval info: CONNECT: @datain_b 0 0 16 0 datain_b 0 0 16 0
-- Retrieval info: CONNECT: @io_config_clk 0 0 0 0 io_config_clk 0 0 0 0
-- Retrieval info: CONNECT: @io_config_clkena 0 0 16 0 io_config_clkena 0 0 16 0
-- Retrieval info: CONNECT: @io_config_datain 0 0 0 0 io_config_datain 0 0 0 0
-- Retrieval info: CONNECT: @io_config_update 0 0 0 0 io_config_update 0 0 0 0
-- Retrieval info: CONNECT: dataout 0 0 16 0 @dataout 0 0 16 0
-- Retrieval info: GEN_FILE: TYPE_NORMAL serialRX_iobuf.vhd TRUE
-- Retrieval info: GEN_FILE: TYPE_NORMAL serialRX_iobuf.inc FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL serialRX_iobuf.cmp FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL serialRX_iobuf.bsf FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL serialRX_iobuf_inst.vhd FALSE
-- Retrieval info: LIB_FILE: arriav
