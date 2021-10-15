set_global_assignment -entity "pll_serial" -library "lib_pll_serial" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "pll_serial" -library "lib_pll_serial" -name IP_TOOL_VERSION "19.1"
set_global_assignment -entity "pll_serial" -library "lib_pll_serial" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_pll_serial" -name SPD_FILE [file join $::quartus(sip_path) "pll_serial.spd"]

set_global_assignment -library "lib_pll_serial" -name MISC_FILE [file join $::quartus(sip_path) "pll_serial_sim/pll_serial.vho"]
