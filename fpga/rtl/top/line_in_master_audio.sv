`default_nettype none
// Tang master: 12.288 MHz MCLK, 3.072 MHz BCK and 48 kHz LRCK.
// One clock domain for serial I/O and DSP. Incoming PCM is reduced to Q1.15.
// running means receiver enabled, NOT proof that the ADC is physically present.
module line_in_master_audio #(parameter DSP=1)(input wire clk,rst,start,stop,
 input wire adc_dout,input wire [511:0] parameters,input wire [5:0] routes,
 output wire pcm_bck,pcm_lrck,pcm_din,output wire running,
 output wire source_valid,output wire signed [15:0] source_left,source_right,
 output reg [31:0] samples,output wire [31:0] faults,output wire [239:0] meters);
 reg armed;wire rx_valid,frame_ce;wire [47:0] received;
 wire signed [15:0] processed_l,processed_r;
 // Holding a complete result decouples the DSP pipeline from frame capture.
 reg [5:0] pending;reg [47:0] output_frame;
 assign running=armed&&!rst;assign faults=0;
 assign source_left=received[23:8];assign source_right=received[47:32];
 assign source_valid=rx_valid&&running;
 i2s_rx_master rx(clk,rst,pcm_bck,pcm_lrck,adc_dout,rx_valid,received);
 i2s_tx tx(clk,rst,running?output_frame[23:0]:24'd0,running?output_frame[47:24]:24'd0,frame_ce,pcm_bck,pcm_lrck,pcm_din);
 generate if(DSP)begin
 parallel_fabric fabric(clk,rst||!running,source_valid,source_left,source_right,parameters,routes,processed_l,processed_r,meters);
 end else begin assign processed_l=source_left;assign processed_r=source_right;assign meters=0;end endgenerate
 always @(posedge clk)begin
  if(rst)begin armed<=1;samples<=0;pending<=0;output_frame<=0;end
  else begin
   if(start)armed<=1;
   if(pending!=0)pending<=pending-1'b1;
   if(source_valid)begin samples<=samples+1'b1;pending<=32;end
   if(pending==1&&running)output_frame<={processed_r,8'd0,processed_l,8'd0};
   if(stop)begin armed<=0;pending<=0;output_frame<=0;end
  end
 end
endmodule
`default_nettype wire
