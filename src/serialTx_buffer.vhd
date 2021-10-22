---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
-- PROJECT:      ANNIE 
-- FILE:         uart_rxBuffer.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         June 2021
--
-- DESCRIPTION: 	 Accepts 32 bit instruction words which are written to a fifo
--							Words are read out of the fifo and a frame header is added to create a 6 byte frame
--							bytes are output to the serial transmitter
-- 						flow control is done with txReq input and txAck output, both rising edge triggered
---------------------------------------------------------------------------------

library IEEE; 
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL; 
use work.components.all;
use work.defs.all;
use work.LibDG.all;


entity serialTx_buffer is
	port(
		clock				: in	std_logic;	--system clock		 
      din				: in	std_logic_vector(31 downto 0);
		din_txReq		: in	std_logic;		 
		din_txAck		: out	std_logic;		 
		dout				: out	std_logic_vector(7 downto 0);
		dout_txReq		: out	std_logic;
		dout_txAck		: in	std_logic
		);	
		
end serialTx_buffer;

architecture vhdl of serialTx_buffer is




constant header: std_logic_vector(15 downto 0):= x"B734";




signal fifo_dout: std_logic_vector(31 downto 0);
signal fifo_rdreq: std_logic;
signal fifo_wrreq: std_logic;
signal fifo_empty: std_logic;
signal fifo_full: std_logic;

signal din_txReq_z: std_logic;
signal dout_txAck_z: std_logic;





begin




-----------------------------------------
-- FIFO WRITE
-----------------------------------------
-- check the fifo is not full and write the input data (32 bits)
-- then send an acknowledge that the data was written
FIFO_WR: process(clock)
variable fifo_wrreq_flag: std_logic:= '0';
begin
	if (rising_edge(clock)) then
		
		
		din_txReq_z <= din_txReq;
		
		
		if (din_txReq = '1' and din_txReq_z = '0' and fifo_full = '0') then 	-- rising edge on din_txReq
		
			fifo_wrreq <= '1';
			
		else
		
			fifo_wrreq <= '0';
		
		end if;
		
		
	end if;
	
end process;
		
-- din ack pulse generator
DIN_ACK_GEN: monostable_sync_edge port map (clock, 1, fifo_wrreq, din_txAck);		-- generate a single ack pulse
		
		
		
		
		
-----------------------------------------
-- FIFO READ
-----------------------------------------
-- check fifo for data and if not empty read a 32-bit word and create a 6 byte frame for transmission
-- send the bytes of the frame to the serializer, waiting for an 'ack' after each byte is sent
FIFO_RD: process(clock)
variable frame: std_logic_vector(47 downto 0);
variable byte_count: natural:= 0;
variable dout_txAck_flag: std_logic:= '0';

type state_type is (
	CHECK_FIFO,
	FIFO_RD_REQ,
	FIFO_READ,
	WRITE_BYTE,
	DATA_ACK
);
	
variable state: state_type:= CHECK_FIFO;

begin
	if (rising_edge(clock)) then
	
	
		-- transmitter acknowledge detect
		dout_txAck_z <= dout_txAck;
		if (dout_txAck = '1' and dout_txAck_z = '0') then 	-- rising edge
			dout_txAck_flag := '1';
		end if;



		case state is
		
			when CHECK_FIFO =>

                dout_txReq <= '0';
				if (fifo_empty = '0') then
			
					fifo_rdreq <= '1';			-- request a 32 bit word from the fifo
					state := FIFO_RD_REQ;
					
				end if;
				
				
			when FIFO_RD_REQ =>		-- on this cycle, fifo sees rd req high and outputs the data	
			
				fifo_rdreq <= '0';
				state := FIFO_READ;
				
				
			when FIFO_READ =>			-- data can be read on this clock
			
				frame := header & fifo_dout;
				byte_count := 0;
				state := WRITE_BYTE;
				
				
			when WRITE_BYTE =>
				
				dout <= frame(47 downto 40);
				dout_txReq <= '1';
				state := DATA_ACK;
				
				
			when DATA_ACK =>
			
				dout_txReq <= '0';
				if (dout_txAck_flag = '1') then
					dout_txAck_flag := '0';
					byte_count := byte_count + 1;
					frame := frame(39 downto 0) & x"00";	-- shift next byte into position
					if (byte_count >= 6) then
						state := CHECK_FIFO;
					else
						state := WRITE_BYTE;
					end if;
				end if;
				
				
		end case;
		
	end if;
end process;



			

TX_FIFO_map: txFifo port map 
(
		clock		=> clock,
		data		=> din,
		rdreq		=> fifo_rdreq,
		wrreq		=> fifo_wrreq,
		empty		=> fifo_empty,
		full		=> fifo_full,
		q			=> fifo_dout,
		usedw		=> open
);


	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
end vhdl;
