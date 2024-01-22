
module Ethernet_converter (
	peri_clock_clk,
	peri_reset_reset_n,
	hps_gmii_phy_tx_clk_o,
	hps_gmii_rst_tx_n,
	hps_gmii_rst_rx_n,
	hps_gmii_phy_txd_o,
	hps_gmii_phy_txen_o,
	hps_gmii_phy_txer_o,
	hps_gmii_phy_mac_speed_o,
	hps_gmii_phy_tx_clk_i,
	hps_gmii_phy_rx_clk_i,
	hps_gmii_phy_rxdv_i,
	hps_gmii_phy_rxer_i,
	hps_gmii_phy_rxd_i,
	hps_gmii_phy_col_i,
	hps_gmii_phy_crs_i,
	phy_rgmii_rgmii_rx_clk,
	phy_rgmii_rgmii_rxd,
	phy_rgmii_rgmii_rx_ctl,
	phy_rgmii_rgmii_tx_clk,
	phy_rgmii_rgmii_txd,
	phy_rgmii_rgmii_tx_ctl,
	pll_25m_clock_clk,
	pll_2_5m_clock_clk);	

	input		peri_clock_clk;
	input		peri_reset_reset_n;
	input		hps_gmii_phy_tx_clk_o;
	input		hps_gmii_rst_tx_n;
	input		hps_gmii_rst_rx_n;
	input	[7:0]	hps_gmii_phy_txd_o;
	input		hps_gmii_phy_txen_o;
	input		hps_gmii_phy_txer_o;
	input	[1:0]	hps_gmii_phy_mac_speed_o;
	output		hps_gmii_phy_tx_clk_i;
	output		hps_gmii_phy_rx_clk_i;
	output		hps_gmii_phy_rxdv_i;
	output		hps_gmii_phy_rxer_i;
	output	[7:0]	hps_gmii_phy_rxd_i;
	output		hps_gmii_phy_col_i;
	output		hps_gmii_phy_crs_i;
	input		phy_rgmii_rgmii_rx_clk;
	input	[3:0]	phy_rgmii_rgmii_rxd;
	input		phy_rgmii_rgmii_rx_ctl;
	output		phy_rgmii_rgmii_tx_clk;
	output	[3:0]	phy_rgmii_rgmii_txd;
	output		phy_rgmii_rgmii_tx_ctl;
	input		pll_25m_clock_clk;
	input		pll_2_5m_clock_clk;
endmodule
