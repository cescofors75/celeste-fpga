`timescale 1ns/1ps
module tb_screen #(parameter BANK=0);
 reg [9:0] x=0,y=0;reg [383:0] values=0;wire [15:0] hdmi,lcd;
 fabric_screen a(x,y,values,(BANK?{5'd10,5'd15,5'd12,5'd11,5'd17,5'd14,5'd16,5'd13}:40'h5290611020),6'h3f,1'b1,1'b1,3'd2,hdmi,128'h50001000300040001800200060007000);
 fabric_screen #(.SMALL(1)) b(x,y,values,(BANK?{5'd10,5'd15,5'd12,5'd11,5'd17,5'd14,5'd16,5'd13}:40'h5290611020),6'h3f,1'b1,1'b1,3'd2,lcd,128'h50001000300040001800200060007000);
 integer f,g,i,j;initial begin
  for(i=0;i<18;i=i+1)values[i*16+:16]=i*4096;
  values[21*16+:16]=BANK?65535:0;
  f=$fopen("build/hdmi.ppm","w");g=$fopen("build/lcd.ppm","w");$fwrite(f,"P3\n640 480\n255\n");$fwrite(g,"P3\n240 240\n255\n");
  for(j=0;j<480;j=j+1)for(i=0;i<640;i=i+1)begin x=i;y=j;#10;
   $fwrite(f,"%d %d %d\n",{hdmi[15:11],3'b0},{hdmi[10:5],2'b0},{hdmi[4:0],3'b0});
   if(i<240&&j<240)$fwrite(g,"%d %d %d\n",{lcd[15:11],3'b0},{lcd[10:5],2'b0},{lcd[4:0],3'b0});
  end
  $fclose(f);$fclose(g);$display("Rendered exact HDL HDMI and LCD pixels");$finish;
 end
endmodule
