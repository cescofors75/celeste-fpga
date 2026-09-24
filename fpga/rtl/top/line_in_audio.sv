`default_nettype none
// clk=12.288MHz; PCM1808 master at 48kHz. DAC follows the SAME ADC BCK:
// no resampling, independent clock drift, or periodic sample drops.
module line_in_audio #(parameter DSP=1, CHAOS_BUFFER=0, CELLULAR=0, FEEDBACK=0, EXPANSION=0, EXTERNAL_PROCESSOR=0)(input wire clk,rst,start,stop,
 input wire adc_bck,adc_lrck,adc_dout,
 input wire [511:0] parameters,input wire [5:0] routes,
 output wire pcm_bck,pcm_lrck,pcm_din,output wire running,
 output wire source_valid,output wire signed [15:0] source_left,source_right,
 output reg [31:0] samples,faults,output wire [239:0] meters,output wire [255:0] clock_diagnostics,input wire [511:0] expansion_controls,output wire [63:0] expansion_levels,input wire signed [15:0] external_left,external_right);
 (* ASYNC_REG="TRUE" *) reg [2:0] br=7;
 always @(posedge adc_bck or posedge rst)if(rst)br<=7;else br<={br[1:0],1'b0};
 wire adc_rst=br[2];wire rx_valid,rx_ready,received_valid,tx_ready,tx_valid;
 wire [47:0] rx_frame,received_frame,tx_frame;
 reg armed,locked;reg [3:0] good;reg [11:0] age;reg [6:0] processing;
 (* ASYNC_REG="TRUE" *) reg [1:0] enable_sync;
 wire output_mute=rst||!running;
 always @(posedge adc_bck or posedge output_mute)if(output_mute)enable_sync<=0;else enable_sync<={enable_sync[0],1'b1};
 assign pcm_bck=adc_bck;
 i2s_slave serial(adc_bck,adc_rst,adc_lrck,adc_dout,rx_valid,rx_frame,tx_frame,enable_sync[1],pcm_lrck,pcm_din);
 audio_mailbox ingress(adc_bck,adc_rst,rx_valid,rx_frame,rx_ready,clk,rst,received_valid,received_frame);
 wire signed [15:0] processed_l,processed_r;
 assign source_left=received_frame[23:8];assign source_right=received_frame[47:32];
 reg saw_frame;reg [31:0] interval_min,interval_max,last_bad,bad_intervals,timeouts,tx_drops;
 wire [31:0] cb_late,cb_guard;
 assign clock_diagnostics={cb_guard,cb_late,tx_drops,timeouts,bad_intervals,last_bad,interval_max,interval_min};
 always @(posedge clk)begin
  if(rst)begin saw_frame<=0;interval_min<=32'hffffffff;interval_max<=0;last_bad<=0;bad_intervals<=0;timeouts<=0;tx_drops<=0;end
  else begin
   if(received_valid)begin
    saw_frame<=1;
    if(saw_frame)begin
     if(age<interval_min)interval_min<=age;if(age>interval_max)interval_max<=age;
     if(!rate_ok)begin last_bad<=age;bad_intervals<=bad_intervals+1'b1;end
    end
   end
   if(saw_frame&&age==2048)timeouts<=timeouts+1'b1;
   if(processing==1&&running&&!tx_ready)tx_drops<=tx_drops+1'b1;
  end
 end
 wire rate_ok=age>=252&&age<=260;
 assign running=armed&&locked;
 assign source_valid=received_valid&&running&&rate_ok;
 // Optional laboratory insert. Default zero leaves all production paths intact.
 generate if(EXTERNAL_PROCESSOR)begin
 assign expansion_levels=0;assign cb_late=0;assign cb_guard=0;assign meters=0;
 assign processed_l=external_left;assign processed_r=external_right;
 end else if(FEEDBACK)begin
 assign expansion_levels=0;wire feedback_done;
 feedback_matrix4 fdn(clk,rst||!running,source_valid,source_left,source_right,parameters[0+:16],parameters[1*16+:16],parameters[2*16+:16],parameters[10*16+:16],parameters[20*16+15],processed_l,processed_r,feedback_done,cb_late,cb_guard);
 assign meters=0;
 end else if(CELLULAR)begin
 assign expansion_levels=0;wire cell_done;
 cellular_buffer4 cb(clk,rst||!running,source_valid,source_left,source_right,parameters[0+:16],parameters[2*16+:16],parameters[10*16+:16],parameters[1*16+:16],parameters[28*16+14+:2],parameters[23*16+15],parameters[20*16+15],processed_l,processed_r,cell_done,cb_late,cb_guard);
 assign meters=0;
 end else if(CHAOS_BUFFER)begin
 assign expansion_levels=0;wire cb_done;
 chaos_buffer4 cb(clk,rst||!running,source_valid,source_left,source_right,parameters[0+:16],parameters[2*16+:16],parameters[10*16+:16],parameters[23*16+15],parameters[20*16+15],processed_l,processed_r,cb_done,cb_late,cb_guard);
 assign meters=0; // No fabricated legacy-engine meters in this laboratory build.
 end else if(DSP)begin
 assign cb_guard=0;
 wire signed [15:0] base_l,base_r;wire [15:0] env_mod;
 wire [16:0] mod_cut={1'b0,parameters[4*16+:16]}+{1'b0,env_mod};
wire [15:0] muted=expansion_controls[24*16+:16],soloed=expansion_controls[25*16+:16];
 wire [12:0] audible=(~muted[12:0]) & ((|soloed[12:0])?soloed[12:0]:13'h1fff);
 wire delay_chain_audible=!muted[5]&&(!(|soloed[12:0])||soloed[5]||(parameters[27*16+1]&&soloed[1]))&&!(parameters[27*16+1]&&muted[1]);
 reg [511:0] mod_parameters;
 always @*begin
 mod_parameters=parameters;mod_parameters[4*16+:16]=mod_cut[16]?16'hffff:mod_cut[15:0];
 if(audible==0)mod_parameters[10*16+:16]=0;
 if(!audible[12])mod_parameters[6*16+:16]=0;
 // Preserve delay state and fade its mixer gain instead of stopping the engine.
 if(!delay_chain_audible)mod_parameters[26*16+:16]=0;
 end
 wire [5:0] audible_routes=routes & {audible[4:0],audible[12]};
 parallel_fabric fabric(clk,rst||!running,source_valid,source_left,source_right,EXPANSION?mod_parameters:parameters,EXPANSION?audible_routes:routes,base_l,base_r,meters);
 if(EXPANSION)begin
 wire expansion_done;wire [31:0] expansion_faults;
 expansion_fabric expansion(clk,rst||!running,source_valid,processing==64,source_left,source_right,base_l,base_r,expansion_controls,parameters[10*16+:16],parameters[20*16+:16],processed_l,processed_r,env_mod,expansion_done,expansion_faults,expansion_levels);
 assign cb_late=expansion_faults;
 end else begin assign expansion_levels=0;assign cb_late=0;assign processed_l=base_l;assign processed_r=base_r;assign env_mod=0;end
 end else begin assign expansion_levels=0;assign cb_late=0;assign cb_guard=0;assign processed_l=source_left;assign processed_r=source_right;assign meters=0;end endgenerate
 audio_mailbox egress(clk,rst,processing==1&&running,{processed_r,8'd0,processed_l,8'd0},tx_ready,adc_bck,adc_rst,tx_valid,tx_frame);
 always @(posedge clk)begin
  if(rst)begin armed<=1;locked<=0;good<=0;age<=4095;processing<=0;samples<=0;faults<=0;end
  else begin
   if(start)armed<=1;if(stop)armed<=0;
   if(age!=4095)age<=age+1'b1;
   if(processing!=0)processing<=processing-1'b1;
   if(received_valid)begin
    age<=0;
    if(rate_ok)begin if(good<8)good<=good+1'b1;if(good>=7)locked<=1;end
    else begin good<=0;locked<=0;if(locked)faults<=faults+1'b1;end
    if(source_valid)begin samples<=samples+1'b1;processing<=EXPANSION?96:32;end
   end
   if(age==2048)begin if(locked)faults<=faults+1'b1;locked<=0;good<=0;end
   if(stop)processing<=0;
  end
 end
endmodule
`default_nettype wire
