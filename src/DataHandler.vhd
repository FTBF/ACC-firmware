---------------------------------------------------------------------------------
-- Univ. of Chicago HEP / electronics design group
--    -- + KICP 2015 --
--
-- PROJECT:      ACC
-- FILE:         dataHandler.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         Oct 2020
--
-- DESCRIPTION:  Handles data frame generation and transmission over the usb interface
--						Transmission is initiated by a command from the control computer
--
---------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL; 
use work.defs.all;



entity dataHandler is
	port (
		reset						: 	in   	std_logic;
		clock				      : 	in		std_logic;        
		serialRx					:	in		serialRx_type;
		pllLock					:  in std_logic;
		trig						:	in		trigSetup_type;
		channel          		: in  natural;      
      
      -- rx buffer ram signals
      ramReadEnable        : 	out 	std_logic_vector(7 downto 0);
      ramAddress           :  out   std_logic_vector(transceiver_mem_depth-1 downto 0);
      ramData              :  in    rx_ram_data_type;
      rxDataLen				:  in  	naturalArray_16bit;
		frame_received    	:  in   std_logic_vector(7 downto 0);
		bufferReadoutDone    :  buffer   std_logic_vector(7 downto 0);
		

      -- parameter signals
      param_readReq        : in std_logic;
      param_num            : in natural range 0 to 255;
  
        
      -- usb tx signals
      dout 		            : 	out	std_logic_vector(15 downto 0);
		txReq					   : 	out	std_logic;
      txAck                : 	in 	std_logic; -- a pulse input which shows that the data was sent to the usb chip
      txLockReq            : 	out	std_logic;
      txLockAck            : 	in  	std_logic;
      rxBuffer_readReq		:	in		std_logic;
		localInfo_readRequest: in std_logic;      
      acdcBoardDetect      : in std_logic_vector(7 downto 0);    
      useExtRef				:	in std_logic;

      -- data bit error monitors
      prbs_error_counts  : in DoubleArray_16bit;
      symbol_error_counts  : in DoubleArray_16bit;
      
      -- error
      timeoutError  			:	out	std_logic);
end dataHandler;


architecture vhdl of dataHandler is



type state_type is (
   CHECK_IF_SEND_DATA,
   BUS_REQUEST,
   DATA_SEND,
   DATA_ACK,
   DONE);
   
   




signal localData:  frameData_type;
signal address: natural;
signal txAck_z: std_logic;
signal trigSource_word: std_logic_vector(15 downto 0);
signal serialRx_statusWord: std_logic_vector(31 downto 0);

type ParamMapType is array(255 downto 0) of std_logic_vector(15 downto 0);
signal paramMap : ParamMapType;


	
	begin	
	

               
ramAddress <= std_logic_vector(to_unsigned(address,15));



   
   
DATA_HANDLER: process(clock)
variable getRamData: boolean;
variable getLocalData: boolean;
variable getParameter: boolean;
variable state: state_type;
variable t: natural; -- timeout value 
variable i: natural;  -- the index of the current data word within the frame = number of words done
variable frameLen: natural;
variable holdoff: natural; -- a delay between successive frames to give chance for rxPacketReceived to go low

