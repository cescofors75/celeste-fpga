`default_nettype none
// Laboratory CBM-4: 48kHz signed PCM16, four logical read heads, one RAM port.
// 2048 stereo frames; 1 write + 8 reads/sample, 22 core clocks/sample.
// H?non states are signed 24-bit signed with 20 fractional bits; products retain full width.
module chaos_buffer4(input wire clk,rst,valid,input wire signed [15:0] in_l,in_r,
 input wire [15:0] amount,size,master,input wire raw_mode,bypass,
 output reg signed [15:0] out_l,out_r,output reg done,
 output reg [31:0] deadline_faults,guard_resets);
 reg [31:0] memory[0:2047];reg [10:0] wr,pos[0:3],oldpos[0:3];
 reg [11:0] filled,age[0:3];reg [5:0] fade[0:3];reg reverse[0:3],oldreverse[0:3];
 reg signed [23:0] hx[0:3],hy[0:3];
 reg [2:0] phase;reg [1:0] head;reg busy;
 reg [31:0] fetched,old_sample;reg signed [15:0] dry_l,dry_r;
 reg signed [21:0] sum_l,sum_r;reg [15:0] held_amount,held_master,held_size;
 reg held_raw,held_bypass;
 wire signed [47:0] square=hx[head]*hx[head];
 wire signed [23:0] square_q=square>>>20;
 wire signed [45:0] curve=square_q*22'sd1468006;
 wire signed [43:0] y_product=hx[head]*20'sd314573;
 wire signed [47:0] next_x=48'sd1048576-(curve>>>20)+$signed(hy[head]);
 wire signed [23:0] next_y=y_product>>>20;
 wire [47:0] magnitude=next_x<0?-next_x:next_x;
 wire [11:0] fragment=12'd256+{2'd0,held_size[15:6]};
 wire [5:0] weight=(held_raw||fade[head]>=32)?6'd32:fade[head];
 wire signed [15:0] nl=fetched[15:0],nr=fetched[31:16],ol=old_sample[15:0],orr=old_sample[31:16];
 wire signed [23:0] blend_l=$signed(ol)*$signed({1'b0,6'd32-weight})+$signed(nl)*$signed({1'b0,weight});
 wire signed [23:0] blend_r=$signed(orr)*$signed({1'b0,6'd32-weight})+$signed(nr)*$signed({1'b0,weight});
 wire signed [15:0] sample_l=filled==2048?(blend_l>>>5):16'sd0;
 wire signed [15:0] sample_r=filled==2048?(blend_r>>>5):16'sd0;
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
   wr<=0;filled<=0;busy<=0;phase<=0;head<=0;out_l<=0;out_r<=0;done<=0;deadline_faults<=0;guard_resets<=0;
   dry_l<=0;dry_r<=0;sum_l<=0;sum_r<=0;fetched<=0;old_sample<=0;mixed_l<=0;mixed_r<=0;
   held_amount<=0;held_master<=0;held_size<=0;held_raw<=0;held_bypass<=1;
   for(i=0;i<4;i=i+1)begin hx[i]<=(1638+i*997)*64;hy[i]<=0;pos[i]<=i*384;oldpos[i]<=i*384;age[i]<=i*47;fade[i]<=32;reverse[i]<=0;oldreverse[i]<=0;end
  end else if(valid&&!busy)begin
   memory[wr]<={in_r,in_l};wr<=wr+1'b1;if(filled<2048)filled<=filled+1'b1;
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
      if(next_x>1920000||next_x< -1920000)begin hx[head]<=(1638+head*997)*64;hy[head]<=0;guard_resets<=guard_resets+1'b1;end
      else begin hx[head]<=next_x[23:0];hy[head]<=next_y;end
      pos[head]<=wr-(11'd64+{1'b0,magnitude[9:0]});reverse[head]<=next_x<0;
     end else begin age[head]<=age[head]+1'b1;pos[head]<=reverse[head]?pos[head]-1'b1:pos[head]+1'b1;if(fade[head]<32)fade[head]<=fade[head]+1'b1;end
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
