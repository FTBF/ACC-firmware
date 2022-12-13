---------------------------------------------------------------------------------
-- Fermilab
--    
--
-- PROJECT:      FTBF TOF 
-- FILE:         ethernet_adapter.vhd
-- AUTHOR:       Joe Pastika
-- DATE:         FEb 2022
--
-- DESCRIPTION:  Adapter between GMII ethernet interface and RGMII connection to PHY
--
---------------------------------------------------------------------------------


library IEEE; 
use ieee.std_logic_1164.all;
USE ieee.numeric_std.ALL; 
use ieee.std_logic_misc.ALL;
use work.defs.all;
use work.components.all;
use work.LibDG.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

entity ethernet_adapter is
  port(
    clock           : in clock_type;
    reset           : in std_logic;

    ETH_in          : in  ETH_in_type;
    ETH_out         : out ETH_out_type;

    ETH_mdc         : inout std_logic;
    ETH_mdio        : inout std_logic;

    user_addr				: in    std_logic_vector (7 downto 0);

    -- rx/tx signals
    eth_clk                 : out   std_logic;
    rx_addr              	: out   std_logic_vector (31 downto 0);
    rx_data              	: out   std_logic_vector (63 downto 0);
    rx_wren              	: out   std_logic;
    tx_data              	: in    std_logic_vector (63 downto 0);
    tx_rden              	: out   std_logic;
    -- burst signals
    b_data               	: in    std_logic_vector (63 downto 0);
    b_data_we            	: in    std_logic;
    b_data_force            : in    std_logic;
    b_enable             	: out   std_logic
	);
end ethernet_adapter;
	
		
architecture vhdl of ethernet_adapter is

  component ethernet_interface is
    port (
      reset_in     : in  std_logic;
      reset_out    : out std_logic;
      rx_addr      : out std_logic_vector (31 downto 0);
      rx_data      : out std_logic_vector (63 downto 0);
      rx_wren      : out std_logic;
      tx_data      : in  std_logic_vector (63 downto 0);
      tx_rden      : out   std_logic;
      b_data       : in  std_logic_vector (63 downto 0);
      b_data_we    : in  std_logic;
      b_data_force : in  std_logic;
      b_enable     : out std_logic;
      user_addr	   : in std_logic_vector (7 downto 0);
      MASTER_CLK   : in  std_logic;
      USER_CLK     : in  std_logic;
      PHY_RXD      : in  std_logic_vector (7 downto 0);
      PHY_RX_DV    : in  std_logic;
      PHY_RX_ER    : in  std_logic;
      TX_CLK       : out std_logic;
      PHY_TXD      : out std_logic_vector (7 downto 0);
      PHY_TX_EN    : out std_logic;
      PHY_TX_ER    : out std_logic);
  end component ethernet_interface;
  
  --RX signals
  signal rx_clk  : std_logic;
  signal rx_clk_lock  : std_logic;
  signal rx_dv   : std_logic;
  signal rx_tmp  : std_logic;
  signal rx_er   : std_logic;
  signal rx_dat  : std_logic_vector(7 downto 0);
  
  --TX signals
  signal gtx_clk : std_logic;
  signal tx_clk  : std_logic;
  signal tx_en   : std_logic;
  signal tx_er   : std_logic;
  signal tx_dat  : std_logic_vector(7 downto 0);
  signal tx_dat_z : std_logic_vector(7 downto 0);

  type mem_type is array (7 downto 0) of std_logic_vector(63 downto 0);
  signal cfg_mem : mem_type;
  signal cfg_datum : std_logic_vector(63 downto 0);

--  -- rx/tx signals
--  signal rx_addr              	: std_logic_vector (31 downto 0);
--  signal rx_data              	: std_logic_vector (63 downto 0);
--  signal rx_wren              	: std_logic;
--  signal tx_data              	: std_logic_vector (63 downto 0);
--  -- burst signals
--  signal b_data               	: std_logic_vector (63 downto 0);
--  signal b_data_we            	: std_logic;
--  signal b_data_force           : std_logic;
--  signal b_enable             	: std_logic;

  -- other signals
  signal clockIn_global : std_logic;
  
  signal resetSync_serial : std_logic;

  signal resetSync_eth : std_logic;
