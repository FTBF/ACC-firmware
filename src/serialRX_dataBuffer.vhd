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

    error_counts  : out DoubleArray_16bit;

    io_config_clkena : out std_logic_vector(2*N-1 downto 0);
    io_config_datain : out std_logic;
    io_config_update : out std_logic

    );
end serialRx_dataBuffer;

architecture vhdl of serialRx_dataBuffer is
  attribute PRESERVE          : boolean;
  signal serialRX_hs        : serialRx_hs_array;
  signal error_counts_z     : DoubleArray_16bit;
  signal nreset             : std_logic;
  signal reset_sync1       : std_logic;
  signal reset_sync2       : std_logic;
  signal resetFast_sync1       : std_logic;
  signal resetFast_sync2       : std_logic;
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

  error_count_sync : for i in 0 to 2*N-1 generate
    param_handshake_sync_errorCount: param_handshake_sync
      generic map (
        WIDTH => 16)
      port map (
        src_clk      => clock.serial125,
        src_params   => error_counts_z(i),
        src_aresetn  => not resetFast_sync2,
        dest_clk     => clock.sys,
        dest_params  => error_counts(i),
        dest_aresetn => nreset);
  end generate;
  
  serial_remapping: for i in 2*N-1 downto 0 generate
    signal resetFast_ddr : std_logic;
    attribute PRESERVE of resetFast_ddr            : signal is TRUE;
  begin
    resetExtender : process(clock.serial125)
    begin
      if rising_edge(clock.serial125) then
        resetFast_ddr <= resetFast_sync2;
      end if;
    end process;
      
    serialRX_ddr_inst: serialRX_ddr
      port map (
        aclr      => resetFast_ddr,
        datain    => LVDS_In_hs(i downto i),
        inclock   => clock.serial125,
        dataout_h => serialRX_hs(i)(1 downto 1),
        dataout_l => serialRX_hs(i)(0 downto 0));
  end generate;


  prbsChecker_inst: prbsChecker
    port map (
      clk           => clock.serial125,
      reset         => resetFast_sync2,
      data          => serialRX_hs,
      error_counts  => error_counts_z);

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
