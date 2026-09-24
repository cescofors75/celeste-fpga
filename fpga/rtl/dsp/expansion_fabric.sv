`default_nettype none
// Independent parallel branches. Two shared 18x18 ALUs; sample schedule <64 clocks.
module expansion_fabric(input wire clk,rst,ce,start,input wire signed [15:0] in_l,in_r,base_l,base_r,
 input wire [511:0] controls,input wire [15:0] master,bypass,
 output reg signed [15:0] out_l,out_r,output reg [15:0] envelope_mod,output reg done,
 output reg [31:0] deadline_faults,output wire [63:0] levels);
 wire [15:0] p[0:31];genvar g;generate for(g=0;g<32;g=g+1)begin assign p[g]=controls[g*16+:16];end endgenerate
 wire [5:0] active=p[0][5:0]&~p[24][11:6]&((|p[25][12:0])?p[25][11:6]:6'b111111);
reg [7:0] level[0:7];reg [5:0] meter_tick;
 genvar lm;generate for(lm=0;lm<8;lm=lm+1)begin assign levels[lm*8+:8]=level[lm];end endgenerate
 function automatic [7:0] level8(input signed [39:0] l,r);
 reg [39:0] al,ar,pk;begin al=l<0?-l:l;ar=r<0?-r:r;pk=al>ar?al:ar;level8=pk>=32768?8'd255:pk[14:7];end endfunction
 wire [7:0] branch_peak=level8(product_l>>>16,product_r>>>16);
 reg [31:0] motion_mem[0:2047],freeze_mem[0:2047];
 reg [10:0] wr,rd,fw,fr,freeze_anchor;reg was_held;reg [11:0] filled,ffilled;
 reg [31:0] clock_phase[0:3];wire [15:0] triangle[0:3];
 generate for(g=0;g<4;g=g+1)begin assign triangle[g]=clock_phase[g][31]?~clock_phase[g][30:15]:clock_phase[g][30:15];end endgenerate
 reg [7:0] gain[0:5];reg [15:0] depth0,depth1,env,mod_depth,fx_gain;
 reg [7:0] crush_count,fraction;reg signed [15:0] crush_l,crush_r;
 reg signed [15:0] dry_l,dry_r,original_l,original_r,wet_l,wet_r,prev_l,prev_r;
 reg [31:0] motion_q,freeze_q;
 wire [10:0] motion_addr=state==4?rd-11'd1:rd;
 wire [10:0] freeze_addr=freeze_anchor+(state==13?{4'd0,fr[6:0]}:fr);
 wire [31:0] fetched=state==14?freeze_q:motion_q;
 always @(posedge clk)begin
  if(!rst&&ce)motion_mem[wr]<={in_r,in_l};
  if(!rst&&ce&&(!p[11][15]||ffilled<2048))freeze_mem[fw]<={in_r,in_l};
  motion_q<=motion_mem[motion_addr];freeze_q<=freeze_mem[freeze_addr];
 end
reg signed [18:0] sum_l,sum_r;
 reg [5:0] state;reg branch;integer i;
 wire [15:0] abs_l=in_l[15]?-in_l:in_l,abs_r=in_r[15]?-in_r:in_r;
 wire [15:0] input_peak=abs_l>abs_r?abs_l:abs_r;
 wire [15:0] env_drop=(p[21][15:14]==0?(env>>8):p[21][15:14]==1?(env>>10):p[21][15:14]==2?(env>>12):(env>>14))+1'b1;
 reg signed [17:0] a_l,a_r,b_l,b_r;
 wire signed [35:0] product_l=a_l*b_l,product_r=a_r*b_r;
 wire [20:0] motion=branch?(product_l>>>18):(product_l>>>15);
 wire [15:0] selected_depth=branch?depth1:depth0;
 wire signed [15:0] selected_l=p[1][branch]?dry_l:wet_l,selected_r=p[1][branch]?dry_r:wet_r;
 function automatic [7:0] gain_slew(input [7:0] x,t);
 begin gain_slew=t>x?x+1'b1:t<x?x-1'b1:x;end endfunction
 function automatic [15:0] slew(input [15:0] x,t);
 begin slew=t>x?((t-x)>64?x+16'd64:t):((x-t)>64?x-16'd64:t);end endfunction
 function automatic signed [15:0] sat(input signed [39:0] x);
 begin sat=x>32767?16'sh7fff:x< -32768?16'sh8000:x[15:0];end endfunction
 reg [3:0] control_scan;reg controls_busy;
 wire [2:0] gain_index=control_scan[2:0]-3'd6;
 reg [15:0] rate_target;reg [7:0] gain_target;
 always @*begin
  case(control_scan[1:0])0:rate_target=p[2];1:rate_target=p[5];2:rate_target=p[14];default:rate_target=p[17];endcase
  case(gain_index)0:gain_target=active[0]?p[4][15:8]:8'd0;1:gain_target=active[1]?p[7][15:8]:8'd0;2:gain_target=active[2]?p[10][15:8]:8'd0;3:gain_target=active[3]?p[13][15:8]:8'd0;4:gain_target=active[4]?p[16][15:8]:8'd0;default:gain_target=active[5]?p[19][15:8]:8'd0;endcase
 end
 wire [31:0] next_phase=clock_phase[control_scan[1:0]]+32'd4474+{12'd0,rate_target,4'd0};
 wire [15:0] next_depth=slew(control_scan==4?depth0:depth1,control_scan==4?p[3]:p[6]);
 reg [2:0] whole_l,whole_r;
 wire signed [18:0] master_step=state==34?-($signed({3'd0,fx_gain})<<<2):state==33?($signed({3'd0,fx_gain})<<<1):$signed({3'd0,fx_gain});
 wire whole_bit_l=state==32?whole_l[0]:state==33?whole_l[1]:whole_l[2];
 wire whole_bit_r=state==32?whole_r[0]:state==33?whole_r[1]:whole_r[2];
 always @*begin
  a_l=0;a_r=0;b_l=0;b_r=0;
  case(state)
   1:begin a_l=$signed({1'b0,triangle[branch]});b_l=$signed({1'b0,selected_depth});end
   5,14:begin a_l=$signed(fetched[15:0])-$signed(prev_l);a_r=$signed(fetched[31:16])-$signed(prev_r);b_l=$signed({2'd0,fraction,8'd0});b_r=b_l;end
   7:begin a_l=selected_l;a_r=selected_r;b_l=$signed({1'b0,gain[branch],8'd0});b_r=b_l;end
   10:begin a_l=p[1][2]?dry_l:wet_l;a_r=p[1][2]?dry_r:wet_r;b_l=$signed({1'b0,gain[2],8'd0});b_r=b_l;end
   16:begin a_l=p[1][3]?dry_l:wet_l;a_r=p[1][3]?dry_r:wet_r;b_l=$signed({1'b0,gain[3],8'd0});b_r=b_l;end
   18:begin a_l=$signed({1'b0,triangle[2]});b_l=$signed({1'b0,p[15]});end
   19:begin a_l=dry_l;a_r=dry_r;b_l=$signed({2'd0,(16'hffff-mod_depth)});b_r=b_l;end
   21:begin a_l=p[1][4]?dry_l:wet_l;a_r=p[1][4]?dry_r:wet_r;b_l=$signed({1'b0,gain[4],8'd0});b_r=b_l;end
   23:begin a_l=$signed({1'b0,triangle[3]});b_l=$signed({1'b0,p[18]});end
   24:begin a_l=dry_l;a_r=dry_r;b_l=$signed({2'd0,(16'hffff-mod_depth)});b_r=$signed({2'd0,(16'hffff-(p[18]-mod_depth))});end
   26:begin a_l=p[1][5]?dry_l:wet_l;a_r=p[1][5]?dry_r:wet_r;b_l=$signed({1'b0,gain[5],8'd0});b_r=b_l;end
   28:begin a_l=$signed({1'b0,env});b_l=$signed({1'b0,p[20]});end
   29:begin a_l=$signed({1'b0,master});b_l=$signed({2'd0,(16'hffff-bypass)});end
   31:begin a_l=$signed({2'd0,sum_l[15:0]});a_r=$signed({2'd0,sum_r[15:0]});b_l=$signed({1'b0,fx_gain});b_r=b_l;end
  endcase
 end
 always @(posedge clk)begin
  done<=0;
  if(rst)begin
   control_scan<=0;controls_busy<=0;whole_l<=0;whole_r<=0;meter_tick<=0;for(i=0;i<8;i=i+1)level[i]<=0;freeze_anchor<=0;was_held<=0;state<=0;wr<=0;rd<=0;fw<=0;fr<=0;filled<=0;ffilled<=0;crush_count<=0;crush_l<=0;crush_r<=0;
   depth0<=0;depth1<=0;env<=0;mod_depth<=0;fx_gain<=0;envelope_mod<=0;fraction<=0;
   dry_l<=0;dry_r<=0;original_l<=0;original_r<=0;wet_l<=0;wet_r<=0;prev_l<=0;prev_r<=0;
   out_l<=0;out_r<=0;sum_l<=0;sum_r<=0;branch<=0;deadline_faults<=0;
   for(i=0;i<4;i=i+1)clock_phase[i]<=0;for(i=0;i<6;i=i+1)gain[i]<=0;
  end else begin
   if(ce)begin
    meter_tick<=meter_tick+1'b1;if(meter_tick==0)for(i=0;i<8;i=i+1)if(level[i]!=0)level[i]<=level[i]-1'b1;
    if(state!=0)deadline_faults<=deadline_faults+1'b1;
    dry_l<=in_l;dry_r<=in_r;
    wr<=wr+1'b1;if(filled<2048)filled<=filled+1'b1;
    was_held<=p[11][15]&&ffilled==2048;
    if(!p[11][15]||ffilled<2048)begin fw<=fw+1'b1;if(ffilled<2048)ffilled<=ffilled+1'b1;fr<=0;freeze_anchor<=fw+1'b1;end
    else if(!was_held)begin fr<=0;freeze_anchor<=fw;end
    else fr<=fr==2047?11'd128:fr+1'b1;
    if(crush_count==0)begin crush_l<=in_l;crush_r<=in_r;crush_count<=p[9][15:8];end else crush_count<=crush_count-1'b1;
    env<=input_peak>env?input_peak:(env>env_drop?env-env_drop:16'd0);
    control_scan<=0;controls_busy<=1;
   end
   if(!ce&&controls_busy)begin
    if(control_scan<4)clock_phase[control_scan[1:0]]<=next_phase;
    else if(control_scan==4)depth0<=next_depth;
    else if(control_scan==5)depth1<=next_depth;
    else gain[gain_index]<=gain_slew(gain[gain_index],gain_target);
    if(control_scan==11)controls_busy<=0;else control_scan<=control_scan+1'b1;
   end
   if(start&&state==0)begin original_l<=base_l;original_r<=base_r;sum_l<=0;sum_r<=0;branch<=0;state<=1;end
   else case(state)
    1:begin rd<=wr-(branch?11'd3:11'd384)-motion[18:8];fraction<=motion[7:0];state<=3;end
    3:state<=4;
    4:begin prev_l<=motion_q[15:0];prev_r<=motion_q[31:16];state<=5;end
    5:begin wet_l<=filled==2048?sat(($signed(dry_l)+$signed(prev_l)+(product_l>>>16))>>>1):dry_l;wet_r<=filled==2048?sat(($signed(dry_r)+$signed(prev_r)+(product_r>>>16))>>>1):dry_r;state<=7;end
    7:begin if(branch_peak>level[branch])level[branch]<=branch_peak;sum_l<=sum_l+(product_l>>>16);sum_r<=sum_r+(product_r>>>16);if(!branch)begin branch<=1;state<=1;end else state<=9;end
    9:begin wet_l<=($signed(crush_l)>>>p[8][15:12])<<<p[8][15:12];wet_r<=($signed(crush_r)>>>p[8][15:12])<<<p[8][15:12];state<=10;end
    10:begin if(branch_peak>level[2])level[2]<=branch_peak;sum_l<=sum_l+(product_l>>>16);sum_r<=sum_r+(product_r>>>16);state<=12;end
    12:state<=13;
    13:begin prev_l<=freeze_q[15:0];prev_r<=freeze_q[31:16];fraction<=fr>=1920?{fr[6:0],1'd0}:8'd0;state<=14;end
    14:begin wet_l<=ffilled==2048&&p[11][15]?sat($signed(prev_l)+(product_l>>>16)):dry_l;wet_r<=ffilled==2048&&p[11][15]?sat($signed(prev_r)+(product_r>>>16)):dry_r;state<=16;end
    16:begin if(branch_peak>level[3])level[3]<=branch_peak;sum_l<=sum_l+(product_l>>>16);sum_r<=sum_r+(product_r>>>16);state<=18;end
    18:begin mod_depth<=product_l[31:16];state<=19;end
    19:begin wet_l<=product_l>>>16;wet_r<=product_r>>>16;state<=21;end
    21:begin if(branch_peak>level[4])level[4]<=branch_peak;sum_l<=sum_l+(product_l>>>16);sum_r<=sum_r+(product_r>>>16);state<=23;end
    23:begin mod_depth<=product_l[31:16];state<=24;end
    24:begin wet_l<=product_l>>>16;wet_r<=product_r>>>16;state<=26;end
    26:begin if(branch_peak>level[5])level[5]<=branch_peak;sum_l<=sum_l+(product_l>>>16);sum_r<=sum_r+(product_r>>>16);state<=28;end
    28:begin level[7]<=env[15:8];envelope_mod<=p[0][6]&&!p[1][6]?{product_l[30:16],1'b0}:16'd0;state<=29;end
    29:begin fx_gain<=bypass==0?master:product_l[31:16];state<=31;end
    31:begin whole_l<=sum_l[18:16];whole_r<=sum_r[18:16];sum_l<=$signed({3'd0,product_l[31:16]});sum_r<=$signed({3'd0,product_r[31:16]});state<=32;end
    32,33,34:begin if(whole_bit_l)sum_l<=sum_l+master_step;if(whole_bit_r)sum_r<=sum_r+master_step;state<=state+1'b1;end
    35:begin if(level8(out_l,out_r)>level[6])level[6]<=level8(out_l,out_r);out_l<=sat($signed(original_l)+$signed(sum_l));out_r<=sat($signed(original_r)+$signed(sum_r));done<=1;state<=0;end
    default:state<=0;
   endcase
  end
 end
endmodule
`default_nettype wire
