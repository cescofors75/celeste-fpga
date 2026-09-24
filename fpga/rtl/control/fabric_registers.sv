`default_nettype none
module fabric_registers #(parameter MAP_BITS=5)(input wire clk,rst,host_write,input wire [15:0] host_id,host_value,
 input wire encoder_event,input wire [2:0] encoder_index,input wire signed [31:0] encoder_delta,
 output wire [511:0] values,output wire [8*MAP_BITS-1:0] mappings,output reg [5:0] routes,
 output reg [31:0] revision,output reg [2:0] selected,input wire bypass_toggle,input wire bank_switch,panel_online,input wire encoder_press);
 reg [15:0] p[0:31];reg [MAP_BITS-1:0] map[0:15];integer i;reg signed [33:0] changed;
 genvar g;generate for(g=0;g<32;g=g+1)begin assign values[g*16+:16]=p[g];end
 for(g=0;g<8;g=g+1)begin assign mappings[g*MAP_BITS+:MAP_BITS]=(p[21][0]?map[g+8]:map[g]);end endgenerate
 always @(posedge clk)begin
  if(rst)begin
   for(i=0;i<32;i=i+1)p[i]<=0;
   p[0]<=32768;p[1]<=16384;p[2]<=32768;p[3]<=24576;p[4]<=45000;p[5]<=12000;
   p[6]<=65535;p[7]<=32768;p[8]<=24576;p[9]<=32768;p[10]<=65535;p[11]<=16000;p[18]<=1;p[19]<=1;
   map[0]<=0;map[1]<=1;map[2]<=4;map[3]<=5;map[4]<=2;map[5]<=3;map[6]<=11;map[7]<=10;
   map[8]<=13;map[9]<=16;map[10]<=14;map[11]<=17;map[12]<=11;map[13]<=12;map[14]<=15;map[15]<=10;
   if(MAP_BITS==7)begin
    map[0]<=0;map[1]<=2;map[2]<=24;map[3]<=4;map[4]<=13;map[5]<=14;map[6]<=12;map[7]<=15;
    map[8]<=67;map[9]<=70;map[10]<=72;map[11]<=75;map[12]<=79;map[13]<=82;map[14]<=84;map[15]<=10;
   end
   p[23]<=65535;p[29]<=65535;p[30]<=13107;p[31]<=9830;
   routes<=1;revision<=0;selected<=0;
  end else if(host_write)begin
   if(host_id<32&&host_id!=21)p[host_id[4:0]]<=host_value;
   else if(host_id==32)routes<=host_value[5:0];
   else if(host_id>=40&&host_id<=55)map[host_id-40]<=host_value[MAP_BITS-1:0];
   revision<=revision+1'b1;
  end else if(encoder_event&&map[{p[21][0],encoder_index}]<32)begin
   changed=$signed({1'b0,p[map[{p[21][0],encoder_index}]]})+($signed(encoder_delta)<<<9);
   p[map[{p[21][0],encoder_index}]]<=changed<0?16'd0:changed>65535?16'hffff:changed[15:0];
   selected<=encoder_index;revision<=revision+1'b1;
  end
  if(!rst&&encoder_event)begin selected<=encoder_index;revision<=revision+1'b1;end
  // A button resets the parameter assigned to this encoder in the active bank.
  // Press wins over a simultaneous rotation or host edit of that parameter.
  if(!rst&&encoder_press&&map[{p[21][0],encoder_index}]<32)begin
   p[map[{p[21][0],encoder_index}]]<=0;
   selected<=encoder_index;revision<=revision+1'b1;
  end
  // Keep last bank if the panel disconnects. Register 21 is read-only.
  if(!rst&&panel_online&&bank_switch!=p[21][0])begin p[21]<=bank_switch?16'hffff:16'd0;revision<=revision+1'b1;end
  // Touch and unrelated host writes can coexist. An explicit host bypass write wins.
  if(!rst&&bypass_toggle&&!(host_write&&host_id==20))begin p[20]<=p[20]==0?16'hffff:16'd0;revision<=revision+1'b1;end
 end
endmodule
`default_nettype wire
