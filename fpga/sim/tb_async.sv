`timescale 1ns/1ps
module tb_async;
 reg wc=0,rc=0,wr=1,rr=1,wv=0,ready=0;always #5 wc=~wc;always #7 rc=~rc;
 reg [7:0] wd=0;wire space,valid;wire [7:0] data;integer sent=0,seen=0,ticks=0;
 async_fifo #(.AW(3)) dut(wc,wr,wv,wd,space,rc,rr,valid,data,ready);
 always @(negedge wc)if(!wr)begin
  wv=sent<1000;wd=sent;
 end
 always @(posedge wc)if(!wr&&wv&&space)sent=sent+1;
 always @(negedge rc)if(!rr)begin ticks=ticks+1;ready=ticks%11<7;end
 always @(posedge rc)if(!rr&&valid&&ready)begin
  if(data!==(seen&255))$fatal(1,"CDC ordering %d got %h",seen,data);
  seen=seen+1;if(seen==1000)begin $display("PASS asynchronous FIFO: 1000 bytes, unequal clocks, stalls, wrap");$finish;end
 end
 initial begin repeat(4)@(negedge wc);wr=0;repeat(4)@(negedge rc);rr=0;end
 initial begin #100000;$fatal(1,"CDC timeout");end
endmodule
