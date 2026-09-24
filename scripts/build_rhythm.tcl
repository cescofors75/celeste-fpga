set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build rhythm-lab]
file mkdir $out
cd $out
set_device -name GW2AR-18C GW2AR-LV18QN88C8/I7
foreach src {audio/audio_mailbox.sv audio/i2s_slave.sv top/line_in_audio.sv top/celeste_rhythm_board.sv dsp/rhythm_gate.sv dsp/rhythm_delay.sv control/rhythm_controls.sv control/rhythm_debug.sv control/uart_8n1.sv control/touch_input.v control/display_snapshot.sv video/rhythm_screen.sv video/rhythm_video.sv} {add_file -type verilog [file join $root fpga rtl $src]}
foreach src {encoder8_panel.v i2c_register_master.v} {add_file -type verilog [file join $root fpga reference control $src]}
foreach src {st7789_panel.v ui_font.v video_timing.v tmds_encoder.v tmds_output.v video_clocks.v} {add_file -type verilog [file join $root fpga reference video $src]}
add_file -type cst [file join $root fpga constraints line_in.cst]
add_file -type sdc [file join $root fpga constraints line_in.sdc]
set_option -top_module celeste_rhythm_board
set_option -output_base_name celeste_rhythm_lab
set_option -bit_security 0
run all
exit
