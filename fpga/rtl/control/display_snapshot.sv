`default_nettype none
// Bundled-data CDC: source holds the entire bus until destination acknowledges.
// Request takes three destination clocks before capture; no per-bit live sampling.
module display_snapshot #(parameter WIDTH=803)(input wire src_clk,src_rst,publish,input wire [WIDTH-1:0] data,
 input wire dst_clk,dst_rst,output reg [WIDTH-1:0] snapshot);
 reg [WIDTH-1:0] held;reg request,acknowledge;
 (* ASYNC_REG="TRUE" *)reg [1:0] ack_sync;
 (* ASYNC_REG="TRUE" *)reg [2:0] request_sync;
 always @(posedge src_clk)begin
  if(src_rst)begin held<=0;request<=0;ack_sync<=0;end
  else begin ack_sync<={ack_sync[0],acknowledge};if(publish&&ack_sync[1]==request)begin held<=data;request<=!request;end end
 end
 always @(posedge dst_clk)begin
  if(dst_rst)begin request_sync<=0;acknowledge<=0;snapshot<=0;end
  else begin request_sync<={request_sync[1:0],request};
   if(request_sync[2]!=acknowledge)begin snapshot<=held;acknowledge<=request_sync[2];end
  end
 end
endmodule
`default_nettype wire
