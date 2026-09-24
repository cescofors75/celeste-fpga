`default_nettype none
// FDN-4 laboratory. Four independent delay memories, normalized Hadamard feedback.
// One arithmetic lane schedules the four updates within each 256-clock sample.
module feedback_matrix4(input wire clk,rst,valid,input wire signed [15:0] in_l,in_r,
 input wire [15:0] amount,feedback,tone,master,input wire bypass,
 output reg signed [15:0] out_l,out_r,output reg done,
 output reg [31:0] deadline_faults,limit_events);
 reg signed [23:0] ram0[0:2047],ram1[0:2047],ram2[0:2047],ram3[0:2047];
 reg [10:0] ptr[0:3];reg [11:0] filled;
 reg signed [23:0] damp[0:3],tap[0:3],fetched,filtered;
 reg signed [15:0] dry_l,dry_r,mixed_l,mixed_r;
 reg [15:0] mix_s,fb_s,tone_s,gain_s;
 reg busy;reg [2:0] phase;reg [1:0] head;
 wire [10:0] length=head==0?11'd1493:head==1?11'd1601:head==2?11'd1867:11'd1999;
 wire signed [24:0] delta=$signed(fetched)-$signed(damp[head]);
 wire [16:0] alpha=17'd2048+{2'b0,tone_s[15:1]};
 wire signed [42:0] damp_product=delta*$signed({1'b0,alpha});
 wire signed [31:0] filtered_next=$signed(damp[head])+(damp_product>>>16);
 // Widen before summing: H/2 is orthonormal; loop gain is always <= 0.9375.
 wire signed [26:0] a=tap[0],b=tap[1],c=tap[2],d=tap[3];
 wire signed [26:0] hsum=head==0?a+b+c+d:head==1?a-b+c-d:head==2?a+b-c-d:a-b-c+d;
 wire signed [25:0] h=hsum>>>1;
 wire [16:0] loop_gain={1'b0,fb_s}-{5'd0,fb_s[15:4]};
 wire signed [43:0] loop_product=h*$signed({1'b0,loop_gain});
 wire signed [17:0] inject=head==0?$signed(dry_l):head==1?$signed(dry_r):head==2?-$signed({dry_l[15],dry_l}):-$signed({dry_r[15],dry_r});
 wire signed [43:0] next_value=(loop_product>>>16)+($signed(inject)>>>2);
 // Internal headroom 4x PCM16. Symmetric saturation only as emergency containment.
 wire signed [23:0] write_value=next_value>131071?24'sd131071:next_value< -131071?-24'sd131071:next_value[23:0];
 wire signed [26:0] wet_l=(a-c)>>>1,wet_r=(b-d)>>>1;
 wire [16:0] mix={1'b0,mix_s}+{16'd0,&mix_s};
 wire signed [45:0] mix_l=$signed(dry_l)*$signed(18'd65536-{1'b0,mix})+wet_l*$signed({1'b0,mix});
 wire signed [45:0] mix_r=$signed(dry_r)*$signed(18'd65536-{1'b0,mix})+wet_r*$signed({1'b0,mix});
 wire [16:0] gain={1'b0,gain_s}+{16'd0,&gain_s};
 wire signed [33:0] scaled_l=mixed_l*$signed({1'b0,gain}),scaled_r=mixed_r*$signed({1'b0,gain});
 function automatic signed [15:0] sat16(input signed [45:0] v);
 begin sat16=v>32767?16'sh7fff:v< -32768?16'sh8000:v[15:0];end endfunction
 function automatic [15:0] slew(input [15:0] current,target);
 begin if(target>current)slew=(target-current>32)?current+16'd32:target;
 else slew=(current-target>32)?current-16'd32:target;end endfunction
 integer i;
 always @(posedge clk)begin
  done<=0;
  if(rst)begin
   busy<=0;phase<=0;head<=0;filled<=0;fetched<=0;filtered<=0;
   dry_l<=0;dry_r<=0;mixed_l<=0;mixed_r<=0;out_l<=0;out_r<=0;
   mix_s<=0;fb_s<=0;tone_s<=0;gain_s<=0;deadline_faults<=0;limit_events<=0;
   for(i=0;i<4;i=i+1)begin ptr[i]<=0;damp[i]<=0;tap[i]<=0;end
  end else if(valid&&!busy)begin
   dry_l<=in_l;dry_r<=in_r;mix_s<=slew(mix_s,bypass?16'd0:amount);
   fb_s<=slew(fb_s,feedback);tone_s<=slew(tone_s,tone);gain_s<=slew(gain_s,master);
   busy<=1;head<=0;phase<=1;
  end else if(busy)begin
   if(valid)deadline_faults<=deadline_faults+1'b1;
   case(phase)
    1:begin
     case(head)
      0:fetched<=ram0[ptr[0]];1:fetched<=ram1[ptr[1]];
      2:fetched<=ram2[ptr[2]];3:fetched<=ram3[ptr[3]];
     endcase
     phase<=2;
    end
    2:begin filtered<=filled>=length?filtered_next[23:0]:24'sd0;phase<=3;end
    3:begin
     tap[head]<=filtered;damp[head]<=filtered;
     if(head==3)begin head<=0;phase<=4;end else begin head<=head+1'b1;phase<=1;end
    end
    4:begin
     case(head)
      0:ram0[ptr[0]]<=write_value;1:ram1[ptr[1]]<=write_value;
      2:ram2[ptr[2]]<=write_value;3:ram3[ptr[3]]<=write_value;
     endcase
     if(next_value>131071||next_value< -131071)limit_events<=limit_events+1'b1;
     ptr[head]<=ptr[head]==(length-11'd1) ? 11'd0 : ptr[head]+1'b1;
     if(head==3)begin if(filled<1999)filled<=filled+1'b1;phase<=5;end else head<=head+1'b1;
    end
    5:begin mixed_l<=sat16(mix_l>>>16);mixed_r<=sat16(mix_r>>>16);phase<=6;end
    6:begin out_l<=sat16(scaled_l>>>16);out_r<=sat16(scaled_r>>>16);done<=1;busy<=0;phase<=0;end
    default:begin busy<=0;phase<=0;end
   endcase
  end
 end
endmodule
`default_nettype wire
