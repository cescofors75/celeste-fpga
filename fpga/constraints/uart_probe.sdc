create_clock -name clk27 -period 37.037 [get_ports {clk27}]
set_false_path -from [get_ports {uart_rx reset_button}]
