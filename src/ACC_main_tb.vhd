-------------------------------------------------------------------------------
-- Title      : Testbench for design "ACC_main"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : ACC_main_tb.vhd
-- Author     :   <Pastika@ITID20020501N>
-- Company    : 
-- Created    : 2021-10-15
-- Last update: 2021-10-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2021 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2021-10-15  1.0      Pastika	Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
USE ieee.numeric_std.ALL; 
use work.defs.all;
use work.components.all;
use work.LibDG.all;

-------------------------------------------------------------------------------

entity ACC_main_tb is

end entity ACC_main_tb;

-------------------------------------------------------------------------------

architecture sim of ACC_main_tb is

  -- constants 
  constant OSC_PERIOD : time := 40 ns; 

  shared variable ENDSIM : boolean := false; 
  
  -- component ports
  signal clockIn      : clockSource_type;
  signal clockCtrl    : clockCtrl_type;
  signal systemIn     : systemIn_type;
  signal systemOut    : systemOut_type;
  signal LVDS_In      : LVDS_inputArray_type;
  signal LVDS_In_hs_p : LVDS_inputArray_hs_type;
  signal LVDS_In_Hs_n : LVDS_inputArray_hs_type;
  signal LVDS_Out     : LVDS_outputArray_type;
  signal led          : std_logic_vector(2 downto 0);
  signal SMA          : std_logic_vector(1 to 6);
  signal USB_in       : USB_in_type;
  signal USB_out      : USB_out_type;
  signal USB_bus      : USB_bus_type;
  signal DIPswitch    : std_logic_vector (9 downto 0);

begin  -- architecture sim

  -- component instantiation
  DUT: entity work.ACC_main
    port map (
      clockIn      => clockIn,
      clockCtrl    => clockCtrl,
      systemIn     => systemIn,
      systemOut    => systemOut,
      LVDS_In      => LVDS_In,
      LVDS_In_hs_p => LVDS_In_hs_p,
      LVDS_In_Hs_n => LVDS_In_Hs_n,
      LVDS_Out     => LVDS_Out,
      led          => led,
      SMA          => SMA,
      USB_in       => USB_in,
      USB_out      => USB_out,
      USB_bus      => USB_bus,
      DIPswitch    => DIPswitch);

  -- clock generation
  ACC_OSC_GEN_PROC : process 
  begin
    if ENDSIM = false then
      clockIn.localOsc <= '0';
      wait for OSC_PERIOD / 2;
      clockIn.localOsc <= '1';
      wait for OSC_PERIOD / 2;
    else 
      wait;
    end if;
  end process;

  
  -- waveform generation
  WaveGen_Proc: process
  begin
    -- insert signal assignments here
    
    wait;
  end process WaveGen_Proc;

  

end architecture sim;

-------------------------------------------------------------------------------

--configuration ACC_main_tb_sim_cfg of ACC_main_tb is
--  for sim
--  end for;
--end ACC_main_tb_sim_cfg;

-------------------------------------------------------------------------------
