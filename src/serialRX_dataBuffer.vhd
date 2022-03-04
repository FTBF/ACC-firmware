library IEEE; 
use ieee.std_logic_1164.all;
USE ieee.numeric_std.ALL; 
use work.defs.all;
use work.components.all;
use work.LibDG.all;

LIBRARY altera;
USE altera.altera_primitives_components.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

entity serialRx_dataBuffer is
  port(
    clock  : in clock_type;
    reset  : in reset_type;

    rxFIFO_resetReq    : in std_logic_vector(N-1 downto 0);

    delayCommand       : in std_logic_vector(11 downto 0);
    delayCommandSet    : in std_logic;
    delayCommandMask   : in std_logic_vector(2*N-1 downto 0);

    LVDS_In_hs   	: in std_logic_vector(2*N-1 downto 0);

    data_out        : out Array_16bit;
    data_occ        : out Array_16bit;
    data_re         : in  std_logic_vector(N-1 downto 0);

    byte_fifo_occ       : out DoubleArray_16bit;
    prbs_error_counts   : out DoubleArray_16bit;
    symbol_error_counts : out DoubleArray_16bit;
    backpressure_threshold : in std_logic_vector(11 downto 0);
    backpressure_out    : out std_logic_vector(N-1 downto 0);
    count_reset   : in std_logic;

    trig_out         : out std_logic_vector(N-1 downto 0);
    
    io_config_clkena : out std_logic_vector(2*N-1 downto 0);
    io_config_datain : out std_logic;
    io_config_update : out std_logic

    );
end serialRx_dataBuffer;

architecture vhdl of serialRx_dataBuffer is
  constant sync_word0: std_logic_vector(9 downto 0):= "0001111100";		-- the symbol for codeword K28.7
  constant sync_word1: std_logic_vector(9 downto 0):= "0010111100";		-- the symbol for codeword K28.0

  signal data_occ_loc        : Array_16bit;
  
  attribute PRESERVE          : boolean;
  signal serialRX_hs        : serialRx_hs_array;
  signal prbs_error_counts_z    : DoubleArray_16bit;
  signal symbol_error_counts_z  : DoubleArray_16bit;
  signal nreset             : std_logic;
  signal reset_sync0       : std_logic;
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
  signal serialRX_deser_8bit_kout : std_logic_vector(2*N-1 downto 0);
  signal serialRX_deser_8bit_valid : std_logic_vector(2*N-1 downto 0);

