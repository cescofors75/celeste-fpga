`timescale 1ns/1ps
// End-to-end DSP -> serialized I2S, independent unity-gain reference.
module tb_dsp_i2s;
 reg clk=0,rst=1;always #5 clk=~clk;
 reg signed [15:0] l=1234,r=-2345;
 reg [383:0] p=0;wire ce,bck,lrck,dout;wire signed [15:0] ol,orr;
 parallel_fabric fabric(clk,rst,ce,l,r,p,6'd1,ol,orr,);
 i2s_tx tx(clk,rst,{ol,8'b0},{orr,8'b0},ce,bck,lrck,dout);
 reg [31:0] expected_l[0:255],expected_r[0:255];
 reg signed [15:0] previous_l=0,previous_r=0;
 integer written=0,age=0,n,j;reg [31:0] received_l,received_r;
 always @(posedge clk)if(!rst)begin
  if(ce)begin
   if(fabric.phase!=0)$fatal(1,"DSP missed 256-clock sample deadline");
   expected_l[written]={previous_l,16'b0};expected_r[written]={previous_r,16'b0};
   previous_l=l;previous_r=r;written=written+1;
   l<=l+16'd631;r<=r-16'd977;age<=0;
  end else age<=age+1;
 end
 always @(negedge clk)if(!rst&&age==6)begin
  if(ol!==previous_l||orr!==previous_r)$fatal(1,"DSP output not ready at six clocks");
 end
 initial begin
  p[6*16+:16]=65535;p[10*16+:16]=65535;
  repeat(5)@(negedge clk);rst=0;
  @(negedge lrck);@(posedge bck);
  for(n=0;n<128;n=n+1)begin
   received_l=0;received_r=0;
   for(j=0;j<32;j=j+1)begin @(posedge bck);received_l={received_l[30:0],dout};end
   for(j=0;j<32;j=j+1)begin @(posedge bck);received_r={received_r[30:0],dout};end
   if(received_l!==expected_l[n]||received_r!==expected_r[n])$fatal(1,"DSP/I2S frame %0d mismatch %h %h expected %h %h",n,received_l,received_r,expected_l[n],expected_r[n]);
  end
  $display("PASS DSP->I2S: 128 bit-exact stereo frames; six-clock DSP, one-frame serializer handoff, no missed deadline");$finish;
 end
 initial begin #1000000;$fatal(1,"DSP I2S timeout");end
endmodule
