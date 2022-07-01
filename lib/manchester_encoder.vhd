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

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

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

  signal out_z : std_logic_vector(1 downto 0);
  signal sendTrain : std_logic;
  signal toggle : std_logic;
  
begin

  toggle_map : process(all)
  begin
    if sendTrain = '1' then
      if toggle = '1' then
        out_Z <= "01";
      else
        out_z <= "10";
      end if;
    else
      if sig_in = '1' then
        out_Z <= "01";
      else
        out_z <= "10";
      end if;
    end if;
  end process;

  ALTDDIO_OUT_component : ALTDDIO_OUT
	GENERIC MAP (
      extend_oe_disable => "OFF",
      intended_device_family => "Arria V",
      invert_output => "OFF",
      lpm_hint => "UNUSED",
      lpm_type => "altddio_out",
      oe_reg => "UNREGISTERED",
      power_up_high => "OFF",
      width => 1
      )
	PORT MAP (
      aclr => '0',
      datain_h(0) => out_z(0),
      datain_l(0) => out_z(1),
      outclock => clock,
      dataout(0) => sig_out
      );

  manchesterEncoding_train : process (clock)
    variable timer : natural range 0 to 1024;
  begin
    if rising_edge(clock) then
      if reset = '1' then
        sendTrain <= '0';
        timer := 1000;
        toggle <= '0';
      else
        toggle <= not toggle;
        if trainTrig = '1' then
          timer := 1000;
          sendTrain <= '1';
        elsif timer > 0 then
          timer := timer - 1;
          sendTrain <= '1';
        else
          sendTrain <= '0';
        end if;
      end if;
    end if;
  end process;
  
--  manchesterEncoding : process (clock)
--    variable sig : std_logic;
--    variable train : std_logic;
--    variable timer : natural range 0 to 1024;
--  begin
--    if rising_edge(clock) then
--      if reset = '1' then
--        toggle <= '0';
--        out_z <= '0';
--        sig_out <= '0';
--        timer := 1000;
--        train := '0';
--        sig := '0';
--      else
--        if trainTrig = '1' then
--          timer := 1000;
--        elsif timer > 0 then
--          timer := timer - 1;
--        end if;
--
--        if toggle = '0' then
--          if timer > 0 then
--            sig := train;
--            train := not train;
--          else
--            sig := sig_in;
--            train := '0';
--          end if;
--          sig_out <= sig;
--          out_z <= not sig;
--        else
--          sig_out <= out_z;
--        end if;
--        toggle <= not toggle;
--      end if;
--    end if;
--  end process;

  
end vhdl;
