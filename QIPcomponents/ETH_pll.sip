set_global_assignment -entity "ETH_pll" -library "lib_ETH_pll" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "ETH_pll" -library "lib_ETH_pll" -name IP_TOOL_VERSION "19.1"
set_global_assignment -entity "ETH_pll" -library "lib_ETH_pll" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_ETH_pll" -name SPD_FILE [file join $::quartus(sip_path) "ETH_pll.spd"]

set_global_assignment -library "lib_ETH_pll" -name MISC_FILE [file join $::quartus(sip_path) "ETH_pll_sim/ETH_pll.vho"]
