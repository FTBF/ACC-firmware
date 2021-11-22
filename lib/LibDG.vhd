---------------------------------------------------------------------------------
-- AUTHOR:       D. Greenshields
-- DATE:         Oct 2020         
--
-- DESCRIPTION:  library component definitions
--
---------------------------------------------------------------------------------


library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


package LibDG is


-- 8b10b K codes
constant K28_0	: std_logic_vector(7 downto 0) := x"1C";	
constant K28_1	: std_logic_vector(7 downto 0) := x"3C"; 	
constant K28_2	: std_logic_vector(7 downto 0) := x"5C";
constant K28_3	: std_logic_vector(7 downto 0) := x"7C";
constant K28_4	: std_logic_vector(7 downto 0) := x"9C";
constant K28_5	: std_logic_vector(7 downto 0) := x"BC"; 	
constant K28_6	: std_logic_vector(7 downto 0) := x"DC";
constant K28_7	: std_logic_vector(7 downto 0) := x"FC";
constant K23_7	: std_logic_vector(7 downto 0) := x"F7"; 
constant K27_7	: std_logic_vector(7 downto 0) := x"FB"; 
constant K29_7	: std_logic_vector(7 downto 0) := x"FD";
constant K30_7	: std_logic_vector(7 downto 0) := x"FE";


constant PRBS_WIDTH : natural := 16;




component synchronousTx_8b10b IS 
	PORT
	(
		clock 				:  IN  std_logic;		
		rd_reset				:	in	 std_logic;
		din 					:  IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
		txReq					:  IN  STD_LOGIC;
		txAck					:	out std_logic;
		dout 					:  OUT STD_LOGIC	-- serial bitstream out
	);
END component;



component synchronousRx_8b10b IS 
	PORT
	(
		clock_sys				:  IN  STD_LOGIC;
		clock_x4					:  IN  STD_LOGIC;
		clock_x8					:  IN  STD_LOGIC;
		din						:  IN  STD_LOGIC;
		rx_clock_fail			:	buffer std_logic;
		symbol_align_error	:	buffer std_logic;
		symbol_code_error		:	out std_logic;
		disparity_error		:	out std_logic;
		dout 						:	OUT STD_LOGIC_VECTOR(7 DOWNTO 0);	-- byte out
		kout 						:	OUT STD_LOGIC;		-- when high indicates the output byte is a control byte, not data
		dout_valid				:  OUT STD_LOGIC
	);
END component;



component encoder_8b10b is port (
	clock:			in		std_logic;
	rd_reset:		in		std_logic;
	din:				in 	std_logic_vector(7 downto 0);
	din_valid:		in		std_logic;
	kin:				in		std_logic;
	dout:				out 	std_logic_vector(9 downto 0);
	dout_valid:		out 	std_logic;
	rd_out:			out	integer
);
end component;




component decoder_8b10b is port (
	clock:			in		std_logic;
	rd_reset:		in		std_logic;
	din:				in 	std_logic_vector(9 downto 0);
	din_valid:		in		std_logic;
	kout:				out	std_logic;
	dout:				out 	std_logic_vector(7 downto 0);
	dout_valid:		out 	std_logic;
	rd_out:			out	integer;
	symbol_error:	out	std_logic
);
end component;



	
component pulseGobbler is
	Port(
		clock		: in	std_logic;
		input		: in	std_logic;
		N			: in natural;
		output	: out std_logic
		);
end component;
		
		
component pulseSync is
   port (
		inClock     : in std_logic;
      outClock    : in std_logic;
		din_valid	: in	std_logic;       
      dout_valid  : out std_logic);
		
end component;
      
      
component fastCounter64 is
	PORT
	(
		clock		:	IN	STD_LOGIC;
		reset		:	in	std_logic;
		q			: 	out std_logic_vector(63 downto 0)
	);
end component;
		
		
 

COMPONENT uart
	GENERIC ( dataLen			: natural:= 8;
				 clockDivRatio : natural:= 8 );
	PORT
	(
		clock				:	 IN STD_LOGIC;
		reset				:	 IN STD_LOGIC;
		txData			:	 IN STD_LOGIC_VECTOR(dataLen-1 DOWNTO 0);
		txData_valid	:	 IN STD_LOGIC;
		txData_ack		:	 OUT STD_LOGIC;
		txReady			:	 OUT STD_LOGIC;
		txOut				:	 OUT STD_LOGIC;
		rxData			:	 OUT STD_LOGIC_VECTOR(dataLen-1 DOWNTO 0);
		rxData_valid	:	 OUT STD_LOGIC;
		rxError 			:	 OUT STD_LOGIC;
		rxIn				:	 IN STD_LOGIC
	);
END COMPONENT;





component monostable_async_level is
	port (
		clock	      : in std_logic;        
		len         : in natural;
		trig        : in std_logic;
		output      : out std_logic);
end component;


component monostable_sync_level is
	port (
		clock	      : in std_logic;        
		len         : in natural;
		trig        : in std_logic;
		output      : out std_logic);
end component;
   
	
	
component monostable_sync_edge is
	port (
		clock	      : in std_logic;        
		len         : in natural;
		trig        : in std_logic;
		output      : out std_logic);
end component;



component monostable_async_edge is
	port (
		clock	      : in std_logic;        
		len         : in natural;
		trig        : in std_logic;
		output      : out std_logic);
end component;



component monostable_asyncio_edge is
	port (
		clock	      : in std_logic;        
		len         : in natural;
		trig        : in std_logic;
		output      : buffer std_logic);
end component;
  
   

component risingEdgeDetect is
	port (
		clock	      : in std_logic;        
		input        : in std_logic;
		output      : out std_logic);
end component;




component fallingEdgeDetect is
	port (
		clock	      : in std_logic;        
		input        : in std_logic;
		output      : out std_logic);
end component;


component prbsGenerator is
  generic (
    ITERATIONS : natural;
    POLY       : std_logic_vector(PRBS_WIDTH-1 downto 0));
  port (
    clk    : in  std_logic;
    reset  : in  std_logic;
    input  : in  std_logic_vector(PRBS_WIDTH-1 downto 0);
    output : out std_logic_vector(PRBS_WIDTH-1 downto 0));
end component prbsGenerator;


component pulseSync2 is
  Generic(
    RESET_VAL : std_logic := '0'
    );
  port (
    src_clk      : in  std_logic;
    src_pulse    : in  std_logic;
    src_aresetn  : in  std_logic;
    dest_clk     : in  std_logic;
    dest_pulse   : out std_logic;
    dest_aresetn : in  std_logic);
end component pulseSync2;


component param_handshake_sync is
  generic (
    WIDTH : natural);
  port (
    src_clk      : in  std_logic;
    src_params   : in  std_logic_vector(WIDTH-1 downto 0);
    src_aresetn  : in  std_logic;
    dest_clk     : in  std_logic;
    dest_params  : out std_logic_vector(WIDTH-1 downto 0);
    dest_aresetn : in  std_logic);
end component param_handshake_sync;


component sync_Bits_Altera is
  generic (
    BITS       : positive;
    INIT       : std_logic_vector;
    SYNC_DEPTH : natural range 2 to 5);
  port (
    Clock  : in  std_logic;
    Input  : in  std_logic_vector(BITS - 1 downto 0);
    Output : out std_logic_vector(BITS - 1 downto 0));
end component sync_Bits_Altera;

end LibDG;























