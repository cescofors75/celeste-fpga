`default_nettype none
// Q1.15 stereo. Five source-parallel effects + dry, plus Delay 2 (4096 frames).
// Delay 1 remains 8192 frames. Delay 2 can consume source or Delay 1 output.
// Independent states; feedback/interpolation/gain arithmetic shares clock slots.
// Parameters U0.16; signed wide accumulation and explicit saturation.
// Pipeline finishes within 32 clocks, before the next 256-clock audio frame.
module parallel_fabric(input wire clk,rst,ce,input wire signed [15:0] in_l,in_r,
 input wire [511:0] parameters,input wire [5:0] routes,
 output reg signed [15:0] out_l,out_r,output wire [239:0] meters);
 reg [15:0] p[0:31];integer i;
 reg [4:0] control_scan;reg controls_busy;
 wire [4:0] control_id=control_scan<18?control_scan:control_scan==18?5'd20:control_scan==19?5'd24:control_scan==20?5'd25:control_scan==21?5'd26:5'd31;
 wire route_off=(control_id>=6&&control_id<=9&&!routes[control_id-6])||(control_id==16&&!routes[4])||(control_id==17&&!routes[5]);
 wire modulation_off=(control_id==12&&parameters[22*16+6])||(control_id==15&&parameters[22*16+7]);
 wire [15:0] control_target=(route_off||modulation_off)?16'd0:parameters[control_id*16+:16];
 wire [15:0] control_old=p[control_id];
 wire [15:0] control_next=control_target>control_old?(control_target-control_old>256?control_old+16'd256:control_target):(control_old-control_target>256?control_old-16'd256:control_target);
 function automatic signed [15:0] sat(input signed [47:0] x);
 begin sat=x>32767?16'sh7fff:x< -32768?16'sh8000:x[15:0];end endfunction
 function automatic signed [15:0] scale(input signed [15:0] x,input [15:0] gain);
 reg signed [32:0] product;begin product=x*$signed({1'b0,gain});scale=gain==65535?x:sat(product>>>16);end endfunction
 function automatic signed [15:0] fold(input signed [15:0] x,input [15:0] drive);
 reg signed [35:0] driven;reg [16:0] wrapped;reg [18:0] gain;
 begin gain=19'd65536+{1'b0,drive,2'b0};driven=$signed(x)*$signed({1'b0,gain});wrapped=(driven>>>16)+32768;
 fold=wrapped[16]?$signed(18'd98303-$signed({1'b0,wrapped})):$signed({1'b0,wrapped})-32768;end endfunction
 function automatic signed [15:0] blend(input signed [15:0] a,b,input [15:0] amount);
 reg signed [16:0] difference;reg signed [33:0] product;
 begin difference=$signed({b[15],b})-$signed({a[15],a});product=difference*$signed({1'b0,amount});
 blend=amount==65535?b:sat($signed(a)+(product>>>16));end endfunction
 // Exact 19x16 scaling with one 16x16 multiplier. The 3-bit integer part
 // uses shifts/adds, preserving six-branch headroom without another DSP block.
 function automatic signed [18:0] scale_mix(input signed [18:0] x,input [15:0] gain);
 reg [31:0] fraction;reg signed [19:0] g,whole;
 begin fraction=x[15:0]*gain;g=$signed({4'd0,gain});
 case(x[18:16])
 0:whole=0;1:whole=g;2:whole=g<<<1;3:whole=g+(g<<<1);
 4:whole=-(g<<<2);5:whole=-(g+(g<<<1));6:whole=-(g<<<1);7:whole=-g;
 endcase
 scale_mix=gain==65535?x:whole+$signed({1'b0,fraction[31:16]});end endfunction
 reg [15:0] chaos_target,chaos_value;reg [11:0] chaos_count;
 reg signed [15:0] wave_l,wave_r,vca_l,vca_r;
 reg [1:0] filter_mode;reg [15:0] filter_fade;reg signed [15:0] filter_selected_l,filter_selected_r;
 reg [4:0] phase;reg signed [15:0] dry_l,dry_r,gl_l,gl_r,held_l,held_r,del_l,del_r,fl_l,fl_r;
 reg [31:0] random_state;reg [7:0] hold_count;
 // Stereo capture/repeat buffer, four BSRAM blocks. Capture one complete
 // grain before replaying: uninitialized RAM can never reach the output.
 reg [31:0] grain_mem[0:2047];reg [31:0] grain_read;
 reg [10:0] grain_pos;reg [11:0] grain_length;
 reg [4:0] grain_repeats;reg grain_wet;
 reg [15:0] grain_amount;
 wire [11:0] requested_grain=12'd256 << parameters[29*16+14+:2];
 wire [11:0] grain_remaining=grain_length-{1'b0,grain_pos}-1'b1;
 wire [5:0] grain_edge=grain_pos<32?{1'b0,grain_pos[4:0]}:grain_remaining<32?grain_remaining[5:0]:6'd32;
 wire [21:0] grain_fade=p[0]*grain_edge;
 reg [31:0] delay_mem[0:8191];reg [12:0] wr,rd;reg [13:0] written;
 reg [31:0] delay2_mem[0:4095];reg [11:0] wr2,rd2;reg [12:0] written2,length2;
 reg [31:0] delayed2;reg signed [15:0] del2_l,del2_r;
 reg [15:0] bypass_gain[0:5];
 wire dual=parameters[27*16];wire serial_delay=parameters[27*16+1];
 wire bypass_active=|bypass_gain[0]|| |bypass_gain[1]|| |bypass_gain[2]|| |bypass_gain[3]|| |bypass_gain[4];
 // One stereo interpolation unit is shared across glitch and bypass stages.
 reg signed [15:0] interp_a_l,interp_a_r,interp_b_l,interp_b_r;reg [15:0] interp_amount;
 always @* begin
  interp_a_l=in_l;interp_a_r=in_r;interp_b_l=held_l;interp_b_r=held_r;interp_amount=p[0];
  if(!ce)begin
   interp_b_l=dry_l;interp_b_r=dry_r;interp_amount=0;
   case(phase)
    1:begin interp_a_l=dry_l;interp_a_r=dry_r;interp_b_l=grain_wet?grain_read[15:0]:dry_l;interp_b_r=grain_wet?grain_read[31:16]:dry_r;interp_amount=grain_amount;end
    4:begin interp_a_l=0;interp_a_r=0;interp_b_l=filter_selected_l;interp_b_r=filter_selected_r;interp_amount=filter_fade;end
    8:begin interp_a_l=gl_l;interp_a_r=gl_r;interp_amount=bypass_gain[0];end
    9:begin interp_a_l=del_l;interp_a_r=del_r;interp_amount=bypass_gain[1];end
    10:begin interp_a_l=fl_l;interp_a_r=fl_r;interp_amount=bypass_gain[2];end
    11:begin interp_a_l=wave_l;interp_a_r=wave_r;interp_amount=bypass_gain[3];end
    12:begin interp_a_l=vca_l;interp_a_r=vca_r;interp_amount=bypass_gain[4];end
    17:begin interp_a_l=del2_l;interp_a_r=del2_r;interp_b_l=serial_delay?del_l:dry_l;interp_b_r=serial_delay?del_r:dry_r;interp_amount=bypass_gain[5];end
   endcase
  end
 end
 wire signed [15:0] interpolated_l=blend(interp_a_l,interp_b_l,interp_amount);
 wire signed [15:0] interpolated_r=blend(interp_a_r,interp_b_r,interp_amount);
 // Delay feedback and branch-gain multipliers are reused in disjoint stages.
 wire signed [15:0] feedback_l=scale(phase==16?del2_l:del_l,{1'b0,(phase==16?p[25][15:1]:p[3][15:1])});
 wire signed [15:0] feedback_r=scale(phase==16?del2_r:del_r,{1'b0,(phase==16?p[25][15:1]:p[3][15:1])});
 wire signed [15:0] delay_mix_l=scale(phase==18?del2_l:del_l,phase==18?p[26]:p[8]);
 wire signed [15:0] delay_mix_r=scale(phase==18?del2_r:del_r,phase==18?p[26]:p[8]);
 reg [31:0] delayed;reg [13:0] delay_length;
 reg signed [15:0] low_l,low_r,band_l,band_r,high_l,high_r;
 reg [15:0] coefficient,damping;reg [31:0] lfo_phase;
 reg signed [18:0] mix_l,mix_r;
 // Complementary weights preserve headroom until the final output saturation.
 wire [31:0] dry_weight_product=p[20]*p[10];
 wire [15:0] dry_weight=p[20]==65535?p[10]:dry_weight_product[31:16];
 wire [15:0] fx_weight=p[10]-dry_weight;
 // Fractional error feedback prevents integrator deadbands at low cutoff.
 reg [14:0] low_frac_l,low_frac_r,band_frac_l,band_frac_r;
 wire signed [33:0] low_step_l=$signed(band_l)*$signed({1'b0,coefficient})+$signed({1'b0,low_frac_l});
 wire signed [33:0] low_step_r=$signed(band_r)*$signed({1'b0,coefficient})+$signed({1'b0,low_frac_r});
 wire signed [33:0] band_step_l=$signed(high_l)*$signed({1'b0,coefficient})+$signed({1'b0,band_frac_l});
 wire signed [33:0] band_step_r=$signed(high_r)*$signed({1'b0,coefficient})+$signed({1'b0,band_frac_r});
 wire [15:0] triangle=lfo_phase[31]?~lfo_phase[30:15]:lfo_phase[30:15];
 wire [31:0] lfo_product=triangle*p[12];
 wire [15:0] modulation=p[12]==65535?triangle:lfo_product[31:16];
 wire [31:0] chaos_product=chaos_value*p[15];
 wire [15:0] chaos_mod=p[15]==65535?chaos_value:chaos_product[31:16];
 wire [17:0] mod_cut={2'b0,p[4]}+(parameters[18*16]?modulation:16'd0)+(parameters[19*16]?chaos_mod:16'd0);
 wire [16:0] attenuation=(parameters[18*16+1]?modulation:16'd0)+(parameters[19*16+1]?chaos_mod:16'd0);
 wire [15:0] vca_factor=attenuation[16]?16'd0:16'hffff-attenuation[15:0];
 wire [31:0] vca_product=p[14]*vca_factor;
 wire [15:0] vca_gain=vca_factor==65535?p[14]:p[14]==65535?vca_factor:vca_product[31:16];
 reg [31:0] chaos_phase;
 wire [32:0] chaos_next={1'b0,chaos_phase}+33'd4474+({17'd0,p[31]}<<4);
 always @* begin
  case(filter_mode)
   1:begin filter_selected_l=high_l;filter_selected_r=high_r;end
   2:begin filter_selected_l=band_l;filter_selected_r=band_r;end
   3:begin filter_selected_l=sat($signed(low_l)+$signed(high_l));filter_selected_r=sat($signed(low_r)+$signed(high_r));end
   default:begin filter_selected_l=low_l;filter_selected_r=low_r;end
  endcase
 end
 wire [15:0] cut=(|mod_cut[17:16])?16'hffff:mod_cut[15:0];
 reg signed [15:0] delay2_mix_l,delay2_mix_r;
 reg [15:0] envelope[0:14];
 reg [13:0] peak_hold[0:14]; // 200 ms at 48 kHz; bridges 150 ms host polling.
 function automatic [15:0] peak(input signed [15:0] a,b);
 reg [15:0] aa,bb;begin aa=a[15]?-a:a;bb=b[15]?-b:b;peak=aa>bb?aa:bb;end endfunction
 // Meter work is scheduled after the audio pipeline; one peak/decay unit.
 reg [3:0] meter_index;reg meter_busy;integer mr;
 reg signed [15:0] meter_l,meter_r;
 genvar m;generate for(m=0;m<15;m=m+1)begin assign meters[m*16+:16]=envelope[m];end endgenerate
 always @*begin
  meter_l=0;meter_r=0;
  case(meter_index)
  0:begin meter_l=dry_l;meter_r=dry_r;end
  1:begin meter_l=scale(dry_l,p[6]);meter_r=scale(dry_r,p[6]);end
  2:begin meter_l=scale(gl_l,p[7]);meter_r=scale(gl_r,p[7]);end
  3:begin meter_l=delay_mix_l;meter_r=delay_mix_r;end
  4:begin meter_l=scale(fl_l,p[9]);meter_r=scale(fl_r,p[9]);end
  5:begin meter_l=scale(wave_l,p[16]);meter_r=scale(wave_r,p[16]);end
  6:begin meter_l=scale(vca_l,p[17]);meter_r=scale(vca_r,p[17]);end
  7:begin meter_l=out_l;meter_r=out_r;end
  8:begin meter_l=gl_l;meter_r=gl_r;end
  9:begin meter_l=del_l;meter_r=del_r;end
  10:begin meter_l=fl_l;meter_r=fl_r;end
  11:begin meter_l=wave_l;meter_r=wave_r;end
  12:begin meter_l=vca_l;meter_r=vca_r;end
  13:if(dual)begin meter_l=del2_l;meter_r=del2_r;end
  14:if(dual)begin meter_l=delay2_mix_l;meter_r=delay2_mix_r;end
  endcase
 end
 wire [15:0] measured_peak=peak(meter_l,meter_r);
 wire [15:0] previous_peak=envelope[meter_index];
 wire [13:0] previous_hold=peak_hold[meter_index];
 always @(posedge clk)begin
  if(rst)begin meter_index<=0;meter_busy<=0;for(mr=0;mr<15;mr=mr+1)begin envelope[mr]<=0;peak_hold[mr]<=0;end end
  else if(phase==7)begin meter_index<=0;meter_busy<=1;end
  else if(meter_busy)begin
   if(measured_peak>=previous_peak)begin envelope[meter_index]<=measured_peak;peak_hold[meter_index]<=9600;end
   else if(previous_hold!=0)peak_hold[meter_index]<=previous_hold-1'b1;
   else if(previous_peak>8)envelope[meter_index]<=previous_peak-(previous_peak>>12)-1'b1;
   else envelope[meter_index]<=0;
   if(meter_index==14)meter_busy<=0;else meter_index<=meter_index+1'b1;
  end
 end
 always @(posedge clk)begin
  if(rst)begin
   control_scan<=0;controls_busy<=0;for(i=0;i<32;i=i+1)p[i]<=parameters[i*16+:16];
   for(i=6;i<10;i=i+1)if(!routes[i-6])p[i]<=0;
   for(i=0;i<6;i=i+1)bypass_gain[i]<=parameters[22*16+i]?65535:0;
   delay2_mix_l<=0;delay2_mix_r<=0;wr2<=0;rd2<=0;written2<=0;length2<=1;delayed2<=0;del2_l<=0;del2_r<=0;
   if(!routes[4])p[16]<=0;if(!routes[5])p[17]<=0;
   chaos_target<=32768;chaos_value<=32768;chaos_count<=0;wave_l<=0;wave_r<=0;vca_l<=0;vca_r<=0;
   chaos_phase<=0;filter_mode<=parameters[28*16+14+:2];filter_fade<=65535;
   grain_pos<=0;grain_length<=requested_grain;grain_repeats<=0;grain_read<=0;grain_wet<=0;grain_amount<=0;
   phase<=0;out_l<=0;out_r<=0;held_l<=0;held_r<=0;hold_count<=0;random_state<=32'hce1e57e1;
   wr<=0;rd<=0;written<=0;delayed<=0;low_l<=0;low_r<=0;band_l<=0;band_r<=0;lfo_phase<=0;
   dry_l<=0;dry_r<=0;gl_l<=0;gl_r<=0;del_l<=0;del_r<=0;fl_l<=0;fl_r<=0;
   low_frac_l<=0;low_frac_r<=0;band_frac_l<=0;band_frac_r<=0;
   mix_l<=0;mix_r<=0;coefficient<=100;damping<=50000;delay_length<=1;high_l<=0;high_r<=0;
  end else if(ce)begin
   // One shared control-ramp unit updates 23 continuous controls in unused clock slots.
   control_scan<=0;controls_busy<=1;
   for(i=0;i<6;i=i+1)begin
    if(parameters[22*16+i])bypass_gain[i]<=bypass_gain[i]>65279?65535:bypass_gain[i]+16'd256;
    else bypass_gain[i]<=bypass_gain[i]>256?bypass_gain[i]-16'd256:0;
   end
   chaos_phase<=chaos_next[31:0];if(chaos_next[32])chaos_target<=random_state[31:16];
   if(filter_mode!=parameters[28*16+14+:2])begin
    if(filter_fade>2048)filter_fade<=filter_fade-16'd2048;
    else begin filter_fade<=0;filter_mode<=parameters[28*16+14+:2];end
   end else filter_fade<=filter_fade>63487?65535:filter_fade+16'd2048;
   grain_read<=grain_mem[grain_pos];grain_wet<=grain_repeats!=0;
   grain_amount<=grain_edge==32?p[0]:grain_fade[20:5];
   if(grain_repeats==0)grain_mem[grain_pos]<={in_r,in_l};
   if({1'b0,grain_pos}+1>=grain_length)begin
    grain_pos<=0;
    if(grain_repeats!=0)begin
     grain_repeats<=grain_repeats-1'b1;
     if(grain_repeats==1)grain_length<=requested_grain;
    end else if(random_state[31:16]<p[1]&&parameters[23*16+15]&&p[0]!=0)
     grain_repeats<=5'd1+{1'b0,parameters[30*16+12+:4]};
    else grain_length<=requested_grain;
   end else grain_pos<=grain_pos+1'b1;
   if(chaos_value<chaos_target)chaos_value<=chaos_target-chaos_value>64?chaos_value+16'd64:chaos_target;
   else chaos_value<=chaos_value-chaos_target>64?chaos_value-16'd64:chaos_target;
   wave_l<=fold(in_l,p[13]);wave_r<=fold(in_r,p[13]);
   vca_l<=scale(in_l,vca_gain);vca_r<=scale(in_r,vca_gain);
   dry_l<=in_l;dry_r<=in_r;phase<=1;
   lfo_phase<=lfo_phase+32'd4474+({16'b0,p[11]}<<4);
   random_state<={random_state[30:0],random_state[31]^random_state[21]^random_state[1]^random_state[0]};
   if(hold_count==0)begin
    held_l<=in_l;held_r<=in_r;
    if(random_state[31:16]<p[1])hold_count<=p[0][15:8]>247?8'd255:8'd8+p[0][15:8];
   end else hold_count<=hold_count-1'b1;
   gl_l<=hold_count==0?in_l:interpolated_l;
   gl_r<=hold_count==0?in_r:interpolated_r;
   delay_length<=14'd1+{1'b0,p[2][15:3]};
   rd<=wr-(13'd1+p[2][15:3]);
   coefficient<=16'd86+(cut>>2); // f=0.0026..0.5026; cutoff ~20..3880 Hz.
   damping<=16'd60000-(p[5]>>1); // bounded resonance, damping ~0.83..1.83.
  end else begin
   if(controls_busy)begin
    p[control_id]<=control_next;
    if(control_scan==22)controls_busy<=0;else control_scan<=control_scan+1'b1;
   end
   case(phase)
   1:begin delayed<=delay_mem[rd];if(parameters[23*16+15])begin gl_l<=interpolated_l;gl_r<=interpolated_r;end phase<=2;end
   2:begin
    del_l<=written>=delay_length?delayed[15:0]:16'd0;del_r<=written>=delay_length?delayed[31:16]:16'd0;
    low_frac_l<=low_step_l[14:0];low_frac_r<=low_step_r[14:0];
    low_l<=sat($signed(low_l)+(low_step_l>>>15));
    low_r<=sat($signed(low_r)+(low_step_r>>>15));phase<=3;
   end
   3:begin
    delay_mem[wr]<={sat($signed(dry_r)+$signed(feedback_r)),sat($signed(dry_l)+$signed(feedback_l))};
    wr<=wr+1'b1;if(written<8192)written<=written+1'b1;
    high_l<=sat($signed(dry_l)-$signed(low_l)-($signed(band_l)*$signed({1'b0,damping})>>>15));
    high_r<=sat($signed(dry_r)-$signed(low_r)-($signed(band_r)*$signed({1'b0,damping})>>>15));phase<=4;
   end
   4:begin
    band_frac_l<=band_step_l[14:0];band_frac_r<=band_step_r[14:0];
    band_l<=sat($signed(band_l)+(band_step_l>>>15));
    band_r<=sat($signed(band_r)+(band_step_r>>>15));
    fl_l<=interpolated_l;fl_r<=interpolated_r;phase<=bypass_active?8:dual?14:5;
   end
   5:begin
    mix_l<=$signed(scale(dry_l,p[6]))+$signed(scale(gl_l,p[7]))+$signed(delay_mix_l)+$signed(scale(fl_l,p[9]))+$signed(scale(wave_l,p[16]))+$signed(scale(vca_l,p[17]));
    mix_r<=$signed(scale(dry_r,p[6]))+$signed(scale(gl_r,p[7]))+$signed(delay_mix_r)+$signed(scale(fl_r,p[9]))+$signed(scale(wave_r,p[16]))+$signed(scale(vca_r,p[17]));phase<=dual?18:6;
   end
   6:begin out_l<=sat($signed(scale_mix(mix_l,fx_weight))+$signed(scale(dry_l,dry_weight)));out_r<=sat($signed(scale_mix(mix_r,fx_weight))+$signed(scale(dry_r,dry_weight)));phase<=7;end
   8:begin gl_l<=interpolated_l;gl_r<=interpolated_r;phase<=9;end
   9:begin del_l<=interpolated_l;del_r<=interpolated_r;phase<=10;end
   10:begin fl_l<=interpolated_l;fl_r<=interpolated_r;phase<=11;end
   11:begin wave_l<=interpolated_l;wave_r<=interpolated_r;phase<=12;end
   12:begin vca_l<=interpolated_l;vca_r<=interpolated_r;phase<=dual?14:5;end
   14:begin rd2<=wr2-(12'd1+p[24][15:4]);length2<=13'd1+{1'b0,p[24][15:4]};phase<=19;end
   19:begin delayed2<=delay2_mem[rd2];phase<=15;end
   15:begin del2_l<=written2>=length2?delayed2[15:0]:16'd0;del2_r<=written2>=length2?delayed2[31:16]:16'd0;phase<=16;end
   16:begin
    delay2_mem[wr2]<={sat($signed(serial_delay?del_r:dry_r)+$signed(feedback_r)),sat($signed(serial_delay?del_l:dry_l)+$signed(feedback_l))};
    wr2<=wr2+1'b1;if(written2<4096)written2<=written2+1'b1;phase<=17;
   end
   17:begin del2_l<=interpolated_l;del2_r<=interpolated_r;phase<=5;end
   18:begin delay2_mix_l<=delay_mix_l;delay2_mix_r<=delay_mix_r;mix_l<=mix_l+$signed(delay_mix_l);mix_r<=mix_r+$signed(delay_mix_r);phase<=6;end
   default:phase<=0;
  endcase
  end
 end
endmodule
`default_nettype wire
