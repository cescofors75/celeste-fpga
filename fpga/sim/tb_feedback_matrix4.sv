`timescale 1ns/1ps
module tb_feedback_matrix4;
 reg clk=0,rst=1,valid=0,raw=0,bypass=0;always #5 clk=~clk;
 reg signed [15:0] l=0,r=0;wire signed [15:0] ol,orr;wire done;wire [31:0] late,guards;
 reg [31:0] input_frames[0:29999],expected[0:29999];integer i,cycles;
 feedback_matrix4 dut(clk,rst,valid,l,r,16'd32768,16'd45875,16'd24576,16'd26214,bypass,ol,orr,done,late,guards);
 initial begin
  $readmemh("build/feedback-reference/input.hex",input_frames);
  $readmemh("build/feedback-reference/expected.hex",expected);
  repeat(4)@(negedge clk);rst=0;
  for(i=0;i<30000;i=i+1)begin
   l=input_frames[i][15:0];r=input_frames[i][31:16];valid=1;
   @(negedge clk);valid=0;cycles=0;
   while(!done&&cycles<32)begin @(negedge clk);cycles=cycles+1;end
   if(!done||cycles>24)$fatal(1,"Missed deadline at frame %0d",i);
   if({orr,ol}!==expected[i])$fatal(1,"Reference mismatch frame %0d got %h expected %h",i,{orr,ol},expected[i]);
   if(late!=0||guards!=0)$fatal(1,"Unexpected fault");
   repeat(256-cycles-1)@(negedge clk);
  end
  $display("PASS FDN-4 integer reference 30000 stereo frames, deadline");$finish;
 end
 initial begin #90000000;$fatal(1,"timeout");end
endmodule
