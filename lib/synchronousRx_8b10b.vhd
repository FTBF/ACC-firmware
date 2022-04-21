---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
--
-- PROJECT:      ANNIE - ACDC
-- FILE:         serialRx.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         May 2021
--
-- DESCRIPTION:  serially receives the synchronous bitstream and converts it to bytes
--
--						Performs various tasks:
--							clock recovery
--							symbol synchronization 
--							data recovery
--
-- received data is a continuous stream of 10-bit words
-- These have a limited number of consecutive 0's or 1's
-- so that a clock may be recovered from each edge received
--
-- special synchronization words are sent periodically which allow the
-- receiver to align its symbols at the correct bit position
--

---------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all; 
USE ieee.numeric_std.ALL;
LIBRARY work;
use work.defs.all;
use work.LibDG.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;


ENTITY synchronousRx_8b10b IS 
	PORT
	(
		clock_sys				:  IN  STD_LOGIC;
		clock_x4					:  IN  STD_LOGIC;
		clock_x8					:  IN  STD_LOGIC;
		din						:  IN  STD_LOGIC;
		rx_clock_fail			:	buffer std_logic;
		symbol_align_error	:	buffer std_logic;
		symbol_code_error		:	buffer std_logic;
		disparity_error		:	out std_logic;
		dout 						:	buffer STD_LOGIC_VECTOR(7 DOWNTO 0);	-- byte out
		kout 						:	buffer STD_LOGIC;		-- when high indicates the output byte is a control byte, not data
		dout_valid				:  buffer STD_LOGIC
	);
END synchronousRx_8b10b;


ARCHITECTURE vhdl OF synchronousRx_8b10b IS 



signal rd_out: integer;
signal rd_reset: std_logic;
signal rxBit: std_logic;
signal rxBit_valid: std_logic;
signal rxBit_x: std_logic;
signal rxBit_y: std_logic;
signal rxBit_valid_x: std_logic;
signal rxBit_valid_y: std_logic;
signal serialIn_z: std_logic;
signal serialIn_z2: std_logic;
signal symbol: std_logic_vector(9 downto 0);
signal symbol_y: std_logic_vector(9 downto 0);
signal symbol_valid: std_logic;
signal symbol_valid_y: std_logic;
signal symbol_valid_z: std_logic;
signal symbol_align_error_y: std_logic;
signal sync_timeout_error: std_logic;
signal sync_timeout_error_y: std_logic;
signal clock_detect: std_logic;
signal disparity_error_y: std_logic;
signal bitFIFOEmpty : std_logic;


constant sync_word0: std_logic_vector(9 downto 0):= "0001111100";		-- the symbol for codeword K28.7
constant sync_word1: std_logic_vector(9 downto 0):= "0010111100";		-- the symbol for codeword K28.0





begin



	
---------------------------------------------------
-- DATA RECOVERY
---------------------------------------------------
DECODER_map: decoder_8b10b port map (
	clock				=> clock_sys,
	rd_reset			=> rd_reset,
	din				=> symbol,
	din_valid		=> symbol_valid,
	kout				=> kout,
	dout				=> dout,
	dout_valid		=> dout_valid,
	rd_out			=> rd_out,
	symbol_error	=> symbol_code_error
);






---------------------------------------------------
-- ERROR CHECKING
---------------------------------------------------
DATA_REC: process(clock_sys)
variable t_sync: natural:= 0;
variable clk_timeout: natural:= 0;
begin
	if (rising_edge(clock_sys)) then
				
				
		--sync
		symbol <= symbol_y;
		symbol_valid <= symbol_valid_y;
		symbol_align_error <= symbol_align_error_y or rx_clock_fail;
		disparity_error <= disparity_error_y or rx_clock_fail;


		-- sync timeout check
		if (t_sync > 0) then 
			sync_timeout_error <= '0';
			t_sync := t_sync - 1; 
		else 
			sync_timeout_error <= '1';
			t_sync := 50000;			-- reset timeout. This ensures that sync_timeout_error doesn't stay high so that the symbol alignment has a chance to lock on again.
		end if;
		
		if (dout = K28_7 and kout = '1' and dout_valid = '1') then	
			t_sync := 50000;
		end if;
		
		
		-- clock fail detect 
		if (clock_detect = '1') then 
			clk_timeout := 40; 
			rx_clock_fail <= '0';
		else
			if (clk_timeout > 0) then
				clk_timeout := clk_timeout - 1;
				rx_clock_fail <= '0'; 
			else 
				rx_clock_fail <= '1'; 
			end if;
		end if;


		-- running disparity check (difference between number of 1's received and number of 0's received); this is a check for DC on the line
		if (rd_out > 100 or rd_out < -100) then 
			disparity_error <= '1'; 
		else 
			disparity_error <= '0'; 
		end if;
		rd_reset <= symbol_align_error;
	
	
	end if;
end process;

-- sync to x4 clock
SYNC_ERR: pulseSync port map (clock_sys, clock_x4, sync_timeout_error, sync_timeout_error_y);

