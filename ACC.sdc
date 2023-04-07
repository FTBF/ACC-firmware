#**************************************************************
# Create Clock
#**************************************************************
derive_pll_clocks -create_base_clocks -use_net_name
derive_clock_uncertainty -add

set_false_path -from *signaltap*
set_false_path -to *signaltap*

create_clock -period "125.0 MHz" [get_ports clockIn.localOsc]
create_clock -period "125.0 MHz" [get_ports ETH_in.rx_clk]
#create_clock -period "48.0 MHz"  [get_ports clockIn.USB_IFCLK]

#Clock Generation for PLL clocks
#create_generated_clock -name   -source [get_nets {inst134|pll_new_inst|altera_pll_i|arriav_pll|divclk[0]}] -divide_by 1 -multiply_by 1 -duty_cycle 50 -phase 0 -offset 0 

set_max_delay -from [get_registers *param_handshake_sync*src_params_latch*] -to [get_registers *param_handshake_sync*dest_params*] 25

set_false_path -from {ethernet_adapter:ethernet_adapter_inst|ethernet_interface:ethernet_interface_inst|internal_reset*} -to {ethernet_adapter:ethernet_adapter_inst|ethernet_interface:ethernet_interface_inst|reset_mgr:reset_mgr|*}

set_false_path -from {reset.global} -to {serialRx_buffer:\rxBuffer_gen:*:rxBuffer_map|rx_data_fifo:rx_fifo_map|dcfifo:dcfifo_component|*}
set_false_path -from {reset.global} -to {serialRx_dataBuffer:serialRx_dataBuffer_inst|dcfifo:\link_buffers:*:dcfifo_component|*}
set_false_path -from {commandHandler:CMD_HANDLER_MAP|commandSync:commandSync_inst|pulseSync2:\loop_gen:*:pulseSync2_rxBuffer_resetReq|dest_pulse} -to {serialRx_buffer:\rxBuffer_gen:*:rxBuffer_map|rx_data_fifo:rx_fifo_map|dcfifo:dcfifo_component*}
set_false_path -from {reset.global} -to {commandHandler:CMD_HANDLER_MAP|nreset_eth_sync*}
set_false_path -from {reset.global} -to {dataHandler:dataHandler_inst|reset_eth_sync*}
set_false_path -from [get_ports *DIPswitch*]

#trig slow control prameters 
set_false_path -from [get_registers {commandHandler:CMD_HANDLER_MAP|trig.SMA_invert commandHandler:CMD_HANDLER_MAP|trig.source*}] -to [get_registers {serialTx_ddr:serialTx_ddr_trigger|altddio_out:ALTDDIO_OUT_component|ddio_out_m9j:auto_generated|ddio_outa*}]

#set_multicycle_path -setup -end -from [get_registers {*serialRx_dataBuffer_inst*dataout_*}] -to [get_registers {*serialRx_dataBuffer_inst*serialRX_hs_z2*}] 2
