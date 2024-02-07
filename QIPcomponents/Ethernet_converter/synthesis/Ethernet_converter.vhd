-- Ethernet_converter.vhd

-- Generated using ACDS version 19.1 670

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity Ethernet_converter is
	port (
		hps_gmii_phy_tx_clk_o    : in  std_logic                    := '0';             --       hps_gmii.phy_tx_clk_o
		hps_gmii_rst_tx_n        : in  std_logic                    := '0';             --               .rst_tx_n
		hps_gmii_rst_rx_n        : in  std_logic                    := '0';             --               .rst_rx_n
		hps_gmii_phy_txd_o       : in  std_logic_vector(7 downto 0) := (others => '0'); --               .phy_txd_o
		hps_gmii_phy_txen_o      : in  std_logic                    := '0';             --               .phy_txen_o
		hps_gmii_phy_txer_o      : in  std_logic                    := '0';             --               .phy_txer_o
		hps_gmii_phy_mac_speed_o : in  std_logic_vector(1 downto 0) := (others => '0'); --               .phy_mac_speed_o
		hps_gmii_phy_tx_clk_i    : out std_logic;                                       --               .phy_tx_clk_i
		hps_gmii_phy_rx_clk_i    : out std_logic;                                       --               .phy_rx_clk_i
		hps_gmii_phy_rxdv_i      : out std_logic;                                       --               .phy_rxdv_i
		hps_gmii_phy_rxer_i      : out std_logic;                                       --               .phy_rxer_i
		hps_gmii_phy_rxd_i       : out std_logic_vector(7 downto 0);                    --               .phy_rxd_i
		hps_gmii_phy_col_i       : out std_logic;                                       --               .phy_col_i
		hps_gmii_phy_crs_i       : out std_logic;                                       --               .phy_crs_i
		peri_clock_clk           : in  std_logic                    := '0';             --     peri_clock.clk
		peri_reset_reset_n       : in  std_logic                    := '0';             --     peri_reset.reset_n
		phy_rgmii_rgmii_rx_clk   : in  std_logic                    := '0';             --      phy_rgmii.rgmii_rx_clk
		phy_rgmii_rgmii_rxd      : in  std_logic_vector(3 downto 0) := (others => '0'); --               .rgmii_rxd
		phy_rgmii_rgmii_rx_ctl   : in  std_logic                    := '0';             --               .rgmii_rx_ctl
		phy_rgmii_rgmii_tx_clk   : out std_logic;                                       --               .rgmii_tx_clk
		phy_rgmii_rgmii_txd      : out std_logic_vector(3 downto 0);                    --               .rgmii_txd
		phy_rgmii_rgmii_tx_ctl   : out std_logic;                                       --               .rgmii_tx_ctl
		pll_25m_clock_clk        : in  std_logic                    := '0';             --  pll_25m_clock.clk
		pll_2_5m_clock_clk       : in  std_logic                    := '0'              -- pll_2_5m_clock.clk
	);
end entity Ethernet_converter;

architecture rtl of Ethernet_converter is
	component Ethernet_converter_gmii_to_rgmii_adapter_0 is
		generic (
			TX_PIPELINE_DEPTH : integer := 0;
			RX_PIPELINE_DEPTH : integer := 0
		);
		port (
			peri_clock_clk           : in  std_logic                    := 'X';             -- clk
			peri_reset_reset_n       : in  std_logic                    := 'X';             -- reset_n
			hps_gmii_phy_tx_clk_o    : in  std_logic                    := 'X';             -- phy_tx_clk_o
			hps_gmii_rst_tx_n        : in  std_logic                    := 'X';             -- rst_tx_n
			hps_gmii_rst_rx_n        : in  std_logic                    := 'X';             -- rst_rx_n
			hps_gmii_phy_txd_o       : in  std_logic_vector(7 downto 0) := (others => 'X'); -- phy_txd_o
			hps_gmii_phy_txen_o      : in  std_logic                    := 'X';             -- phy_txen_o
			hps_gmii_phy_txer_o      : in  std_logic                    := 'X';             -- phy_txer_o
			hps_gmii_phy_mac_speed_o : in  std_logic_vector(1 downto 0) := (others => 'X'); -- phy_mac_speed_o
			hps_gmii_phy_tx_clk_i    : out std_logic;                                       -- phy_tx_clk_i
			hps_gmii_phy_rx_clk_i    : out std_logic;                                       -- phy_rx_clk_i
			hps_gmii_phy_rxdv_i      : out std_logic;                                       -- phy_rxdv_i
			hps_gmii_phy_rxer_i      : out std_logic;                                       -- phy_rxer_i
			hps_gmii_phy_rxd_i       : out std_logic_vector(7 downto 0);                    -- phy_rxd_i
			hps_gmii_phy_col_i       : out std_logic;                                       -- phy_col_i
			hps_gmii_phy_crs_i       : out std_logic;                                       -- phy_crs_i
			phy_rgmii_rgmii_rx_clk   : in  std_logic                    := 'X';             -- rgmii_rx_clk
			phy_rgmii_rgmii_rxd      : in  std_logic_vector(3 downto 0) := (others => 'X'); -- rgmii_rxd
			phy_rgmii_rgmii_rx_ctl   : in  std_logic                    := 'X';             -- rgmii_rx_ctl
			phy_rgmii_rgmii_tx_clk   : out std_logic;                                       -- rgmii_tx_clk
			phy_rgmii_rgmii_txd      : out std_logic_vector(3 downto 0);                    -- rgmii_txd
			phy_rgmii_rgmii_tx_ctl   : out std_logic;                                       -- rgmii_tx_ctl
			pll_25m_clock_clk        : in  std_logic                    := 'X';             -- clk
			pll_2_5m_clock_clk       : in  std_logic                    := 'X'              -- clk
		);
	end component Ethernet_converter_gmii_to_rgmii_adapter_0;

