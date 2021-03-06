// ========== Copyright Header Begin ==========================================
// 
// OpenSPARC T1 Processor File: mul64.v
// Copyright (c) 2006 Sun Microsystems, Inc.  All Rights Reserved.
// DO NOT ALTER OR REMOVE COPYRIGHT NOTICES.
// 
// The above named program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License version 2 as published by the Free Software Foundation.
// 
// The above named program is distributed in the hope that it will be 
// useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// General Public License for more details.
// 
// You should have received a copy of the GNU General Public
// License along with this work; if not, write to the Free Software
// Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.
// 
// ========== Copyright Header End ============================================
/*//////////////////////////////////////////////////////////////////////
//
//  Module Name: mul64
//  Description:        *This block implements the multiplier used in the modular multiplier
//                       unit (MUL) and be shared by sparc EXU and the streaming unit (SPU).
//                       It is also used as the 54x54 multiplier in the FPU.
//                      *It takes two 64-bit unsign data and accumulated operand and do the
//                       64x64 MAC operation at two cycle thruput and 5 cycle latency.
//                      *The mul_valid signal indicate the beginning of a new operation.
//                       It MUST be dis-asserted at the next cycle to have the proper 2-cycle
//                       latency operation in the csa array. If there are two back-to-back
//                       cycle operation, the first operation result will be incorrect.
//                      *Results are avaliable on the 5th cycle of the mul_valid as shows
//
//			*Following inputs should tie to "0" when used as a 64x64 multiplier
//			 - areg 
//			 - accreg 
//			 - x2
//
//                         Cycle-0  | Cycle-1 | Cycle-2 | Cycle-3 | Cycle-4 | Cycle-5
//                       1st        *         |         |         |         |
//                       rs1, rs2   ^         |         |         |         | 1st results
//                       valid=1    | valid=0 |         *         |         | avaliable
//                                1st         | 2nd OP  ^         |         |
//                                setup       | valid=1 |         |         |
//                                            |        2nd        |         |
//                                            |       setup       |         |
//
*/

//FPGA_SYN enables all FPGA related modifications





module mul64(rs1_l, rs2, valid, areg, accreg, x2, out, rclk, si, so, se, 
	mul_rst_l, mul_step);

	input	[63:0]		rs1_l;
	input	[63:0]		rs2;
	input			valid;
	input	[96:0]		areg;
	input	[135:129]	accreg;
	input			x2;
	input			rclk;
	input			si;
	input			se;
	input			mul_rst_l;
	input			mul_step;
	output			so;
	output	[135:0]		out;

reg [135:0] myout, myout_a1, myout_a2, myout_a3;

reg [63:0] rs1_ff;
reg [64:0] rs2_ff;

reg [63:0] par1, par2;
reg [64:0] par3, par4;

reg [5:0] state;

always @(posedge rclk)
  state <= {valid,state[5:1]};


always @(posedge rclk) begin
  if(mul_step) begin
    if(valid) begin
      rs1_ff <= ~rs1_l;
      rs2_ff <= x2 ? {rs2,1'b0} : {1'b0,rs2};
    end else begin
      rs1_ff <= {32'b0, rs1_ff[63:32]};
    end
    par1 <= (rs1_ff[31:0] * rs2_ff[31:0]);
    par3 <= rs1_ff[31:0] * rs2_ff[64:32];
    myout_a1 <= ({32'b0, myout_a1[135:32]} & {136{state[3]}}) + par1 + {par3, 32'b0} + areg;
    myout <= {(myout_a1[103:97]+accreg),myout_a1[96:0],myout[63:32]};
  end 
end

assign out = myout;
assign so = 1'b0;

endmodule

































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































