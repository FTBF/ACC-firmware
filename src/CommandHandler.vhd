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
use work.components.all;
use work.LibDG.all;


entity commandHandler is
  port (
    -- contorl signals
    reset						: 	in   	std_logic;
    clock				      : 	in		clock_type;

    -- ethernet adapter io signals
    eth_clk                 : in    std_logic;
    rx_addr              	: in    std_logic_vector (31 downto 0);
    rx_data              	: in    std_logic_vector (63 downto 0);
    rx_wren              	: in    std_logic;
    tx_data              	: out   std_logic_vector (63 downto 0);
    tx_rden              	: in    std_logic;

    -- registers
    config            : out config_type;

    regs              : in readback_reg_type;

    -- ACDC commands
    extCmd            : out extCmd_type;

    -- slow serial interface
    serialRX_data     : in  Array_16bit;
    serialRX_rden     : out std_logic_vector(N-1 downto 0)
    
    );
end commandHandler;


architecture vhdl of commandHandler is

  signal config_z            : config_type;

  signal regs_z              : readback_reg_type;

  signal nreset           : std_logic;
  signal nreset_eth_sync0 : std_logic;
  signal nreset_eth_sync1 : std_logic;
  signal nreset_eth_sync2 : std_logic;

begin

-- note
-- the signals generated in this process either stay set until a new command arrives to change them,
-- or they will last for one clock cycle and then reset
--
  nreset <= not reset;
  reset_eth_sync : process(eth_clk, clock.serialpllLock)
  begin
    if nreset = '0' or clock.serialpllLock = '0' then
      nreset_eth_sync0 <= '0';
      nreset_eth_sync1 <= '0';
      nreset_eth_sync2 <= '0';
    else
      if rising_edge(eth_clk) then
        nreset_eth_sync0 <= nreset;
        nreset_eth_sync1 <= nreset_eth_sync0;
        nreset_eth_sync2 <= nreset_eth_sync1;
      end if;
    end if;
  end process;
  
  commandSync_inst: commandSync
    port map (
      reset      => reset,
      clock      => clock,
      eth_clk    => eth_clk,
      eth_reset  => nreset_eth_sync2,
      config_z   => config_z,
      config     => config,
      reg        => regs,
      reg_z      => regs_z);
  
  COMMAND_HANDLER:	process(eth_clk)
  begin
	if (rising_edge(eth_clk)) then

      if (nreset_eth_sync2 = '0' or rx_wren = '0') then

        if (nreset_eth_sync2 = '0') then

          -----------------------------------
          -- POWER-ON DEFAULT VALUES
          -----------------------------------

          for j in 0 to N-1 loop
            config_z.trig.source(j) <= 0;
          end loop;

          -----------------------------------

          config_z.trig.SMA_invert <= '0';
          config_z.trig.windowStart <= 16000; 	-- 400us
          config_z.trig.windowLen <= 2000;		-- 50us
          config_z.trig.ppsDivRatio <= 1;
          config_z.trig.ppsMux_enable <= '1';
          config_z.testCmd.channel <= 1;
          config_z.delayCommand <= X"000";
          config_z.delayCommandMask <= X"0000";
          config_z.updn    <= '0';
          config_z.cntsel  <= "00000";
          config_z.backpressure_threshold <= X"07f";

        end if;

        -----------------------------------
        -- clear the single-pulse signals
        -----------------------------------

        config_z.globalResetReq <= '0';
        config_z.rxBuffer_resetReq <= x"00";
        config_z.trig.sw <= (others => '0');
        config_z.localInfo_readReq <= '0';
        config_z.rxBuffer_readReq <= '0';
        config_z.dataFIFO_readReq <= '0';
        extCmd.valid <= '0';
        config_z.delayCommandSet <= '0';
        config_z.count_reset <= '0';
        config_z.phaseUpdate <= '0';
        config_z.train_manchester_links <= '0';
        config_z.rxFIFO_resetReq <= X"00";

      else     -- new instruction received

        case rx_addr is

          -- reset signals 
          when x"00000000" =>  config_z.globalResetReq    <= rx_data(0);
          when x"00000001" =>  config_z.rxFIFO_resetReq   <= rx_data(N-1 downto 0);
          when x"00000002" =>  config_z.rxBuffer_resetReq <= rx_data(N-1 downto 0);

          -- generate software trigger
          when x"00000010" =>  config_z.trig.sw <= rx_data(N-1 downto 0);

          -- read data
          when x"00000020" =>  config_z.localInfo_readReq <= '1';
          --when x"00000021" =>
          --  config_z.rxBuffer_readReq <= '1';
          --  config_z.readChannel <= to_integer(unsigned(rx_data(3 downto 0)));
          when x"00000022" =>
            config_z.dataFIFO_readReq <= '1';
            config_z.readChannel <= to_integer(unsigned(rx_data(3 downto 0)));

          -- trigger setup
          -- set trigger mode for the specified acdc boards
          -- mode 0 = trigger off
          -- mode 1 = software trigger
          -- mode 2 = acc sma trigger
          when x"00000030" =>  config_z.trig.source(0) <= to_integer(unsigned(rx_data(3 downto 0)));
          when x"00000031" =>  config_z.trig.source(1) <= to_integer(unsigned(rx_data(3 downto 0)));
          when x"00000032" =>  config_z.trig.source(2) <= to_integer(unsigned(rx_data(3 downto 0)));
          when x"00000033" =>  config_z.trig.source(3) <= to_integer(unsigned(rx_data(3 downto 0)));
          when x"00000034" =>  config_z.trig.source(4) <= to_integer(unsigned(rx_data(3 downto 0)));
          when x"00000035" =>  config_z.trig.source(5) <= to_integer(unsigned(rx_data(3 downto 0)));
          when x"00000036" =>  config_z.trig.source(6) <= to_integer(unsigned(rx_data(3 downto 0)));
          when x"00000037" =>  config_z.trig.source(7) <= to_integer(unsigned(rx_data(3 downto 0)));

          when x"00000038" =>  config_z.trig.SMA_invert    <= rx_data(0);
          when x"0000003a" =>  config_z.trig.windowStart   <= to_integer(unsigned(rx_data(15 downto 0)));
          when x"0000003b" =>  config_z.trig.windowLen     <= to_integer(unsigned(rx_data(15 downto 0)));
          when x"0000003c" =>  config_z.trig.ppsDivRatio   <= to_integer(unsigned(rx_data(15 downto 0)));
          when x"0000003d" =>  config_z.trig.ppsMux_enable <= rx_data(0);

          -- serialRx high speed controls
          when x"00000050" => config_z.delayCommandSet <= '1';
          when x"00000051" => config_z.delayCommand <= rx_data(11 downto 0);
          when x"00000052" => config_z.delayCommandMask <= rx_data(2*N-1 downto 0);
          when x"00000053" => config_z.count_reset <= '1';
          when x"00000054" => config_z.updn <= rx_data(0);
          when x"00000055" => config_z.cntsel <= rx_data(4 downto 0);
          when x"00000056" => config_z.phaseUpdate <= '1';
          when x"00000057" => config_z.backpressure_threshold <= rx_data(11 downto 0);

          -- manchester link controls
          when x"00000060" => config_z.train_manchester_links <= '1'; 

          -- acdc commands - forward the received command directly to the acdc unaltered
          when x"00000100" =>
            extCmd.data   <= rx_data(31 downto 0);
            extCmd.valid  <= '1';
            extCmd.enable <= rx_data(31 downto 24);

          when others => null;

        end case;

      end if;

    end if;
  end process;


  -- read back mux
  readback_mux : process(all)
  begin
    tx_data <= X"0000000000000000";
    serialRX_rden <= X"00";
    
    if unsigned(rx_addr) < X"00001100" then
      case rx_addr is

        -- trigger setup
        -- set trigger mode for the specified acdc boards
        -- mode 0 = trigger off
        -- mode 1 = software trigger
        -- mode 2 = acc sma trigger
        when x"00000030" =>  tx_data(3 downto 0) <= std_logic_vector(to_unsigned(config_z.trig.source(0), 4));
        when x"00000031" =>  tx_data(3 downto 0) <= std_logic_vector(to_unsigned(config_z.trig.source(1), 4));
        when x"00000032" =>  tx_data(3 downto 0) <= std_logic_vector(to_unsigned(config_z.trig.source(2), 4));
        when x"00000033" =>  tx_data(3 downto 0) <= std_logic_vector(to_unsigned(config_z.trig.source(3), 4));
        when x"00000034" =>  tx_data(3 downto 0) <= std_logic_vector(to_unsigned(config_z.trig.source(4), 4));
        when x"00000035" =>  tx_data(3 downto 0) <= std_logic_vector(to_unsigned(config_z.trig.source(5), 4));
        when x"00000036" =>  tx_data(3 downto 0) <= std_logic_vector(to_unsigned(config_z.trig.source(6), 4));
        when x"00000037" =>  tx_data(3 downto 0) <= std_logic_vector(to_unsigned(config_z.trig.source(7), 4));

        when x"00000038" =>  tx_data(0) <= config_z.trig.SMA_invert;
        when x"0000003a" =>  tx_data(15 downto 0) <= std_logic_vector(to_unsigned(config_z.trig.windowStart, 16));
        when x"0000003b" =>  tx_data(15 downto 0) <= std_logic_vector(to_unsigned(config_z.trig.windowLen, 16));

        -- serialRx high speed controls
        when x"00000051" => tx_data(11 downto 0) <= config_z.delayCommand;
        when x"00000052" => tx_data(2*N-1 downto 0) <= config_z.delayCommandMask;
        when x"00000054" => tx_data(0) <= config_z.updn;
        when x"00000055" => tx_data(4 downto 0) <= config_z.cntsel;
        when x"00000057" => tx_data(11 downto 0) <= config_z.backpressure_threshold;

        -- read only registers 
        when x"00001000" => tx_data(15 downto 0) <= firwareVersion.number;
        when x"00001001" => tx_data(31 downto 0) <= firwareVersion.year & firwareVersion.MMDD;
        when x"00001002" => tx_data( 3 downto 0) <= regs_z.pllLock;

        when x"00001010" => tx_data(N-1 downto 0) <= regs_z.serialRX_rx_clock_fail;
        when x"00001011" => tx_data(N-1 downto 0) <= regs_z.serialRX_symbol_align_error;
        when x"00001012" => tx_data(N-1 downto 0) <= regs_z.serialRX_symbol_code_error;
        when x"00001013" => tx_data(N-1 downto 0) <= regs_z.serialRX_disparity_error;
                          
                            
        when others => null;

      end case;

    elsif unsigned(rx_addr) < X"00001110" then
      tx_data(15 downto 0) <= regs_z.byte_fifo_occ(to_integer(unsigned(rx_addr(3 downto 0))));

    elsif unsigned(rx_addr) < X"00001120" then
      tx_data(15 downto 0) <= regs_z.prbs_error_counts(to_integer(unsigned(rx_addr(3 downto 0))));

    elsif unsigned(rx_addr) < X"00001130" then
      tx_data(15 downto 0) <= regs_z.symbol_error_counts(to_integer(unsigned(rx_addr(3 downto 0))));

    elsif unsigned(rx_addr) < X"00001138" then
      tx_data(15 downto 0) <= regs_z.data_occ(to_integer(unsigned(rx_addr(2 downto 0))));

    elsif unsigned(rx_addr) < X"00001140" then
      tx_data(15 downto 0) <= regs_z.rxDataLen(to_integer(unsigned(rx_addr(2 downto 0))));

    -- 0x00001200 block reserved for slow serial RX FIFO readout
    elsif unsigned(rx_addr) = X"00001200" then
      tx_data(15 downto 0) <= serialRX_data(0);
      serialRX_rden(0) <= tx_rden;
    elsif unsigned(rx_addr) = X"00001201" then
      tx_data(15 downto 0) <= serialRX_data(1);
      serialRX_rden(1) <= tx_rden;
    elsif unsigned(rx_addr) = X"00001202" then
      tx_data(15 downto 0) <= serialRX_data(2);
      serialRX_rden(2) <= tx_rden;
    elsif unsigned(rx_addr) = X"00001203" then
      tx_data(15 downto 0) <= serialRX_data(3);
      serialRX_rden(3) <= tx_rden;
    elsif unsigned(rx_addr) = X"00001204" then
      tx_data(15 downto 0) <= serialRX_data(4);
      serialRX_rden(4) <= tx_rden;
    elsif unsigned(rx_addr) = X"00001205" then
      tx_data(15 downto 0) <= serialRX_data(5);
      serialRX_rden(5) <= tx_rden;
    elsif unsigned(rx_addr) = X"00001206" then
      tx_data(15 downto 0) <= serialRX_data(6);
      serialRX_rden(6) <= tx_rden;
    elsif unsigned(rx_addr) = X"00001207" then
      tx_data(15 downto 0) <= serialRX_data(7);
      serialRX_rden(7) <= tx_rden;
    
    end if;
  end process;
  
  
end vhdl;
