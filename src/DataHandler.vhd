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
use ieee.std_logic_misc.all;
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
    dataFIFO_chan    : in  natural range 0 to 15;
    
    data_out         : in  Array_16bit;
    data_occ         : in  Array_16bit;
    data_re          : out std_logic_vector(N-1 downto 0)
  );
end dataHandler;


architecture vhdl of dataHandler is

  type state_type is (
    IDLE,
    HEADER,
    HEADER2,
    DATA,
    DONE);

  signal state : state_type;

  signal reset_eth_sync0 : std_logic;
  signal reset_eth_sync1 : std_logic;
  signal reset_eth_sync2 : std_logic;

  signal data_skidbuf  : std_logic_vector(15 downto 0);
  signal write_skidbuf : std_logic;
  signal read_skidbuf  : std_logic;
  signal data_muxed    : std_logic_vector(15 downto 0);

  signal data_re_loc   : std_logic_vector(N-1 downto 0);

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

  data_re <= data_re_loc;
  write_skidbuf <= or_reduce(data_re_loc) and not b_enable;

  data_in_mux : process(all)
  begin
    if read_skidbuf = '1' then
      data_muxed <= data_skidbuf;
    else
      data_muxed <= data_out(dataFIFO_chan);
    end if;
  end process;

  DATA_HANDLER: process(eth_clk, reset_eth_sync2)
    variable iWord : natural;
    variable iChunk : natural;
    variable dataBuf : std_logic_vector(63 downto 0);
  begin
    if reset_eth_sync2 = '1' then
      state <= IDLE;
      iWord := 0;
      iChunk := 0;
      data_re_loc <= X"00";
      dataBuf := X"0000000000000000";
      read_skidbuf <= '0';
    else
      if rising_edge(eth_clk) then
        state <= state;
        b_data       <= X"0000000000000000";
        b_data_we    <= '0';
        b_data_force <= '0';
        data_re_loc <= X"00";

        if write_skidbuf = '1' then
          data_skidbuf <= data_out(dataFIFO_chan);
          read_skidbuf <= '1';
        end if;

        case state is
          when IDLE =>
            iWord := 0;
            iChunk := 0;
            if dataFIFO_readReq = '1' and to_integer(unsigned(data_occ(dataFIFO_chan))) >= 7696 then
              state <= HEADER;
              data_re_loc(dataFIFO_chan) <= '1';
            end if;

          when HEADER =>
            if b_enable = '1' then
              b_data       <= X"123456789abcdef0";
              b_data_we    <= '1';
              data_re_loc(dataFIFO_chan) <= '1';
              iWord := 0;
              iChunk := 0;
              state <= HEADER2;
            end if;

          when HEADER2 =>
            if b_enable = '1' then
              dataBuf(15 + (3 - iChunk)*16 downto 0 + (3 - iChunk)*16) := data_muxed;
              read_skidbuf <= '0';
              
              if iChunk < 4 - 1 then
                iChunk := iChunk + 1;
              else
                iChunk := 0;
                b_data     <= dataBuf;
                b_data_we  <= '1';
              end if;

              iWord := iWord + 1;
              if iWord >= 16 then
                iWord := 0;
                iChunk := 0;
                dataBuf(63 downto 60) := X"0";
                state <= DATA;
              end if;

              data_re_loc(dataFIFO_chan) <= '1';
            end if;

          when DATA =>
            if b_enable = '1' then
              dataBuf(11 + (4 - iChunk)*12 downto 0 + (4 - iChunk)*12) := data_muxed(11 downto 0);
              read_skidbuf <= '0';
              
              if iChunk < 5 - 1 then
                iChunk := iChunk + 1;
              else
                iChunk := 0;
                b_data     <= dataBuf;
                b_data_we  <= '1';
                dataBuf    := X"0000000000000000";
              end if;

              iWord := iWord + 1;
              if iWord >= 7680 then
                state <= DONE;
                if iChunk /= 0 then
                  b_data     <= dataBuf;
                  b_data_we  <= '1';
                end if;

              else
                data_re_loc(dataFIFO_chan) <= '1';
              end if;
            end if;
              
          when DONE =>
            b_data_force <= '1';
            state <= IDLE;
            
        end case;
      end if;
    end if;
  end process;
  			
end vhdl;
