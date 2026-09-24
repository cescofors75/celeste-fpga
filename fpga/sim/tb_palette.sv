`timescale 1ns/1ps
module tb_palette;
 reg clk=0,rst=1,write=0,bank=0,online=1;
 always #5 clk=~clk;
 reg [15:0] address=0,value=0;
 wire [39:0] mappings;wire [191:0] leds;
 fabric_registers regs(.clk(clk),.rst(rst),.host_write(write),.host_id(address),.host_value(value),
  .encoder_press(1'b0),.encoder_event(1'b0),.encoder_index(3'd0),.encoder_delta(32'sd0),.mappings(mappings),
  .bypass_toggle(1'b0),.bank_switch(bank),.panel_online(online));
 encoder_palette palette(mappings,leds);
 fabric_screen screen(.x(10'd0),.y(10'd0),.values(512'd0),.mappings(mappings),.routes(6'd0),
  .running(1'b0),.online(online),.selected(3'd0),.meters(240'd0),.flow_phase(4'd0),.clk(clk));
 task check(input integer channel,input [23:0] expected);
 begin if(leds[channel*24+:24]!==expected)$fatal(1,"LED channel %0d: %h != %h",channel,leds[channel*24+:24],expected);end endtask
 task remap(input [15:0] addr,param);
 begin @(negedge clk);address=addr;value=param;write=1;@(negedge clk);write=0;#1;end endtask
 initial begin
  repeat(3)@(negedge clk);rst=0;#1;
  // Physical wire bytes are R then G then B, not the packed HTML order.
  check(0,24'h0f0a1f);check(1,24'h0f0a1f);check(2,24'h07141f);check(3,24'h07141f);
  check(4,24'h1f1506);check(5,24'h1f1506);check(6,24'h141b00);check(7,24'h1b1a17);
  bank=1;repeat(2)@(negedge clk);
  check(0,24'h170c1f);check(1,24'h170c1f);check(2,24'h1f0f15);check(3,24'h1f0f15);
  check(4,24'h141b00);check(5,24'h141b00);check(6,24'h1f0e15);check(7,24'h1b1a17);
  remap(48,26);check(0,24'h1f190b); // Delay 2 mix must be cyan, not mixer white.
  remap(49,7);check(1,24'h0f0a1f); // Glitch mix follows Glitch.
  remap(40,28);check(0,24'h1f190b); // Inactive bank write cannot recolor active controls.
  online=0;bank=0;repeat(2)@(negedge clk);check(0,24'h1f190b);
  online=1;repeat(2)@(negedge clk);check(0,24'h07141f);check(1,24'h0f0a1f);
  if(screen.tint(0)!==16'hfa8f||screen.tint(7)!==screen.branch_color(1))$fatal(1,"Glitch HDMI mismatch");
  if(screen.tint(24)!==16'h5e7f||screen.tint(26)!==screen.branch_color(6))$fatal(1,"Delay 2 HDMI mismatch");
  if(screen.tint(13)!==screen.branch_color(4)||screen.tint(17)!==screen.branch_color(5))$fatal(1,"Extended HDMI mismatch");
  $display("PASS palette: RGB byte order, both banks, live/inactive remap, offline retention, HDMI effect colors");$finish;
 end
 initial begin #100000;$fatal(1,"Palette timeout");end
endmodule
