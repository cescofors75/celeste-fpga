`default_nettype none
// 24-bit signed PCM in two 32-bit I2S slots. LRCLK: 0=left, 1=right.
// clk must be 12.288 MHz for 48 kHz with HALF_BCK_CYCLES=2.
module i2s_tx #(
    parameter integer HALF_BCK_CYCLES = 2
) (
    input wire clk,
    input wire rst,
    input wire signed [23:0] sample_l,
    input wire signed [23:0] sample_r,
    output wire frame_ce,
    output reg bck,
    output reg lrck,
    output reg dout
);
    localparam integer DIV_BITS = (HALF_BCK_CYCLES < 2) ? 1 : $clog2(HALF_BCK_CYCLES);
    reg [DIV_BITS-1:0] divider;
    reg [5:0] slot_bit;
    reg [23:0] held_l, held_r;
    wire [5:0] next_bit = slot_bit + 6'd1;

    // Both channels are captured together at the beginning of a stereo frame.
    // Upstream logic may advance to the NEXT sample on this same clock edge.
    assign frame_ce = !rst && (divider == HALF_BCK_CYCLES-1) && bck && (slot_bit == 63);

    always @(posedge clk) begin
        if (rst) begin
            divider <= 0;
            bck <= 0;
            lrck <= 1;
            dout <= 0;
            slot_bit <= 63;
            held_l <= 0;
            held_r <= 0;
        end else if (divider == HALF_BCK_CYCLES-1) begin
            divider <= 0;
            bck <= ~bck;
            if (bck) begin
                // Data and LRCLK change only at falling BCK edges.
                slot_bit <= next_bit;
                if (next_bit == 0) begin
                    held_l <= sample_l;
                    held_r <= sample_r;
                    lrck <= 0;
                    dout <= 0;
                end else if (next_bit == 32) begin
                    lrck <= 1;
                    dout <= 0;
                end else if (next_bit >= 1 && next_bit <= 24) begin
                    dout <= held_l[24-next_bit];
                end else if (next_bit >= 33 && next_bit <= 56) begin
                    dout <= held_r[56-next_bit];
                end else begin
                    dout <= 0;
                end
            end
        end else begin
            divider <= divider + 1'b1;
        end
    end
endmodule
`default_nettype wire
