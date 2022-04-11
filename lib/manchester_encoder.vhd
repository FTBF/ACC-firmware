---------------------------------------------------------------------------------
--    
--
-- PROJECT:      ANNIE - ACDC
-- FILE:         ACDC_main.vhd
-- AUTHOR:       Joe Pastika
-- DATE:         June 2021
--
-- DESCRIPTION:  top-level firmware module for ACDC
--
---------------------------------------------------------------------------------

library IEEE; 
use ieee.std_logic_1164.all;
USE ieee.numeric_std.ALL; 
use ieee.std_logic_misc.all;
use work.defs.all;
use work.components.all;
use work.LibDG.all;


entity manchester_encoder is
  port(
    clock         : in  std_logic;
    reset         : in  std_logic;

    trainTrig     : in  std_logic;

    sig_in        : in  std_logic;
    sig_out       : out std_logic
);
end manchester_encoder;

architecture vhdl of manchester_encoder is

  signal toggle : std_logic;
  signal out_z : std_logic;
  
begin

  manchesterEncoding : process (clock)
    variable sig : std_logic;
    variable train : std_logic;
    variable timer : natural range 0 to 1024;
  begin
    if rising_edge(clock) then
      if reset = '1' then
        toggle <= '0';
        out_z <= '0';
        sig_out <= '0';
        timer := 1000;
        train := '0';
        sig := '0';
      else
        if trainTrig = '1' then
          timer := 1000;
        elsif timer > 0 then
          timer := timer - 1;
        end if;

        if toggle = '0' then
          if timer > 0 then
            sig := train;
            train := not train;
          else
            sig := sig_in;
            train := '0';
          end if;
          sig_out <= sig;
          out_z <= not sig;
        else
          sig_out <= out_z;
        end if;
        toggle <= not toggle;
      end if;
    end if;
  end process;

  
end vhdl;
