`timescale 1ns/1ps
// Run with a permitted SystemVerilog simulator. Not a substitute for HDMI capture.
module tb_expanded_screen;
 reg clk=0;always #5 clk=~clk;
 reg [9:0] x=272,y=105;
 reg [511:0] values=0;reg [103:0] expansion=0;
 reg [239:0] meters={15{16'd8192}};
 wire [15:0] pixel;
 fabric_screen #(.EXPANDED(1)) dut(x,y,values,40'd0,6'h3f,1'b1,1'b1,3'd0,pixel,meters,4'd0,clk,expansion);
 integer i;
 initial begin
  values[27*16]=1;expansion[70:64]=7'h7f;expansion[63:0]={8{8'd64}};
  for(i=0;i<13;i=i+1)begin
   y=105+i*24;#2;
   if(dut.branch!==i||!dut.active||dut.muted||dut.excluded)$fatal(1,"Wrong active row %0d",i);
   expansion[78+(i==0?12:i-1)]=1;#2;
   if(!dut.muted)$fatal(1,"Wrong mute bit %0d",i);
   expansion[90:78]=0;
  end
  expansion[91+8]=1; // Solo Bitcrusher.
  for(i=0;i<13;i=i+1)begin
   y=105+i*24;#2;
   if(dut.excluded!==(i!=9))$fatal(1,"Wrong solo mask %0d",i);
  end
  expansion[103:91]=0;values[27*16+1]=1;
  expansion[91+1]=1;y=105+6*24;#2;
  if(dut.excluded)$fatal(1,"Solo Delay 1 lost downstream Delay 2");
  expansion[103:91]=13'd32;y=105+2*24;#2;
  if(dut.excluded)$fatal(1,"Solo Delay 2 lost upstream Delay 1");
  expansion[78+1]=1;y=105+6*24;#2;
  if(!dut.muted)$fatal(1,"Mute Delay 1 did not silence series tail");
  expansion[103:78]=0;expansion[71]=1;y=105+7*24;#2;
  if(!dut.bypassed)$fatal(1,"Chorus bypass not reflected");
  // The output meter must use the expansion final sum, not legacy meter 7.
  x=500;y=86;meters=0;expansion[55:48]=128;#2;
  if(dut.background!==16'h07d4)$fatal(1,"Final output meter omitted new FX");
  expansion[55:48]=0;meters[7*16+:16]=32767;#2;
  if(dut.background!==16'h1924)$fatal(1,"Final output meter uses stale legacy sum");
  // Encoder seven now lives in the left column, in both banks.
  x=16;y=328;#2;if(!dut.row_on||dut.index!=6)$fatal(1,"Encoder column mapping");
  $display("PASS expanded HDMI rows, masks, series, final meter and encoder layout");$finish;
 end
endmodule
