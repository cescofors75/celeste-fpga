`timescale 1ns/1ps
module tb_i2s;
    reg clk=0, rst=1;
    always #5 clk=~clk;
    reg [23:0] left=24'h800001, right=24'h7ffffe;
    wire bck, lrck, dout, ce;
    i2s_tx dut(clk,rst,left,right,ce,bck,lrck,dout);
    reg [23:0] expected_l[0:255], expected_r[0:255];
    integer written=0, cycles=0, last_ce=-1;
    integer n, bitno, passno;
    reg [31:0] received_l, received_r;
    time last_bck=0;
    always @(posedge clk) begin
        if(rst) begin written=0; cycles=0; last_ce=-1; end
        else begin
            cycles=cycles+1;
            if(ce) begin
                if(last_ce>=0 && cycles-last_ce!=256) $fatal(1,"Frame rate mismatch");
                last_ce=cycles;
                expected_l[written]=left;
                expected_r[written]=right;
                written=written+1;
            end
        end
    end
    always @(bck) begin
        if(rst) last_bck=0;
        else begin
            if(last_bck!=0 && $time-last_bck!=20) $fatal(1,"BCK jitter");
            last_bck=$time;
        end
    end
    // Inputs deliberately change during a frame: the right channel must remain paired.
    always @(negedge clk) if(!rst) begin
        left <= left + 24'h021307;
        right <= right - 24'h010321;
    end
    initial begin
        for(passno=0;passno<2;passno=passno+1) begin
            rst=1; last_bck=0;
            repeat(5) @(negedge clk);
            rst=0;
            @(negedge lrck);
            @(posedge bck); // I2S one-bit delay following the LRCLK transition.
            for(n=0;n<64;n=n+1) begin
                received_l=0; received_r=0;
                for(bitno=0;bitno<32;bitno=bitno+1) begin
                    @(posedge bck); received_l={received_l[30:0],dout};
                    if(lrck !== (bitno==31)) $fatal(1,"Left LRCLK phase");
                end
                for(bitno=0;bitno<32;bitno=bitno+1) begin
                    @(posedge bck); received_r={received_r[30:0],dout};
                    if(lrck !== (bitno!=31)) $fatal(1,"Right LRCLK phase");
                end
                if(received_l !== {expected_l[n],8'b0} || received_r !== {expected_r[n],8'b0})
                    $fatal(1,"PCM mismatch frame %0d: %h %h expected %h %h",n,received_l,received_r,expected_l[n],expected_r[n]);
            end
            @(negedge clk); // reset during active transmission, then reacquire framing
        end
        $display("PASS I2S: 128 stereo frames, signs, padding, channel pairing, clocks, reset");
        $finish;
    end
    initial begin #1000000; $fatal(1,"I2S timeout"); end
endmodule
