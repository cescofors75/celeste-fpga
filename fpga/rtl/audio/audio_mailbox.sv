`default_nettype none
// One stereo frame, held until acknowledged. No independent per-bit CDC.
module audio_mailbox #(parameter WIDTH=48)(
 input wire src_clk,src_rst,send,input wire [WIDTH-1:0] data,output wire ready,
 input wire dst_clk,dst_rst,output reg valid,output reg [WIDTH-1:0] received
);
 reg [WIDTH-1:0] held;reg request,ack;
 (* ASYNC_REG="TRUE" *) reg [1:0] ack_sync;
 (* ASYNC_REG="TRUE" *) reg [2:0] req_sync;
 assign ready=ack_sync[1]==request;
 always @(posedge src_clk or posedge src_rst)begin
  if(src_rst)begin held<=0;request<=0;ack_sync<=0;end
  else begin ack_sync<={ack_sync[0],ack};if(send&&ready)begin held<=data;request<=~request;end end
 end
 always @(posedge dst_clk or posedge dst_rst)begin
  if(dst_rst)begin req_sync<=0;ack<=0;valid<=0;received<=0;end
  else begin req_sync<={req_sync[1:0],request};valid<=0;
   if(req_sync[2]!=ack)begin received<=held;valid<=1;ack<=req_sync[2];end
  end
 end
endmodule
`default_nettype wire
