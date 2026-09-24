`timescale 1ns/1ps
module tb_cellular_buffer4;
 reg clk=0,rst=1,valid=0,raw=0,bypass=0;always #5 clk=~clk;
 reg signed [15:0] l=0,r=0;wire signed [15:0] ol,orr;wire done;wire [31:0] late,guards;
 reg [31:0] input_frames[0:23999],expected[0:23999];integer i,cycles,k;reg [1:0] rule_mode=0;
 cellular_buffer4 dut(clk,rst,valid,l,r,16'hffff,16'h8000,16'hffff,16'hffff,rule_mode,raw,bypass,ol,orr,done,late,guards);
 initial begin
  for(k=0;k<3;k=k+1)begin
  rst=1;rule_mode=k;
  case(k)
  0:begin $readmemh("build/cellular-reference/input-30.hex",input_frames);$readmemh("build/cellular-reference/expected-30.hex",expected);end
  1:begin $readmemh("build/cellular-reference/input-90.hex",input_frames);$readmemh("build/cellular-reference/expected-90.hex",expected);end
  2:begin $readmemh("build/cellular-reference/input-110.hex",input_frames);$readmemh("build/cellular-reference/expected-110.hex",expected);end
  endcase
  repeat(4)@(negedge clk);rst=0;
  for(i=0;i<24000;i=i+1)begin
   l=input_frames[i][15:0];r=input_frames[i][31:16];valid=1;
   @(negedge clk);valid=0;cycles=0;
   while(!done&&cycles<32)begin @(negedge clk);cycles=cycles+1;end
   if(!done||cycles>24)$fatal(1,"Missed deadline at frame %0d",i);
   if({orr,ol}!==expected[i])$fatal(1,"Reference mismatch frame %0d got %h expected %h",i,{orr,ol},expected[i]);
   if(late!=0||guards!=0)$fatal(1,"Unexpected fault");
   repeat(256-cycles-1)@(negedge clk);
  end
  end
  $display("PASS Cellular integer reference 72000 stereo frames, three rules, deadline");$finish;
 end
 initial begin #200000000;$fatal(1,"timeout");end
endmodule
