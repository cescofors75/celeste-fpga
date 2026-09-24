`default_nettype none
// Byte-level proof of concept: validated packets -> PCM FIFO -> I2S + responses.
// Byte transport must honor rx_ready and tx_ready. No board UART/pins assumed.
module stream_endpoint #(parameter DEPTH=4096, AW=$clog2(DEPTH), DSP=0, SDRAM=0, LINE_IN=0, EXPANDED=0)(
 input wire clk_audio,rst,input wire rx_valid,input wire [7:0] rx_data,output wire rx_ready,
 output wire tx_valid,output reg [7:0] tx_data,input wire tx_ready,
 output wire pcm_bck,pcm_lrck,pcm_din,
 output wire monitor_valid,output wire signed [15:0] monitor_left,
 input wire encoder_event,input wire [2:0] encoder_index,input wire signed [31:0] encoder_delta,
 input wire panel_online,output wire [511:0] control_values,output wire [(EXPANDED?56:40)-1:0] control_mappings,
 output wire [5:0] control_routes,output wire [31:0] control_revision,output wire [2:0] control_selected,
 output wire stream_running,input wire bypass_toggle,output wire [239:0] meters,input wire bank_switch,
 output wire ram_clk,ram_cke,ram_cs_n,ram_ras_n,ram_cas_n,ram_we_n,output wire [10:0] ram_addr,output wire [1:0] ram_ba,output wire [3:0] ram_dqm,inout wire [31:0] ram_dq,
 input wire adc_bck,adc_lrck,adc_dout,encoder_press,encoder_long,output wire [103:0] display_expansion,output reg [127:0] display_encoder_values
);
 wire packet_valid;reg packet_done;wire [7:0] kind,payload_data;
 wire [31:0] seq,protocol_errors;wire [10:0] length;reg [9:0] address;
 protocol_rx receiver(clk_audio,rst,rx_valid,rx_data,rx_ready,packet_valid,packet_done,kind,seq,length,address,payload_data,protocol_errors);
 reg start,stop,drain,frame_valid;reg [31:0] frame_data;
 assign display_expansion={expansion_p[25][12:0],expansion_p[24][12:0],expansion_p[1][6:0],expansion_p[0][6:0],expansion_levels};
 wire [255:0] clock_diagnostics;wire [63:0] expansion_levels;
 wire frame_ready,running,source_valid;wire [AW:0] fill;
 wire [31:0] samples,under,over;wire signed [15:0] source_l,source_r;
 assign monitor_valid=source_valid;
 assign monitor_left=source_l;
 // Physical bring-up diagnostics: measure the actual FIFO samples and I2S pins.
 // These counters persist across STOP and never imply that the analog DAC works.
 reg [31:0] nonzero_samples,sum_l,sum_r,din_ones,bck_edges,lrck_edges;
 reg [15:0] peak_l,peak_r;
 reg previous_bck,previous_lrck;
 (* ASYNC_REG="TRUE" *) reg [1:0] diagnostic_bck,diagnostic_lrck,diagnostic_din;
 always @(posedge clk_audio)begin
  if(rst)begin diagnostic_bck<=0;diagnostic_lrck<=0;diagnostic_din<=0;end
  else begin diagnostic_bck<={diagnostic_bck[0],pcm_bck};diagnostic_lrck<={diagnostic_lrck[0],pcm_lrck};diagnostic_din<={diagnostic_din[0],pcm_din};end
 end
 wire measured_bck=LINE_IN?diagnostic_bck[1]:pcm_bck;
 wire measured_lrck=LINE_IN?diagnostic_lrck[1]:pcm_lrck;
 wire measured_din=LINE_IN?diagnostic_din[1]:pcm_din;
 wire [15:0] magnitude_l=source_l[15]?(~source_l+16'd1):source_l;
 wire [15:0] magnitude_r=source_r[15]?(~source_r+16'd1):source_r;
 always @(posedge clk_audio)begin
  if(rst)begin
   nonzero_samples<=0;sum_l<=0;sum_r<=0;din_ones<=0;bck_edges<=0;lrck_edges<=0;
   peak_l<=0;peak_r<=0;previous_bck<=0;previous_lrck<=0;
  end else begin
   previous_bck<=measured_bck;previous_lrck<=measured_lrck;
   if(measured_bck&&!previous_bck)begin bck_edges<=bck_edges+1'b1;if(measured_din)din_ones<=din_ones+1'b1;end
   if(measured_lrck&&!previous_lrck)lrck_edges<=lrck_edges+1'b1;
   if(source_valid)begin
    if(source_l!=0||source_r!=0)nonzero_samples<=nonzero_samples+1'b1;
    sum_l<=sum_l+{16'b0,source_l};sum_r<=sum_r+{16'b0,source_r};
    if(magnitude_l>peak_l)peak_l<=magnitude_l;
    if(magnitude_r>peak_r)peak_r<=magnitude_r;
   end
  end
 end
 assign stream_running=running;
 reg host_write;reg [15:0] host_id,host_value;
 localparam MAP_BITS=EXPANDED?7:5;
 fabric_registers #(.MAP_BITS(MAP_BITS)) registers(clk_audio,rst,host_write,host_id,host_value,encoder_event,encoder_index,encoder_delta,control_values,control_mappings,control_routes,control_revision,control_selected,bypass_toggle,bank_switch,panel_online,encoder_press&&!EXPANDED);
 reg [15:0] expansion_p[0:31];wire [511:0] expansion_values;integer ei;
 genvar eg;generate for(eg=0;eg<32;eg=eg+1)begin assign expansion_values[eg*16+:16]=expansion_p[eg];end endgenerate
 function automatic [3:0] component(input [6:0] id);
 begin case(id)
 0,1,7,23,29,30:component=0;2,3,8:component=1;4,5,9,28:component=2;
 13,16:component=3;14,17:component=4;24,25,26:component=5;6:component=12;10:component=14;
 66,67,68:component=6;69,70,71:component=7;72,73,74:component=8;75,77:component=9;78,79,80:component=10;81,82,83:component=11;
 default:component=15;endcase end endfunction
 wire [6:0] encoder_parameter=control_mappings[encoder_index*MAP_BITS+:MAP_BITS];
 reg signed [33:0] expanded_changed;
 reg [2:0] display_scan;
 wire [6:0] display_id=control_mappings[display_scan*MAP_BITS+:MAP_BITS];
 always @(posedge clk_audio)begin
  if(rst)begin display_scan<=0;display_encoder_values<=0;end
  else begin
   display_scan<=display_scan+1'b1;
   display_encoder_values[display_scan*16+:16]<=display_id<32?control_values[display_id*16+:16]:expansion_values[(display_id-64)*16+:16];
  end
 end
 wire [3:0] pressed_component=component(control_mappings[encoder_index*MAP_BITS+:MAP_BITS]);
 always @(posedge clk_audio)begin
 if(rst)for(ei=0;ei<32;ei=ei+1)expansion_p[ei]<=0;
 else if(EXPANDED&&host_write&&host_id>=64&&host_id<90&&host_id!=76&&host_id!=86&&host_id!=87)begin
 if(host_id==64||host_id==65)expansion_p[host_id-64]<={9'd0,host_value[6:0]};
 else if(host_id==88||host_id==89)expansion_p[host_id-64]<={3'd0,host_value[12:0]};
 else expansion_p[host_id-64]<=host_value;end
 else if(EXPANDED&&encoder_event&&encoder_parameter>=66&&encoder_parameter<=85&&encoder_parameter!=76)begin
 expanded_changed=$signed({1'b0,expansion_p[encoder_parameter-64]})+($signed(encoder_delta)<<<9);
 if(encoder_parameter==75&&encoder_delta!=0)expansion_p[11]<=encoder_delta>0?16'hffff:16'd0;
 else expansion_p[encoder_parameter-64]<=expanded_changed<0?16'd0:expanded_changed>65535?16'hffff:expanded_changed[15:0];
 end
 else if(EXPANDED&&pressed_component<15)begin
 if(encoder_press&&pressed_component==14)expansion_p[24]<=expansion_p[24]==16'h1fff ? 16'd0 : 16'h1fff;
 else if(encoder_press)expansion_p[24]<=expansion_p[24]^(16'd1<<pressed_component);
 if(encoder_long&&pressed_component==14)expansion_p[25]<=0;
 else if(encoder_long)begin expansion_p[24]<=expansion_p[24]&~(16'd1<<pressed_component);expansion_p[25]<=expansion_p[25]==(16'd1<<pressed_component)?16'd0:(16'd1<<pressed_component);end
 end
 end
 generate if(LINE_IN>=2)begin
  line_in_audio #(.DSP(DSP),.CHAOS_BUFFER(LINE_IN==3),.CELLULAR(LINE_IN==4),.FEEDBACK(LINE_IN==5),.EXPANSION(EXPANDED)) audio(clk_audio,rst,start,stop,adc_bck,adc_lrck,adc_dout,control_values,control_routes,pcm_bck,pcm_lrck,pcm_din,running,source_valid,source_l,source_r,samples,under,meters,clock_diagnostics,expansion_values,expansion_levels);
  assign fill=0;assign over=0;assign frame_ready=0;
  assign {ram_clk,ram_cke,ram_ras_n,ram_cas_n,ram_we_n,ram_addr,ram_ba,ram_dqm}=0;
  assign ram_cs_n=1;assign ram_dq=32'bz;
 end else if(LINE_IN)begin
  assign clock_diagnostics=0;
  line_in_master_audio #(.DSP(DSP)) audio(clk_audio,rst,start,stop,adc_dout,control_values,control_routes,pcm_bck,pcm_lrck,pcm_din,running,source_valid,source_l,source_r,samples,under,meters);
  assign fill=0;assign over=0;assign frame_ready=0;
  assign {ram_clk,ram_cke,ram_ras_n,ram_cas_n,ram_we_n,ram_addr,ram_ba,ram_dqm}=0;
  assign ram_cs_n=1;assign ram_dq=32'bz;
 end else begin
  assign clock_diagnostics=0;
  stream_audio #(.DEPTH(DEPTH),.DSP(DSP),.SDRAM(SDRAM)) audio(clk_audio,rst,start,stop,drain,frame_valid,frame_data,frame_ready,pcm_bck,pcm_lrck,pcm_din,running,fill,samples,under,over,source_valid,source_l,source_r,control_values,control_routes,meters,ram_clk,ram_cke,ram_cs_n,ram_ras_n,ram_cas_n,ram_we_n,ram_addr,ram_ba,ram_dqm,ram_dq);
 end endgenerate
 reg [3:0] state;reg [7:0] response[0:109];reg [6:0] response_len;
 reg [7:0] response_kind;reg [31:0] response_seq;
 reg [6:0] tx_index;reg [15:0] tx_crc;reg [10:0] cursor;reg [1:0] byte_index;
 integer i;
 function automatic [15:0] crc_byte(input [15:0] c,input [7:0] b);
  reg [15:0] v;integer j;begin v=c^{b,8'b0};for(j=0;j<8;j=j+1)v=v[15]?(v<<1)^16'h1021:v<<1;crc_byte=v;end
 endfunction
 assign tx_valid=state==8;
 always @*begin
  case(tx_index)
   0:tx_data=8'h43;1:tx_data=8'h45;2:tx_data=1;3:tx_data=response_kind;
   4,5,6,7:tx_data=response_seq[(tx_index-4)*8+:8];
   8:tx_data={1'b0,response_len};9:tx_data=0;
   default:begin
    if(tx_index<10+response_len)tx_data=response[tx_index-10];
    else if(tx_index==10+response_len)tx_data=tx_crc[7:0];
    else tx_data=tx_crc[15:8];
   end
  endcase
 end
 always @(posedge clk_audio)begin
  if(rst)begin state<=0;packet_done<=0;start<=0;stop<=0;drain<=0;frame_valid<=0;frame_data<=0;address<=0;
   response_len<=0;response_kind<=0;response_seq<=0;tx_index<=0;tx_crc<=16'hffff;cursor<=0;byte_index<=0;
   host_write<=0;host_id<=0;host_value<=0;
   for(i=0;i<110;i=i+1)response[i]<=0;
  end else begin
   packet_done<=0;start<=0;stop<=0;drain<=0;host_write<=0;
   case(state)
    0:if(packet_valid)begin
     response_seq<=seq;response_kind<=kind|8'h80;response_len<=0;
     state<=7;
     if(kind==4)begin
      if(LINE_IN)begin response_kind<=8'hff;response_len<=1;response[0]<=1;end
      else if(length==0||length[1:0]!=0)begin response_kind<=8'hff;response_len<=1;response[0]<=2;end
      else if((DEPTH-fill)<(length>>2))begin response_kind<=8'hff;response_len<=1;response[0]<=3;end
      else begin address<=0;cursor<=0;byte_index<=0;state<=1;end
     end else if(kind==3&&DSP&&length==4)begin address<=0;byte_index<=0;state<=10;end
     else if(length!=0)begin response_kind<=8'hff;response_len<=1;response[0]<=2;end
     else case(kind)
      1:begin response_len<=9;response[0]<=8'h43;response[1]<=8'h45;response[2]<=8'h4c;response[3]<=8'h45;response[4]<=8'h53;response[5]<=8'h54;response[6]<=8'h45;response[7]<=8'h2f;response[8]<=8'h31;end
      2:begin
       response_len<=DEPTH>65535?40:32;
       {response[3],response[2],response[1],response[0]}<=32'd48000;
       {response[5],response[4]}<=DEPTH>65535?16'hffff:DEPTH;
       {response[7],response[6]}<=fill>65535?16'hffff:fill;
       {response[11],response[10],response[9],response[8]}<=under;
       {response[15],response[14],response[13],response[12]}<=over;
       {response[19],response[18],response[17],response[16]}<=samples;
       {response[23],response[22],response[21],response[20]}<=protocol_errors;
       {response[25],response[24]}<=LINE_IN>=3?16'd1:DSP?16'd63:16'd0;
       {response[27],response[26]}<=DSP?{10'd0,control_routes}:16'd0;
       {response[29],response[28]}<=(LINE_IN==5?16'd16400:LINE_IN==4?16'd49168:LINE_IN==3?16'd16400:DSP?16'd2047:16'd1)|(SDRAM?16'd2048:16'd0)|(DEPTH>65535?16'd4096:16'd0)|(LINE_IN?16'd8192:16'd0)|(EXPANDED?16'd49152:16'd0);
       {response[31],response[30]}<={15'b0,running};
       {response[35],response[34],response[33],response[32]}<=DEPTH;
       {response[39],response[38],response[37],response[36]}<=fill;
      end
      5:start<=1;
      6:stop<=1;
      7:drain<=1;
      8:begin
       response_len<=32;
       {response[3],response[2],response[1],response[0]}<=samples;
       {response[7],response[6],response[5],response[4]}<=nonzero_samples;
       {response[11],response[10],response[9],response[8]}<=sum_l;
       {response[15],response[14],response[13],response[12]}<=sum_r;
       {response[19],response[18],response[17],response[16]}<={peak_r,peak_l};
       {response[23],response[22],response[21],response[20]}<=din_ones;
       {response[27],response[26],response[25],response[24]}<=bck_edges;
       {response[31],response[30],response[29],response[28]}<=lrck_edges;
      end
      11:if(EXPANDED)begin response_len<=72;for(i=0;i<8;i=i+1)response[64+i]<=expansion_levels[i*8+:8];for(i=0;i<64;i=i+1)response[i]<=expansion_values[i*8+:8];end
      else begin response_kind<=8'hff;response_len<=1;response[0]<=1;end
      10:if(LINE_IN>=2)begin
       response_len<=32;
       for(i=0;i<32;i=i+1)response[i]<=clock_diagnostics[i*8+:8];
      end else begin response_kind<=8'hff;response_len<=1;response[0]<=1;end
      9:if(DSP)begin
       response_len<=110;
       for(i=0;i<30;i=i+1)response[80+i]<=meters[i*8+:8];
       for(i=0;i<64;i=i+1)response[i]<=control_values[i*8+:8];
       for(i=0;i<8;i=i+1)response[64+i]<=control_mappings[i*MAP_BITS+:MAP_BITS];
       response[72]<={2'd0,control_routes};response[73]<={3'd0,control_values[21*16],control_selected,panel_online};
       {response[77],response[76],response[75],response[74]}<=control_revision;
       response[78]<=6;response[79]<=0;
      end else begin response_kind<=8'hff;response_len<=1;response[0]<=1;end
      default:begin response_kind<=8'hff;response_len<=1;response[0]<=1;end
     endcase
    end
    1:state<=2; // synchronous staging RAM address latency
    2:begin
     frame_data[byte_index*8+:8]<=payload_data;
     if(byte_index==3)begin frame_valid<=1;state<=3;end
     else begin byte_index<=byte_index+1;address<=address+1;cursor<=cursor+1;state<=1;end
    end
    3:if(frame_ready)begin
     frame_valid<=0;
     if(cursor==length-1)state<=7;
     else begin byte_index<=0;address<=address+1;cursor<=cursor+1;state<=1;end
    end
    7:begin tx_index<=0;tx_crc<=16'hffff;state<=8;end
    10:state<=11;
    11:begin
     case(byte_index)0:host_id[7:0]<=payload_data;1:host_id[15:8]<=payload_data;2:host_value[7:0]<=payload_data;3:host_value[15:8]<=payload_data;endcase
     if(byte_index==3)state<=12;else begin byte_index<=byte_index+1'b1;address<=address+1'b1;state<=10;end
    end
    12:begin
     if((host_id<32&&host_id!=21)||host_id==32||(host_id>=40&&host_id<=55&&(host_value<18||(host_value>=23&&host_value<=26)||(host_value>=28&&host_value<=31)||(EXPANDED&&host_value>=66&&host_value<=85&&host_value!=76)))||(EXPANDED&&host_id>=64&&host_id<90&&host_id!=76&&host_id!=86&&host_id!=87))host_write<=1;
     else begin response_kind<=8'hff;response_len<=1;response[0]<=2;end
     state<=7;
    end
    8:if(tx_ready)begin
     if(tx_index>=2&&tx_index<10+response_len)tx_crc<=crc_byte(tx_crc,tx_data);
     if(tx_index==11+response_len)begin packet_done<=1;state<=9;end
     else tx_index<=tx_index+1;
    end
    9:state<=13;
    13:state<=0;
    default:state<=0;
   endcase
  end
 end
endmodule
`default_nettype wire
