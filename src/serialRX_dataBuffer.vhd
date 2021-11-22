library IEEE; 
use ieee.std_logic_1164.all;
USE ieee.numeric_std.ALL; 
use work.defs.all;
use work.components.all;
use work.LibDG.all;

LIBRARY altera;
USE altera.altera_primitives_components.all;

entity serialRx_dataBuffer is
  port(
    clock  : in clock_type;
    reset  : in std_logic;

    delayCommand       : in std_logic_vector(11 downto 0);
    delayCommandSet    : in std_logic;
    delayCommandMask   : in std_logic_vector(2*N-1 downto 0);

    LVDS_In_hs   	: in std_logic_vector(2*N-1 downto 0);

    prbs_error_counts   : out DoubleArray_16bit;
    symbol_error_counts : out DoubleArray_16bit;
    count_reset   : in std_logic;
    
    io_config_clkena : out std_logic_vector(2*N-1 downto 0);
    io_config_datain : out std_logic;
    io_config_update : out std_logic

    );
end serialRx_dataBuffer;

architecture vhdl of serialRx_dataBuffer is
  constant sync_word0: std_logic_vector(9 downto 0):= "0001111100";		-- the symbol for codeword K28.7
  constant sync_word1: std_logic_vector(9 downto 0):= "0010111100";		-- the symbol for codeword K28.0

  attribute PRESERVE          : boolean;
  signal serialRX_hs        : serialRx_hs_array;
  signal prbs_error_counts_z    : DoubleArray_16bit;
  signal symbol_error_counts_z  : DoubleArray_16bit;
  signal nreset             : std_logic;
  signal reset_sync1       : std_logic;
  signal reset_sync2       : std_logic;
  signal resetFast_sync1       : std_logic;
  signal resetFast_sync2       : std_logic;

  type serialRx_hs_array_array is array (3 downto 0) of serialRx_hs_array;
  signal serialRX_hs_z        : serialRx_hs_array;
  signal serialRX_hs_z2       : serialRx_hs_array;
  signal serialRX_hs_in        : serialRx_hs_array;
  signal bitAlignCount        : unsigned(0 downto 0);
  attribute PRESERVE of serialRX_hs_z  : signal is TRUE;

  type wordAlignCount_array is array (2*N-1 downto 0) of unsigned(2 downto 0);
  signal wordAlignCount       : wordAlignCount_array;
  signal wordAlignOffset      : std_logic_vector(2*N-1 downto 0);
  signal serialRX_deser_23bit : serialRx_hs_23bit_array;
  signal serialRX_deser_10bit_z : serialRx_hs_10bit_array;
  signal serialRX_deser_10bit : serialRx_hs_10bit_array;
  signal serialRX_deser_8bit : serialRx_hs_8bit_array;

