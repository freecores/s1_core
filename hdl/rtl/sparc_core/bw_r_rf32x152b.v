// ========== Copyright Header Begin ==========================================
// 
// OpenSPARC T1 Processor File: bw_r_rf32x152b.v
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
////////////////////////////////////////////////////////////////////////
/*
//      Description:    DCache Fill Queue of Load Store Unit.
//                      - Contains invalidates and loads.
//                      - loads will bypass and/or fill dcache.
//                      - Entry at head of queue may have to
//                      be held for multiple passes.
//
*/

////////////////////////////////////////////////////////////////////////
// Local header file includes / local defines
////////////////////////////////////////////////////////////////////////

//FPGA_SYN enables all FPGA related modifications
 




module bw_r_rf32x152b (/*AUTOARG*/
   // Outputs
   dout, so, 
   // Inputs
   rd_en, rd_adr, wr_en, wr_adr, din, 
   si, se, sehold, rclk, rst_tri_en, reset_l);  

parameter NUMENTRIES = 32 ;     // number of entries in dfq 

input [4:0]   rd_adr;     // read adr. 
input         rd_en;      // read pointer
input         wr_en;      // write pointer vld
input [4:0]   wr_adr;     // write adr.
input [151:0] din;            // wr data 
input             rclk;       // clock
input         reset_l;    // active low reset
input         rst_tri_en; // reset and scan  
input         sehold;     // scan hold 
input             si;             // scan in 
input             se;             // scan enable 

output  [151:0] dout ; // data read out
output                  so ;   // scan out  

wire [151:0]    dout;
wire clk; 
wire wr_vld; 

reg     [151:0]         dfq_mem [NUMENTRIES-1:0] /* synthesis syn_ramstyle = block_ram  syn_ramstyle = no_rw_check */ ;

reg [151:0]     local_dout;
// reg                  so; 

integer i,j;

//
// added for atpg support
wire [4:0]   sehold_rd_adr;        // output of sehold mux - read adr. 
wire         sehold_rd_en;         // output of sehold mux - read pointer
wire         sehold_wr_en;         // output of sehold mux - write pointer vld
wire [4:0]   sehold_wr_adr;        // output of sehold mux - write adr.
wire [151:0]  sehold_din;          // wr data 

wire [4:0]   rd_adr_d1;    // flopped read adr. 
wire         rd_en_d1;     // flopped read pointer
wire         wr_en_d1;     // flopped write pointer vld
wire [4:0]   wr_adr_d1;    // flopped write adr.
wire [151:0]  din_d1;      // flopped wr data 

//
// creating local clock
assign clk=rclk;
// 
//=========================================================================================
//      support for atpg pattern generation
//=========================================================================================
//
// read controls
dp_mux2es #(6) mux_sehold_rd_ctrl (
    .in0  ({rd_adr[4:0], rd_en}),
    .in1  ({rd_adr_d1[4:0], rd_en_d1}),
    .sel  (sehold),
    .dout ({sehold_rd_adr[4:0],sehold_rd_en})
);

dff #(6) dff_rd_ctrl_d1(
    .din ({sehold_rd_adr[4:0], sehold_rd_en}),
    .q   ({rd_adr_d1[4:0], rd_en_d1}),
    .clk (clk), 
    .se  (se),
    .si  (),
    .so  ()
);
//
// write controls
dp_mux2es #(6) mux_sehold_wr_ctrl (
        .in0    ({wr_adr[4:0], wr_en}),
        .in1    ({wr_adr_d1[4:0], wr_en_d1}),
        .sel    (sehold),
        .dout   ({sehold_wr_adr[4:0],sehold_wr_en})
);

dff #(6) dff_wr_ctrl_d1(
    .din ({sehold_wr_adr[4:0], sehold_wr_en}),
    .q   ({wr_adr_d1[4:0], wr_en_d1}),
    .clk (clk), 
    .se  (se),
    .si  (),
    .so  ()
);
//
// write data
dp_mux2es #(152) mux_sehold_din (
        .in0    (din[151:0]),
        .in1    (din_d1[151:0]),
        .sel    (sehold),
        .dout   (sehold_din[151:0])
);

dff #(152) dff_din_d1(
    .din (sehold_din[151:0]),
    .q   (din_d1[151:0]),
    .clk (clk), 
    .se  (se),
    .si  (),
    .so  ()
);

//
// diable write to register file during reset or scan
assign wr_vld = sehold_wr_en & ~rst_tri_en & reset_l; 

//    always @ (posedge clk)
//      begin
//         so <= 1'bx;
//      end

//=========================================================================================
//      generate wordlines
//=========================================================================================

// Word-Line Generation skipped. Implicit in read and write.

//=========================================================================================
//      write or read to/from memory
//=========================================================================================


always @ ( posedge clk ) 
        begin
                if (wr_vld)
                 dfq_mem[sehold_wr_adr] = sehold_din[151:0] ;
		end

always @ ( posedge clk ) 
        begin
                   if (sehold_rd_en)
                      begin 

		local_dout[151:0] <= dfq_mem[sehold_rd_adr[4:0]];










                    end     
        end











assign dout[151:0] = local_dout[151:0];








































endmodule
