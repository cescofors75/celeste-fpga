`timescale 1ns/1ps
module tb_touch;
    reg clk=0, rst=1, raw=1;
    always #5 clk=~clk;
    wire pressed, pulse, low_pressed, low_pulse;
    integer events=0;
    reg previous=0;
    touch_input #(.STABLE_CYCLES(4)) dut(clk,rst,raw,pressed,pulse);
    touch_input #(.STABLE_CYCLES(4),.ACTIVE_HIGH(0)) inv(clk,rst,~raw,low_pressed,low_pulse);
    always @(negedge clk) if (!rst) begin
        if (pulse !== low_pulse || pressed !== low_pressed) $fatal(1,"Polarity mismatch");
        if (pulse && previous) $fatal(1,"Pulse wider than one clock");
        if (pulse) events=events+1;
        previous=pulse;
    end
    task wait_cycles(input integer n);
        repeat(n) @(negedge clk);
    endtask
    initial begin
        wait_cycles(3); #1 rst=0;
        wait_cycles(20);
        if(events!=0) $fatal(1,"Startup held touch fired");
        #1 raw=0; wait_cycles(12);
        #1 raw=1; wait_cycles(1);
        #1 raw=0; wait_cycles(12);
        if(events!=0) $fatal(1,"Glitch accepted");
        #1 raw=1; wait_cycles(30);
        if(events!=1) $fatal(1,"Held touch must fire once");
        #1 raw=0; wait_cycles(1);
        #1 raw=1; wait_cycles(12);
        if(events!=1) $fatal(1,"Release glitch retriggered");
        #1 raw=0; wait_cycles(12);
        #1 raw=1; wait_cycles(12);
        if(events!=2) $fatal(1,"Second touch missing");
        #1 rst=1; wait_cycles(3); #1 rst=0; wait_cycles(20);
        if(events!=2) $fatal(1,"Reset while held retriggered");
        $display("PASS touch: startup, debounce, hold, release, reset and both polarities");
        $finish;
    end
    initial begin #100000; $fatal(1,"Timeout"); end
endmodule
