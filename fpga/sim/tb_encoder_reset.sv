`timescale 1ns/1ps
module tb_encoder_reset;
 reg clk=0,rst=1,hw=0,event_valid=0,press=0,bank=0;
 reg [15:0] id=0,value=0;reg [2:0] index=0;reg signed [31:0] delta=0;
 wire [511:0] values;wire [39:0] mappings;wire [5:0] routes;wire [31:0] revision;wire [2:0] selected;
 always #5 clk=~clk;
 fabric_registers dut(clk,rst,hw,id,value,event_valid,index,delta,values,mappings,routes,revision,selected,1'b0,bank,1'b1,press);
 task push(input [2:0] encoder);
 begin @(negedge clk);index=encoder;press=1;@(negedge clk);press=0;end endtask
 initial begin
  repeat(3)@(negedge clk);rst=0;
  push(4);if(values[2*16+:16]!==0||values[3*16+:16]===0)$fatal(1,"bank0 reset wrong target");
  @(negedge clk);hw=1;id=13;value=50000;@(negedge clk);hw=0;bank=1;
  repeat(2)@(negedge clk);push(0);if(values[13*16+:16]!==0||values[0+:16]===0)$fatal(1,"bank1 reset wrong target");
  @(negedge clk);hw=1;id=48;value=3;@(negedge clk);hw=0;
  push(0);if(values[3*16+:16]!==0)$fatal(1,"custom mapping ignored");
  @(negedge clk);index=0;event_valid=1;delta=1;@(negedge clk);event_valid=0;
  if(values[3*16+:16]!==512)$fatal(1,"rotation after reset broken");
  $display("PASS encoder reset banks, custom mapping and rotation");$finish;
 end
endmodule
