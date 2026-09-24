`timescale 1ns/1ps
module tb_sdram_fifo;
 reg clk=0;always #40 clk=~clk;
 reg rst=1,clear=0,valid=0,rd=0;reg [31:0] value;
 wire ready,rv;wire [31:0] result,over,under,dq;wire [17:0] fill;
 wire ck,cke,cs,ras,cas,we;wire [10:0] addr;wire [1:0] ba;wire [3:0] dqm;
 sdram_fifo #(.DEPTH(131072)) dut(clk,rst,clear,valid,value,ready,rd,result,rv,fill,over,under,ck,cke,cs,ras,cas,we,addr,ba,dqm,dq);
 reg [31:0] memory[0:131071];reg [10:0] row;reg [31:0] read_data;reg [2:0] read_pipe=0;
 integer refreshes=0,age=0,i;reg initialized=0;
 assign dq=read_pipe[2]?read_data:32'bz;
 always @(posedge ck)begin
  read_pipe<={read_pipe[1:0],1'b0};age<=age+1;
  if(cke&&!cs)case({ras,cas,we})
   3'b011:row<=addr;
   3'b100:begin if(!initialized||!addr[10]||ba!=0||dqm!=0)$fatal(1,"Invalid SDRAM write");memory[{row[8:0],addr[7:0]}]<=dq;end
   3'b101:begin read_data<=memory[{row[8:0],addr[7:0]}];read_pipe[0]<=1;end
   3'b001:begin refreshes<=refreshes+1;age<=0;end
   3'b000:begin if(addr!=11'h220)$fatal(1,"Mode is not BL1/CAS2");initialized<=1;age<=0;end
  endcase
  if(initialized&&!rst&&!clear&&dut.state>=7&&age>100)$fatal(1,"Refresh deadline missed");
 end
 task push(input [31:0] data);begin
  @(negedge clk);value=data;valid=1;while(!ready)@(negedge clk);@(negedge clk);valid=0;
 end endtask
 task pop(input [31:0] expected);integer wait_cycles;begin
  @(negedge clk);rd=1;@(negedge clk);rd=0;wait_cycles=0;
  while(!rv)begin @(negedge clk);wait_cycles=wait_cycles+1;if(wait_cycles>32)$fatal(1,"Read timeout");end
  if(result!==expected)$fatal(1,"PCM mismatch %h expected %h",result,expected);
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;wait(ready);
  for(i=0;i<131072;i=i+1)push(i^32'habcd4321);
  if(fill!=131072||ready)$fatal(1,"Full credit wrong");
  for(i=0;i<131072;i=i+1)pop(i^32'habcd4321);
  if(fill!=0)$fatal(1,"Empty credit wrong");
  for(i=0;i<1024;i=i+1)begin push(i*32'h01020305);pop(i*32'h01020305);end
  push(32'hdeadbeef);@(negedge clk);clear=1;@(negedge clk);clear=0;
  wait(ready);if(fill!=0||rv)$fatal(1,"STOP leaked stale data");push(32'h12345678);pop(32'h12345678);
  if(over||under||refreshes<100)$fatal(1,"FIFO counters/refresh failed");
  $display("PASS SDRAM: full 131072 stereo frames, wrap, CAS2, refresh, STOP, exact PCM");$finish;
 end
 initial begin #1000000000;$fatal(1,"Test timeout");end
endmodule
