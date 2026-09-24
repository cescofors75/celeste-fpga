`default_nettype none
// 640x480, negative sync, 800x525 total. 25.2 MHz => exactly 60 Hz.
module video_timing (
    input wire clk_pixel, rst,
    output reg [9:0] x, y,
    output wire de, hsync, vsync
);
    always @(posedge clk_pixel) begin
        if (rst) begin x <= 0; y <= 0; end
        else if (x == 799) begin
            x <= 0;
            y <= (y == 524) ? 10'd0 : y + 10'd1;
        end else x <= x + 10'd1;
    end
    assign de = (x < 640) && (y < 480);
    assign hsync = !((x >= 656) && (x < 752));
    assign vsync = !((y >= 490) && (y < 492));
endmodule
`default_nettype wire
