---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
--
-- PROJECT:      ANNIE - ACDC
-- FILE:         serialTx.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         May 2021
--
-- DESCRIPTION:  transmits data to the serial data line
--						each byte is converted to a 10 bit code and transmitted
--						
--						If there is no data to transmit, a special code is transmitted meaning 'line idle'
--						to keep the tx line transitioning so that the receiver can maintain bit sync
--
--						Every 1ms a sync word is sent to allow the receiver to achieve symbol lock
--						and/or to verify that everything is still in sync
---------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all; 
LIBRARY work;
use work.defs.all;
use work.LibDG.all;


ENTITY synchronousTx_8b10b IS 
	PORT
	(
		clock 				:  IN  std_logic;		
		rd_reset				:	in	 std_logic;
		din 					:  IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
		txReq					:  IN  STD_LOGIC;
		txAck					:	out std_logic;
		dout 					:  OUT STD_LOGIC	-- serial bitstream out
	);
END synchronousTx_8b10b;


ARCHITECTURE vhdl OF synchronousTx_8b10b IS 


-- input
signal txReq_z: std_logic;
signal txAck_req: std_logic;


-- encoder
signal enc_kin: std_logic;
signal enc_din: std_logic_vector(7 downto 0);
signal enc_dout: std_logic_vector(9 downto 0);
signal enc_din_valid: std_logic;


-- serializer
signal serialTxReq: std_logic;
signal serialTxReq_z: std_logic;
signal serialTxAck: std_logic;
signal serialTxAck_z: std_logic;
signal serialTxAck_req: std_logic;



-- flow control:
--
-- The external controller puts data on din and then applies a rising edge to txReq
-- Then it waits for a rising edge on txAck
-- once this happens the cycle can be repeated


BEGIN 
	
	
	
	
	
	
-----------------------------------------
-- CODEWORD GENERATOR
-----------------------------------------
-- code the 8 bit data into 10 bit words using the 8b10b encoder engine
-- Send a sync word every 1ms
-- Send 'line idle' words when no data is available to transmit
-- 

-- Note on the sync bytes..
--
-- Every millisecond two sync bytes are sent, K28.7 followed by a K28.0
--
-- The K28.7 is a dedicated sync word which has a longer run of consecutive 1's than normal, 
-- hence the receiver can find this unique word.
-- However if only the K28.7 is detected by the receiver, an inverted false K28.7 could be locked onto as shown below:
--
--	  K28.7      K28.0
-- 0011111000 0011110100
--      11000 00111 => inverted K28.7 word (false sync word)
--
-- Hence to avoid this problem the transmitter always sends K28.7 followed directly by K28.0
-- and the receiver always looks for same sequence, thus it will never lock onto the false sync word.


CODEWORD_GENERATOR: process(clock)
variable t: natural:= 0;
variable sync_flag: std_logic;
variable sync_count: natural;		-- count the sync bytes transmitted
variable data_reg: std_logic_vector(7 downto 0);		-- this is the current byte being processed
variable tx_req_flag : std_logic:='0';
variable serial_tx_ack_flag : std_logic:='0';



type state_type is (
	INIT,
	WRITE_DATA,
	WAIT_FOR_DATA_ACK
);

variable state: state_type:= INIT;

