library IEEE; 
use ieee.std_logic_1164.all;
USE ieee.numeric_std.ALL; 
use work.defs.all;
use work.components.all;
use work.LibDG.all;

entity io_delay_ctrl is
  port(
    clk    : in std_logic;
    reset  : in std_logic;

    delayCommand       : in std_logic_vector(11 downto 0);
    delayCommandSet    : in std_logic;
    delayCommandMask   : in std_logic_vector(15 downto 0) := x"0000";

    io_config_clkena : out std_logic_vector(15 downto 0);
    io_config_datain : out std_logic;
    io_config_update : out std_logic

    );
end io_delay_ctrl;

architecture vhdl of io_delay_ctrl is

  constant NBITS : natural := 25;
  
begin  -- architecture vhdl

  delay_ctrl : process(clk)
    type STATE_TYPE is ( IDLE, WRITE_DATA, WRITE_ZEROS, UPDATE);
    variable state : STATE_TYPE;
    variable ibit : natural;
  begin
    if rising_edge(clk) then
      if reset = '1' then
        io_config_clkena <= X"0000";
        io_config_datain <= '0';
        io_config_update <= '0';
        ibit := NBITS-1;
        state := IDLE;
      else
        case state is
          when IDLE =>
            if delayCommandSet = '1' then
              io_config_clkena <= delayCommandMask;
              io_config_datain <= '0';
              io_config_update <= '0';
              ibit := ibit - 1;
              state := WRITE_ZEROS;
            else
              io_config_clkena <= X"0000";
              io_config_datain <= '0';
              io_config_update <= '0';
              ibit := NBITS-1;
              state := state;
            end if;

          when WRITE_ZEROS =>
            io_config_clkena <= io_config_clkena;
            io_config_datain <= '0';
            io_config_update <= '0';
            ibit := ibit - 1;
            if ibit >= 12 then
              state := state;
            else
              state := WRITE_DATA;
            end if;

          when WRITE_DATA =>
            io_config_datain <= delayCommand(ibit);
            io_config_update <= '0';
            ibit := ibit - 1;
            if ibit > 0 then
            io_config_clkena <= io_config_clkena;
              state := state;
            else
              io_config_clkena <= X"0000";
              state := UPDATE;
            end if;

          when UPDATE =>
            io_config_clkena <= X"0000";
            io_config_datain <= '0';
            io_config_update <= '1';
            ibit := 0;
            state := IDLE;
            
        end case;
      end if;
    
    end if;
    
  end process;
    

end architecture vhdl;
