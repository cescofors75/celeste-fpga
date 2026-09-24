`default_nettype none
// Cellular laboratory: four audio heads controlled by a separate 256-cell automaton.
module cellular_buffer4(input wire clk,rst,valid,input wire signed [15:0] in_l,in_r,
 input wire [15:0] amount,size,master,density,
 input wire [1:0] rule_mode,input wire raw_mode,bypass,
 output reg signed [15:0] out_l,out_r,output reg done,
 output reg [31:0] deadline_faults,output wire [31:0] guard_resets);
 reg [31:0] memory[0:8191];reg [12:0] wr,pos[0:3],oldpos[0:3];
 reg [13:0] filled;reg [12:0] age[0:3],anchor[0:3];reg silent[0:3],oldsilent[0:3];reg [7:0] fade[0:3];reg reverse[0:3],oldreverse[0:3];

 reg [2:0] phase;reg [1:0] head;reg busy;
 reg [31:0] fetched,old_sample;reg signed [15:0] dry_l,dry_r;
 reg signed [21:0] sum_l,sum_r;reg [15:0] held_amount,held_master,held_size;
 reg held_raw,held_bypass;
 wire [255:0] cells;
 wire [12:0] fragment=13'd128+{1'b0,held_size[15:4]};
 wire ca_step=busy&&phase==5&&head==0&&age[0]>=fragment;
 cellular256 automaton(clk,rst,ca_step,rule_mode,32'hce1e57e1,cells,guard_resets);
 wire [7:0] decision=cells[head*64+:8];
 wire act=cells[head*64+8+:8]<density[15:8];
 wire freeze_input=cells[31:24]<density[15:8]&&cells[23:21]==3'd5;
 // 128-sample crossfade (2.67 ms at 48 kHz), bounded by the minimum fragment.
 wire [7:0] weight=(held_raw||fade[head]>=128)?8'd128:fade[head];
 wire signed [15:0] nl=silent[head]?16'sd0:fetched[15:0],nr=silent[head]?16'sd0:fetched[31:16],ol=oldsilent[head]?16'sd0:old_sample[15:0],orr=oldsilent[head]?16'sd0:old_sample[31:16];
 wire signed [25:0] blend_l=$signed(ol)*$signed({1'b0,8'd128-weight})+$signed(nl)*$signed({1'b0,weight});
 wire signed [25:0] blend_r=$signed(orr)*$signed({1'b0,8'd128-weight})+$signed(nr)*$signed({1'b0,weight});
 wire signed [15:0] sample_l=filled==8192?(blend_l>>>7):16'sd0;
 wire signed [15:0] sample_r=filled==8192?(blend_r>>>7):16'sd0;
 // Complementary fixed panning weights: each channel sums to 8, preserving headroom.
 wire [2:0] pan_l=head==0?4:head==1?3:head==2?1:0;
 wire [2:0] pan_r=head==0?0:head==1?1:head==2?3:4;
 wire signed [21:0] add_l=$signed(sample_l)*$signed({1'b0,pan_l});
 wire signed [21:0] add_r=$signed(sample_r)*$signed({1'b0,pan_r});
 wire signed [15:0] wet_l=sum_l>>>3,wet_r=sum_r>>>3;
 wire [16:0] mix=held_bypass?17'd0:{1'b0,held_amount}+{16'd0,&held_amount};
 wire signed [34:0] mix_l=$signed(dry_l)*$signed(18'd65536-{1'b0,mix})+$signed(wet_l)*$signed({1'b0,mix});
 wire signed [34:0] mix_r=$signed(dry_r)*$signed(18'd65536-{1'b0,mix})+$signed(wet_r)*$signed({1'b0,mix});
 reg signed [15:0] mixed_l,mixed_r;
 wire [16:0] gain={1'b0,held_master}+{16'd0,&held_master};
 wire signed [33:0] scaled_l=mixed_l*$signed({1'b0,gain}),scaled_r=mixed_r*$signed({1'b0,gain});
 function automatic signed [15:0] sat16(input signed [34:0] v);
 begin sat16=v>32767?16'sh7fff:v< -32768?16'sh8000:v[15:0];end endfunction
 integer i;
 always @(posedge clk)begin
  done<=0;
  if(rst)begin
   wr<=0;filled<=0;busy<=0;phase<=0;head<=0;out_l<=0;out_r<=0;done<=0;deadline_faults<=0;
   dry_l<=0;dry_r<=0;sum_l<=0;sum_r<=0;fetched<=0;old_sample<=0;mixed_l<=0;mixed_r<=0;
   held_amount<=0;held_master<=0;held_size<=0;held_raw<=0;held_bypass<=1;
   for(i=0;i<4;i=i+1)begin anchor[i]<=i*384;silent[i]<=0;oldsilent[i]<=0;pos[i]<=i*384;oldpos[i]<=i*384;age[i]<=i*47;fade[i]<=128;reverse[i]<=0;oldreverse[i]<=0;end
  end else if(valid&&!busy)begin
   if(!freeze_input||filled<8192)begin memory[wr]<={in_r,in_l};wr<=wr+1'b1;if(filled<8192)filled<=filled+1'b1;end
   dry_l<=in_l;dry_r<=in_r;held_amount<=amount;held_master<=master;held_size<=size;held_raw<=raw_mode;held_bypass<=bypass;
   sum_l<=0;sum_r<=0;head<=0;phase<=1;busy<=1;
  end else if(busy)begin
   if(valid)deadline_faults<=deadline_faults+1'b1;
   case(phase)
    1:begin fetched<=memory[oldpos[head]];phase<=2;end
    2:begin old_sample<=fetched;phase<=3;end
    3:begin fetched<=memory[pos[head]];phase<=4;end
    4:phase<=5;
    5:begin
     sum_l<=sum_l+add_l;sum_r<=sum_r+add_r;
     oldpos[head]<=oldreverse[head]?oldpos[head]-1'b1:oldpos[head]+1'b1;
     if(age[head]>=fragment+{8'd0,head,2'b00})begin
      age[head]<=0;fade[head]<=0;oldpos[head]<=reverse[head]?pos[head]-1'b1:pos[head]+1'b1;oldreverse[head]<=reverse[head];
      oldsilent[head]<=silent[head];silent[head]<=0;
      if(!act)begin pos[head]<=wr-13'd64;anchor[head]<=wr-13'd64;reverse[head]<=0;end
      else case(decision[2:0])
       1,3,5:begin pos[head]<=anchor[head];reverse[head]<=decision[0]&&decision[1];end
       2:begin pos[head]<=anchor[head]+fragment;reverse[head]<=1;end
       4:begin silent[head]<=1;pos[head]<=wr-13'd64;reverse[head]<=0;end
       default:begin
        pos[head]<=wr-(13'd128+{decision[7:3],7'd0});
        anchor[head]<=wr-(13'd128+{decision[7:3],7'd0});reverse[head]<=decision[5];
       end
      endcase
     end else begin age[head]<=age[head]+1'b1;pos[head]<=reverse[head]?pos[head]-1'b1:pos[head]+1'b1;if(fade[head]<128)fade[head]<=fade[head]+1'b1;end
     if(head==3)phase<=6;else begin head<=head+1'b1;phase<=1;end
    end
    6:begin mixed_l<=sat16(mix_l>>>16);mixed_r<=sat16(mix_r>>>16);phase<=7;end
    7:begin out_l<=sat16(scaled_l>>>16);out_r<=sat16(scaled_r>>>16);done<=1;busy<=0;phase<=0;end
    default:begin busy<=0;phase<=0;end
   endcase
  end
 end
endmodule
`default_nettype wire
