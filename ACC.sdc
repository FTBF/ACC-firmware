#**************************************************************
# Create Clock
#**************************************************************
derive_pll_clocks -create_base_clocks -use_net_name
derive_clock_uncertainty -add

set_false_path -from *signaltap*
set_false_path -to *signaltap*

create_clock -period "25.0 MHz" [get_ports clockIn.localOsc]
#create_clock -period "48.0 MHz"  [get_ports clockIn.USB_IFCLK]

#Clock Generation for PLL clocks
#create_generated_clock -name   -source [get_nets {inst134|pll_new_inst|altera_pll_i|arriav_pll|divclk[0]}] -divide_by 1 -multiply_by 1 -duty_cycle 50 -phase 0 -offset 0 

set_max_delay -from [get_registers *param_handshake_sync*src_params_latch*] -to [get_registers *param_handshake_sync*dest_params*] 25
