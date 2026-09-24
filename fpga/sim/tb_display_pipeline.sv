`timescale 1ns/1ps
module tb_display_pipeline;
 reg clk=0;always #20 clk=~clk;
 reg [9:0] x=0,y=0;wire [15:0] p;
 fabric_screen screen(x,y,512'd0,40'd0,6'd0,1'b0,1'b0,3'd0,p,240'd0,4'd0,clk);
 reg rst=1;wire [7:0] lx;wire [8:0] ly;wire fs,scl,sda,dc,res;reg [15:0] lp;
 st7789_panel #(.WAIT_CYCLES(1),.HALF_PERIOD(1),.FRAME_HEIGHT(1),.PIXEL_PIPELINED(1)) lcd(clk,rst,lp,lx,ly,fs,scl,sda,dc,res,1'b1);
 always @(posedge clk)lp<=16'h8000|lx;
 integer checked=0;
 always @(posedge clk)if(!rst&&lcd.state==5)begin
  if(lp!==(16'h8000|lx))$fatal(1,"LCD captured previous coordinate");
  checked=checked+1;
 end
 initial begin
  repeat(3)@(negedge clk);rst=0;x=26;y=16;@(negedge clk);
  if(p!==16'h07ff)$fatal(1,"Pipelined C glyph lost its color or position");
  x=24;@(negedge clk);if(p!==16'h0041)$fatal(1,"Glyph background shifted");
  x=24;y=92;@(negedge clk);if(p!==16'h1a88)$fatal(1,"Background pipeline mismatch");
  wait(checked>=240);$display("PASS display pipeline: glyph/background alignment and all 240 LCD coordinates");$finish;
 end
 initial begin #10000000;$fatal(1,"Display test timeout");end
endmodule