begin  -- architecture vhdl

  data_occ <= data_occ_loc;

  --synchronize signals
  nreset <= not reset.global;
  reset_sync : process(clock.serial25, clock.serialpllLock)
  begin
    if clock.serialpllLock = '0' then
      reset_sync0 <= '1';
      reset_sync1 <= '1';
      reset_sync2 <= '1';
    else
      if rising_edge(clock.serial25) then
        reset_sync0 <= reset.global;
        reset_sync1 <= reset_sync0;
        reset_sync2 <= reset_sync1;
      end if;
    end if;
  end process;
  
  resetFast_sync : process(clock.serial125, clock.serialpllLock)
  begin
    if clock.serialpllLock = '0' then
      resetFast_sync1 <= '1';
      resetFast_sync2 <= '1';
    else
      if rising_edge(clock.serial125) then
        resetFast_sync1 <= reset_sync2;
        resetFast_sync2 <= resetFast_sync1;
      end if;
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
    signal fifoEmpty       : std_logic;
    signal dpa_pll_lock    : std_logic;
  begin
    pll_lock_switch: if i < N generate
      dpa_pll_lock <= clock.dpa1pllLock;
    else generate
      dpa_pll_lock <= clock.dpa2pllLock;
    end generate;
    
    syncReset: sync_Bits_Altera
      generic map (
        BITS       => 1,
        INIT       => "0",
        SYNC_DEPTH => 3)
      port map (
        Clock     => clock.serial125_ps(i),
        Input(0)  => resetFast_sync2 and not dpa_pll_lock,
        Output(0) => resetFast_ddr);
      
    serialRX_ddr_inst: serialRX_ddr
      port map (
        aclr      => resetFast_ddr,
        datain    => LVDS_In_hs(i downto i),
        inclock   => clock.serial125_ps(i),
        dataout_h => serialRX_hs_z(i)(0 downto 0),
        dataout_l => serialRX_hs_z(i)(1 downto 1));

    serialRX_dpa_fifo_inst: serialRX_dpa_fifo
      port map (
        aclr    => resetFast_ddr,
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
          if (serialRX_deser_23bit(iLink)(19 downto 10) =     sync_word0 and serialRX_deser_23bit(iLink)( 9 downto  0) =     sync_word1) or
             (serialRX_deser_23bit(iLink)(19 downto 10) = not sync_word0 and serialRX_deser_23bit(iLink)( 9 downto  0) = not sync_word1) then
            wordAlignCount(iLink) <= "000";
            wordAlignOffset(iLink) <= '0';
          elsif (serialRX_deser_23bit(iLink)(20 downto 11) =     sync_word0 and serialRX_deser_23bit(iLink)(10 downto  1) =     sync_word1) or
                (serialRX_deser_23bit(iLink)(20 downto 11) = not sync_word0 and serialRX_deser_23bit(iLink)(10 downto  1) = not sync_word1) then
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

  serial_hs_controldecode : process(all)
  begin
    for iLink in 0 to N-1 loop
      if serialRX_deser_10bit_z(2*iLink) = "0001011011" or serialRX_deser_10bit_z(2*iLink) = "1110100100" then --FB k-code for trigger 
        trig_out(iLink) <= '1';
      else
        trig_out(iLink) <= '0';
      end if;
    end loop;
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
        rd_reset     => reset_sync2,
        din          => serialRX_deser_10bit(iLink),
        din_valid    => '1',
        kout         => serialRX_deser_8bit_kout(iLink),
        dout         => serialRX_deser_8bit(iLink),
        dout_valid   => serialRX_deser_8bit_valid(iLink),
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

  -- data buffer
  -- first stage FIFO, shallow FIFO to ensure bytes are aligned
  link_buffers : for iACDC in 0 to 7 generate
    signal data_in_lsb : std_logic_vector(7 downto 0);
    signal data_in_msb : std_logic_vector(7 downto 0);
    signal data_in_lsb_kout : std_logic;
    signal data_in_msb_kout : std_logic;
    signal data_in_lsb_valid : std_logic;
    signal data_in_msb_valid : std_logic;
    signal data_in_lsb_dly : std_logic_vector(7 downto 0);
    signal data_in_msb_dly : std_logic_vector(7 downto 0);
    signal data_in_lsb_write : std_logic;
    signal data_in_msb_write : std_logic; 
    signal data_in_lsb_enable : std_logic;
    signal data_in_msb_enable : std_logic; 
    signal empty_lsb : std_logic;
    signal empty_msb : std_logic;
    signal full_lsb : std_logic;
    signal full_msb : std_logic;
    signal reset_local : std_logic;
    signal data_out_lsb : std_logic_vector(7 downto 0);
    signal data_out_msb : std_logic_vector(7 downto 0);
    signal readFifo : std_logic;
    signal writeBuffer : std_logic;
    signal rxFIFO_resetReq_sync : std_logic;
  begin

    -- map links into pairs for each ACDC 
    data_in_lsb <= serialRX_deser_8bit(iACDC*2 + 0);
    data_in_msb <= serialRX_deser_8bit(iACDC*2 + 1);
    --data_in_msb(7) <= serialRX_deser_8bit_valid(iACDC*2 + 0) and serialRX_deser_8bit_valid(iACDC*2 + 1);
    --data_in_msb(6 downto 0) <= serialRX_deser_8bit(iACDC*2 + 1)(6 downto 0);
    data_in_lsb_kout <= serialRX_deser_8bit_kout(iACDC*2 + 0);
    data_in_msb_kout <= serialRX_deser_8bit_kout(iACDC*2 + 1);
    data_in_lsb_valid <= serialRX_deser_8bit_valid(iACDC*2 + 0);
    data_in_msb_valid <= serialRX_deser_8bit_valid(iACDC*2 + 1);

    -- determine when valid data is being sent
    data_in_delay : process(clock.serial25)
    begin
      if rising_edge(clock.serial25) then
        data_in_msb_dly <= data_in_msb;
        data_in_lsb_dly <= data_in_lsb;

        -- write when inside a packet (after symbol F7 but before 9C or Idle
        -- (1C)) and when data is valid and not a k code
        if reset_sync2 = '1' or reset_local = '1' then
          data_in_lsb_write <= '0';
          data_in_msb_write <= '0';
          data_in_lsb_enable <= '0';
          data_in_msb_enable <= '0';
          writeBuffer <= '0';
        else
          if data_in_lsb_enable = '1' and data_in_lsb_kout = '0' and data_in_lsb_valid = '1' then
            data_in_lsb_write <= '1';
          else
            data_in_lsb_write <= '0';
          end if;

          if data_in_msb_enable = '1' and data_in_msb_kout = '0' and data_in_msb_valid = '1' then
            data_in_msb_write <= '1';
          else
            data_in_msb_write <= '0';
          end if;
          
          if    data_in_lsb_kout = '1' and data_in_lsb_valid = '1' and data_in_lsb = X"F7" then  data_in_lsb_enable <= '1';
          elsif data_in_lsb_kout = '1' and data_in_lsb_valid = '1' and data_in_lsb = X"9c" then  data_in_lsb_enable <= '0';
          elsif data_in_lsb_kout = '1' and data_in_lsb_valid = '1' and data_in_lsb = X"1C" then  data_in_lsb_enable <= '0';
          end if;

          if    data_in_msb_kout = '1' and data_in_msb_valid = '1' and data_in_msb = X"F7" then  data_in_msb_enable <= '1';
          elsif data_in_msb_kout = '1' and data_in_msb_valid = '1' and data_in_msb = X"9c" then  data_in_msb_enable <= '0';
          elsif data_in_msb_kout = '1' and data_in_msb_valid = '1' and data_in_msb = X"1C" then  data_in_msb_enable <= '0';
          end if;

          -- delay buffer write to wait until data from byte FIFOs are ready 
          writeBuffer <= readFifo;
        end if;
      end if;
    end process;
    
    readFifo <= not (empty_lsb or empty_msb);
    byte_fifo_occ(2*iACDC + 0)(15 downto 4) <= "000000000000";
    byte_fifo_occ(2*iACDC + 1)(15 downto 4) <= "000000000000";

    -- shallow byte alignment FIFOs
    pulseSync2_rxFIFO_resetReq: pulseSync2
      port map (
        src_clk      => clock.sys,
        src_pulse    => rxFIFO_resetReq(iACDC),
        src_aresetn  => nreset,
        dest_clk     => clock.serial25,
        dest_pulse   => rxFIFO_resetReq_sync,
        dest_aresetn => not reset_sync2);

    serialRX_InterByteAlign_lsb: serialRX_InterByteAlign_fifo
      port map (
        clock => clock.serial25,
        data  => data_in_lsb_dly,
        rdreq => readFifo,
        sclr  => reset_sync2 or reset_local or rxFIFO_resetReq_sync,
        wrreq => data_in_lsb_write,
        empty => empty_lsb,
        full  => full_lsb,
        q     => data_out_lsb,
        usedw => byte_fifo_occ(2*iACDC + 0)(3 downto 0));

    serialRX_InterByteAlign_msb: serialRX_InterByteAlign_fifo
      port map (
        clock => clock.serial25,
        data  => data_in_msb_dly,
        rdreq => readFifo,
        sclr  => reset_sync2 or reset_local or rxFIFO_resetReq_sync,
        wrreq => data_in_msb_write,
        empty => empty_msb,
        full  => full_msb,
        q     => data_out_msb,
        usedw => byte_fifo_occ(2*iACDC + 1)(3 downto 0));

    -- error detector circuit - reset interByteAlignment if FIFO overflow
    -- occurs
    oveflow_detector : process(clock.serial25)
    begin
      if rising_edge(clock.serial25) then
        if reset_sync2 = '1' then
          reset_local <= '0';
        else
          if full_lsb = '1' or full_msb = '1' then
            reset_local <= '1';
          else
            reset_local <= '0';
          end if;
        end if;
      end if;
    end process;

    -- deep data FIFO storing 16 bit wide words
	dcfifo_component : dcfifo
	GENERIC MAP (
		intended_device_family => "Arria V",
		lpm_numwords => 65536,
		lpm_showahead => "OFF",
		lpm_type => "dcfifo",
		lpm_width => 16,
		lpm_widthu => 16,
		overflow_checking => "ON",
		rdsync_delaypipe => 4,
		read_aclr_synch => "OFF",
		underflow_checking => "ON",
		use_eab => "ON",
		write_aclr_synch => "OFF",
		wrsync_delaypipe => 4
	)
	PORT MAP (
		aclr => reset.global or rxFIFO_resetReq(iACDC),
		data => data_out_msb & data_out_lsb,
		rdclk => clock.sys,
		rdreq => data_re(iACDC),
		wrclk => clock.serial25,
		wrreq => writeBuffer,
		q => data_out(iACDC),
		rdempty => open,
		rdusedw => data_occ_loc(iACDC),
		wrfull => open,
		wrusedw => open
	);
--    serialRX_data_buffer: serialRX_data_fifo
--      port map (
--        aclr    => reset_sync2 or rxFIFO_resetReq(iACDC),
--        data    => data_out_msb & data_out_lsb,
--        rdclk   => clock.sys,
--        rdreq   => data_re(iACDC),
--        wrclk   => clock.serial25,
--        wrreq   => writeBuffer,
--        q       => data_out(iACDC),
--        rdempty => open,
--        rdusedw => data_occ_loc(iACDC)(14 downto 0),
--        wrfull  => open);

    backpressure_gen : process( clock.serial25 )
    begin
      if rising_edge(clock.serial25) then
        -- backpressure signals
        if to_integer(unsigned(data_occ_loc(iACDC))) >= (unsigned(backpressure_threshold(7 downto 0)) & X"00") then
          backpressure_out(iACDC) <= '1';
        else
          backpressure_out(iACDC) <= '0';
        end if;
      end if;
    end process;
    
  end generate;

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
