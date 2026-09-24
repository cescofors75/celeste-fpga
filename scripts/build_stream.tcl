set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build stream]
file mkdir $out
cd $out
set_device -name GW2AR-18C GW2AR-LV18QN88C8/I7
foreach src {audio/sample_fifo.sv audio/sdram_fifo.sv audio/async_fifo.sv audio/i2s_tx.v top/stream_audio.sv control/protocol_rx.sv control/stream_endpoint.sv control/uart_8n1.sv top/celeste_stream_board.sv} {add_file -type verilog [file join $root fpga rtl $src]}
foreach src {dsp/parallel_fabric.sv control/touch_input.v control/fabric_registers.sv control/encoder_palette.sv control/display_snapshot.sv video/fabric_screen.sv video/fabric_video.sv} {add_file -type verilog [file join $root fpga rtl $src]}
foreach src {encoder8_panel.v i2c_register_master.v} {add_file -type verilog [file join $root fpga reference control $src]}
foreach src {st7789_panel.v ui_font.v} {add_file -type verilog [file join $root fpga reference video $src]}
foreach src {video_timing.v scope_view.v tmds_encoder.v hdmi_content.v sine_lut.v tone_dds.v tmds_output.v video_clocks.v} {add_file -type verilog [file join $root fpga reference video $src]}
add_file -type cst [file join $root fpga constraints stream.cst]
add_file -type sdc [file join $root fpga constraints stream.sdc]
set_option -top_module celeste_stream_board
set_option -output_base_name celeste_stream
set_option -bit_security 0
run all
exit
