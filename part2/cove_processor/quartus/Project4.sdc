create_clock -name "clock_50_2" -period 20.000ns [get_ports {CLOCK_50_B5B}]
create_clock -name "clock_50_3" -period 20.000ns [get_ports {CLOCK_50_B6A}]
create_clock -name "clock_50_4" -period 20.000ns [get_ports {CLOCK_50_B7A}]
create_clock -name "clock_50_5" -period 20.000ns [get_ports {CLOCK_50_B8A}]

derive_pll_clocks -create_base_clocks
derive_clock_uncertainty
