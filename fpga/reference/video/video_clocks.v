`default_nettype none
module video_clocks (
    input wire clk27, reset,
    output wire clk_serial, clk_pixel, locked
);
    // 27 MHz / 3 * 14 = 126 MHz; VCO = 126 * 8 = 1008 MHz.
    rPLL pll (
        .CLKOUT(clk_serial), .LOCK(locked),
        .CLKOUTP(), .CLKOUTD(), .CLKOUTD3(),
        .RESET(reset), .RESET_P(1'b0), .CLKIN(clk27), .CLKFB(1'b0),
        .FBDSEL(6'd0), .IDSEL(6'd0), .ODSEL(6'd0),
        .PSDA(4'd0), .DUTYDA(4'd0), .FDLY(4'd0)
    );
    defparam pll.FCLKIN = "27";
    defparam pll.IDIV_SEL = 2;
    defparam pll.FBDIV_SEL = 13;
    defparam pll.ODIV_SEL = 8;
    defparam pll.CLKFB_SEL = "internal";
    defparam pll.DYN_IDIV_SEL = "false";
    defparam pll.DYN_FBDIV_SEL = "false";
    defparam pll.DYN_ODIV_SEL = "false";
    defparam pll.DEVICE = "GW2AR-18C";
    CLKDIV divider (
        .RESETN(locked && !reset), .HCLKIN(clk_serial),
        .CLKOUT(clk_pixel), .CALIB(1'b1)
    );
    defparam divider.DIV_MODE = "5";
    defparam divider.GSREN = "false";
endmodule
`default_nettype wire
