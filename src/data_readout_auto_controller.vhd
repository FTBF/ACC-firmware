library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL; 
use ieee.std_logic_misc.all;
use work.defs.all;

entity data_readout_auto_controller is
  port (
    reset            : in  std_logic;
    clock            : in  std_logic;

    dataFIFO_readReq : out  std_logic;
    dataFIFO_chan    : out  natural range 0 to 15;
    dataFIFO_auto    : in   std_logic;

    data_occ         : in  Array_16bit;

    data_done        : in std_logic
  );
end data_readout_auto_controller;


architecture vhdl of data_readout_auto_controller is

  type state_type is (IDLE, WAITFIFO);

  signal state : state_type;

  signal chan :   natural range 0 to 15;
  
begin

  control_loop : process(clock, reset)
  begin
    if rising_edge(clock) then
      if reset = '1' then
        dataFIFO_readReq <= '0';
        dataFIFO_chan <= 0;
        state <= IDLE;
        chan <= 0;
      else
        case state is
          when IDLE =>
            if chan < 8-1 then
              chan <= chan + 1;
            else
              chan <= 0;
            end if;
            
            if dataFIFO_auto = '1' then
              if to_integer(unsigned(data_occ(chan))) >= EVENT_SIZE then
                dataFIFO_readReq <= '1';
                dataFIFO_chan <= chan;
                state <= WAITFIFO;
              end if;
            else
              state <= IDLE;  
            end if;
            
          when WAITFIFO =>
            chan <= chan;
            dataFIFO_readReq <= '0';
            if data_done = '1' then
              state <= IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;

end vhdl;
