---------------------------------------------------------------------------------
-- Univ. of Chicago HEP / electronics design group
--    -- + KICP 2015 --
--
-- PROJECT:      ACC
-- FILE:         commandHandler.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         Oct 2020
--
-- DESCRIPTION:  receives 32bit commands and generates appropriate control signals locally
--                and passes on commands to the ACDC boards if necessary
--
---------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
use work.defs.all;
use work.LibDG.all;


entity commandHandler is
  port (
    reset						: 	in   	std_logic;
    clock				      : 	in		clock_type;        
    din		      	   :  in    std_logic_vector(31 downto 0);
    din_valid				:  in    std_logic;
    localInfo_readReq    :  out   std_logic;
    rxBuffer_resetReq    :  out   std_logic_vector(7 downto 0);
    rxBuffer_readReq		:	out	std_logic;
    param_readReq        : out std_logic;
    param_num            : out natural range 0 to 255;
    globalResetReq       :  out   std_logic;
    trig		            :	out	trigSetup_type;
    readChannel          :	out	natural range 0 to 15;
    ledSetup					: 	out	LEDSetup_type;
    ledPreset				: 	in		LEDPreset_type;
    extCmd			      : 	out 	extCmd_type;
    testCmd					: 	out	testCmd_type;
    delayCommand            : out std_logic_vector(11 downto 0);
    delayCommandSet         : out std_logic;
    delayCommandMask        : out std_logic_vector(15 downto 0)
    );
end commandHandler;


architecture vhdl of commandHandler is

    signal delayCommand_z            : std_logic_vector(11 downto 0);
    signal delayCommandSet_z         : std_logic;
    signal delayCommandMask_z        : std_logic_vector(15 downto 0);
    signal nreset                    : std_logic;
    signal nreset_sync1              : std_logic;
    signal nreset_sync2              : std_logic;
begin	
  
