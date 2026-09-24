`timescale 1ns/1ps
// File-driven real RTL. Eight clocks per sample is an accelerated simulation;
// a separate deadline/I2S test runs the actual 256-clock frame cadence.
module tb_audio_audit;
 reg clk=0,rst=1,ce=0;always #5 clk=~clk;
 reg signed [15:0] l=0,r=0;reg [511:0] p=0;reg [5:0] routes=0;
 wire signed [15:0] ol,orr;wire [127:0] meters;
 parallel_fabric dut(clk,rst,ce,l,r,p,routes,ol,orr,meters);
 reg [31:0] stimulus[0:524287];integer f,g,rc,count,offset,i,case_id;
 initial begin
 $readmemh("build/audio-audit/input.hex",stimulus);
 f=$fopen("build/audio-audit/cases.txt","r");g=$fopen("build/audio-audit/output.txt","w");
 if(!f||!g)$fatal(1,"Missing audit vectors");
 while(!$feof(f))begin
 rc=$fscanf(f,"%d %d %d %h %h\n",case_id,offset,count,p,routes);
 if(rc==5)begin
 rst=1;ce=0;repeat(3)@(negedge clk);rst=0;
 for(i=0;i<count;i=i+1)begin
 {r,l}=stimulus[offset+i];ce=1;@(negedge clk);ce=0;repeat(7)@(negedge clk);
 if((^ol)===1'bx||(^orr)===1'bx)$fatal(1,"Unknown sample case=%0d frame=%0d",case_id,i);
 $fwrite(g,"%0d %0d %0d %0d %0d\n",ol,orr,dut.cut,dut.vca_gain,dut.coefficient);
 end
 $display("CASE %0d DONE (%0d frames)",case_id,count);
 end
 end
 $fclose(f);$fclose(g);$finish;
 end
 initial begin #100000000;$fatal(1,"Audit deadline");end
endmodule
