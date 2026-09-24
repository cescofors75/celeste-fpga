`default_nettype none
module fabric_video #(parameter EXPANDED=0,MAP_BITS=5)(input wire clk,rst,input wire [511:0] values,input wire [8*MAP_BITS-1:0] mappings,
 input wire [5:0] routes,input wire running,online,input wire [2:0] selected,
 output wire [9:0] red_symbol,green_symbol,blue_symbol,input wire [239:0] meters,input wire [103:0] expansion,input wire [127:0] mapped_values);
 wire [9:0] x,y;wire de,hs,vs;wire [15:0] pixel;
 video_timing timing(clk,rst,x,y,de,hs,vs);
 reg [3:0] flow_phase;
 always @(posedge clk)if(rst)flow_phase<=0;else if(x==0&&y==0)flow_phase<=flow_phase-1'b1;
 fabric_screen #(.EXPANDED(EXPANDED),.MAP_BITS(MAP_BITS)) display(x,y,values,mappings,routes,running,online,selected,pixel,meters,flow_phase,clk,expansion,mapped_values);
 reg [15:0] q;reg dq,hq,vq,d0,h0,v0;
 always @(posedge clk)if(rst)begin q<=0;dq<=0;hq<=1;vq<=1;d0<=0;h0<=1;v0<=1;end else begin q<=pixel;d0<=de;h0<=hs;v0<=vs;dq<=d0;hq<=h0;vq<=v0;end
 tmds_encoder r(clk,rst,dq,{q[15:11],q[15:13]},2'b0,red_symbol);
 tmds_encoder g(clk,rst,dq,{q[10:5],q[10:9]},2'b0,green_symbol);
 tmds_encoder b(clk,rst,dq,{q[4:0],q[4:2]},{vq,hq},blue_symbol);
endmodule
`default_nettype wire