begin  -- architecture vhdl

  --synchronize signals
  nreset <= not reset;
  reset_sync : process(clock.serial25)
  begin
    if rising_edge(clock.serial25) then
      reset_sync1 <= reset;
      reset_sync2 <= reset_sync1;
    end if;
  end process;
  
  resetFast_sync : process(clock.serial125)
  begin
    if rising_edge(clock.serial125) then
      resetFast_sync1 <= reset_sync2;
      resetFast_sync2 <= resetFast_sync1;
    end if;
  end process;

  prbs_error_count_sync : for i in 0 to 2*N-1 generate
    param_handshake_sync_errorCount: param_handshake_sync
      generic map (
        WIDTH => 16)
      port map (
        src_clk      => clock.serial25,
        src_params   => prbs_error_counts_z(i),
        src_aresetn  => not resetFast_sync2,
        dest_clk     => clock.sys,
        dest_params  => prbs_error_counts(i),
        dest_aresetn => nreset);
  end generate;
  
  symbol_error_count_sync : for i in 0 to 2*N-1 generate
    param_handshake_sync_errorCount: param_handshake_sync
      generic map (
        WIDTH => 16)
      port map (
        src_clk      => clock.serial25,
        src_params   => symbol_error_counts_z(i),
        src_aresetn  => not resetFast_sync2,
        dest_clk     => clock.sys,
        dest_params  => symbol_error_counts(i),
        dest_aresetn => nreset);
  end generate;
  
  serial_remapping: for i in 2*N-1 downto 0 generate
    signal resetFast_ddr   : std_logic;
    signal resetFast_ddr_vhdlIsDumb   : std_logic_vector(0 downto 0);
    signal fifoEmpty       : std_logic;
  begin
    resetFast_ddr <= resetFast_ddr_vhdlIsDumb(0);
    syncReset: sync_Bits_Altera
      generic map (
        BITS       => 1,
        INIT       => "0",
        SYNC_DEPTH => 2)
      port map (
        Clock  => clock.serial125_ps(i),
        Input  => ""&resetFast_sync2,
        Output => resetFast_ddr_vhdlIsDumb);
      
    serialRX_ddr_inst: serialRX_ddr
      port map (
        aclr      => resetFast_ddr,
        datain    => LVDS_In_hs(i downto i),
        inclock   => clock.serial125_ps(i),
        dataout_h => serialRX_hs_z(i)(0 downto 0),
        dataout_l => serialRX_hs_z(i)(1 downto 1));

    serialRX_dpa_fifo_inst: serialRX_dpa_fifo
      port map (
        data    => serialRX_hs_z(i),
        rdclk   => clock.serial125,
        rdreq   => not fifoEmpty,
        wrclk   => clock.serial125_ps(i),
        wrreq   => '1',
        q       => serialRX_hs_z2(i),
        rdempty => fifoEmpty,
        wrfull  => open);
    
  end generate;

  serial_hs_deserialization : process(clock.serial125)
  begin
    if rising_edge(clock.serial125) then
      for iLink in 0 to 2*N-1 loop
        --deserialize links
        serialRX_hs_in(iLink) <= serialRX_hs_z2(iLink);
        serialRX_deser_23bit(iLink) <= serialRX_deser_23bit(iLink)(20 downto 0) & serialRX_hs_in(iLink);
        if resetFast_sync2 = '1' then
          wordAlignCount(iLink) <= "000";
          wordAlignOffset(iLink) <= '0';
        else
          if serialRX_deser_23bit(iLink)(19 downto 0) = sync_word0 & sync_word1 then
            wordAlignCount(iLink) <= "000";
            wordAlignOffset(iLink) <= '0';
          elsif serialRX_deser_23bit(iLink)(20 downto 1) = sync_word0 & sync_word1 then
            wordAlignCount(iLink) <= "000";
            wordAlignOffset(iLink) <= '1';
          elsif to_integer(wordAlignCount(iLink)) >= 4 then
            wordAlignCount(iLink) <= "000";
            wordAlignOffset(iLink) <= wordAlignOffset(iLink);
          else
            wordAlignCount(iLink) <= wordAlignCount(iLink) + 1;
            wordAlignOffset(iLink) <= wordAlignOffset(iLink);
          end if;
        end if;

        if wordAlignCount(iLink) = "000" then
          if wordAlignOffset(iLink) = '1' then
            serialRX_deser_10bit_z(iLink) <= serialRX_deser_23bit(iLink)(12 downto 3);
          else
            serialRX_deser_10bit_z(iLink) <= serialRX_deser_23bit(iLink)(11 downto 2);
          end if;
        else
          serialRX_deser_10bit_z(iLink) <= serialRX_deser_10bit_z(iLink);
        end if;
      end loop;
    end if;
  end process;


  -- synchronize to 25 Mz domain
  serialRX_deser_sync : process(clock.serial25)
  begin
    if rising_edge(clock.serial25) then
      serialRX_deser_10bit <= serialRX_deser_10bit_z;
    end if;
  end process;

  decoder_inst : for iLink in 0 to 2*N-1 generate
    signal symbol_error : std_logic;
  begin
    decoder_8b10b_inst: decoder_8b10b
      port map (
        clock        => clock.serial25,
        rd_reset     => '0',
        din          => serialRX_deser_10bit(iLink),
        din_valid    => '1',
        kout         => open,
        dout         => serialRX_deser_8bit(iLink),
        dout_valid   => open,
        rd_out       => open,
        symbol_error => symbol_error);

    symbol_error_count : process(clock.serial25)
    begin
      if rising_edge(clock.serial25) then
        if(reset_sync2 = '1' or count_reset = '1') then
          symbol_error_counts_z(iLink) <= X"0000";
        else
          if(symbol_error = '1' and symbol_error_counts_z(iLink) /= X"ffff") then
            symbol_error_counts_z(iLink) <= std_logic_vector(unsigned(symbol_error_counts_z(iLink)) + 1);
          end if;
        end if;
      end if;
    end process;
      
  end generate;
  
  prbsChecker_inst: prbsChecker
    port map (
      clk           => clock.serial25,
      reset         => resetFast_sync2,
      data          => serialRX_deser_8bit,
      error_counts  => prbs_error_counts_z,
      count_reset   => count_reset);

  io_delay_ctrl_inst: io_delay_ctrl
    port map (
      clk              => clock.serial25,
      reset            => reset_sync2,
      delayCommand     => delayCommand,
      delayCommandSet  => delayCommandSet,
      delayCommandMask => delayCommandMask,
      io_config_clkena => io_config_clkena,
      io_config_datain => io_config_datain,
      io_config_update => io_config_update);

end architecture vhdl;    
