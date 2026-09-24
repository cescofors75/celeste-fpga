`default_nettype none
// Read-only paced diagnostic stream: RHL1 + 48-byte coherent snapshot.
module rhythm_debug(input wire clk,rst,input wire [383:0] snapshot,output wire tx);
 reg [383:0] held;reg [5:0] index;reg active;reg [20:0] timer;reg [9:0] gap;
 wire ready;wire valid=active&&gap==0;reg [7:0] data;
 always @*begin
  case(index)0:data=82;1:data=72;2:data=76;3:data=49;default:data=held[7:0];endcase
 end
 uart_8n1 uart(.clk(clk),.rst(rst),.rx(1'b1),.tx(tx),.tx_valid(valid),.tx_data(data),.tx_ready(ready));
 always @(posedge clk)begin
  if(rst)begin held<=0;index<=0;active<=0;timer<=0;gap<=0;end
  else begin
   if(timer==1350000)begin timer<=0;if(!active)begin held<=snapshot;index<=0;active<=1;end end
   else timer<=timer+1'b1;
   if(gap!=0)gap<=gap-1'b1;
   if(valid&&ready)begin gap<=800;if(index>=4)held<=held>>8;if(index==51)active<=0;else index<=index+1'b1;end
  end
 end
endmodule
`default_nettype wire
