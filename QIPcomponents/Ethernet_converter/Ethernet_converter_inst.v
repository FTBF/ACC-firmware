	Ethernet_converter u0 (
		.peri_clock_clk           (<connected-to-peri_clock_clk>),           //     peri_clock.clk
		.peri_reset_reset_n       (<connected-to-peri_reset_reset_n>),       //     peri_reset.reset_n
		.hps_gmii_phy_tx_clk_o    (<connected-to-hps_gmii_phy_tx_clk_o>),    //       hps_gmii.phy_tx_clk_o
		.hps_gmii_rst_tx_n        (<connected-to-hps_gmii_rst_tx_n>),        //               .rst_tx_n
		.hps_gmii_rst_rx_n        (<connected-to-hps_gmii_rst_rx_n>),        //               .rst_rx_n
		.hps_gmii_phy_txd_o       (<connected-to-hps_gmii_phy_txd_o>),       //               .phy_txd_o
		.hps_gmii_phy_txen_o      (<connected-to-hps_gmii_phy_txen_o>),      //               .phy_txen_o
		.hps_gmii_phy_txer_o      (<connected-to-hps_gmii_phy_txer_o>),      //               .phy_txer_o
		.hps_gmii_phy_mac_speed_o (<connected-to-hps_gmii_phy_mac_speed_o>), //               .phy_mac_speed_o
		.hps_gmii_phy_tx_clk_i    (<connected-to-hps_gmii_phy_tx_clk_i>),    //               .phy_tx_clk_i
		.hps_gmii_phy_rx_clk_i    (<connected-to-hps_gmii_phy_rx_clk_i>),    //               .phy_rx_clk_i
		.hps_gmii_phy_rxdv_i      (<connected-to-hps_gmii_phy_rxdv_i>),      //               .phy_rxdv_i
		.hps_gmii_phy_rxer_i      (<connected-to-hps_gmii_phy_rxer_i>),      //               .phy_rxer_i
		.hps_gmii_phy_rxd_i       (<connected-to-hps_gmii_phy_rxd_i>),       //               .phy_rxd_i
		.hps_gmii_phy_col_i       (<connected-to-hps_gmii_phy_col_i>),       //               .phy_col_i
		.hps_gmii_phy_crs_i       (<connected-to-hps_gmii_phy_crs_i>),       //               .phy_crs_i
		.phy_rgmii_rgmii_rx_clk   (<connected-to-phy_rgmii_rgmii_rx_clk>),   //      phy_rgmii.rgmii_rx_clk
		.phy_rgmii_rgmii_rxd      (<connected-to-phy_rgmii_rgmii_rxd>),      //               .rgmii_rxd
		.phy_rgmii_rgmii_rx_ctl   (<connected-to-phy_rgmii_rgmii_rx_ctl>),   //               .rgmii_rx_ctl
		.phy_rgmii_rgmii_tx_clk   (<connected-to-phy_rgmii_rgmii_tx_clk>),   //               .rgmii_tx_clk
		.phy_rgmii_rgmii_txd      (<connected-to-phy_rgmii_rgmii_txd>),      //               .rgmii_txd
		.phy_rgmii_rgmii_tx_ctl   (<connected-to-phy_rgmii_rgmii_tx_ctl>),   //               .rgmii_tx_ctl
		.pll_25m_clock_clk        (<connected-to-pll_25m_clock_clk>),        //  pll_25m_clock.clk
		.pll_2_5m_clock_clk       (<connected-to-pll_2_5m_clock_clk>)        // pll_2_5m_clock.clk
	);

