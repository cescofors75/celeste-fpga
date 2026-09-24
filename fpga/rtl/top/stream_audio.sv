`default_nettype none
// Portable clean-stream audio core. clk_audio MUST be 12.288 MHz.
// Transport adapter writes one complete signed PCM16 stereo frame per handshake.
// Future DSP consumes source_valid/source_left/source_right, independent of origin.
module stream_audio #(parameter DEPTH=4096, AW=$clog2(DEPTH), DSP=0, SDRAM=0)(
 input wire clk_audio,rst,input wire start,stop,drain,
 input wire frame_valid,input wire [31:0] frame_data,output wire frame_ready,
 output wire pcm_bck,pcm_lrck,pcm_din,output reg running,
 output wire [AW:0] fifo_fill,output reg [31:0] sample_counter,
 output reg [31:0] underruns,output wire [31:0] overruns,
 output wire source_valid,output wire signed [15:0] source_left,source_right,
 input wire [511:0] parameters,input wire [5:0] routes,output wire [239:0] meters,
 output wire ram_clk,ram_cke,ram_cs_n,ram_ras_n,ram_cas_n,ram_we_n,output wire [10:0] ram_addr,output wire [1:0] ram_ba,output wire [3:0] ram_dqm,inout wire [31:0] ram_dq
);
 wire [AW:0] stored;wire [31:0] data;wire read_valid;wire frame_ce;
 reg holding,pending,draining;reg [31:0] held;
 wire pop=!holding&&!pending&&(stored!=0);
 wire [31:0] ignored_under;
 generate if(SDRAM)begin
 sdram_fifo #(.DEPTH(DEPTH)) fifo(clk_audio,rst,stop,frame_valid,frame_data,frame_ready,pop,data,read_valid,stored,overruns,ignored_under,ram_clk,ram_cke,ram_cs_n,ram_ras_n,ram_cas_n,ram_we_n,ram_addr,ram_ba,ram_dqm,ram_dq);
 end else begin
 sample_fifo #(.DEPTH(DEPTH)) fifo(clk_audio,rst,stop,frame_valid,frame_data,frame_ready,pop,data,read_valid,stored,overruns,ignored_under);
 assign {ram_clk,ram_cke,ram_cs_n,ram_ras_n,ram_cas_n,ram_we_n,ram_addr,ram_ba,ram_dqm}=0;
 end endgenerate
 assign fifo_fill=stored+holding+pending;
 assign source_valid=frame_ce&&running&&holding;
 assign source_left=held[15:0];assign source_right=held[31:16];
 wire signed [23:0] left_pcm=(running&&holding)?{held[15:0],8'b0}:24'b0;
 wire signed [23:0] right_pcm=(running&&holding)?{held[31:16],8'b0}:24'b0;
 wire signed [15:0] processed_l,processed_r;
 generate if(DSP)begin
 parallel_fabric fabric(clk_audio,rst||stop,frame_ce,left_pcm[23:8],right_pcm[23:8],parameters,routes,processed_l,processed_r,meters);
 i2s_tx tx(clk_audio,rst,{processed_l,8'b0},{processed_r,8'b0},frame_ce,pcm_bck,pcm_lrck,pcm_din);
 end else begin
 assign meters=0;
 i2s_tx tx(clk_audio,rst,left_pcm,right_pcm,frame_ce,pcm_bck,pcm_lrck,pcm_din);
 end endgenerate
 always @(posedge clk_audio)begin
  if(rst)begin holding<=0;pending<=0;draining<=0;held<=0;running<=0;sample_counter<=0;underruns<=0;end
  else if(stop)begin holding<=0;pending<=0;draining<=0;held<=0;running<=0;end
  else begin
   if(start)running<=1;
   if(drain)draining<=1;
   if(pop)pending<=1;
   if(read_valid)begin held<=data;holding<=1;pending<=0;end
   if(frame_ce&&running)begin
    if(holding)begin holding<=0;sample_counter<=sample_counter+1;end
    else if(draining&&stored==0&&!pending)begin running<=0;draining<=0;end
    else underruns<=underruns+1;
   end
  end
 end
endmodule
`default_nettype wire
