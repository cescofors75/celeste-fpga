`default_nettype none
// Two banks: capture 512 samples, then swap only in vertical blanking.
module scope_view #(parameter COMPACT=0) (
    input wire clk_pixel, rst,
    input wire [9:0] x, y,
    input wire de,
    input wire sample_valid,
    input wire signed [23:0] sample,
    output reg [7:0] red, green, blue
);
    reg signed [7:0] trace [0:1023];
    reg read_bank, capture_done, trace_valid;
    reg [8:0] write_index;
    reg [7:0] peak;
    reg [7:0] display_peak;
    wire [8:0] read_column = x - 10'd64;
    wire [8:0] previous_column = (read_column == 0) ? 9'd0 : read_column - 9'd1;
    wire [7:0] magnitude = sample[23] ? (~sample[23:16] + 8'd1) : sample[23:16];
    always @(posedge clk_pixel) begin
        if (rst) begin
            read_bank <= 0;
            capture_done <= 0;
            trace_valid <= 0;
            write_index <= 0;
            peak <= 0;
            display_peak <= 0;
        end else begin
            if (sample_valid) begin
                if (magnitude > peak) peak <= magnitude;
                if (!capture_done) begin
                    trace[{~read_bank, write_index}] <= sample[23:16];
                    if (write_index == 511) capture_done <= 1;
                    else write_index <= write_index + 1'b1;
                end
            end
            if (x == 0 && y == 480) begin
                display_peak <= peak;
                peak <= (sample_valid ? magnitude : 8'd0);
                if (capture_done) begin
                    read_bank <= ~read_bank;
                    capture_done <= 0;
                    write_index <= 0;
                    trace_valid <= 1;
                end
            end
        end
    end

    // Fixed 5x7 title, CELESTE, scaled 4x. Each glyph is seven 5-bit rows.
    function [34:0] glyph;
        input [2:0] letter;
        begin
            case (letter)
                0: glyph = 35'b01110_10001_10000_10000_10000_10001_01110;
                1,3,6: glyph = 35'b11111_10000_10000_11110_10000_10000_11111;
                2: glyph = 35'b10000_10000_10000_10000_10000_10000_11111;
                4: glyph = 35'b01111_10000_10000_01110_00001_00001_11110;
                5: glyph = 35'b11111_00100_00100_00100_00100_00100_00100;
                default: glyph = 0;
            endcase
        end
    endfunction
    integer wave_y, previous_y, column, gx, gy, character;
    reg [34:0] letter_bits;
    always @* begin
        red = 8'h0a; green = 8'h10; blue = 8'h20;
        column = (x - 64) & 511;
        wave_y = (COMPACT ? 208:240) - $signed(trace[{read_bank, read_column}]) * (COMPACT ? 2:4);
        previous_y = (COMPACT ? 208:240) - $signed(trace[{read_bank, previous_column}]) * (COMPACT ? 2:4);
        gx = (x - 64) / 4;
        gy = (y - 40) / 4;
        character = gx / 6;
        letter_bits = glyph(character[2:0]);
        if (x >= 64 && x < 232 && y >= 40 && y < 68 && gx % 6 < 5)
            if (letter_bits[34 - gy*5 - gx%6]) begin
                red = 8'hdc; green = 8'hf8; blue = 8'hff;
            end
        if (x >= 64 && x < 576 && y >= 112 && y <= (COMPACT ? 296:368)) begin
            if ((x-64) % 64 == 0 || (y-112) % 32 == 0) begin
                red = 8'h1a; green = 8'h2b; blue = 8'h40;
            end
            if (y == (COMPACT ? 208:240)) begin red = 8'h30; green = 8'h48; blue = 8'h60; end
            if (trace_valid &&
                ((y >= wave_y-1 && y <= previous_y+1) ||
                 (y >= previous_y-1 && y <= wave_y+1))) begin
                red = 8'h35; green = 8'hdc; blue = 8'hff;
            end
        end
        if (x >= 64 && x < 576 && y >= 408 && y < 424) begin
            red = 8'h1a; green = 8'h2b; blue = 8'h40;
            if (x-64 < display_peak*4) begin
                red = 8'h50; green = 8'he0; blue = 8'ha0;
            end
        end
        if (!de) begin red = 0; green = 0; blue = 0; end
    end
endmodule
`default_nettype wire
