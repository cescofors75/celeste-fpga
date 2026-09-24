`default_nettype none
module celeste_euclidean_board(
 input wire clk27,clk_audio,reset_button,uart_rx,touch_async,adc_bck,adc_lrck,adc_dout,
 inout wire panel_scl,panel_sda,output wire lcd_scl,lcd_sda,lcd_dc,lcd_res,
 output wire uart_tx,pcm_bck,pcm_din,pcm_lrck,led,
 output wire tmds_clk_p,tmds_clk_n,output wire [2:0] tmds_data_p,tmds_data_n,
 output wire O_sdram_clk,O_sdram_cke,O_sdram_cs_n,O_sdram_ras_n,O_sdram_cas_n,O_sdram_wen_n,
 output wire [10:0] O_sdram_addr,output wire [1:0] O_sdram_ba,output wire [3:0] O_sdram_dqm,inout wire [31:0] IO_sdram_dq
);
 reg [7:0] boot=0;always @(posedge clk27)if(!(&boot))boot<=boot+1'b1;
 wire reset_async=reset_button||!(&boot);
 (* ASYNC_REG="TRUE" *)reg [2:0] ar=7;
 always @(posedge clk_audio or posedge reset_async)if(reset_async)ar<=7;else ar<={ar[1:0],1'b0};
 wire touch_pulse,touch_pressed;
 touch_input #(.STABLE_CYCLES(122880)) touch_button(clk_audio,ar[2],touch_async,touch_pressed,touch_pulse);
 wire panel_online,encoder_event,encoder_press,encoder_long,panel_switch;
 wire [2:0] encoder_index;wire signed [31:0] encoder_delta;
 wire [4:0] pulses;wire [3:0] rotation,step;wire dry;
 wire [15:0] pattern;wire [7:0] envelope;
 euclidean_controls controls(clk_audio,ar[2],encoder_event,encoder_index,encoder_delta,touch_pulse,pulses,rotation,dry);
 // Only controls 1 and 2 are lit. Bank switch and all encoder buttons are ignored.
 wire [215:0] panel_colors={dry?24'h1f1000:24'h001f00,144'd0,24'h1f1800,24'h001f1f};
 encoder8_panel #(.GESTURES(1),.HALF_PERIOD(31),.RETRY_CYCLES(1228800),.POLL_CYCLES(0),.TIMEOUT_CYCLES(245760),.CACHE_LEDS(1)) panel(
 clk_audio,ar[2],panel_colors,panel_scl,panel_sda,panel_online,encoder_event,encoder_press,encoder_index,encoder_delta,panel_switch,encoder_long);
 wire running,source_valid;wire signed [15:0] source_l,source_r,gated_l,gated_r;
 wire [31:0] samples,faults;wire [255:0] diagnostics;
 line_in_audio #(.DSP(0),.EXTERNAL_PROCESSOR(1)) audio(
 .clk(clk_audio),.rst(ar[2]),.start(1'b0),.stop(1'b0),.adc_bck(adc_bck),.adc_lrck(adc_lrck),.adc_dout(adc_dout),
 .parameters(512'd0),.routes(6'd0),.pcm_bck(pcm_bck),.pcm_lrck(pcm_lrck),.pcm_din(pcm_din),.running(running),
 .source_valid(source_valid),.source_left(source_l),.source_right(source_r),.samples(samples),.faults(faults),
 .clock_diagnostics(diagnostics),.expansion_controls(512'd0),.external_left(gated_l),.external_right(gated_r));
 euclidean_gate gate(clk_audio,ar[2]||!running,source_valid,source_l,source_r,pulses,rotation,dry,gated_l,gated_r,pattern,step,envelope);
 assign led=!running;
 assign uart_tx=1'b1;
 assign {O_sdram_clk,O_sdram_cke,O_sdram_ras_n,O_sdram_cas_n,O_sdram_wen_n,O_sdram_addr,O_sdram_ba,O_sdram_dqm}=0;
 assign O_sdram_cs_n=1'b1;assign IO_sdram_dq=32'bz;
 wire clk_serial,clk_pixel,locked;
 video_clocks clocks(clk27,reset_button,clk_serial,clk_pixel,locked);
 wire video_reset_async=reset_button||!locked;
 (* ASYNC_REG="TRUE" *)reg [2:0] vr=7;
 always @(posedge clk_pixel or posedge video_reset_async)if(video_reset_async)vr<=7;else vr<={vr[1:0],1'b0};
 reg [12:0] display_div;
 always @(posedge clk_audio)if(ar[2])display_div<=0;else display_div<=display_div+1'b1;
 wire [39:0] display_state;
 display_snapshot #(.WIDTH(40)) display_cdc(clk_audio,ar[2],display_div==0,{running,panel_online,dry,pulses,rotation,step,pattern,envelope},clk_pixel,vr[2],display_state);
 wire [9:0] red_symbol,green_symbol,blue_symbol;
 euclidean_video video(clk_pixel,vr[2],display_state,red_symbol,green_symbol,blue_symbol);
 wire [7:0] lcd_x;wire [8:0] lcd_y;wire lcd_frame;wire [15:0] lcd_pixel;
 st7789_panel #(.FRAME_HEIGHT(240),.HALF_PERIOD(1),.PIXEL_PIPELINED(1)) lcd(clk_pixel,vr[2],lcd_pixel,lcd_x,lcd_y,lcd_frame,lcd_scl,lcd_sda,lcd_dc,lcd_res,1'b1);
 euclidean_screen #(.SMALL(1)) small_screen(clk_pixel,{2'b0,lcd_x},{1'b0,lcd_y},display_state,lcd_pixel);
 (* ASYNC_REG="TRUE" *)reg [2:0] serial_reset_pipe=7;
 always @(negedge clk_serial or posedge video_reset_async)if(video_reset_async)serial_reset_pipe<=7;else serial_reset_pipe<={serial_reset_pipe[1:0],1'b0};
 tmds_output output_stage(clk_pixel,clk_serial,serial_reset_pipe[2],red_symbol,green_symbol,blue_symbol,tmds_clk_p,tmds_clk_n,tmds_data_p,tmds_data_n);
endmodule
`default_nettype wire
