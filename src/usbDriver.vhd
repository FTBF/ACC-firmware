---------------------------------------------------------------------------------
-- Univ. of Chicago HEP / electronics design group
--    -- + KICP 2015 --
--
-- PROJECT:      ANNIE/LAPPD
-- FILE:         usbDriver.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         June 2021
--
-- DESCRIPTION:  Handles reading and writing of data to / from the usb chip
--
---------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.defs.all;




entity usbDriver is
   port ( 	
		
		clock   					: in		std_logic;
				
		-- signals to/from usb chip
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
		
		-- fpga signals
		tx_busReq  				: in		std_logic;  -- request to lock the bus in tx mode, preventing any interruptions from usb read
		tx_busAck  				: out		std_logic;  
      txData_in        		: in   	std_logic_vector(15 downto 0);		
      txReq		        		: in   	std_logic;		
      txAck		        		: out   	std_logic;		
      rxData_out       		: out   	std_logic_vector(31 downto 0);
		rxData_valid     		: out		std_logic;
		
		test						: out		std_logic_vector(15 downto 0)
		
);
end usbDriver;


	
architecture vhdl of usbDriver is


-- note
--
-- We will use the aynchronous timings specified in the usb chip datasheet for reading and writing,
-- therefore there is no need to use  usb clock supplied by the chip.
-- We can use system clock (40MHz) so long as we meet these timings.
--
-- As is standard practice, all input signals changing asynchronously to the system clock must be sychronized first.
-- This includes the two flags from the usb chip: 'tx buffer ready', and 'rx data available'.
--
--	There is only one data bus so an arbitration method is needed to switch between read and write.
-- The default mode will be reading, but if transmit is required, the data sending module
-- must request and receive acknowledgement for bus access before it may start sending.
-- During this mode the state machine will be locked into tx mode and read will be suspended
-- until the data sender de-asserts the bus request signal.
--
-- To transmit a data word once bus access is granted, apply the data to din with a rising edge on txReq.
-- Wait for a rising edge on txAck, then repeat the cycle for the next data word.
-- Once bus request is deasserted a packet end signal will be sent so that the usb chip sends the current
-- packet immediately which may not be a full packet.
--
-- Output data is 32-bits made by concatenating two successive 16-bit words.
-- If a 16-bit word was received but no other word is received to complete the 32-bit word within a certain time,
-- a timeout will reset the state machine so that it will restart looking for the first 16-bit word again.



-- Async read timings from datasheet:
--	
-- SLRD LOW 					50 ns min
-- SLRD HIGH 					50 ns min
-- SLRD to FLAGS 				70 ns max
-- SLRD to FIFO data out	15 ns max
-- SLOE to FIFO valid		10.5ns max
-- SLOE to FIFO hold			10.5ns max


-- Async write timings from datasheet:
--
-- SLWR LOW						50 ns min
-- SLWR HIGH					70 ns min
-- SLWR to FIFO DATA setup	10 ns min
-- FIFO data to SLWR hold	10 ns min
-- SLWR to FLAGS output		70 ns max


-- 
-- Aynchronous packet end: 
--
-- PKTEND LOW					50 ns min
-- PKTEND HIGH					50 ns min
-- PKTEND to FLAGS output	115 ns max


-- Note that there should also be added to the above timings a value
-- that includes fpga IO delays and also pcb trace delays.
--
-- A suggested reasonable value for this would be around 10ns
--
-- Note also that due synchronization of the input flags to the system clock,
-- a further clock cycle (25ns) will have to be added for any timings using these signals.


signal   txBufferReady_z 		: std_logic;		
signal	rxDataAvailable_z  	: std_logic;   
signal	txReq_z					: std_logic;   


	
begin




USB_CTRL: process(clock)
variable tx_req_flag: std_logic:='0';			-- valid output data flag
variable tx_data_reg: std_logic_vector(15 downto 0);
variable rx_data_reg: std_logic_vector(31 downto 0);
variable t: natural:= 0;
variable v: std_logic;			-- valid output data flag
variable w: natural;			-- wait cycle counter
variable rx_word_count: natural:= 0;
type state_type is (INIT, CHECK_FLAGS, READ_RX_DATA, WAIT_RD_HIGH, SEND_TX_DATA, WAIT_WR_LOW,
	WAIT_WR_HIGH, SEND_PKTEND, PKTEND_LOW_WAIT, PKTEND_HIGH_WAIT);
