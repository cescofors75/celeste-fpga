`default_nettype none
// V1.1 building block. Not yet connected to the board top level.
// Require a stable release after reset before accepting the first touch.
module touch_input #(
    parameter integer STABLE_CYCLES = 252000, // 10 ms at 25.2 MHz
    parameter ACTIVE_HIGH = 1
)(
    input wire clk, rst, touch_async,
    output reg pressed,
    output reg touch_pulse
);
    localparam integer CW = (STABLE_CYCLES < 2) ? 1 : $clog2(STABLE_CYCLES);
    (* ASYNC_REG = "TRUE" *) reg [1:0] sync_pipe;
    reg [CW-1:0] count;
    reg armed;
    wire active = ACTIVE_HIGH ? sync_pipe[1] : !sync_pipe[1];
    always @(posedge clk) begin
        if (rst) begin
            // Assume pressed until the physical input has settled at release.
            sync_pipe <= ACTIVE_HIGH ? 2'b11 : 2'b00;
            pressed <= 1'b1;
            touch_pulse <= 1'b0;
            count <= 0;
            armed <= 1'b0;
        end else begin
            sync_pipe <= {sync_pipe[0], touch_async};
            touch_pulse <= 1'b0;
            if (active == pressed) count <= 0;
            else if (count == STABLE_CYCLES-1) begin
                count <= 0;
                pressed <= active;
                if (!active) armed <= 1'b1;
                else if (armed) touch_pulse <= 1'b1;
            end else count <= count + 1'b1;
        end
    end
endmodule
`default_nettype wire
