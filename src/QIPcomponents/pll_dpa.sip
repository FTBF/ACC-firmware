set_global_assignment -entity "pll_dpa" -library "lib_pll_dpa" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "pll_dpa" -library "lib_pll_dpa" -name IP_TOOL_VERSION "19.1"
set_global_assignment -entity "pll_dpa" -library "lib_pll_dpa" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_pll_dpa" -name SPD_FILE [file join $::quartus(sip_path) "pll_dpa.spd"]

set_global_assignment -library "lib_pll_dpa" -name MISC_FILE [file join $::quartus(sip_path) "pll_dpa_sim/pll_dpa.vho"]
