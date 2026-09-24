`default_nettype none
// HDMI diagnostic: an internal reference waveform, sampled exactly at 48 kHz
// using a pixel-clock enable (25.2 MHz / 525). This is not a DAC audio clock.
module hdmi_content #(parameter EXTERNAL_AUDIO = 0, parameter SHOW_CONTROLS = 0) (
    input wire clk_pixel, rst,
    output wire led,
    output wire [9:0] red_symbol, green_symbol, blue_symbol,
    input wire external_sample_ce,
    input wire signed [23:0] external_sample,
    input wire [63:0] parameters,
    input wire effects_enabled, panel_online,
    input wire control_event,input wire [2:0] control_index
);
    reg [9:0] sample_divider;
    wire sample_ce = !rst && (sample_divider == 10'd524);
    always @(posedge clk_pixel) begin
        if (rst || sample_ce) sample_divider <= 0;
        else sample_divider <= sample_divider + 1'b1;
    end
    wire signed [23:0] sample;
    tone_dds oscillator (
        .clk(clk_pixel), .rst(rst), .sample_ce(sample_ce),
        .phase_step(32'd39370534), .sample(sample)
    );
    wire [9:0] x, y;
    wire de, hs, vs;
    wire [7:0] red, green, blue;
    video_timing timing(clk_pixel,rst,x,y,de,hs,vs);
    wire display_ce = EXTERNAL_AUDIO ? external_sample_ce : sample_ce;
    wire signed [23:0] display_sample = EXTERNAL_AUDIO ? external_sample : sample;
    scope_view #(.COMPACT(SHOW_CONTROLS)) display(clk_pixel,rst,x,y,de,display_ce,display_sample,red,green,blue);
    wire [7:0] view_r,view_g,view_b;
    generate if(SHOW_CONTROLS) begin: hud_view
        fx_hud hud(clk_pixel,rst,de,x,y,parameters,effects_enabled,panel_online,
            red,green,blue,view_r,view_g,view_b,control_event,control_index);
    end else begin
        assign view_r=red;assign view_g=green;assign view_b=blue;
    end endgenerate
    // Register the rendered pixel and its syncs together before TMDS encoding.
    reg [7:0] red_q, green_q, blue_q;
    reg de_q, hs_q, vs_q;
    always @(posedge clk_pixel) begin
        if (rst) begin
            red_q<=0; green_q<=0; blue_q<=0;
            de_q<=0; hs_q<=1; vs_q<=1;
        end else begin
            red_q<=view_r; green_q<=view_g; blue_q<=view_b;
            de_q<=de; hs_q<=hs; vs_q<=vs;
        end
    end
    tmds_encoder enc_r(clk_pixel,rst,de_q,red_q,2'b00,red_symbol);
    tmds_encoder enc_g(clk_pixel,rst,de_q,green_q,2'b00,green_symbol);
    tmds_encoder enc_b(clk_pixel,rst,de_q,blue_q,{vs_q,hs_q},blue_symbol);
    reg [5:0] frames;
    always @(posedge clk_pixel) begin
        if (rst) frames <= 0;
        else if (x==799 && y==524) frames <= (frames==59) ? 6'd0 : frames+1'b1;
    end
    assign led = rst || (frames >= 30);
endmodule
`default_nettype wire
