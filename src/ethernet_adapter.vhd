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
    ETH_out         : out ETH_out_type

--    -- rx/tx signals
--    rx_addr              	: out   std_logic_vector (31 downto 0); 
--    rx_data              	: out   std_logic_vector (63 downto 0);   	
--    rx_wren              	: out   std_logic;												   
--    tx_data              	: in    std_logic_vector (63 downto 0); 	 					 
--    -- burst signals
--    b_data               	: in    std_logic_vector (63 downto 0); 
--    b_data_we            	: in    std_logic; 												                            
--    b_enable             	: out   std_logic; 				  		  						
	);
end ethernet_adapter;
	
		
architecture vhdl of ethernet_adapter is

  component ethernet_interface is
    port (
      reset_in   : in  std_logic;
      reset_out  : out std_logic;
      rx_addr    : out std_logic_vector (31 downto 0);
      rx_data    : out std_logic_vector (63 downto 0);
      rx_wren    : out std_logic;
      tx_data    : in  std_logic_vector (63 downto 0);
      b_data     : in  std_logic_vector (63 downto 0);
      b_data_we  : in  std_logic;
      b_enable   : out std_logic;
      MASTER_CLK : in  std_logic;
      USER_CLK   : in  std_logic;
      PHY_RXD    : in  std_logic_vector (7 downto 0);
      PHY_RX_DV  : in  std_logic;
      PHY_RX_ER  : in  std_logic;
      TX_CLK     : out std_logic;
      PHY_TXD    : out std_logic_vector (7 downto 0);
      PHY_TX_EN  : out std_logic;
      PHY_TX_ER  : out std_logic);
  end component ethernet_interface;
  
  --RX signals
  signal rx_dv   : std_logic;
  signal rx_tmp  : std_logic;
  signal rx_er   : std_logic;
  signal rx_dat  : std_logic_vector(7 downto 0);
  
  --TX signals
  signal gtx_clk : std_logic;
  signal tx_en   : std_logic;
  signal tx_er   : std_logic;
  signal tx_dat  : std_logic_vector(7 downto 0);

  type mem_type is array (7 downto 0) of std_logic_vector(63 downto 0);
  signal cfg_mem : mem_type;
  signal cfg_datum : std_logic_vector(63 downto 0);

  -- rx/tx signals
  signal rx_addr              	: std_logic_vector (31 downto 0);
  signal rx_data              	: std_logic_vector (63 downto 0);
  signal rx_wren              	: std_logic;
  signal tx_data              	: std_logic_vector (63 downto 0);
  -- burst signals
  signal b_data               	: std_logic_vector (63 downto 0);
  signal b_data_we            	: std_logic;
  signal b_enable             	: std_logic;

  -- other signals
  signal resetSync_serial : std_logic;

  signal resetSync_eth : std_logic;

begin

  reset_sync_serial: sync_Bits_Altera
    generic map (
      BITS       => 1,
      INIT       => x"00000000",
      SYNC_DEPTH => 2)
    port map (
      Clock  => clock.serial125,
      Input(0)  => reset,
      Output(0) => resetSync_serial);

  reset_sync_eth: sync_Bits_Altera
    generic map (
      BITS       => 1,
      INIT       => x"00000000",
      SYNC_DEPTH => 2)
    port map (
      Clock  => ETH_in.rx_ctl,
      Input(0)  => reset,
      Output(0) => resetSync_eth);

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
      aclr => resetSync_eth,
      datain(0) => ETH_in.rx_ctl,
      inclock => ETH_in.rx_clk,
      dataout_h(0) => rx_dv,
      dataout_l(0) => rx_tmp
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
      aclr => resetSync_eth,
      datain => ETH_in.rx_dat,
      inclock => ETH_in.rx_clk,
      dataout_h => rx_dat(3 downto 0),
      dataout_l => rx_dat(7 downto 4)
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
      datain_l(0) => tx_en xor tx_er,
      outclock => gtx_clk,
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
      outclock => gtx_clk,
      dataout => ETH_out.tx_dat
      );

  --ethernet interface
  ethernet_interface_inst: ethernet_interface
    port map (
      reset_in   => resetSync_eth,
      reset_out  => open,

      -- mmap interface signals 
      rx_addr    => rx_addr,
      rx_data    => rx_data,
      rx_wren    => rx_wren,
      tx_data    => tx_data,
      --burst interface signals 
      b_data     => b_data,
      b_data_we  => b_data_we,
      b_enable   => b_enable,
      --PHY interface signals 
      MASTER_CLK => ETH_in.rx_clk,
      USER_CLK   => ETH_in.rx_clk,
      PHY_RXD    => rx_dat,
      PHY_RX_DV  => rx_dv,
      PHY_RX_ER  => rx_er,
      TX_CLK     => gtx_clk,
      PHY_TXD    => tx_dat,
      PHY_TX_EN  => tx_en,
      PHY_TX_ER  => tx_er);

  tx_data <= cfg_mem(to_integer(unsigned(rx_addr)));
  read_mux : process(ETH_in.rx_clk)
  begin
    if rising_Edge(ETH_in.rx_clk) then
      if resetSync_eth = '1' then
        for i in 0 to 7 loop
          cfg_mem(i) <= X"0000000000000000";
        end loop;
      else
        if rx_wren = '1' then
          cfg_mem(to_integer(unsigned(rx_addr))) <= rx_data;
        end if;
      end if;
    end if;
  end process;

end vhdl;
