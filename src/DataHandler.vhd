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
use work.components.all;
use work.LibDG.all;

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
    dataFIFO_auto    : in  std_logic;
	 dataFIFO_reset   : in  std_logic;
    
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
  
  signal dataFIFO_reset_eth_sync0 : std_logic;
  signal dataFIFO_reset_eth_sync1 : std_logic;
  signal dataFIFO_reset_eth_sync2 : std_logic;

  signal data_skidbuf  : std_logic_vector(15 downto 0);
  signal write_skidbuf : std_logic;
  signal read_skidbuf  : std_logic;
  signal data_muxed    : std_logic_vector(15 downto 0);

  signal data_re_loc   : std_logic_vector(N-1 downto 0);

  signal dataFIFO_readReq_z : std_logic;
  signal dataFIFO_chan_z    : natural range 0 to 15;

  signal dataFIFO_readReq_auto : std_logic;
  signal dataFIFO_chan_auto    : natural range 0 to 15;
  signal data_done             : std_logic;

begin	

  reset_eth_sync : process(eth_clk)
  begin
    if reset = '1' then
      reset_eth_sync0 <= '1';
      reset_eth_sync1 <= '1';
      reset_eth_sync2 <= '1';
    else
      if rising_edge(eth_clk) then
        reset_eth_sync2 <= reset_eth_sync1;
        reset_eth_sync1 <= reset_eth_sync0;
        reset_eth_sync0 <= reset;
      end if;
    end if;
  end process;

  syncReset: sync_Bits_Altera
    generic map (
      BITS       => 1,
      INIT       => "0",
      SYNC_DEPTH => 3)
    port map (
      Clock     => eth_clk,
      Input(0)  => dataFIFO_reset,
      Output(0) => dataFIFO_reset_eth_sync2);

  --dataFIFO_reset_eth_sync : process(eth_clk)
  --begin
  --  if reset = '1' then
  --    dataFIFO_reset_eth_sync0 <= '1';
  --    dataFIFO_reset_eth_sync1 <= '1';
  --    dataFIFO_reset_eth_sync2 <= '1';
  --  else
  --    if rising_edge(eth_clk) then
  --      dataFIFO_reset_eth_sync2 <= dataFIFO_reset_eth_sync1;
  --      dataFIFO_reset_eth_sync1 <= dataFIFO_reset_eth_sync0;
  --      dataFIFO_reset_eth_sync0 <= dataFIFO_reset;
  --    end if;
  --  end if;
  --end process;

  data_re <= data_re_loc;
  write_skidbuf <= or_reduce(data_re_loc) and not b_enable;

  control_sig_mux : process(all)
  begin
    if dataFIFO_auto = '1' then
      dataFIFO_readReq_z <= dataFIFO_readReq_auto;
      dataFIFO_chan_z    <= dataFIFO_chan_auto;
    else
      dataFIFO_readReq_z <= dataFIFO_readReq;
      dataFIFO_chan_z    <= dataFIFO_chan;
    end if;
  end process;

  data_readout_auto_controller_inst: data_readout_auto_controller
    port map (
      reset            => reset_eth_sync2 or dataFIFO_reset_eth_sync2,
      clock            => ETH_clk,
      dataFIFO_readReq => dataFIFO_readReq_auto,
      dataFIFO_chan    => dataFIFO_chan_auto,
      dataFIFO_auto    => dataFIFO_auto,
      data_occ         => data_occ,
      b_enable         => b_enable,
      data_done        => data_done);

  data_done <= b_data_force;
  
  data_in_mux : process(all)
  begin
    if read_skidbuf = '1' then
      data_muxed <= data_skidbuf;
    else
      data_muxed <= data_out(dataFIFO_chan_z);
    end if;
  end process;

  DATA_HANDLER: process(eth_clk, reset_eth_sync2, dataFIFO_reset_eth_sync2)
    variable iWord : natural;
    variable iChunk : natural;
    variable dataBuf : std_logic_vector(63 downto 0);
  begin
    if reset_eth_sync2 = '1' or dataFIFO_reset_eth_sync2 = '1' then
      state <= IDLE;
      iWord := 0;
      iChunk := 0;
      data_re_loc <= (others => '0');
      dataBuf := X"1111111111111111";
      read_skidbuf <= '0';
      b_data       <= X"3333333333333333";
      b_data_we    <= '0';
      b_data_force <= '0';
    else
      if rising_edge(eth_clk) then
        state <= state;
        b_data       <= X"2222222222222222";
        b_data_we    <= '0';
        b_data_force <= '0';
        data_re_loc <= (others => '0');

        if write_skidbuf = '1' then
          data_skidbuf <= data_out(dataFIFO_chan_z);
          read_skidbuf <= '1';
        end if;

        case state is
          when IDLE =>
            iWord := 0;
            iChunk := 0;
            if dataFIFO_readReq_z = '1' and to_integer(unsigned(data_occ(dataFIFO_chan_z))) >= EVENT_SIZE then
              state <= HEADER;
              data_re_loc(dataFIFO_chan_z) <= '1';
            end if;

          when HEADER =>
            if b_enable = '1' then
              b_data       <= X"123456789abcde" & std_logic_vector(to_unsigned(dataFIFO_chan_z, 8));
              b_data_we    <= '1';
              data_re_loc(dataFIFO_chan_z) <= '1';
              iWord := 0;
              iChunk := 0;
              state <= DATA;
            end if;

          when DATA =>
            if b_enable = '1' then
              dataBuf := dataBuf(47 downto 0) & data_muxed;
              read_skidbuf <= '0';
              
              if iChunk < 4 - 1 then
                iChunk := iChunk + 1;
              else
                iChunk := 0;
                b_data     <= dataBuf;
                b_data_we  <= '1';
                --dataBuf    := X"3333333333333333";
              end if;

              iWord := iWord + 1;
              if iWord >= EVENT_SIZE then
                state <= DONE;
              elsif iWord = EVENT_SIZE - 1 then
                data_re_loc(dataFIFO_chan_z) <= '0';
              else
                data_re_loc(dataFIFO_chan_z) <= '1';
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