-- rising edge detect
CLOCK_DET: monostable_async_edge port map (clock_sys, 1, serialIn_z, clock_detect);







---------------------------------------------------
-- SYMBOL RECOVERY 
---------------------------------------------------
-- rx bitstream is a continuous stream of 10 bit words
-- so we need to find out which is bit 0 and then everything will
-- fall into place and all the received data will be correct
--
-- This is done by looking for special unique sync words which have a longer
-- than normal string of 1's or 0's and so can be easily identified
-- once locked in it should stay in sync
--
-- sync words will be sent periodically by the sending end

SYMBOL_SYNC: process(clock_sys)
variable  sym_reg: std_logic_vector(19 downto 0);		-- Symbol register. Stores the most recent 2 symbols. This length is needed is for detecting the 2-symbol sync word
variable  b: natural range 0 to 15;	-- bit number
variable  aligned: std_logic:= '0';
variable  sync_detect: std_logic_vector(1 downto 0);
begin
  if (rising_edge(clock_sys)) then
    
    -- sync
    rxBit <= rxBit_y;
    --rxBit_valid <= rxBit_valid_y;
    
    -- store bit in shift register. Lsb is always recevied first
    sym_reg := rxBit & sym_reg(19 downto 1);

    -- check for special unique symbol sync code if not yet aligned
    if (aligned = '0') then
      sync_detect := "00";
      if (sym_reg(19 downto 10) =      sync_word1  and sym_reg(9 downto 0) =      sync_word0)  then sync_detect(0) := '1'; end if;
      if (sym_reg(19 downto 10) = (not sync_word1) and sym_reg(9 downto 0) = (not sync_word0)) then sync_detect(1) := '1'; end if;
      if (sync_detect(0) = '1' or sync_detect(1) = '1') then
        aligned := '1';
        b := 9;			-- the bit just stored must be the last bit (msb) of the special code which has just been received, because the lsb is transmitted first
      end if;
    end if;		
    
    if (b = 9 and aligned = '1') then		-- bit 9 was just received i.e. the 10th bit so a complete symbol has been received and is in the shift reg			
      symbol_y <= sym_reg(9 downto 0);		-- output the new symbol to the symbol decoder
      symbol_valid_y <= '1'; 
    else				
      symbol_valid_y <= '0';
    end if;
    
    b := b + 1;	if (b = 10) then b := 0; end if;		-- bit counter
    
    symbol_align_error_y <= not aligned;
    
    if (sync_timeout_error_y = '1') then aligned := '0'; end if;
    
  end if;
end process;

-- sync to sys clock
--SYMBOL_CLOCK_SYNC: pulseSync port map (clock_x4, clock_sys, symbol_valid_y, symbol_valid_z);



------------------------------------------
-- BIT RECOVERY
------------------------------------------
-- recover the data bits from the received data stream by starting a timer at each clock transition received.
-- then count the x8 clock cycles to find the middle of the bit period
-- input bits will be sampled at the centre of the bit period
--
-- This is the only process that needs to run on the fastest clock (320MHz)
--
BIT_RECOVERY: process(clock_x8)
variable t: unsigned(2 downto 0);
begin
	if (rising_edge(clock_x8)) then
		
        serialIn_z <= din;
		serialIn_z2 <= serialIn_z;

        -- input transition
		if (serialIn_z /= serialIn_z2) then
          t := "000";
        else
          t := t + 1;
        end if;		
			
		-- processing clock = 320MHz
		-- input bit rate = 40Mbps
		-- so 8 processing clocks per bit, therefore t = 4 gives centre of bit
		
		if (t = 4) then 
			rxBit_x <= serialIn_z;		-- the recovered output bit
			rxBit_valid_x <= '1'; 		-- output valid flag
		else 
			rxBit_valid_x <= '0'; 
		end if;
	end if;
end process;

dcfifo_component : dcfifo
  GENERIC MAP (
    intended_device_family => "Arria V",
    lpm_numwords => 8,
    lpm_showahead => "OFF",
    lpm_type => "dcfifo",
    lpm_width => 1,
    lpm_widthu => 3,
    overflow_checking => "ON",
    rdsync_delaypipe => 2,
    read_aclr_synch => "OFF",
    underflow_checking => "ON",
    use_eab => "ON",
    write_aclr_synch => "OFF",
    wrsync_delaypipe => 2
	)
  PORT MAP (
    aclr => '0',
    data(0) => rxBit_x,
    rdclk => clock_sys,
    rdreq => not bitFIFOEmpty,
    wrclk => clock_x8,
    wrreq => rxBit_valid_x,
    q(0) => rxBit_y,
    rdempty => bitFIFOEmpty,
    rdusedw => open,
    wrfull => open,
    wrusedw => open
	);


-- sync to x4 clock
--BIT_CLOCK_SYNC: pulseSync port map (clock_x8, clock_x4, rxBit_valid_x, rxBit_valid_y);


end vhdl;
