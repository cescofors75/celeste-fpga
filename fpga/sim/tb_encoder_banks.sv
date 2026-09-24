`timescale 1ns/1ps
module tb_encoder_banks;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,event_in=0,press=0,long_press=0,bank=0;
 reg [2:0] index=0;reg signed [31:0] delta=0;
 wire [511:0] controls;wire [55:0] mappings;wire [127:0] display_values;
 stream_endpoint #(.DEPTH(16),.EXPANDED(1)) dut(
  .clk_audio(clk),.rst(rst),.rx_valid(1'b0),.rx_data(8'd0),.tx_ready(1'b1),
  .encoder_event(event_in),.encoder_index(index),.encoder_delta(delta),.panel_online(1'b1),
  .control_values(controls),.control_mappings(mappings),.bypass_toggle(1'b0),.bank_switch(bank),
  .adc_bck(1'b0),.adc_lrck(1'b0),.adc_dout(1'b0),.encoder_press(press),.encoder_long(long_press),
  .display_encoder_values(display_values));
 task turn(input [2:0] n,input signed [31:0] amount);
 begin @(negedge clk);index=n;delta=amount;event_in=1;@(negedge clk);event_in=0;#1;end endtask
 initial begin
  repeat(3)@(negedge clk);rst=0;repeat(3)@(negedge clk);
  if(mappings!={7'd15,7'd12,7'd14,7'd13,7'd4,7'd24,7'd2,7'd0})$fatal(1,"Bank 0 defaults");
  turn(0,1);if(controls[15:0]!=33280)$fatal(1,"Legacy turn");
  bank=1;repeat(3)@(negedge clk);
  if(mappings!={7'd10,7'd84,7'd82,7'd79,7'd75,7'd72,7'd70,7'd67})$fatal(1,"Bank 1 defaults");
  turn(0,1);if(dut.expansion_p[3]!=512)$fatal(1,"Chorus turn");
  repeat(10)@(negedge clk);if(display_values[15:0]!=512)$fatal(1,"Display readback");
  turn(0,-2);if(dut.expansion_p[3]!=0)$fatal(1,"Lower clamp");
  turn(0,9999);if(dut.expansion_p[3]!=65535)$fatal(1,"Upper clamp");
  turn(3,1);if(dut.expansion_p[11]!=65535)$fatal(1,"Freeze Hold");
  turn(3,-1);if(dut.expansion_p[11]!=0)$fatal(1,"Freeze Capture");
  @(negedge clk);index=0;press=1;@(negedge clk);press=0;#1;
  if(dut.expansion_p[24]!=64)$fatal(1,"Chorus Mute");
  @(negedge clk);long_press=1;@(negedge clk);long_press=0;#1;
  if(dut.expansion_p[24]!=0||dut.expansion_p[25]!=64)$fatal(1,"Chorus Solo");
  $display("PASS 16 encoder defaults, old/new rotation, clamp, Freeze, display, Mute/Solo");$finish;
 end
endmodule
