set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build uart_probe]
file mkdir $out
cd $out
set_device -name GW2AR-18C GW2AR-LV18QN88C8/I7
foreach src {audio/sample_fifo.sv control/uart_8n1.sv top/uart_probe.sv} {
 add_file -type verilog [file join $root fpga rtl $src]
}
add_file -type cst [file join $root fpga constraints uart_probe.cst]
add_file -type sdc [file join $root fpga constraints uart_probe.sdc]
set_option -top_module uart_probe
set_option -output_base_name uart_probe
set_option -bit_security 0
run all
exit
