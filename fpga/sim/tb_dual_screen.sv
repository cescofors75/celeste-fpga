`timescale 1ns/1ps
module tb_dual_screen;
 reg [9:0] x=0,y=0;reg [511:0] values=0;reg [39:0] maps=0;wire [15:0] pixel;
 integer f,xx,yy,i;reg [7:0] red,green,blue;
 fabric_screen screen(x,y,values,maps,6'd63,1'b1,1'b1,3'd0,pixel,{15{16'd9000}},4'd0);
 initial begin
  for(i=0;i<32;i=i+1)values[i*16+:16]=32768;
  values[20*16+:16]=0;values[21*16+:16]=0;values[22*16+:16]=2;values[27*16+:16]=3;
  for(i=0;i<8;i=i+1)maps[i*5+:5]=i;
  f=$fopen("build/dual-delay-hdmi.ppm","wb");$fwrite(f,"P6\n640 480\n255\n");
  for(yy=0;yy<480;yy=yy+1)for(xx=0;xx<640;xx=xx+1)begin
   x=xx;y=yy;#1;red={pixel[15:11],3'b0};green={pixel[10:5],2'b0};blue={pixel[4:0],3'b0};$fwrite(f,"%c%c%c",red,green,blue);
  end
  $fclose(f);$display("PASS HDMI render");$finish;
 end
endmodule