begin

	gmii_to_rgmii_adapter_0 : component Ethernet_converter_gmii_to_rgmii_adapter_0
		generic map (
			TX_PIPELINE_DEPTH => 0,
			RX_PIPELINE_DEPTH => 0
		)
		port map (
			peri_clock_clk           => peri_clock_clk,           --     peri_clock.clk
			peri_reset_reset_n       => peri_reset_reset_n,       --     peri_reset.reset_n
			hps_gmii_phy_tx_clk_o    => hps_gmii_phy_tx_clk_o,    --       hps_gmii.phy_tx_clk_o
			hps_gmii_rst_tx_n        => hps_gmii_rst_tx_n,        --               .rst_tx_n
			hps_gmii_rst_rx_n        => hps_gmii_rst_rx_n,        --               .rst_rx_n
			hps_gmii_phy_txd_o       => hps_gmii_phy_txd_o,       --               .phy_txd_o
			hps_gmii_phy_txen_o      => hps_gmii_phy_txen_o,      --               .phy_txen_o
			hps_gmii_phy_txer_o      => hps_gmii_phy_txer_o,      --               .phy_txer_o
			hps_gmii_phy_mac_speed_o => hps_gmii_phy_mac_speed_o, --               .phy_mac_speed_o
			hps_gmii_phy_tx_clk_i    => hps_gmii_phy_tx_clk_i,    --               .phy_tx_clk_i
			hps_gmii_phy_rx_clk_i    => hps_gmii_phy_rx_clk_i,    --               .phy_rx_clk_i
			hps_gmii_phy_rxdv_i      => hps_gmii_phy_rxdv_i,      --               .phy_rxdv_i
			hps_gmii_phy_rxer_i      => hps_gmii_phy_rxer_i,      --               .phy_rxer_i
			hps_gmii_phy_rxd_i       => hps_gmii_phy_rxd_i,       --               .phy_rxd_i
			hps_gmii_phy_col_i       => hps_gmii_phy_col_i,       --               .phy_col_i
			hps_gmii_phy_crs_i       => hps_gmii_phy_crs_i,       --               .phy_crs_i
			phy_rgmii_rgmii_rx_clk   => phy_rgmii_rgmii_rx_clk,   --      phy_rgmii.rgmii_rx_clk
			phy_rgmii_rgmii_rxd      => phy_rgmii_rgmii_rxd,      --               .rgmii_rxd
			phy_rgmii_rgmii_rx_ctl   => phy_rgmii_rgmii_rx_ctl,   --               .rgmii_rx_ctl
			phy_rgmii_rgmii_tx_clk   => phy_rgmii_rgmii_tx_clk,   --               .rgmii_tx_clk
			phy_rgmii_rgmii_txd      => phy_rgmii_rgmii_txd,      --               .rgmii_txd
			phy_rgmii_rgmii_tx_ctl   => phy_rgmii_rgmii_tx_ctl,   --               .rgmii_tx_ctl
			pll_25m_clock_clk        => pll_25m_clock_clk,        --  pll_25m_clock.clk
			pll_2_5m_clock_clk       => pll_2_5m_clock_clk        -- pll_2_5m_clock.clk
		);

end architecture rtl; -- of Ethernet_converter