set_global_assignment -entity "ETH_out_pll" -library "lib_ETH_out_pll" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "ETH_out_pll" -library "lib_ETH_out_pll" -name IP_TOOL_VERSION "19.1"
set_global_assignment -entity "ETH_out_pll" -library "lib_ETH_out_pll" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_ETH_out_pll" -name SPD_FILE [file join $::quartus(sip_path) "ETH_out_pll.spd"]

set_global_assignment -library "lib_ETH_out_pll" -name MISC_FILE [file join $::quartus(sip_path) "ETH_out_pll_sim/ETH_out_pll.vho"]