--  signal resetSync_eth_z : std_logic;

  signal reset_out : std_logic;

  signal tx_mdc     : std_logic;
  signal rx_mdio    : std_logic;
  signal tx_mdio    : std_logic;
  signal tx_mdio_we : std_logic;

  signal debug_clock : std_logic;

begin

  eth_clk_ctrl_inst: eth_clk_ctrl
    port map (
      inclk  => ETH_in.rx_clk,
      outclk => clockIn_global);
  
  ETH_pll_inst: ETH_pll
    port map (
      refclk   => clockIn_global,
      rst      => '0',
      outclk_0 => rx_clk,
      outclk_1 => gtx_clk,
      locked   => rx_clk_lock);
  
  eth_clk <= rx_clk;
  
--  reset_sync_serial: sync_Bits_Altera
--    generic map (
--      BITS       => 1,
--      INIT       => x"00000000",
--      SYNC_DEPTH => 2)
--    port map (
--      Clock  => clock.serial125,
--      Input(0)  => reset,
--      Output(0) => resetSync_serial);

--  reset_sync_eth: sync_Bits_Altera
--    generic map (
--      BITS       => 1,
--      INIT       => x"00000000",
--      SYNC_DEPTH => 2)
--    port map (
--      Clock  => rx_clk,
--      Input(0)  => reset,
--      Output(0) => resetSync_eth_z);
  
  resetSync_eth <= not rx_clk_lock;
  
  -- RX signal DDR logic 
  rx_ctl_ddr : ALTDDIO_IN
	GENERIC MAP (
      intended_device_family => "Arria V",
      invert_input_clocks => "OFF",
      lpm_hint => "UNUSED",
      lpm_type => "altddio_in",
      power_up_high => "OFF",
      width => 1
      )
	PORT MAP (
      aclr => '0',
      datain(0) => ETH_in.rx_ctl,
      inclock => rx_clk,
      dataout_h(0) => rx_tmp,
      dataout_l(0) => rx_dv
      );

  rx_er <= rx_dv xor rx_tmp;

  rx_data_ddr : ALTDDIO_IN
	GENERIC MAP (
      intended_device_family => "Arria V",
      invert_input_clocks => "OFF",
      lpm_hint => "UNUSED",
      lpm_type => "altddio_in",
      power_up_high => "OFF",
      width => 4
      )
	PORT MAP (
      aclr => '0',
      datain => ETH_in.rx_dat,
      inclock => rx_clk,
      dataout_h => rx_dat(7 downto 4),
      dataout_l => rx_dat(3 downto 0)
      );

  --TX signal DDR logic
  ETH_out.tx_clk <= gtx_clk;
  
  tx_ctl_ddr : ALTDDIO_OUT
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
      datain_h(0) => tx_en,
      datain_l(0) => tx_en,
      outclock => tx_clk,
      dataout(0) => ETH_out.tx_ctl
      );

  tx_data_ddr : ALTDDIO_OUT
    GENERIC MAP (
      extend_oe_disable => "OFF",
      intended_device_family => "Arria V",
      invert_output => "OFF",
      lpm_hint => "UNUSED",
      lpm_type => "altddio_out",
      oe_reg => "UNREGISTERED",
      power_up_high => "OFF",
      width => 4
      )
    PORT MAP (
      datain_h => tx_dat(3 downto 0),
      datain_l => tx_dat(7 downto 4),
      outclock => tx_clk,
      dataout  => ETH_out.tx_dat      
      );

  --tx_dat_z <= tx_dat when tx_en = '1' else X"DD";

