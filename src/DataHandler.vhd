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
    reset            : in  std_logic;
    clock            : in  std_logic;
    eth_clk          : in  std_logic;

    -- Ethernet burst controls
    b_data           : out std_logic_vector (63 downto 0);
    b_data_we        : out std_logic;
    b_data_force     : out std_logic;
    b_enable         : in  std_logic;
    
    -- Highspeed data FIFO controls
    dataFIFO_readReq : in  std_logic;
    
    data_out         : in  Array_16bit;
    data_occ         : in  Array_16bit;
    data_re          : out std_logic_vector(N-1 downto 0)
  );
end dataHandler;


architecture vhdl of dataHandler is

  type state_type is (
    IDLE,
    HEADER,
    DATA,
    DONE);

  signal state : state_type;

  signal reset_eth_sync0 : std_logic;
  signal reset_eth_sync1 : std_logic;
  signal reset_eth_sync2 : std_logic;

  
begin	

  reset_eth_sync : process(eth_clk)
  begin
    if reset = '1' then
      reset_eth_sync0 <= '1';
      reset_eth_sync1 <= '1';
      reset_eth_sync2 <= '1';
    else
      if rising_edge(eth_clk) then
        reset_eth_sync0 <= reset;
        reset_eth_sync1 <= reset_eth_sync0;
        reset_eth_sync2 <= reset_eth_sync1;
      end if;
    end if;
  end process;


  DATA_HANDLER: process(eth_clk, reset_eth_sync2)
    variable iACDC : natural;
  begin
    if reset_eth_sync2 = '1' then
      state <= IDLE;
    else
      if rising_edge(eth_clk) then
      end if;
    end if;
  end process;
  
  
--DATA_HANDLER: process(clock)
--  variable getRamData: boolean;
--  variable getFIFOData: boolean;
--  variable getLocalData: boolean;
--  variable getParameter: boolean;
--  variable state: state_type;
--  variable t: natural; -- timeout value 
--  variable i: natural;  -- the index of the current data word within the frame = number of words done
--  variable frameLen: natural;
--  variable holdoff: natural; -- a delay between successive frames to give chance for rxPacketReceived to go low
--  variable data_re_v : std_logic_vector(N-1 downto 0);
--
--begin
--  if (rising_edge(clock)) then
--	
--    if (reset = '1') then
--      
--      bufferReadoutDone <= x"00";
--      state := CHECK_IF_SEND_DATA;
--      ramReadEnable <= X"FF"; 
--      timeoutError <= '0';
--      txReq <= '0';
--      txLockReq <= '0';
--      holdoff := 0;
--      t := 0;
--      data_re <= X"00";
--      
--    else
--      
--      -- tx data acknowledge - rising edge detect
--      txAck_z <= txAck;
--      
--      if (holdoff > 0) then holdoff := holdoff -  1; end if;
--      
--      case state is
--        
--        when CHECK_IF_SEND_DATA => -- check for rx buffer full, or request to send local info
--          
--          i := 0;
--          t := 0;
--          address <= 0;
--          data_re <= X"00";
--          
--          bufferReadoutDone <= x"00";		
--          
--          timeoutError <= '0';
--          
--          getRamData := false;    -- flags used to indicate frame type required
--          getFIFOData := false;
--          getLocalData := false;
--          getParameter := false;
--          
--          if (dataFIFO_readReq = '1' and holdoff = 0) then
--              frameLen :=  to_integer(signed(data_occ(channel)));
--              getFIFOData := true;
--              -- advance to the first data word 
--              data_re_v := X"00";
--              data_re_v(channel) := '1';
--              data_re <= data_re_v;
--              state := BUS_REQUEST;
--          end if;
--
--          if (rxBuffer_readReq = '1' and holdoff = 0) then
--            if (rxDataLen(channel) > 0) then 
--              frameLen :=  rxDataLen(channel);
--              getRamData := true; 
--              state := BUS_REQUEST;
--            end if;				
--          end if;
--
--          if (localInfo_readRequest = '1' and holdoff = 0) then 
--            frameLen := 32;
--            getLocalData := true; 
--            state := BUS_REQUEST;						
--          end if;
--          
--          if (param_readReq = '1' and holdoff = 0) then 
--            frameLen := 1;
--            getParameter := true; 
--            state := BUS_REQUEST;						
--          end if;
--          
--        when BUS_REQUEST =>               
--          txLockReq <= '1';  -- request locking the usb bus in tx mode
--          data_re <= X"00";
--          if (txLockAck = '1') then
--            state := DATA_SEND; -- usb bus acknowledge, bus is now locked for tx use
--          end if;  
--
--        when DATA_SEND =>
--          -- choose the correct data depending on the frame type and index pos within the frame
--          data_re <= X"00";
--          if (getLocalData) then   
--            dout <= localData(i);
--          elsif getParameter then
--            dout <= paramMap(param_num);
--          elsif getRamData then
--            dout <= ramData(channel); --ram data                     
--            address <= address + 1; 
--          else -- getFIFOData
--            dout <= data_out(channel); --ram data                     
--            data_re_v := X"00";
--            data_re_v(channel) := '1';
--            data_re <= data_re_v;
--          end if;
--          txReq <= '1';   -- initiate the usb tx process
--          i := i + 1; -- increment the index   (= number of words done)            
--          t := 40000000;  -- set timeout delay 1s for data acknowledge
--          state := DATA_ACK;
--          
--        when DATA_ACK =>
--          txReq <= '0';
--          data_re <= X"00";
--          if (txAck_z = '0' and txAck = '1') then  -- rising edge detect means the new data was acked
--            t := 0; -- clear timeout
--            if (i >= frameLen) then
--              state := DONE;
--            else
--              state := DATA_SEND;
--            end if;
--          end if;
--          
--        when DONE => 
--          txLockReq <= '0';    -- this going low causes the packet end signal to be sent and gives chance for the read module to operate if necessary
--          if (txLockAck = '0') then                
--            if (getRamData) then bufferReadoutDone(channel) <= '1'; end if; -- flag that the buffer was read. This is used to reset the corresponding buffer write process
--            holdoff := 5;
--            state := CHECK_IF_SEND_DATA;
--          end if;
--          
--      end case;
--      
--      -- timeout error
--      
--      if (t > 0) then
--        t := t - 1;
--        if (t = 0) then 
--          timeoutError <= '1';   -- generate an output pulse to indicate the error
--          state := DONE; 
--        end if;     
--      else
--        timeoutError <= '0';
--      end if;
--      
--    end if;
--    
--  end if;
--   
--   
--end process;
               
			
end vhdl;