variable state: state_type:= INIT;
begin
	if (rising_edge(clock)) then
		
		-- sync
      txBufferReady_z <= txBufferReady;
		rxDataAvailable_z <= rxDataAvailable;
		txReq_z <= txReq;
		
		-- edge detect
		if (txReq = '1' and txReq_z = '0') then tx_req_flag := '1'; tx_data_reg := txData_in; end if;
		
		v := '0';
		
		
		case state is
			
      
			when INIT =>		
			
				busWriteEnable <= '0';		-- enable output data from fpga onto usb bus (active high)
				SLWR				<=	'1';
				SLRD				<=	'1';
				SLOE				<=	'1';		-- enable output data from usb device onto bus (active low)
				PKTEND  			<= '1';		--usb packet end flag
				FIFOADR  	   <= "00"; 	-- "00" = RX FIFO; 
            txAck				<= '0';
            rxData_valid	<= '0';
            tx_busAck		  <= '0';      
				rx_word_count := 0;
				w := 0;
				state := CHECK_FLAGS;
				
				
			when CHECK_FLAGS =>		-- CHECK RX DATA RECEIVED OR TX BUS REQUEST
								
				w := 0;					
				if (rxDataAvailable_z = '1') then
					busWriteEnable <= '0';
					FIFOADR <= "00"; -- select the rx data fifo  
					SLOE <= '0'; 
					SLRD <= '0';	
					SLWR <= '1';	
					state := READ_RX_DATA;		
				elsif (tx_busReq = '1') then
					tx_busAck <= '1';
					busWriteEnable <= '1';
					FIFOADR <= "10"; 	-- "10" = TX FIFO
					SLOE <= '1'; 
					SLRD <= '1';	
					state := SEND_TX_DATA;
				end if;
			
			
			
			
			
-------------------------------------
-- READ RX DATA
-------------------------------------

-- Timings:

-- RD low width:	50 ns = 2 clocks
-- RD high width:	50 ns = 2 clocks
-- RD low to flags valid: 70ns + 10ns (2 * pcb/fpga delay) + 25ns (flag sync) = 105 ns = 5 clocks
--
-- An extra clock is generated going from state 'rd high' to state 'check flags'
-- so rd low to flags timing will have 5 clocks total.
 

			when READ_RX_DATA =>		
								
				w := w + 1; 
				if (w >= 2) then			-- rd low wait
					t := 0;
					case rx_word_count is
						when 0 => rx_data_reg(15 downto 0) := rxData_in; 
						when 1 => rx_data_reg(31 downto 16) := rxData_in; 
						when others => null;
					end case;
					rx_word_count := rx_word_count + 1;
					if (rx_word_count >= 2) then 				-- 2 words received = valid data out
						v := '1'; 
						rxData_out <= rx_data_reg;
						rx_word_count := 0; 
					end if;	
					SLOE <= '1'; 
					SLRD <= '1';	
					w := 0;
					state := WAIT_RD_HIGH;
				end if;
										
				
			when WAIT_RD_HIGH => 		 
			
				w := w + 1; 
				if (w >= 2) then		-- rd high wait
					state := CHECK_FLAGS;
				end if;


				
				
-------------------------------------
-- SEND TX DATA
-------------------------------------

-- Timings:

-- WR low width:	50 ns = 2 clocks
-- WR high width:	70 ns = 3 clocks
-- WR low to flags valid: 70ns + 10ns (2 * pcb/fpga delay) + 25ns (flag sync) = 105 ns = 5 clocks
--
-- An extra wr high clock is generated going from state 'wr high' to state 'send tx data'
-- so wr high timing can be reduced to 2 clocks and still give 5 clocks total for wr low to flags.
 
 


			when SEND_TX_DATA =>		-- CHECK FOR WRITE REQUEST

				if (tx_req_flag = '1' and txBufferReady_z = '1') then
					tx_req_flag := '0';
					txAck <= '1';
					txData_out <= tx_data_reg;
					SLWR <= '0'; 
					w := 0;					
					state := WAIT_WR_LOW;
				elsif (tx_busReq = '0') then
					state := SEND_PKTEND;	-- send packet end
				end if;
				
				
			when WAIT_WR_LOW => 		
				
				txAck <= '0';
				w := w + 1; 
				if (w >= 2) then		-- wr low wait. 
					SLWR <= '1';
					w := 0;
					state := WAIT_WR_HIGH;
				end if;
				
					
			when WAIT_WR_HIGH =>		
			
				txAck <= '0';
				w := w + 1; 
				if (w >= 2) then		-- WR high wait. 
					state := SEND_TX_DATA;
				end if;
				
				
							
				
				
-------------------------------------
-- SEND PACKET END
-------------------------------------
			
			
			when SEND_PKTEND =>		
			
				busWriteEnable <= '0';
				PKTEND <= '0';		
				w := 0;
				state := PKTEND_LOW_WAIT;
				
				
			when PKTEND_LOW_WAIT =>		
				
				w := w + 1; 
				if (w >= 3) then			-- wait clocks. Timing = 50 (pktend low) + 10 (fpga/pcb) = 60 ns = 3 clock cycles @ 40MHz-- wait clocks. 
					PKTEND <= '1';
					state := PKTEND_HIGH_WAIT;
				end if;
			
				
			when PKTEND_HIGH_WAIT =>		
			
				w := w + 1; 
				if (w >= 3) then		-- wait clocks. Timing = 65 (pktend to flags - pktned low) + 10 (fpga/pcb) = 75 ns = 3 clock cycles @ 40MHz-- wait clocks. 
					tx_busAck <= '0';				
					state := CHECK_FLAGS;
				end if;
				
								
				
		end case;
		


		
-------------------------------------
-- PARTIAL RX WORD TIMEOOUT
-------------------------------------

		-- timeout timer for partial 32-bit words received- reset back to looking for first word
		t := t + 1; if (t > 400000 and rx_word_count = 1) then rx_word_count := 0; end if;
		
		
		
		
		
		
		rxData_valid <= v;
			
			
	end if;
	
end process;




   
   
   

end vhdl;