--  phy_reset : process(clock.serial25)
  ETH_out.resetn <= not reset_out;

  --ethernet interface
  ethernet_interface_inst: ethernet_interface
    port map (
      reset_in     => resetSync_eth,
      reset_out    => reset_out,

      -- mmap interface signals 
      rx_addr      => rx_addr,
      rx_data      => rx_data,
      rx_wren      => rx_wren,
      tx_data      => tx_data,
      tx_rden      => tx_rden,
      --burst interface signals 
      b_data       => b_data,
      b_data_we    => b_data_we,
      b_data_force => b_data_force,
      b_enable     => b_enable,
      --address
      user_addr    => user_addr,
      --PHY interface signals 
      MASTER_CLK   => rx_clk,
      USER_CLK     => rx_clk,-- this is only used externally, no need to mince clocks with clock.serial25,
      PHY_RXD      => rx_dat,
      PHY_RX_DV    => rx_dv,
      PHY_RX_ER    => rx_er,
      TX_CLK       => tx_clk,
      PHY_TXD      => tx_dat,
      PHY_TX_EN    => tx_en,
      PHY_TX_ER    => tx_er);

--  tx_data <= cfg_mem(to_integer(unsigned(rx_addr)));
--  read_mux : process(rx_clk)
--  begin
--    if rising_Edge(rx_clk) then
--      if resetSync_eth = '1' then
--        for i in 0 to 7 loop
--          cfg_mem(i) <= X"0000000000000000";
--        end loop;
--      else
--        if rx_wren = '1' then
--          cfg_mem(to_integer(unsigned(rx_addr))) <= rx_data;
--        end if;
--      end if;
--    end if;
--  end process;
--
--  -- start data gen block
--  dataGenGen : for i in 0 to 0 generate
--    signal reg_cnt : unsigned(63 downto 0) := (others => '0'); -- 1s is infinite
--    signal reg_rate : unsigned(63 downto 0) := (others => '0');  -- delay between 8 clock periods
--    
--    signal cnt : unsigned(2 downto 0) := (others => '0');
--    signal delay_cnt : unsigned(63 downto 0) := (others => '0');
--    signal data_cnt : unsigned(31 downto 0) := (others => '0');
--
----    attribute mark_debug of reg_cnt : signal is "true";
----    attribute mark_debug of reg_rate : signal is "true";
----    attribute mark_debug of cnt : signal is "true";
----    attribute mark_debug of delay_cnt : signal is "true";
----    attribute mark_debug of data_cnt : signal is "true";
--  begin
--    process(rx_clk)
--    begin
--      if (rising_edge(rx_clk)) then
--        
--        b_data_we <= '0';
--        b_data_force <= '0';
--        
--        -- register map
--        if (rx_wren = '1') then 	
--          if (unsigned(rx_addr) = x"1001") then --reg_cnt
--            reg_cnt <= unsigned(rx_data); 
--          elsif (unsigned(rx_addr) = x"1002") then --reg_rate
--            reg_rate <= unsigned(rx_data); 						
--          end if;
--          delay_cnt <= (others => '0'); --reset delay and execute burst write
--        else
--          
--          cnt <= cnt + 1; 
--          if (cnt = 0) then	--count groups of 8 with wrap around
--            delay_cnt <= delay_cnt + 1;
--            
--            if (delay_cnt = reg_rate and reg_cnt /= 0) then
--              delay_cnt <= (others => '0'); --reset delay and execute burst write
--              b_data(63 downto 32) <= std_logic_vector(data_cnt);
--              b_data(31 downto 0) <= tx_data(31 downto 0); -- last saved write
--              b_data_we <= '1';
--              data_cnt <= data_cnt + 1;
--              
--              if ( and_reduce(std_logic_vector(reg_cnt)) /= '1' ) then --count down pulses, if not infinite
--                reg_cnt <= reg_cnt - 1;
--              end if;
--
--              if reg_cnt = 1 then
--                b_data_force <= '1';
--              end if;
--            end if;
--          end if;
--        end if;
--      end if;
--        
--    end process;
--
--  end generate;	
--  -- end data gen block

end vhdl;
