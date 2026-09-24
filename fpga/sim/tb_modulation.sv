`timescale 1ns/1ps
module tb_modulation;
 reg clk=0,rst=1,ce=0;always #5 clk=~clk;
 reg signed [15:0] sample=0;reg [383:0] p=0,q=0;
 wire signed [15:0] wet,dry;
 parallel_fabric a(clk,rst,ce,sample,sample,p,6'd8,wet,,);
 parallel_fabric b(clk,rst,ce,sample,sample,q,6'd8,dry,,);
 integer i,changed=0,mincut=65535,maxcut=0;real energy=0,reference=0;
 initial begin
 p[4*16+:16]=7864;p[5*16+:16]=22937;p[9*16+:16]=64158;p[10*16+:16]=52428;p[15*16+:16]=65535;p[19*16+:16]=1;
 q=p;q[15*16+:16]=0;
 repeat(3)@(negedge clk);rst=0;
 for(i=0;i<96000;i=i+1)begin
 sample=$rtoi(12000*$sin(6.283185307179586*3000*i/48000));ce=1;@(negedge clk);ce=0;repeat(8)@(negedge clk);
 if(i>1000)begin
 if(wet!=dry)changed=changed+1;
 if(a.coefficient<mincut)mincut=a.coefficient;if(a.coefficient>maxcut)maxcut=a.coefficient;
 energy=energy+$itor(wet)*$itor(wet);reference=reference+$itor(dry)*$itor(dry);
 end
 end
 if(changed<90000||maxcut-mincut<1000||energy<reference*2)$fatal(1,"Chaos must alter real filtered samples over time");
 $display("PASS Chaos->Filter: changed=%0d coefficient=%0d..%0d energy ratio=%f",changed,mincut,maxcut,energy/reference);$finish;
 end
endmodule
