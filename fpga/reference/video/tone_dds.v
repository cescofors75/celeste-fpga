`default_nettype none
// 32-bit phase accumulator, 256-entry sine table. Output peak is -18.06 dBFS.
module tone_dds (
    input wire clk,
    input wire rst,
    input wire sample_ce,
    input wire [31:0] phase_step,
    output wire signed [23:0] sample
);
    reg [31:0] phase;
    wire signed [15:0] sine;
    sine_lut lut (.address(phase[31:24]), .value(sine));
    assign sample = {{3{sine[15]}}, sine, 5'b0};
    always @(posedge clk) begin
        if (rst) phase <= 0;
        else if (sample_ce) phase <= phase + phase_step;
    end
endmodule
`default_nettype wire