-- note
-- the signals generated in this process either stay set until a new command arrives to change them,
-- or they will last for one clock cycle and then reset
--
--
--
-- Command types 0 to 9 are for the acc 
-- On receiving these commands, a command may also be sent to the acdc,
-- depeding on the task required of the recived command.
-- This forwarded command will be of type A to F (hex) for the acdc
--
-- Command types A to F are for the acdc
-- On receiving these commands, the acc will do nothing except forward them to the acdc
--
--

  -- synchronizers
  nreset <= not reset;
  reset_sync : process(clock.serial25)
  begin
    if rising_edge(clock.serial25) then
      nreset_sync1 <= nreset;
      nreset_sync2 <= nreset_sync1;
    end if;
  end process;
  
  pulseSync2_delaySet: pulseSync2
    port map (
      src_clk      => clock.sys,
      src_pulse    => delayCommandSet_z,
      src_aresetn  => nreset,
      dest_clk     => clock.serial25,
      dest_pulse   => delayCommandSet,
      dest_aresetn => nreset_sync2);

  param_handshake_delayCmd: param_handshake_sync
    generic map (
      WIDTH => delayCommand_z'length)
    port map (
      src_clk      => clock.sys,
      src_params   => delayCommand_z,
      src_aresetn  => nreset,
      dest_clk     => clock.serial25,
      dest_params  => delayCommand,
      dest_aresetn => nreset_sync2);
  
  param_handshake_delayMask: param_handshake_sync
    generic map (
      WIDTH => delayCommandMask_z'length)
    port map (
      src_clk      => clock.sys,
      src_params   => delayCommandMask_z,
      src_aresetn  => nreset,
      dest_clk     => clock.serial25,
      dest_params  => delayCommandMask,
      dest_aresetn => nreset_sync2);
  
  
  COMMAND_HANDLER:	process(clock.sys)
    variable acdcBoardMask: 	std_logic_vector(7 downto 0);
    variable cmdType: 		std_logic_vector(3 downto 0);
    variable cmdOption: 		std_logic_vector(3 downto 0);
    variable cmdValue: 		std_logic_vector(15 downto 0);
    variable acdc_cmd: 		std_logic_vector(31 downto 0);	
    variable m: 		natural;	
    variable init: std_logic:= '1';		-- a flag used to set initial values for signals whose value will not go back to default on global reset
    variable x: natural range 0 to 31;	
    variable opt: natural range 0 to 15;
  begin
	if (rising_edge(clock.sys)) then
      
      if (init = '1') then
		
        init := '0';
        testCmd.pps_useSMA	<= '0';				-- pps will be taken from SMA connector, not LVDS
        testCmd.beamgateTrigger_useSMA <= '0';	-- beamgate trigger will be taken from SMA connector, not LVDS
        ledSetup <= ledPreset(0);		-- only occurs at power-up
        
      end if;
      
      
      if (reset = '1' or din_valid = '0') then
        
        
        if (reset = '1') then
          
          -----------------------------------
          -- POWER-ON DEFAULT VALUES
          -----------------------------------

          for j in 0 to N-1 loop 
            trig.source(j) <= 0;
          end loop;
          
          
          -----------------------------------
          
          trig.SMA_invert <= '0';
          trig.windowStart <= 16000; 	-- 400us
          trig.windowLen <= 2000;		-- 50us
          trig.ppsDivRatio <= 1;
          trig.ppsMux_enable <= '1';
          testCmd.channel <= 1;
          delayCommand_z <= X"000";
          delayCommandMask_z <= X"0000";

          
        end if;
        
        
        -----------------------------------
        -- clear the single-pulse signals
        -----------------------------------
        
        globalResetReq <= '0';
        rxBuffer_resetReq <= x"00";
        trig.sw <= '0';
        localInfo_readReq <= '0';
        rxBuffer_readReq <= '0';
        extCmd.valid <= '0';
        param_readReq <= '0';
        delayCommandSet_z <= '0';
        
        
      else     -- new instruction received
        
        
		
        acdc_cmd := x"00000000";		-- initially, no command to acdc
		
		
        
        --parse 32 bit instruction word:
        acdcBoardMask		:= din(31 downto 24);
        cmdType				:= din(23 downto 20);
        cmdOption			:= din(19 downto 16);
        cmdValue				:= din(15 downto 0);
        opt := to_integer(unsigned(cmdOption));
        
        
        
        case cmdType is                

          
          
          -- 0 to 9 are for acc			
          
          
          when x"0" =>	-- reset requests

            case cmdOption is
              when x"0" => globalResetReq <= '1';
              when x"2" => rxBuffer_resetReq <= din(7 downto 0);
              when others => null;
            end case;	

            
            
          when x"1" =>	-- generate software trigger
            
            trig.sw <= '1'; 			 
            

            
          when x"2" =>   -- read data 
            
            case cmdOption is												
              
              when x"0" => 		-- request to read short (32 word) info frame
                localInfo_readReq <= '1';   
                
              when x"1" => 		-- request to read uart rx data buffer of the specified channel
                rxBuffer_readReq <= '1'; 
                readChannel <= to_integer(unsigned(cmdValue(3 downto 0))); 

              when x"2" => 		-- request parameter read
                param_readReq <= '1';
                param_num <= to_integer(unsigned(cmdValue(7 downto 0))); 

              when others => null;
                             
            end case;
            
            
            
          when x"3" => 	-- trigger setup
            
            
            -- acc trigger modes (these are local- different to system trigger modes set by software)
            --
            -- 0 = off (trigger not supplied by ACC)
            -- 1 = software
            -- 2 = hardware
            -- 3 = pps
            -- 4 = beam gate / pps multiplexed
            
            
            case cmdOption is
              
              when x"0" => 		-- set trigger mode for the specified acdc boards (bits 11:4)
                
                for i in 0 to 7 loop
                  if (din(i + 4) = '1') then		-- acdc board mask bit
                    case din(3 downto 0) is
                      when x"0" => trig.source(i) <= 0; -- mode 0 = trigger off
                      when x"1" => trig.source(i) <= 1; -- mode 1 = software trigger
                      when x"2" => trig.source(i) <= 2; -- mode 2 = acc sma trigger
                      when x"3" => trig.source(i) <= 0; -- mode 3 = acdc sma trigger
                      when x"4" => trig.source(i) <= 0; -- mode 4 = self-trigger
                      when x"5" => trig.source(i) <= 4; -- mode 5 = self-trigger with acc sma validation
                      when x"6" => trig.source(i) <= 0; -- mode 6 = self-trigger with acdc sma validation
                      when x"7" => trig.source(i) <= 2; -- mode 7 = acc sma trigger with acdc sma validation
                      when x"8" => trig.source(i) <= 4; -- mode 8 = acdc sma trigger with acc sma validation
                      when x"9" => trig.source(i) <= 3; -- mode 9 = pps trigger 
                      when others =>	trig.source(i) <= 0;
                    end case;
                  end if;
                end loop;
                
                
                
              when x"1" => trig.SMA_invert <= din(0);
              when x"2" => trig.windowStart <= to_integer(unsigned(din(15 downto 0)));
              when x"3" => trig.windowLen <= to_integer(unsigned(din(15 downto 0)));
              when x"4" => trig.ppsDivRatio <= to_integer(unsigned(din(15 downto 0)));
              when x"5" => trig.ppsMux_enable <= din(0);
                           
                           
              when others => null;
                             
                             
            end case;	
            
            
            
            
          when x"4" =>	-- led control			
            
            -- set all leds
            if (cmdOption = x"F") then ledSetup <= ledPreset(to_integer(unsigned(din(3 downto 0))));
                                       
            -- set one led 
            else ledSetup(opt) <= din(15 downto 0); end if;					
            
            
          when x"5" =>  -- serialRx high speed controls

            case cmdOption is
              
              when x"0" => delayCommandSet_z <= '1';
              when x"1" => delayCommand_z <= cmdValue(11 downto 0);
              when x"2" => delayCommandMask_z <= cmdValue;
              when others => null;
            end case;
              

                
          when x"9" =>	-- test command
            
            case cmdOption is
              
              when x"0" => testCmd.pps_useSMA	<= din(0);				-- pps will be taken from SMA connector, not LVDS
              when x"1" => testCmd.beamgateTrigger_useSMA <= din(0);	-- beamgate trigger will be taken from SMA connector, not LVDS
              when x"2" => testCmd.channel <= to_integer(unsigned(din(2 downto 0)));
              when others => null;
                             
            end case;
            
            
            
            
            -- A to F are for acdc			
            
            
          -- acdc commands - forward the received command directly to the acdc unaltered
          when x"A" => 	acdc_cmd := din;
          when x"B" => 	acdc_cmd := din;
          when x"C" => 	acdc_cmd := din;
          when x"D" => 	acdc_cmd := din;
          when x"E" => 	acdc_cmd := din;
          when x"F" => 	acdc_cmd := din;
                        

                        
                        
          when others => null;
                         
                         
                         
                         
                         
        end case;
        
        
        
        if (acdc_cmd /= x"00000000") then 		-- if non-zero acdc command, send it 
          
          extCmd.data <= acdc_cmd;		
          extCmd.valid <= '1';		
          extCmd.enable <= acdcBoardMask;
          
        end if;      
        
        
        
        
      end if;
	end if;
  end process;

end vhdl;
