---------------------------------------------------------------------------------
-- FILE:         uart.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         Oct 2020
--
-- DESCRIPTION:  serial comms
--	       	    
---------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL; 



entity uart is
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
		rxError			:	out std_logic;
		rxIn				:	 IN STD_LOGIC
	);
end uart;


architecture vhdl of uart is


-- receiver notes
--
-- Normally a single sample is taken in the middle of the bit period to determine the bit value (0 or 1).
-- This has the disadvantage that an electrical spike lasting only one sample will cause a bit error
-- if it occurs exactly on the sampled bit.
--
-- In order to eliminate this problem and provide good noise immunity, 
-- in this receiver the bit will be sampled more than once.
--
-- Multiple samples will be taken during the bit period, and a sum will be generated
-- resulting from the number of logic '1' samples measured.
-- Then a decision will be made as to whether it is a 1 or 0 based whether more than half the samples
-- are logic 1.
--
-- e.g. if there are 8 samples taken during the bit period and 6 are 1's then it is logic 1.
-- If 8 samples are taken and only 3 are logic 1 then it is a logic 0.
--
-- two parameters specify the sampling period:
-- (i) Sample start    = the clock cycle number from start of bit period on which the first sample will be taken
-- (ii) samples per bit	= the number of consecutive samples that will be taken once sampling is started
-- 
-- This should give good immunity to noise and spikes that may be on the line.
-- You see, democracy does still exist...






type tx_state_type is (IDLE, TX_DATA);
signal tx_state: tx_state_type;
   
type rx_state_type is (IDLE, RX_DATA);
signal rx_state: rx_state_type;
   


constant frameLen: natural:= dataLen + 2;		-- add 2 for start & stop bits
constant holdoffTime: natural:= 4;			-- the number of clocks delay between successive tx words
constant samplesPerBit: natural:= clockDivRatio / 2;				-- the number of consecutive clock cycles on which sampling is performed
constant threshold: natural:= samplesPerBit / 2;				-- the number of samples that need to be high to result in a logic 1 for the bit
constant sampleStart: natural:= (clockDivRatio / 2) - (samplesPerBit / 2);		-- the clock cycle (from start of bit) on which sampling starts
   
   
signal txFrame: std_logic_vector(frameLen - 1 downto 0); 	
signal rxIn_z: std_logic_vector(3 downto 0);		-- delayed versions of the rx input

	
	
begin	
	
    


TX_PROCESS: process(clock)
variable bitsDone: natural range 0 to 255;	-- the small range keeps the bit width small which helps to keep the max operating frequnecy high
variable t: natural range 0 to 255;			
variable holdoff: natural range 0 to 255;
begin
	if (rising_edge(clock)) then
		
		if (reset = '1') then
		
			txOut <= '1';
			txData_ack <= '0';
			txReady <= '1';
			tx_state <= IDLE;
		
				
		else
		
			case tx_state is
			
			
				when IDLE => 

					txOut <= '1';
					txData_ack <= '0';
					
					if (holdoff > 0) then 
						holdoff := holdoff - 1; 	-- a delay between transmitted words
					else
						if (txData_valid = '1') then
							txFrame <= '1' & txData & '0'; 	-- stop bit + data + start bit. Note the frame is backwards as lsb will be sent first
							t := 0;
							bitsDone := 0;
							txReady <= '0';
							tx_state <= TX_DATA;
						else
							txReady <= '1';
						end if;
					end if;
					
					
				when TX_DATA =>
					
					if (t = 0) then txOut <= txFrame(bitsDone); end if;
					t := t + 1;
					if (t >= clockDivRatio) then
						t := 0;
						bitsDone := bitsDone + 1;
						if (bitsDone >= frameLen) then 
							txData_ack <= '1';
							tx_state <= IDLE; 
							holdoff := holdoffTime;
						end if;
					end if;
				
				
			end case;
		end if;
	end if;
end process;





RX_PROCESS: process(clock)
variable bitsDone: natural range 0 to 255;	-- the range specifier keeps the bit width small which helps to keep it fast
variable samplesDone: natural range 0 to 255;
variable sum: natural range 0 to 255;				-- the running total (per bit) of how many samples were logic 1 
variable t: natural range 0 to 255;				-- clock cycle number since the start of each bit. Cycles from 0 to (clockDivRatio - 1) during each bit period 
variable rxReg: std_logic_vector(dataLen - 1 downto 0);
variable bitValue: std_logic;
variable err: std_logic;
begin
	if (rising_edge(clock)) then
		
		rxIn_z <= rxIn_z(2 downto 0) & rxIn;	-- delayed and synced versions of the rx input	
		
				
		if (reset = '1') then
		
			rxData_valid <= '0';
			rx_state <= IDLE;
			rxError <= '0';
		
				
		else
		
			case rx_state is
			
			
				when IDLE => 

					rxError <= '0';
					rxData_valid <= '0';
					if (rxIn_z(2 downto 0) = "100") then		-- start bit edge detect (filtered)
						t := 1;		-- start on clock 1 as clock 0 was the rx_in_z(0) value already verified as 0 (the start flag). rx_in_z(0) is the data used for processing
						err := '0';
						bitsDone := 0;
						samplesDone := 0;
						sum := 0;
						rx_state <= RX_DATA;
					end if;
					
					
					
				when RX_DATA =>
								
					-- sample the bit multiple times to determine its value
					if (samplesDone < samplesPerBit and t >= sampleStart) then	-- sampling started, need to get the specified number of samples
						if (rxIn_z(0) = '1') then sum := sum + 1; end if;		-- sample the input and add its value to the running total of 1's received
						samplesDone := samplesDone + 1;
						if (samplesDone = samplesPerBit) then	-- finished taking samples. Now the bit value can be determined
							if (sum > threshold) then bitValue := '1'; else bitValue := '0'; end if;	-- a democratic decision to determine the bit value
							if (bitsDone >= 1 and bitsDone < 1 + dataLen) then	-- data bit
								rxReg(bitsDone - 1) := bitValue;
							elsif (bitsDone = 1 + dataLen) then  -- stop bit
								if (bitValue = '0') then err := '1'; end if;	-- stop bit is zero , this is an error
							end if;
						end if;
					end if;
										
					t := t + 1;
					if (t >= clockDivRatio) then
						t := 0;
						sum := 0;
						samplesDone := 0;
						bitsDone := bitsDone + 1;
						if (bitsDone >= frameLen) then
							if (err = '0') then 
								rxData_valid <= '1';
								rxData <= rxReg;
							else
								rxError <= '1';
							end if;
							rx_state <= IDLE; 
						end if;
					end if;
				
										
				
			end case;
		end if;
	end if;
end process;

               
               
			
end vhdl;































