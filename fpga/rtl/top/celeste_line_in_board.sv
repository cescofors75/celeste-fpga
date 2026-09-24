`default_nettype none
module celeste_line_in_board(
 input wire clk27,clk_audio,reset_button,uart_rx,touch_async,adc_bck,adc_lrck,adc_dout,
 inout wire panel_scl,panel_sda,output wire lcd_scl,lcd_sda,lcd_dc,lcd_res,
 output wire uart_tx,pcm_bck,pcm_din,pcm_lrck,led,
 output wire tmds_clk_p,tmds_clk_n,output wire [2:0] tmds_data_p,tmds_data_n,
 output wire O_sdram_clk,O_sdram_cke,O_sdram_cs_n,O_sdram_ras_n,O_sdram_cas_n,O_sdram_wen_n,
 output wire [10:0] O_sdram_addr,output wire [1:0] O_sdram_ba,output wire [3:0] O_sdram_dqm,inout wire [31:0] IO_sdram_dq
);
 reg [7:0] boot=0;always @(posedge clk27)if(!(&boot))boot<=boot+1'b1;
 wire reset_async=reset_button||!(&boot);
 (* ASYNC_REG="TRUE" *) reg [2:0] ar=7,ur=7;
 always @(posedge clk_audio or posedge reset_async)if(reset_async)ar<=7;else ar<={ar[1:0],1'b0};
 always @(posedge clk27 or posedge reset_async)if(reset_async)ur<=7;else ur<={ur[1:0],1'b0};
 wire rx_valid,rx_space,framing,tx_valid,tx_ready,uart_ready;wire [7:0] rx_data,tx_data;
 // Keep the bridge's return FIFO below its short-burst limit. Ingress remains 3M.
 reg [9:0] return_gap;
 assign tx_ready=uart_ready&&return_gap==0;
 always @(posedge clk27)if(ur[2])return_gap<=0;else if(tx_valid&&tx_ready)return_gap<=800;else if(return_gap!=0)return_gap<=return_gap-1'b1;
 uart_8n1 serial(clk27,ur[2],uart_rx,uart_tx,rx_valid,rx_data,framing,tx_valid&&return_gap==0,tx_data,uart_ready);
 wire ep_rx_valid,ep_rx_ready,ep_tx_valid,ep_tx_ready;wire [7:0] ep_rx_data,ep_tx_data;
 async_fifo #(.AW(11)) ingress(clk27,ur[2],rx_valid,rx_data,rx_space,clk_audio,ar[2],ep_rx_valid,ep_rx_data,ep_rx_ready);
 async_fifo #(.AW(6)) egress(clk_audio,ar[2],ep_tx_valid,ep_tx_data,ep_tx_ready,clk27,ur[2],tx_valid,tx_data,tx_ready);
 wire monitor_valid;wire signed [15:0] monitor_left;
 wire touch_pulse,touch_pressed;
 touch_input #(.STABLE_CYCLES(122880)) touch_button(clk_audio,ar[2],touch_async,touch_pressed,touch_pulse);
 wire panel_online,encoder_event,encoder_press,encoder_long,panel_switch;wire [2:0] encoder_index;wire signed [31:0] encoder_delta;
 wire [239:0] meters;wire [103:0] display_expansion;wire [127:0] display_encoder_values;
 wire [511:0] controls;wire [55:0] mappings;wire [31:0] revision;wire [5:0] routes;wire [2:0] selected;wire running;
 wire [191:0] encoder_leds;
 encoder_palette #(.MAP_BITS(7)) palette(mappings,encoder_leds);
 encoder8_panel #(.GESTURES(1),.HALF_PERIOD(31),.RETRY_CYCLES(1228800),.POLL_CYCLES(0),.TIMEOUT_CYCLES(245760),.CACHE_LEDS(1)) panel(
 clk_audio,ar[2],{24'h001010,encoder_leds},
 panel_scl,panel_sda,panel_online,encoder_event,encoder_press,encoder_index,encoder_delta,panel_switch,encoder_long);
 stream_endpoint #(.DEPTH(16),.DSP(1),.SDRAM(0),.LINE_IN(2),.EXPANDED(1)) endpoint(clk_audio,ar[2],ep_rx_valid,ep_rx_data,ep_rx_ready,ep_tx_valid,ep_tx_data,ep_tx_ready,pcm_bck,pcm_lrck,pcm_din,monitor_valid,monitor_left,
 encoder_event,encoder_index,encoder_delta,panel_online,controls,mappings,routes,revision,selected,running,touch_pulse,meters,panel_switch,O_sdram_clk,O_sdram_cke,O_sdram_cs_n,O_sdram_ras_n,O_sdram_cas_n,O_sdram_wen_n,O_sdram_addr,O_sdram_ba,O_sdram_dqm,IO_sdram_dq,adc_bck,adc_lrck,adc_dout,encoder_press,encoder_long,display_expansion,display_encoder_values);
 reg uart_fault;
 always @(posedge clk27)if(ur[2])uart_fault<=0;else if(framing||(rx_valid&&!rx_space))uart_fault<=1;
 assign led=!uart_fault;

 // Keep HDMI alive using the inherited timing/serializer. Scope receives actual
 // PCM sample data through a separate CDC queue; never a synthetic waveform.
 wire clk_serial,clk_pixel,locked;
 video_clocks clocks(clk27,reset_button,clk_serial,clk_pixel,locked);
 wire video_reset_async=reset_button||!locked;
 (* ASYNC_REG="TRUE" *) reg [2:0] vr=7;
 always @(posedge clk_pixel or posedge video_reset_async)if(video_reset_async)vr<=7;else vr<={vr[1:0],1'b0};
 reg [12:0] display_div;
 always @(posedge clk_audio)if(ar[2])display_div<=0;else display_div<=display_div+1'b1;
 // Unsupported mapping IDs and unused flag bits need not cross the video CDC.
 wire [511:0] display_controls;genvar dc;
 generate for(dc=0;dc<32;dc=dc+1)begin
  assign display_controls[dc*16+:16]=(dc==12||dc==15)?{15'd0,|controls[dc*16+:16]}:controls[dc*16+:16] & ((dc==20||dc==21)?16'd1:dc==22?16'h00ff:dc==23?16'h8000:dc==27?16'd3:dc==28?16'hc000:16'd0);
 end endgenerate
 wire [1050:0] display_state;
 display_snapshot #(.WIDTH(1051)) display_cdc(clk_audio,ar[2],display_div==0,{display_encoder_values,display_expansion,meters,selected,panel_online,running,routes,mappings,display_controls},clk_pixel,vr[2],display_state);
 wire [9:0] red_symbol,green_symbol,blue_symbol;wire ignored_led;
 fabric_video #(.EXPANDED(1),.MAP_BITS(7)) video(clk_pixel,vr[2],display_state[511:0],display_state[567:512],display_state[573:568],display_state[574],display_state[575],display_state[578:576],red_symbol,green_symbol,blue_symbol,display_state[818:579],display_state[922:819],display_state[1050:923]);
 wire [7:0] lcd_x;wire [8:0] lcd_y;wire lcd_frame;wire [15:0] lcd_pixel;
 st7789_panel #(.FRAME_HEIGHT(240),.HALF_PERIOD(1),.PIXEL_PIPELINED(1)) lcd(clk_pixel,vr[2],lcd_pixel,lcd_x,lcd_y,lcd_frame,lcd_scl,lcd_sda,lcd_dc,lcd_res,1'b1);
 fabric_screen #(.SMALL(1),.EXPANDED(1),.MAP_BITS(7)) small_screen({2'b0,lcd_x},{1'b0,lcd_y},display_state[511:0],display_state[567:512],display_state[573:568],display_state[574],display_state[575],display_state[578:576],lcd_pixel,display_state[818:579],4'd0,clk_pixel,display_state[922:819],display_state[1050:923]);
 (* ASYNC_REG="TRUE" *) reg [2:0] serial_reset_pipe=7;
 always @(negedge clk_serial or posedge video_reset_async)if(video_reset_async)serial_reset_pipe<=7;else serial_reset_pipe<={serial_reset_pipe[1:0],1'b0};
 tmds_output output_stage(clk_pixel,clk_serial,serial_reset_pipe[2],red_symbol,green_symbol,blue_symbol,tmds_clk_p,tmds_clk_n,tmds_data_p,tmds_data_n);
endmodule
`default_nettype wire