begin
	if (rising_edge(clock)) then
	
		if (reset = '1') then
			
         bufferReadoutDone <= x"00";
			state := CHECK_IF_SEND_DATA;
         ramReadEnable <= X"FF"; 
         timeoutError <= '0';
         txReq <= '0';
         txLockReq <= '0';
			holdoff := 0;
         t := 0;
         
			
		else
		
			
         -- tx data acknowledge - rising edge detect
         
         txAck_z <= txAck;
         
         
			if (holdoff > 0) then holdoff := holdoff -  1; end if;
         
         
         
         case state is
         
         
         
				when CHECK_IF_SEND_DATA => -- check for rx buffer full, or request to send local info
			             
               i := 0;
               t := 0;
               address <= 0;
               
					bufferReadoutDone <= x"00";		
					
               timeoutError <= '0';
               
               getRamData := false;    -- flags used to indicate frame type required
               getLocalData := false;
               getParameter := false;
               
					if (rxBuffer_readReq = '1' and holdoff = 0) then
						if (rxDataLen(channel) > 0) then 
							frameLen :=  rxDataLen(channel);
							getRamData := true; 
							state := BUS_REQUEST;
						end if;				
					end if;
					
					if (localInfo_readRequest = '1' and holdoff = 0) then 
						frameLen := 32;
						getLocalData := true; 
						state := BUS_REQUEST;						
					end if;
                             
					if (param_readReq = '1' and holdoff = 0) then 
						frameLen := 1;
						getParameter := true; 
						state := BUS_REQUEST;						
					end if;
                             
               
			   
            when BUS_REQUEST =>               
               txLockReq <= '1';  -- request locking the usb bus in tx mode
               if (txLockAck = '1') then state := DATA_SEND; end if;  -- usb bus acknowledge, bus is now locked for tx use
               
               

            when DATA_SEND =>
               -- choose the correct data depending on the frame type and index pos within the frame
               if (getLocalData) then   
                 dout <= localData(i);
               elsif getParameter then
                 dout <= paramMap(param_num);
               else
						dout <= ramData(channel); --ram data                     
						address <= address + 1; 
               end if;
               txReq <= '1';   -- initiate the usb tx process
               i := i + 1; -- increment the index   (= number of words done)            
               t := 40000000;  -- set timeout delay 1s for data acknowledge
               state := DATA_ACK;
               
                  
                  
            when DATA_ACK =>
               txReq <= '0';
               if (txAck_z = '0' and txAck = '1') then  -- rising edge detect means the new data was acked
                  t := 0; -- clear timeout
                  if (i >= frameLen) then
                     state := DONE;
                  else
                     state := DATA_SEND;
                  end if;
               end if;
               
 

 
            when DONE => 
               txLockReq <= '0';    -- this going low causes the packet end signal to be sent and gives chance for the read module to operate if necessary
               if (txLockAck = '0') then                
                  if (getRamData) then bufferReadoutDone(channel) <= '1'; end if; -- flag that the buffer was read. This is used to reset the corresponding buffer write process
                  holdoff := 5;
						state := CHECK_IF_SEND_DATA;
               end if;
               
               
               
         end case;
         
         
         
         
         -- timeout error
         
         if (t > 0) then
            t := t - 1;
            if (t = 0) then 
               timeoutError <= '1';   -- generate an output pulse to indicate the error
               state := DONE; 
            end if;     
         else
            timeoutError <= '0';
         end if;
         
         
         
         
      end if;
      
   end if;
   
   
end process;
               
               
               
    
    
    
               




--------------------------------------------
-- LOCAL DATA FRAME
--------------------------------------------  

localData(0) <= x"1234";
localData(1) <= x"AAAA";
localData(2) <= firwareVersion.number;
localData(3) <= firwareVersion.year;
localData(4) <= firwareVersion.MMDD;
localData(5) <= x"0000";
localData(6) <= x"0000";
localData(7) <= x"00" & acdcBoardDetect;
localData(8) <= x"000" & "00" & trig.ppsMux_enable & trig.SMA_invert;
localData(9) <= x"0000";
localData(10) <= x"0000";
localData(11) <= x"0000";
localData(12) <= x"000" & "00" & pllLock & useExtRef;
localData(13) <= x"0000";
localData(14) <= x"00" & frame_received;
localData(15) <= x"0000";
localData(16) <= std_logic_vector(to_unsigned(rxDataLen(0),16));
localData(17) <= std_logic_vector(to_unsigned(rxDataLen(1),16));
localData(18) <= std_logic_vector(to_unsigned(rxDataLen(2),16));
localData(19) <= std_logic_vector(to_unsigned(rxDataLen(3),16));
localData(20) <= std_logic_vector(to_unsigned(rxDataLen(4),16));
localData(21) <= std_logic_vector(to_unsigned(rxDataLen(5),16));
localData(22) <= std_logic_vector(to_unsigned(rxDataLen(6),16));
localData(23) <= std_logic_vector(to_unsigned(rxDataLen(7),16));
localData(24) <= serialRx_statusWord(31 downto 16);
localData(25) <= serialRx_statusWord(15 downto 0);
localData(26) <= x"0000";
localData(27) <= x"0000";
localData(28) <= x"0000";
localData(29) <= x"0000";
localData(30) <= x"AAAA";
localData(31) <= x"4321";

error_mapping : process(all)
begin
  for i in 0 to 15 loop
    paramMap(i)      <= prbs_error_counts(i);
    paramMap(16 + i) <= symbol_error_counts(i);
  end loop;
end process;
               
-- serial rx status       
SERIAL_RX_STATUS: process(clock)
begin
	if (rising_edge(clock)) then
		for i in 0 to 7 loop
			serialRx_statusWord(i*4 + 0) <= serialRx.symbol_align_error(i);
			serialRx_statusWord(i*4 + 1) <= serialRx.rx_clock_fail(i);
			serialRx_statusWord(i*4 + 2) <= serialRx.disparity_error(i);
			serialRx_statusWord(i*4 + 3) <= serialRx.symbol_code_error(i);
		end loop;
	end if;
end process;



               
               
               
			
end vhdl;































