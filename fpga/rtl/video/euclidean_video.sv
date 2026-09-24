`default_nettype none
module euclidean_video(input wire clk,rst,input wire [39:0] state,
 output wire [9:0] red_symbol,green_symbol,blue_symbol);
 wire [9:0] x,y;wire de,hs,vs;wire [15:0] pixel;
 video_timing timing(clk,rst,x,y,de,hs,vs);
 euclidean_screen display(clk,x,y,state,pixel);
 reg [15:0] q;reg dq,hq,vq,d0,h0,v0;
 always @(posedge clk)if(rst)begin q<=0;dq<=0;hq<=1;vq<=1;d0<=0;h0<=1;v0<=1;end
 else begin q<=pixel;d0<=de;h0<=hs;v0<=vs;dq<=d0;hq<=h0;vq<=v0;end
 tmds_encoder r(clk,rst,dq,{q[15:11],q[15:13]},2'b0,red_symbol);
 tmds_encoder g(clk,rst,dq,{q[10:5],q[10:9]},2'b0,green_symbol);
 tmds_encoder b(clk,rst,dq,{q[4:0],q[4:2]},{vq,hq},blue_symbol);
endmodule
`default_nettype wire
