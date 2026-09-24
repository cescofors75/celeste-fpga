`timescale 1ns/1ps
module tb_stream;
 reg clk=0,rst=1,start=0,stop=0,drain=0,valid=0;always #5 clk=~clk;
 reg [31:0] data=0;wire ready,bck,lrck,dout,running,source_valid;
 wire [12:0] fill;wire [31:0] samples,under,over;wire signed [15:0] left,right;
 stream_audio dut(clk,rst,start,stop,drain,valid,data,ready,bck,lrck,dout,running,fill,samples,under,over,source_valid,left,right,384'd0,6'd0);
 integer i,seen=0;
 always @(posedge clk)if(source_valid)begin
  if(left!==seen+1||right!==-(seen+1))$fatal(1,"Source pairing/order %d L=%d R=%d",seen,left,right);
  seen=seen+1;
 end
 initial begin
  repeat(4)@(negedge clk);rst=0;
  for(i=1;i<=32;i=i+1)begin valid=1;data={16'(-i),16'(i)};@(negedge clk);end
  valid=0;repeat(10)@(negedge clk);start=1;drain=1;@(negedge clk);start=0;drain=0;
  wait(!running);@(negedge clk);
  if(seen!=32||samples!=32||under!=0||over!=0||fill!=0)$fatal(1,"Drain/count mismatch");
  start=1;@(negedge clk);start=0;repeat(300)@(negedge clk);if(under==0)$fatal(1,"Missing underrun");
  stop=1;@(negedge clk);stop=0;if(running||fill!=0)$fatal(1,"Stop failed");
  $display("PASS stream: prefill, stereo order, drain, underrun, stop");$finish;
 end
 initial begin #200000;$fatal(1,"Timeout");end
endmodule
