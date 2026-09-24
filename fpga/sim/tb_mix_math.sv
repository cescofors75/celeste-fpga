`timescale 1ns/1ps
module tb_mix_math;
 parallel_fabric dut(1'b0,1'b0,1'b0,16'd0,16'd0,384'd0,6'd0,,,);
 integer x,k,checks=0;reg [15:0] gain;reg signed [63:0] expected;reg signed [18:0] actual;
 initial begin
  for(x=-196608;x<=196602;x=x+1)begin
   for(k=0;k<5;k=k+1)begin
    case(k)0:gain=0;1:gain=1;2:gain=32768;3:gain=65535;4:gain=(x*31337+517)&65535;endcase
    expected=x;expected=gain==65535?expected:(expected*$signed({1'b0,gain}))>>>16;
    actual=dut.scale_mix(x,gain);
    if(actual!==expected)$fatal(1,"Wide gain mismatch x=%0d gain=%0d actual=%0d expected=%0d",x,gain,actual,expected);
    checks=checks+1;
   end
  end
  $display("PASS wide mixer: %0d full-range comparisons against signed 64-bit multiplication",checks);$finish;
 end
endmodule
