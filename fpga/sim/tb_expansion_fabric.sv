`timescale 1ns/1ps
module tb_expansion_fabric;
 reg clk=0,rst=1,ce=0,start=0;always #5 clk=~clk;
 reg signed [15:0] l=0,r=0;reg [511:0] p=0;wire signed [15:0] ol,orr;wire [15:0] env;wire done;wire [31:0] faults;wire [63:0] levels;
 reg [31:0] input_frames[0:11999],expected[0:11999];integer i,k,cycles;
 expansion_fabric dut(clk,rst,ce,start,l,r,16'sd0,16'sd0,p,16'd26214,16'd0,ol,orr,env,done,faults,levels);
 initial begin
 p[0+:16]=63;
 p[4*16+:16]=10000;p[7*16+:16]=10000;p[10*16+:16]=10000;p[13*16+:16]=10000;p[16*16+:16]=10000;p[19*16+:16]=10000;
 p[2*16+:16]=16000;p[5*16+:16]=16000;p[14*16+:16]=16000;p[17*16+:16]=16000;
 p[3*16+:16]=40000;p[6*16+:16]=40000;p[8*16+:16]=32768;p[9*16+:16]=1500;p[11*16+:16]=65535;p[15*16+:16]=65535;p[18*16+:16]=65535;
 $readmemh("build/expansion-reference/input.hex",input_frames);$readmemh("build/expansion-reference/expected.hex",expected);
 repeat(4)@(negedge clk);rst=0;
 for(i=0;i<12000;i=i+1)begin
 l=input_frames[i][15:0];r=input_frames[i][31:16];ce=1;@(negedge clk);ce=0;
 repeat(31)@(negedge clk);start=1;@(negedge clk);start=0;cycles=0;
 while(!done&&cycles<60)begin @(negedge clk);cycles=cycles+1;end
 if(!done||faults!=0)$fatal(1,"deadline frame %0d",i);
 if({orr,ol}!==expected[i])$fatal(1,"frame %0d got %h expected %h",i,{orr,ol},expected[i]);
 repeat(223-cycles)@(negedge clk);
 end
 $display("PASS independent FX reference");$finish;
 end
 initial begin #40000000;$fatal(1,"timeout");end
endmodule
