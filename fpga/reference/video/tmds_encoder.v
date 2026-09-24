`default_nettype none
// DVI-compatible TMDS: pixel data or one of the four control symbols.
module tmds_encoder (
    input wire clk_pixel, rst, de,
    input wire [7:0] data,
    input wire [1:0] control,
    output reg [9:0] symbol
);
    reg [8:0] qm;
    reg use_xnor;
    reg signed [5:0] disparity;
    integer ones, balance, i;
    always @* begin
        ones = 0;
        for (i=0; i<8; i=i+1) ones = ones + data[i];
        use_xnor = (ones > 4) || ((ones == 4) && !data[0]);
        qm[0] = data[0];
        for (i=1; i<8; i=i+1) qm[i] = qm[i-1] ^ data[i] ^ use_xnor;
        qm[8] = !use_xnor;
        balance = 0;
        for (i=0; i<8; i=i+1) balance = balance + (qm[i] ? 1 : -1);
    end
    always @(posedge clk_pixel) begin
        if (rst) begin
            disparity <= 0;
            symbol <= 10'b1101010100;
        end else if (!de) begin
            disparity <= 0;
            case (control)
                0: symbol <= 10'b1101010100;
                1: symbol <= 10'b0010101011;
                2: symbol <= 10'b0101010100;
                3: symbol <= 10'b1010101011;
            endcase
        end else if (disparity == 0 || balance == 0) begin
            symbol <= {~qm[8], qm[8], qm[8] ? qm[7:0] : ~qm[7:0]};
            disparity <= disparity + (qm[8] ? balance : -balance);
        end else if ((disparity > 0 && balance > 0) || (disparity < 0 && balance < 0)) begin
            symbol <= {1'b1, qm[8], ~qm[7:0]};
            disparity <= disparity - balance + (qm[8] ? 2 : 0);
        end else begin
            symbol <= {1'b0, qm[8], qm[7:0]};
            disparity <= disparity + balance - (qm[8] ? 0 : 2);
        end
    end
endmodule
`default_nettype wire