begin
	if (rising_edge(clock)) then
	
		
		-- sync generator
		-- raise a flag indicating a sync word should be sent (every 1ms)
		t := t + 1;
		if (t >= 400) then sync_flag := '1';	sync_count := 0; t := 0; end if;
		
			
		-- input data tx request 
		txReq_z <= txReq;
		if (txReq = '1' and txReq_z = '0') then 	-- rising edge
			data_reg := din;		-- copy input data
			tx_req_flag := '1';
		end if;
		
		
		-- serial data tx acknowledge 
		serialTxAck_z <= serialTxAck;
		if (serialTxAck = '1' and serialTxAck_z = '0') then 	-- rising edge
			serial_tx_ack_flag := '1';
		end if;
		
		
		
		case state is
	
	
			when INIT =>
			
				txAck_req <= '0';
				enc_din_valid <= '0';		
				state := WRITE_DATA;
			
			
			when WRITE_DATA =>
													
				-- there are 3 options:				
				--
				-- (i) send sync word
				-- (ii) send data word
				-- (iii) send idle code
						
				enc_din_valid <= '1';		
				serial_tx_ack_flag := '0';
				
				if (tx_req_flag = '1') then
					
					tx_req_flag := '0';
					enc_din <= data_reg;
					enc_kin <= '0';
					txAck_req <= '1';

				elsif (sync_flag = '1') then
						
					case sync_count is
						when 0 => enc_din <= K28_7;		-- send sync code byte 0
						when 1 => enc_din <= K28_0;		-- send sync code byte 1
						when others => null;
					end case;
					sync_count := sync_count + 1;
					if (sync_count >= 2) then sync_flag := '0'; end if;		-- 2 sync bytes sent
					enc_kin <= '1';
					txAck_req <= '0';
	
				else
					
					txAck_req <= '0';
					enc_din <= K28_0;		-- send line idle code
					enc_kin <= '1';
					
				end if;
				
				
				state := WAIT_FOR_DATA_ACK;
				
				
				
				
			when WAIT_FOR_DATA_ACK =>
		
				txAck_req <= '0';
				enc_din_valid <= '0';
				if (serial_tx_ack_flag = '1') then 		-- the data was acknowledged by the serializer
					state := WRITE_DATA; 
				end if;	
					
			when others => null;
			
					
		end case;
		
	end if;
	
end process;


-- din ack pulse generator
ACK_GEN: monostable_sync_edge port map (clock, 1, txAck_req, txAck);		-- generate a single ack pulse







-----------------------------------------
-- 8b10b ENCODER
-----------------------------------------
ENCODER_map: encoder_8b10b port map (
	clock				=> clock,
	rd_reset			=> rd_reset,
	din				=> enc_din,
	din_valid		=> enc_din_valid,
	kin				=> enc_kin,
	dout				=> enc_dout,
	dout_valid		=> serialTxReq,
	rd_out			=> open
);





-----------------------------------------
-- BITSTREAM GENERATOR
-----------------------------------------
-- this should be kept running continuously
-- with data from the 8b10b encoder	
-- output data rate is 1 bit per clock cycle

BITSTREAM_GENERATOR: process(clock)
variable b: natural:=0;		-- bit number (lsb is transmitted first)
variable txWord: std_logic_vector(9 downto 0);
variable data_reg: std_logic_vector(9 downto 0);
variable tx_req_flag: std_logic:= '0';
variable init: std_logic:= '1';

begin
	if (rising_edge(clock)) then	
    	
	
		-- init
		if (init = '1') then
			serialTxReq_z <= '0';
			init := '0';
		else
			serialTxReq_z <= serialTxReq;
		end if;
		
		
		-- input request 
		if (serialTxReq = '1' and serialTxReq_z = '0') then 	-- rising edge
			data_reg := enc_dout;		-- copy input data
			tx_req_flag := '1';
		end if;



		if (b = 0) then	-- bit 0. Get the new word to be transmitted
				
			if (tx_req_flag = '1') then 
				txWord := data_reg; 				-- get next data word
			else 
				txWord := "0000000000"; 				-- this should not happen! It means no data was provided to the serializer
			end if;	
			
			tx_req_flag := '0';	-- clear input request
			serialTxAck_req <= '1';		-- acknowledge the request			
					
		else
		
			serialTxAck_req <= '0';		
		
		end if;
		
			
		dout <= txWord(b);		-- output the data bit			
						
		
		b := b + 1;
		if (b >= 10) then b := 0; end if;

		
	end if;
end process;
	
		
-- serial din ack pulse generator
SERIAL_ACK_GEN: monostable_sync_edge port map (clock, 1, serialTxAck_req, serialTxAck);		-- generate a single ack pulse
		
	

	
	


					
END vhdl;









