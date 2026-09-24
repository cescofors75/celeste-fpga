`default_nettype none
// Hardware-only adapter. Requires the Gowin primitive library, a 25.2 MHz
// pixel clock and its phase-related 126 MHz serial clock (CLKDIV /5).
// Not included in portable simulation; verify with Gowin and on the board.
module tmds_output (
    input wire clk_pixel, clk_serial, rst,
    input wire [9:0] red_symbol, green_symbol, blue_symbol,
    output wire tmds_clk_p, tmds_clk_n,
    output wire [2:0] tmds_data_p, tmds_data_n
);
    wire [9:0] words [0:3];
    wire [3:0] serial;
    assign words[0] = blue_symbol;
    assign words[1] = green_symbol;
    assign words[2] = red_symbol;
    assign words[3] = 10'b0000011111;
    genvar lane;
    generate for (lane=0;lane<4;lane=lane+1) begin: lanes
        OSER10 serializer (
            .Q(serial[lane]),
            .D0(words[lane][0]), .D1(words[lane][1]),
            .D2(words[lane][2]), .D3(words[lane][3]),
            .D4(words[lane][4]), .D5(words[lane][5]),
            .D6(words[lane][6]), .D7(words[lane][7]),
            .D8(words[lane][8]), .D9(words[lane][9]),
            .PCLK(clk_pixel), .FCLK(clk_serial), .RESET(rst)
        );
        defparam serializer.GSREN = "false";
        defparam serializer.LSREN = "true";
    end endgenerate
    TLVDS_OBUF clock_buffer (.I(serial[3]), .O(tmds_clk_p), .OB(tmds_clk_n));
    generate for (lane=0;lane<3;lane=lane+1) begin: buffers
        TLVDS_OBUF data_buffer (.I(serial[lane]), .O(tmds_data_p[lane]), .OB(tmds_data_n[lane]));
    end endgenerate
endmodule
`default_nettype wire
