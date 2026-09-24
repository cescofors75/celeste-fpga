`default_nettype none
module encoder8_panel #(
    parameter integer GESTURES=0, HALF_PERIOD=126, RETRY_CYCLES=2520000,
    parameter integer POLL_CYCLES=RETRY_CYCLES/10, CACHE_LEDS=0,
    parameter integer TIMEOUT_CYCLES=504000
)(input wire clk,rst,
  input wire [215:0] led_colors,
  inout wire scl,sda,
  output reg online,event_valid,press_valid,
  output reg [2:0] event_index,
  output reg signed [31:0] event_delta,
  output reg fx_enabled,output reg long_valid);
    reg [13:0] ms_div;reg [15:0] ms_tick,pressed_at[0:7];reg [7:0] long_sent;integer bi;
    always @(posedge clk)begin
     if(rst)begin ms_div<=0;ms_tick<=0;end
     else if(ms_div==12287)begin ms_div<=0;ms_tick<=ms_tick+1'b1;end else ms_div<=ms_div+1'b1;
    end
    reg start,rd;
    reg [7:0] addr;
    reg [2:0] len;
    reg [31:0] data;
    wire busy,done,error;
    wire [31:0] received;
    i2c_register_master #(.HALF_PERIOD(HALF_PERIOD),.TIMEOUT_CYCLES(TIMEOUT_CYCLES)) bus
        (clk,rst,start,rd,addr,len,data,busy,done,error,received,scl,sda);
    reg [31:0] previous[0:7];
    reg [7:0] known,button_known,buttons;
    reg [215:0] sent_colors;reg [8:0] color_known;
    reg [2:0] channel;
    reg [2:0] operation;
    reg [1:0] state;
    integer cooldown;
    wire signed [31:0] difference=received-previous[channel];
    always @(posedge clk) begin
        start<=0;event_valid<=0;press_valid<=0;long_valid<=0;
        if(rst) begin
            long_sent<=0;for(bi=0;bi<8;bi=bi+1)pressed_at[bi]<=0;online<=0;event_valid<=0;press_valid<=0;event_index<=0;event_delta<=0;
            sent_colors<=0;color_known<=0;fx_enabled<=0;known<=0;button_known<=0;buttons<=8'hff;
            channel<=0;operation<=0;state<=0;cooldown<=RETRY_CYCLES;
            start<=0;rd<=0;addr<=0;len<=1;data<=0;
        end else if(cooldown>0) cooldown<=cooldown-1;
        else case(state)
        0: begin
            state<=1;
            case(operation)
            0: begin rd<=1;addr<={3'b000,channel,2'b00};len<=4;end
            1: begin rd<=1;addr<=8'h50+{5'd0,channel};len<=1;end
            2: begin
                rd<=0;addr<=8'h70+{5'd0,channel}*8'd3;len<=3;
                data<={8'd0,led_colors[channel*24 +: 24]};
                if(CACHE_LEDS && color_known[channel] && sent_colors[channel*24+:24]==led_colors[channel*24+:24])begin
                    state<=0;if(channel==7)operation<=3;else begin channel<=channel+1'b1;operation<=0;end
                end
            end
            3: begin rd<=1;addr<=8'h60;len<=1;end
            4: begin rd<=0;addr<=8'h88;len<=3;data<={8'd0,led_colors[192 +: 24]};
                if(CACHE_LEDS && color_known[8] && sent_colors[192+:24]==led_colors[192+:24])begin
                    state<=0;online<=1;channel<=0;operation<=0;cooldown<=POLL_CYCLES;end
                end
            default: operation<=0;
            endcase
        end
        1: begin start<=1;state<=2;end
        2: if(done) begin
            state<=0;
            if(error) begin
                online<=0;known<=0;button_known<=0;fx_enabled<=0;color_known<=0;
                channel<=0;operation<=0;cooldown<=RETRY_CYCLES;
            end else begin
                case(operation)
                0: begin
                    previous[channel]<=received;known[channel]<=1;
                    if(known[channel] && difference!=0) begin
                        // Discard implausible jumps (e.g. a restarted peripheral).
                        if(difference>=-32 && difference<=32) begin
                            event_valid<=1;event_index<=channel;event_delta<=difference;
                        end
                    end
                    operation<=1;
                end
                1: begin
                    if(button_known[channel] && buttons[channel] && !received[0]) begin
                        if(!GESTURES)press_valid<=1;pressed_at[channel]<=ms_tick;long_sent[channel]<=0;event_index<=channel;
                    end
                    if(GESTURES&&button_known[channel]&&!buttons[channel])begin
                     if(!received[0]&&!long_sent[channel]&&((ms_tick-pressed_at[channel])&16'hffff)>=700)begin long_valid<=1;event_index<=channel;long_sent[channel]<=1;end
                     if(received[0]&&!long_sent[channel])begin press_valid<=1;event_index<=channel;end
                    end
                    button_known[channel]<=1;buttons[channel]<=received[0];operation<=2;
                end
                2: begin
                    sent_colors[channel*24+:24]<=data[23:0];color_known[channel]<=1;
                    if(channel==7) operation<=3;
                    else begin channel<=channel+1'b1;operation<=0;end
                end
                3: begin fx_enabled<=received[0];operation<=4;end
                4: begin sent_colors[192+:24]<=data[23:0];color_known[8]<=1;online<=1;channel<=0;operation<=0;cooldown<=POLL_CYCLES;end
                endcase
            end
        end
        default: state<=0;
        endcase
    end
endmodule
`default_nettype wire
