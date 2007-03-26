// ========== Copyright Header Begin ==========================================
// 
// OpenSPARC T1 Processor File: bw_r_tlb.v
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
///////////////////////////////////////////////////////////////////////
/*
//	Description:	Common TLB for Instruction Fetch and Load/Stores
*/
////////////////////////////////////////////////////////////////////////
// Global header file includes
////////////////////////////////////////////////////////////////////////
`include	"sys.h" // system level definition file which contains the 
					// time scale definition

////////////////////////////////////////////////////////////////////////
// Local header file includes / local defines
////////////////////////////////////////////////////////////////////////
`include	"lsu.h"

//FPGA_SYN enables all FPGA related modifications
`ifdef FPGA_SYN
`define FPGA_SYN_TLB
`endif


`ifdef FPGA_SYN_TLB
`define TLB_ENTRIES 8
`define TLB_INDEX_WIDTH 3
module bw_r_tlb ( /*AUTOARG*/
   // Outputs
   tlb_rd_tte_tag, tlb_rd_tte_data, tlb_pgnum, tlb_pgnum_crit, 
   tlb_cam_hit, cache_way_hit, cache_hit, so, 
   // Inputs
   tlb_cam_vld, tlb_cam_key, tlb_cam_pid,  
   tlb_demap_key, tlb_addr_mask_l, tlb_ctxt, 
   tlb_wr_vld, tlb_wr_tte_tag, tlb_wr_tte_data, tlb_rd_tag_vld, 
   tlb_rd_data_vld, tlb_rw_index, tlb_rw_index_vld, tlb_demap, 
   tlb_demap_auto, tlb_demap_all, cache_ptag_w0, cache_ptag_w1, 
   cache_ptag_w2, cache_ptag_w3, cache_set_vld, tlb_bypass_va, 
   tlb_bypass, se, si, hold, adj, arst_l, rst_soft_l, rclk,
   rst_tri_en
   ) ;	


input			tlb_cam_vld ;		// ld/st requires xlation. 
input	[40:0]		tlb_cam_key ;		// cam data for loads/stores;includes vld 
						// CHANGE : add real bit for cam.
input	[2:0]		tlb_cam_pid ;		// NEW: pid for cam. 
input	[40:0]		tlb_demap_key ;		// cam data for demap; includes vlds. 
						// CHANGE : add real bit for demap
input			tlb_addr_mask_l ;	// address masking occurs
input	[12:0]		tlb_ctxt ;		// context for cam xslate/demap. 
input			tlb_wr_vld;		// write to tlb. 
input	[58:0]		tlb_wr_tte_tag;		// CHANGE:tte tag to be written (55+4-1)
						// R(+1b),PID(+3b),G(-1b). 
input	[42:0]		tlb_wr_tte_data;	// tte data to be written.
						// No change(!!!) - G bit becomes spare
input			tlb_rd_tag_vld ;	// read tag
input			tlb_rd_data_vld ;	// read data
input	[5:0]		tlb_rw_index ;		// index to read/write tlb.
input			tlb_rw_index_vld ;	// indexed write else use algorithm.
input			tlb_demap ;		// demap : page/ctxt/all/auto.  
input			tlb_demap_auto ;	// demap is of type auto 
input			tlb_demap_all;		// demap-all operation : encoded separately.
input  	[29:0]    	cache_ptag_w0;       	// way1 30b(D)/29b(I) tag.
input  	[29:0]    	cache_ptag_w1;       	// way2 30b(D)/29b(I) tag.
input  	[29:0]     	cache_ptag_w2;       	// way0 30b(D)/29b(I) tag.
input  	[29:0]     	cache_ptag_w3;       	// way3 30b(D)/29b(I) tag.
input	[3:0]		cache_set_vld;       	// set vld-4 ways
input	[12:10]		tlb_bypass_va;	   	// bypass va.other va bits from cam-data
input			tlb_bypass;		// bypass tlb xslation

input			se ;			// scan-enable ; unused
input			si ;			// scan data in ; unused
input			hold ;			// scan hold signal
input	[7:0]		adj ;			// self-time adjustment ; unused
input			arst_l ;		// synchronous for tlb ; unused	
input			rst_soft_l ;		// software reset - asi
input			rclk;
input			rst_tri_en ;

output	[58:0]		tlb_rd_tte_tag;		// CHANGE: tte tag read from tlb.
output	[42:0]		tlb_rd_tte_data;	// tte data read from tlb.
// Need two ports for tlb_pgnum - critical and non-critical.
output	[39:10]		tlb_pgnum ;		// bypass or xslated pgnum
output	[39:10]		tlb_pgnum_crit ;	// bypass or xslated pgnum - critical
output			tlb_cam_hit ;		// xlation hits in tlb.
output	[3:0]		cache_way_hit;		// tag comparison results.
output			cache_hit;		// tag comparison result - 'or' of above.

//output			tlb_writeable ;		// tlb can be written in current cycle.

output			so ;		// scan data out ; unused

wire	[53:0]		tlb_cam_data ;
wire	[58:0]		wr_tte_tag ;	// CHANGE
wire	[42:0]		wr_tte_data ;
wire	[29:3]		phy_pgnum_m;
wire	[29:0]		pgnum_m;
wire 	[`TLB_ENTRIES-1:0] used ;
wire			tlb_not_writeable ;
wire	[40:25] 	tlb_cam_key_masked ;
wire	[26:0]		tlb_cam_comp_key ;
wire			cam_vld ;
wire			demap_other ;
wire	[3:0]   	cache_way_hit ;
wire	[`TLB_ENTRIES-1:0]		mismatch;

reg			tlb_not_writeable_d1 ;
reg			tlb_writeable ;
wire	[`TLB_ENTRIES-1:0]		tlb_entry_locked ;
wire	[`TLB_ENTRIES-1:0]		cam_hit ;
wire	[`TLB_ENTRIES-1:0]		demap_hit ;
reg	[`TLB_ENTRIES-1:0]		ademap_hit ;
wire	[58:0]		rd_tte_tag ;	// CHANGE
wire	[42:0]		rd_tte_data ;	
reg	[58:0]		tlb_rd_tte_tag ; // CHANGE	
reg	[42:0]		tlb_rd_tte_data ;	
reg			cam_vld_tmp ;
reg	[2:0]		cam_pid ;
reg	[53:0]		cam_data ;
reg			demap_auto, demap_other_tmp, demap_all ;
reg	[`TLB_ENTRIES-1:0]		tlb_entry_vld ;
wire	[`TLB_ENTRIES-1:0]		tlb_entry_used ;
reg	[`TLB_ENTRIES-1:0]		tlb_entry_replace ;
reg	[`TLB_ENTRIES-1:0]		tlb_entry_replace_d2 ;
reg	[29:0]		pgnum_g ;
reg     [3:0]		cache_set_vld_g;
reg	[29:0]		cache_ptag_w0_g,cache_ptag_w1_g;
reg	[29:0]		cache_ptag_w2_g,cache_ptag_w3_g;
reg	[`TLB_ENTRIES-1:0]		rw_wdline ;

reg			rd_tag; 
reg			rd_data;
reg			wr_vld_tmp;
reg	[`TLB_INDEX_WIDTH-1:0]		rw_index;
reg			rw_index_vld;
wire	[29:0] 		vrtl_pgnum_m;
wire			bypass ;

wire			wr_vld ;

integer	i,j,k,l,m,n,p,r,s,t,u,w;

`define	CAM_CTXT_12_0_HI 	12 	// 13b ctxt
`define	CAM_CTXT_12_0_LO 	0 		


//=========================================================================================
//	What's Left :
//=========================================================================================

// Scan Insertion - scan to be ignored in formal verification for now.

//=========================================================================================
//	Design Notes.
//=========================================================================================

// - Supported Demap Operations - By Page, By Context, All But
// Locked, Autodemap, Invalidate-All i.e., reset. Demap Partition is
// not supported - it is mapped to demap-all by logic. 
// - Interpretation of demap inputs
//	- tlb_demap - this is used to signal demap by page, by ctxt
//	,all, and autodemap. 
//	- tlb_demap_ctxt - If a demap_by_ctxt operation is occuring then
//	this signal and tlb_demap must be active.
//	- tlb_demap_all - demap all operation. If a demap_all operation is
//	occuring, then tlb_demap_all must be asserted with tlb_demap. 
// - Reset is similar to demap-all except that *all* entries
// are invalidated. The action is initiated by software. The reset occurs
// on the negedge and is synchronous with the clk.
// - TTE Tag and Data
// 	- The TTE tag and data can be read together. Each will have its 
//	own bus and the muxing will occur externally. The tag needs to
//	be read on a data request to supply the valid bit.
// 	- The TTE tag and data can be written together.
// - The cam hit is a separate output signal based on the 
// the match signals.
// - Read/Write may occur based on supplied index. If not valid
// then use replacement way determined by algorithm to write.
// - Only write can use replacement way determined by algorithm.
// - Data is formatted appr. on read or write in the MMU. 
// - The TLB will generate a signal which reports whether the 
// tlb can be filled in the current cycle or not.
// **Physical Tag Comparison**
// For I-SIDE, comparison is of 28b, whereas for D-side, comparison is of 29b. The actual
// comparison, due to legacy, is for 30b.
// For the I-TLB, va[11:10] must be hardwired to the same value as the lsb of the 4 tags
// at the port level. Since the itag it only 28b, add two least significant bits to extend it to 30b.
// Similarly, for the dside, va[10] needs to be made same.	
// **Differentiating among Various TLB Operations**
// Valid bits are now associated with the key to allow selective incorporation of
// match results. The 5 valid bits are : v4(b47-28),v3(b27-22),v2(21-16),v1(b15-13)
// and Gk(G bit for auto-demap). The rules of use are :
//	- cam: v4-v1 are set high. G=~cam_real=0/1.
//	- demap_by_page : v4-v1 are set high. G=1. cam_real=0.
// 	- demap_by_ctxt : v4-v1 are low. G=1. cam_real=0
//	- demap_all : v4-v1 are don't-care. G=x. cam_real=x
//	- autodemap : v4-v1 are based on page size of incoming tte. G=~cam_real=0/1.
// Note : Gk is now used only to void a context match on a Real Translation.
// In general, if a valid bit is low then the corresponding va field will not take
// part in the match. Similarly, for the ctxt, if Gk=1, the ctxt will participate
// in the match.
//
// Demap Table (For Satya) :
// Note : To include a context match, Gk must be set to 1.
//--------------------------------------------------------------------------------------------------------
//tlb_demap tlb_demap_all  tlb_ctxt Gk	Vk4 Vk3	Vk2 Vk1 Real	Operation
//--------------------------------------------------------------------------------------------------------
//0		x		x   x	x   x	x   x   0	No demap operation
//1		0		0   1	1   1	1   1	0	Demap by page
//1		0		0   1	1   0	0   0	0/1	256M demap(auto demap)
//1		0		0   0	1   0	0   0	0	256M demap(auto demap) (*Illgl*)
//1		0		0   1	1   1	0   0	0/1	4M demap(auto demap)
//1		0		0   0	1   1	0   0	0	4M demap(auto demap) (*Illgl*)
//1		0		0   1	1   1	1   0	0/1	64k demap(auto demap)
//1		0		0   0	1   1	1   0	0	64k demap(auto demap) (*Illgl*)
//1		0		0   1	1   1	1   1	0/1	8k demap(auto demap)
//1		0		0   0	1   1	1   1	0	8k demap(auto demap) (*Illgl*)
//1		0		1   1	0   0	0   0	0	demap by ctxt
//1		1		x   x	x   x	x   x	0	demap_all
//------------------------------------------------------------------------------------------
//-----
//All other are illegal combinations
//
//=========================================================================================
//	Changes related to Hypervisor/Legacy Compatibility
//=========================================================================================
//
// - Add PID. PID does not effect demap-all. Otherwise it is included in cam, other demap
// operations and auto-demap.
// - Add R. Real translation ignores context. This is controlled externally by Gk.
// - Remove G bit for tte. Input remains in demap-key/cam-key to allow for disabling
//   of context match Real Translation  
// - Final Page Size support - 8KB,64KB,4M,256M
// - SPARC_HPV_EN has been defined to enable new tlb design support. 
// Issues : 
// -Max ptag size is now 28b. Satya, will this help the speed at all. I doubt it !

//=========================================================================================
//	Miscellaneous
//=========================================================================================
   wire clk;
   assign clk = rclk;
   
wire async_reset, sync_reset ;
assign	async_reset = ~arst_l ; 			// hardware
assign	sync_reset = (~rst_soft_l & ~rst_tri_en) ;	// software

wire rw_disable ;
// INNO - wr/rd gated off. Note required as rst_tri_en is
// asserted, but implemented in addition in schematic.
assign	rw_disable = ~arst_l | rst_tri_en ;


reg     [`TLB_INDEX_WIDTH-1:0]   cam_hit_encoded;
integer ii;

reg cam_hit_any;

always @(cam_hit) begin
  cam_hit_any = 1'b0;
  cam_hit_encoded = {`TLB_INDEX_WIDTH{1'b0}};
  for(ii=0;ii<`TLB_ENTRIES;ii=ii+1) begin
    if(cam_hit[ii]) begin
      cam_hit_encoded = ii;
      cam_hit_any = 1'b1;
    end
  end
end

reg cam_hit_any_or_bypass;

always @(posedge clk) 
  cam_hit_any_or_bypass <= cam_hit_any | bypass;  



//=========================================================================================
// 	Stage Data
//=========================================================================================
// Apply address masking
assign	tlb_cam_key_masked[40:25]
	= {16{tlb_addr_mask_l}} & 
		tlb_cam_key[`CAM_VA_47_28_HI:`CAM_VA_47_28_LO+4] ;

// Reconstitute cam data CHANGE : add additional bit for real mapping
assign	tlb_cam_data[53:13] = tlb_demap ? 
	tlb_demap_key[40:0] :
	{tlb_cam_key_masked[40:25],tlb_cam_key[`CAM_VA_47_28_LO+3:0]} ; 

assign tlb_cam_comp_key[26:0] = 
		tlb_demap ?
			{tlb_demap_key[32:21], tlb_demap_key[19:14],tlb_demap_key[12:7],
			tlb_demap_key[5:3]} :
			{tlb_cam_key_masked[32:25],tlb_cam_key[24:21],
			tlb_cam_key[19:14],tlb_cam_key[12:7],tlb_cam_key[5:3]} ;

assign	tlb_cam_data[12:0] = tlb_ctxt[12:0] ;

// These signals are flow-thru.
assign	wr_tte_tag[58:0] 	= tlb_wr_tte_tag[58:0] ;	// CHANGE
assign	wr_tte_data[42:0] 	= tlb_wr_tte_data[42:0] ;

// CHANGE(SATYA) - Currently the rw_index/rw_index_vld are shared by both reads
// and writes. However, writes are done in the cycle of broadcast, whereas
// the reads are done a cycle later, as given in the model(incorrect) 
// They have to be treated uniformly. To make the model work, I've assumed the read/write 
// are done in the cycle the valids are broadcast. 
always @ (posedge clk)
	begin
	if (hold)
		begin
		cam_pid[2:0]		<= cam_pid[2:0] ;
		cam_vld_tmp		<= cam_vld_tmp ;
		cam_data[53:0] 		<= cam_data[53:0] ;
		demap_other_tmp		<= demap_other_tmp ;
		demap_auto		<= demap_auto ;
		demap_all		<= demap_all ;
		wr_vld_tmp 		<= wr_vld_tmp ;
		rd_tag 			<= rd_tag ;
		rd_data			<= rd_data ;
		rw_index_vld		<= rw_index_vld ;
		rw_index[`TLB_INDEX_WIDTH-1:0]		<= rw_index[`TLB_INDEX_WIDTH-1:0] ; 	
		end
	else
		begin
		cam_pid[2:0]		<= tlb_cam_pid[2:0] ;
		cam_vld_tmp		<= tlb_cam_vld ;
		cam_data[53:0] 		<= tlb_cam_data[53:0] ;
		demap_other_tmp		<= tlb_demap ;
		demap_auto		<= tlb_demap_auto ;
		demap_all		<= tlb_demap_all ;
		wr_vld_tmp 		<= tlb_wr_vld ;
		rd_tag 			<= tlb_rd_tag_vld ;
		rd_data			<= tlb_rd_data_vld ;
		rw_index_vld		<= tlb_rw_index_vld ;
		rw_index[`TLB_INDEX_WIDTH-1:0]		<= tlb_rw_index[`TLB_INDEX_WIDTH-1:0] ; 	
		end

	end

// INNO - gate cam,demap,wr with rst_tri_en.
reg rst_tri_en_lat;

 always        @ (clk)
 rst_tri_en_lat = rst_tri_en;

assign	cam_vld = cam_vld_tmp & ~rst_tri_en_lat ;
assign	demap_other = demap_other_tmp & ~rst_tri_en ;
assign	wr_vld = wr_vld_tmp & ~rst_tri_en ;

//=========================================================================================
//	Generate Write Wordlines
//=========================================================================================



// Stage to next cycle.
always	@ (posedge clk)
	begin
		tlb_rd_tte_tag[58:0] 	<= rd_tte_tag[58:0] ;	// CHANGE
		tlb_rd_tte_data[42:0] 	<= rd_tte_data[42:0] ;
	end

//=========================================================================================
//	CAM/DEMAP STLB for xlation
//=========================================================================================


// Demap and CAM operation are mutually exclusive.

always  @ ( negedge clk )
	begin
	
		for (n=0;n<`TLB_ENTRIES;n=n+1)
			begin
                                if (demap_auto & demap_other) 
					ademap_hit[n] = (~mismatch[n] & demap_other & tlb_entry_vld[n]) ;
			end

	end  // always


assign	tlb_cam_hit = |cam_hit[`TLB_ENTRIES-1:0] ;

// Change tlb_entry_vld handling for multi-threaded tlb writes.
// A write is always preceeded by an autodemap. The intent is to make the result of autodemap
// (clearing of vld bit if hit) invisible until write occurs. In the same cycle that the write
// occurs, the vld bit for an entry will be cleared if there is an autodemap hit. The write
// and admp action may even be to same entry. The write must dominate. There is no need to
// clear the dmp latches after the write/clear has occurred as the subsequent admp will set
// up new state in the latches.

// Define valid bit based on write/demap/reset. 

always  @ (/*AUTOSENSE*/rd_data or rd_tag or rw_index or rw_index_vld
           or wr_vld_tmp)
        begin
                for (i=0;i<`TLB_ENTRIES;i=i+1)
                        if ((rw_index[`TLB_INDEX_WIDTH-1:0] == i) & ((wr_vld_tmp & rw_index_vld) | rd_tag | rd_data))
                                rw_wdline[i] = 1'b1 ;
                        else    rw_wdline[i] = 1'b0 ;

        end


always @ (negedge clk)
	begin
	for (r=0;r<`TLB_ENTRIES;r=r+1)
	begin // for
	if (((rw_index_vld & rw_wdline[r]) | (~rw_index_vld & tlb_entry_replace_d2[r])) & 
		wr_vld & ~rw_disable)
			tlb_entry_vld[r] <= wr_tte_tag[`STLB_TAG_V] ;	// write
	else	begin
		if (ademap_hit[r] & wr_vld)			// autodemap specifically
			tlb_entry_vld[r] <= 1'b0 ;		
		end
	  if ((demap_hit[r] & ~demap_auto) | sync_reset)	// non-auto-demap, reset
			tlb_entry_vld[r] <= 1'b0 ;	
	  if(async_reset) tlb_entry_vld[r] <= 1'b0 ;

	end // for
	end


//=========================================================================================
//	TAG COMPARISON
//=========================================================================================

reg [30:0] va_tag_plus ;

// Stage to m
always @(posedge clk)
		begin
		// INNO - add hold to this input
		if (hold)
			va_tag_plus[30:0] <= va_tag_plus[30:0] ;
		else
			va_tag_plus[30:0] 
			<= {tlb_cam_comp_key[26:0],tlb_bypass_va[12:10],tlb_bypass}; 
		end
			
assign vrtl_pgnum_m[29:0] = va_tag_plus[30:1] ;
assign bypass = va_tag_plus[0] ;

// Mux to bypass va or form pa tag based on tte-data.

assign	phy_pgnum_m[29:3] = 
	{rd_tte_data[`STLB_DATA_PA_39_28_HI:`STLB_DATA_PA_39_28_LO],
		rd_tte_data[`STLB_DATA_PA_27_22_HI:`STLB_DATA_PA_27_22_LO],
			rd_tte_data[`STLB_DATA_PA_21_16_HI:`STLB_DATA_PA_21_16_LO],
				rd_tte_data[`STLB_DATA_PA_15_13_HI:`STLB_DATA_PA_15_13_LO]};

// Derive the tlb-based physical address.
assign pgnum_m[2:0] = vrtl_pgnum_m[2:0];
assign pgnum_m[5:3] = (~rd_tte_data[`STLB_DATA_15_13_SEL] & ~bypass)
				? phy_pgnum_m[5:3] : vrtl_pgnum_m[5:3] ;
assign pgnum_m[11:6] = (~rd_tte_data[`STLB_DATA_21_16_SEL] & ~bypass)  
				? phy_pgnum_m[11:6] : vrtl_pgnum_m[11:6] ;
assign pgnum_m[17:12] = (~rd_tte_data[`STLB_DATA_27_22_SEL] & ~bypass)
				? phy_pgnum_m[17:12] : vrtl_pgnum_m[17:12] ;
assign pgnum_m[29:18] = ~bypass ? phy_pgnum_m[29:18] : vrtl_pgnum_m[29:18];

// Stage to g
// Flop tags in tlb itself and do comparison immediately after rising edge.
// Similarly stage va/pa tag to g
always @(posedge clk)
		begin
			pgnum_g[29:0] <= pgnum_m[29:0];
			// rm hold on these inputs.
			cache_set_vld_g[3:0]  	<= cache_set_vld[3:0] ;
			cache_ptag_w0_g[29:0] 	<= cache_ptag_w0[29:0] ;
			cache_ptag_w1_g[29:0] 	<= cache_ptag_w1[29:0] ;
			cache_ptag_w2_g[29:0] 	<= cache_ptag_w2[29:0] ;
			cache_ptag_w3_g[29:0] 	<= cache_ptag_w3[29:0] ;
		end


// Need to stage by a cycle where used.
assign	tlb_pgnum[39:10] = pgnum_g[29:0] ;
// Same cycle as cam - meant for one load on critical path
assign	tlb_pgnum_crit[39:10] = pgnum_m[29:0] ;


assign	cache_way_hit[0] = 
	(cache_ptag_w0_g[29:0] == pgnum_g[29:0]) & cache_set_vld_g[0] & cam_hit_any_or_bypass;
assign	cache_way_hit[1] = 
	(cache_ptag_w1_g[29:0] == pgnum_g[29:0]) & cache_set_vld_g[1] & cam_hit_any_or_bypass;
assign	cache_way_hit[2] = 
	(cache_ptag_w2_g[29:0] == pgnum_g[29:0]) & cache_set_vld_g[2] & cam_hit_any_or_bypass;
assign	cache_way_hit[3] = 
	(cache_ptag_w3_g[29:0] == pgnum_g[29:0]) & cache_set_vld_g[3] & cam_hit_any_or_bypass;

assign	cache_hit = |cache_way_hit[3:0];


//=========================================================================================
//	TLB ENTRY REPLACEMENT
//=========================================================================================

// A single Used bit is used to track the replacement state of each entry.
// Only an unused entry can be replaced.
// An Unused entry is :
//			- an invalid entry
//			- a valid entry which has had its Used bit cleared.
//				- on write of a valid entry, the Used bit is set.
//				- The Used bit of a valid entry is cleared if all
//				entries have their Used bits set and the entry itself is not Locked.
// A locked entry should always appear to be Used.
// A single priority-encoder is required to evaluate the used status. Priority is static
// and used entry0 is of the highest priority if unused.

// Timing :
// Used bit gets updated by cam-hit or hit on negedge.
// After Used bit gets updated off negedge, the replacement entry can be generated in
// Phase2. In parallel, it is determined whether all Used bits are set or not. If
// so, then they are cleared on the next negedge with the replacement entry generated
// in the related Phase1 

// Choosing replacement entry
// Replacement entry is integer k

assign	tlb_not_writeable = &used[`TLB_ENTRIES-1:0] ;
/*
// Used bit can be set because of write or because of cam-hit.
always @(negedge clk)
	begin
		for (s=0;s<`TLB_ENTRIES;s=s+1)
			begin
				if (cam_hit[s]) 
					tlb_entry_used[s] <= 1'b1;			
			end

// Clear on following edge if necessary.
// CHANGE(SATYA) : tlb_entry_used qualified with valid needs to be used to determine
// whether the Used bits are to be cleared. This allows invalid entries created
// by a demap to be used for replacement. Else we will ignore these entries
// for replacement

		if (tlb_not_writeable)
			begin
				for (t=0;t<`TLB_ENTRIES;t=t+1)
					begin
						if (~tlb_entry_locked[t])
							tlb_entry_used[t] <= 1'b0;
					end
			end
	end
*/

// Determine whether entry should be squashed.

assign	used[`TLB_ENTRIES-1:0] = tlb_entry_used[`TLB_ENTRIES-1:0] & tlb_entry_vld[`TLB_ENTRIES-1:0] ;


// Based on updated Used state, generate replacement entry.
// So, replacement entries can be generated on a cycle-by-cycle basis. 
//always @(/*AUTOSENSE*/squash or used)

	reg	[`TLB_ENTRIES-1:0]	tlb_entry_replace_d1;
	reg		tlb_replace_flag;
	always @(/*AUTOSENSE*/used)
	begin
  	  tlb_replace_flag=1'b0;
  	  tlb_entry_replace_d1 = {`TLB_ENTRIES-1{1'b0}};
  	  // Priority is given to entry0
   	  for (u=0;u<`TLB_ENTRIES;u=u+1)
  	  begin
    	    if(~tlb_replace_flag & ~used[u])
    	    begin
      	      tlb_entry_replace_d1[u] = ~used[u] ;
      	      tlb_replace_flag=1'b1; 
    	    end
  	  end
  	  if(~tlb_replace_flag) begin
      	     tlb_entry_replace_d1[`TLB_ENTRIES-1] = 1'b1;
 	  end
	end
	always @(posedge clk)
	begin
	  // named in this manner to keep arch model happy.
  	  tlb_entry_replace <= tlb_entry_replace_d1 ;
	end
	// INNO - 2 stage delay before update is visible
	always @(posedge clk)
	begin
  	  tlb_entry_replace_d2 <= tlb_entry_replace ;
	end

reg [`TLB_INDEX_WIDTH-1:0]  tlb_index_a1;
reg [`TLB_INDEX_WIDTH-1:0]  tlb_index;
wire tlb_index_vld_a1 = |tlb_entry_replace;
reg  tlb_index_vld;
integer jj;
always @(tlb_entry_replace) begin
  tlb_index_a1 = {`TLB_INDEX_WIDTH{1'b0}};
  for(jj=0;jj<`TLB_ENTRIES;jj=jj+1)
    if(tlb_entry_replace[jj]) tlb_index_a1 = jj;
end
always @(posedge clk) begin
  tlb_index <= tlb_index_a1;  //use instead of tlb_entry_replace_d2;
  tlb_index_vld <= tlb_index_vld_a1;
end


  

//=========================================================================================
//	TLB WRITEABLE DETECTION
//=========================================================================================

// 2-cycles later, tlb become writeable
always @(posedge clk)
	begin
		tlb_not_writeable_d1 <= tlb_not_writeable ;
	end

always @(posedge clk)
	begin
		tlb_writeable <= ~tlb_not_writeable_d1 ;
	end

bw_r_tlb_tag_ram bw_r_tlb_tag_ram (
	.rd_tag(rd_tag),
	.rw_index_vld(rw_index_vld),
	.wr_vld_tmp(wr_vld_tmp),
	.clk(clk),
	.rw_index(rw_index),
	.tlb_index(tlb_index),
	.tlb_index_vld(tlb_index_vld),
	.rw_disable(rw_disable),
	.rst_tri_en(rst_tri_en),
	.wr_tte_tag(wr_tte_tag),
	.tlb_entry_vld(tlb_entry_vld),
	.tlb_entry_used(tlb_entry_used),
	.tlb_entry_locked(tlb_entry_locked),
	.rd_tte_tag(rd_tte_tag),
	.mismatch(mismatch),
	.tlb_writeable(tlb_writeable),
	.cam_vld(cam_vld),
	.wr_vld(wr_vld),
	.cam_data(cam_data),
	.cam_hit(cam_hit),
	.cam_pid(cam_pid),
	.demap_all(demap_all),
	.demap_hit(demap_hit),
	.demap_other(demap_other)
);

bw_r_tlb_data_ram bw_r_tlb_data_ram (
	.rd_data(rd_data),
	.rw_index_vld(rw_index_vld),
	.wr_vld_tmp(wr_vld_tmp),
	.clk(clk),
	.cam_vld(cam_vld),
	.cam_index(cam_hit_encoded),
        .cam_hit_any(cam_hit_any),
	.rw_index(rw_index),
	.tlb_index(tlb_index),
	.tlb_index_vld(tlb_index_vld),
	.rw_disable(rw_disable),
	.rst_tri_en(rst_tri_en),
	.wr_tte_data(wr_tte_data),
	.rd_tte_data(rd_tte_data),
	.wr_vld(wr_vld)
);


endmodule

module bw_r_tlb_tag_ram(
	rd_tag,
	rw_index_vld,
	wr_vld_tmp,
	clk,
	rw_index,
	tlb_index,
	tlb_index_vld,
	rw_disable,
	rst_tri_en,
	wr_tte_tag,
	tlb_entry_vld,
	tlb_entry_used,
	tlb_entry_locked,
	rd_tte_tag,
	mismatch,
	tlb_writeable,
	wr_vld,
	cam_vld,
	cam_data,
	cam_hit,
	cam_pid,
	demap_all,
	demap_other,
	demap_hit);

input		rd_tag; 
input		rw_index_vld;
input		wr_vld_tmp;
input		clk;
input	[`TLB_INDEX_WIDTH-1:0]	rw_index;
input	[`TLB_INDEX_WIDTH-1:0]	tlb_index;
input		tlb_index_vld;
input		rw_disable;
input		rst_tri_en;
input	[58:0]	wr_tte_tag;
input	[`TLB_ENTRIES-1:0]	tlb_entry_vld;
input		tlb_writeable;
input		wr_vld;
input	[2:0]	cam_pid;
input		demap_all;
input		demap_other;
input	[53:0]	cam_data;
input		cam_vld ;

output	[`TLB_ENTRIES-1:0]	cam_hit ;
output	[`TLB_ENTRIES-1:0]	demap_hit ;
output	[`TLB_ENTRIES-1:0]	tlb_entry_used;
output	[`TLB_ENTRIES-1:0]	tlb_entry_locked;
reg	[`TLB_ENTRIES-1:0]	tlb_entry_locked ;

output	[58:0]	rd_tte_tag;
output	[`TLB_ENTRIES-1:0]	mismatch;

reg	[`TLB_ENTRIES-1:0]	sat;

reg	[`TLB_ENTRIES-1:0]	mismatch;
reg	[`TLB_ENTRIES-1:0]	cam_hit ;
reg	[`TLB_ENTRIES-1:0]	demap_all_but_locked_hit ;
reg	[58:0]	tag ;	// CHANGE

reg	[58:0]	rd_tte_tag;

reg	[`TLB_ENTRIES-1:0]	mismatch_va_b47_28;
reg	[`TLB_ENTRIES-1:0]	mismatch_va_b27_22;
reg	[`TLB_ENTRIES-1:0]	mismatch_va_b21_16;
reg	[`TLB_ENTRIES-1:0]	mismatch_va_b15_13;
reg	[`TLB_ENTRIES-1:0]	mismatch_ctxt;
reg	[`TLB_ENTRIES-1:0]	mismatch_pid;
reg	[`TLB_ENTRIES-1:0]	mismatch_type;
reg	[`TLB_ENTRIES-1:0]	tlb_entry_used ;

integer i,j,n,m, w, p, k, s, t;


reg	[58:0]		tte_tag_ram  [`TLB_ENTRIES-1:0] /* synthesis syn_ramstyle = block_ram  syn_ramstyle = no_rw_check */ ;



reg	[58:0]	tmp_tag ;

always	@ (negedge clk) begin
//=========================================================================================
//	Write TLB
//=========================================================================================
	if(rw_index_vld & wr_vld_tmp & ~rw_disable) begin
		tte_tag_ram[rw_index] <= wr_tte_tag[58:0];
		tlb_entry_used[rw_index] <= wr_tte_tag[`STLB_TAG_U];
		tlb_entry_locked[rw_index] = wr_tte_tag[`STLB_TAG_L];
		rd_tte_tag[58:0]  <= wr_tte_tag[58:0] ;	// CHANGE 
	end else 
	if(tlb_index_vld & ~rw_index_vld & wr_vld_tmp & ~rw_disable) begin
		tte_tag_ram[tlb_index] <= wr_tte_tag[58:0];
		tlb_entry_used[tlb_index] <= wr_tte_tag[`STLB_TAG_U];
		tlb_entry_locked[tlb_index] = wr_tte_tag[`STLB_TAG_L];
		rd_tte_tag[58:0]  <= wr_tte_tag[58:0] ;	// CHANGE 
	end else begin
	  tlb_entry_used <= (tlb_entry_used | cam_hit) & (tlb_entry_locked | ~{`TLB_ENTRIES{~tlb_writeable & ~cam_vld & ~wr_vld & ~rd_tag & ~rst_tri_en}}) ;
        end

//=========================================================================================
//	Read STLB
//=========================================================================================

	if(rd_tag & ~rw_disable) begin
		tmp_tag  = tte_tag_ram[rw_index];
		rd_tte_tag[58:0] <= {tmp_tag[58:27], tlb_entry_vld[rw_index],
				     tlb_entry_locked[rw_index], tlb_entry_used[rw_index], tmp_tag[23:0]};
	end


end // always

always	@ (cam_data or cam_pid or cam_vld or demap_all
           or demap_other or tlb_entry_vld)
	begin
	
		for (n=0;n<`TLB_ENTRIES;n=n+1)
			begin
			tag[58:0] = tte_tag_ram[n] ;	// CHANGE

			mismatch_va_b47_28[n] = 
			(tag[`STLB_TAG_VA_47_28_HI:`STLB_TAG_VA_47_28_LO] 
			!= cam_data[`CAM_VA_47_28_HI+13:`CAM_VA_47_28_LO+13]);

			mismatch_va_b27_22[n] = 
			(tag[`STLB_TAG_VA_27_22_HI:`STLB_TAG_VA_27_22_LO] 
			!= cam_data[`CAM_VA_27_22_HI+13:`CAM_VA_27_22_LO+13]);

			mismatch_va_b21_16[n] = 
			(tag[`STLB_TAG_VA_21_16_HI:`STLB_TAG_VA_21_16_LO]
			!= cam_data[`CAM_VA_21_16_HI+13:`CAM_VA_21_16_LO+13]) ;

			mismatch_va_b15_13[n] = 
			(tag[`STLB_TAG_VA_15_13_HI:`STLB_TAG_VA_15_13_LO]
			!= cam_data[`CAM_VA_15_13_HI+13:`CAM_VA_15_13_LO+13]) ;

			mismatch_ctxt[n] = 
			(tag[`STLB_TAG_CTXT_12_0_HI:`STLB_TAG_CTXT_12_0_LO] 
			!= cam_data[`CAM_CTXT_12_0_HI:`CAM_CTXT_12_0_LO]) ;
			
			mismatch_pid[n] = (tag[`STLB_TAG_PID_HI:`STLB_TAG_PID_LO] != cam_pid[2:0]) ;
			mismatch_type[n] = (tag[`STLB_TAG_R] ^ cam_data[`CAM_REAL_V+13]);

			mismatch[n] =
			(mismatch_va_b47_28[n] & cam_data[`CAM_VA_47_28_V+13]) 				|
			(mismatch_va_b27_22[n] & tag[`STLB_TAG_VA_27_22_V] & cam_data[`CAM_VA_27_22_V+13]) 	|
			(mismatch_va_b21_16[n] & tag[`STLB_TAG_VA_21_16_V] & cam_data[`CAM_VA_21_16_V+13]) 	|
			(mismatch_va_b15_13[n] & tag[`STLB_TAG_VA_15_13_V] & cam_data[`CAM_VA_15_13_V+13]) 	|
			(mismatch_ctxt[n] & ~cam_data[`CAM_CTXT_GK+13])	|
			(mismatch_type[n] & ~demap_all)  	| 
			mismatch_pid[n] ;	// pid always included in mismatch calculations

			demap_all_but_locked_hit[n] = ~tag[`STLB_TAG_L] & demap_all ;

			cam_hit[n] 	= ~mismatch[n] & cam_vld   & tlb_entry_vld[n] ;
		end

	end  // always

	assign demap_hit = demap_all ? ~mismatch & demap_all_but_locked_hit & tlb_entry_vld & {`TLB_ENTRIES{demap_other}}
				     : ~mismatch & tlb_entry_vld & {`TLB_ENTRIES{demap_other}};

endmodule

module bw_r_tlb_data_ram(rd_data, rw_index_vld, wr_vld_tmp, clk, cam_vld,
        rw_index, tlb_index, tlb_index_vld, rw_disable, rst_tri_en, wr_tte_data,
        rd_tte_data, cam_index, cam_hit_any, wr_vld);

        input                   rd_data;
        input                   rw_index_vld;
        input                   wr_vld_tmp;
        input                   clk;
        input   [(6 - 1):0]     rw_index;
        input   [(6 - 1):0]     tlb_index;
        input                   tlb_index_vld;
        input   [(6 - 1):0]     cam_index;
        input                   cam_hit_any;
        input                   rw_disable;
        input                   rst_tri_en;
        input                   cam_vld;
        input   [42:0]          wr_tte_data;
        input                   wr_vld;
        output  [42:0]          rd_tte_data;

        wire    [42:0]          rd_tte_data;

        reg     [42:0]          tte_data_ram[(64 - 1):0];

        wire [5:0] wr_addr = (rw_index_vld & wr_vld_tmp) ? rw_index :tlb_index;
        wire wr_en = ((rw_index_vld & wr_vld_tmp) & (~rw_disable)) |
                     (((tlb_index_vld & (~rw_index_vld)) & wr_vld_tmp) & (~rw_disable));

        always @(negedge clk) begin
          if (wr_en)
            tte_data_ram[wr_addr] <= wr_tte_data[42:0];
          end

        wire [5:0] rd_addr = rd_data ? rw_index : cam_index;
        wire rd_en = (rd_data & (~rw_disable)) | ((cam_vld & (~rw_disable)));

        reg [42:0] rd_tte_data_temp;

        always @(negedge clk) begin
	  //required for simulation; otherwise regression fails...
	  if((cam_vld & (~rw_disable)) & (!cam_hit_any)) begin
	    rd_tte_data_temp <= 43'bx;
	  end else
          if (rd_en) begin
            rd_tte_data_temp[42:0] <= tte_data_ram[rd_addr];
          end
	end

reg rdwe;
reg [42:0] wr_tte_data_d;

	
       always @(negedge clk) begin
	 wr_tte_data_d <= wr_tte_data;
       end
       always @(negedge clk) begin
         if(wr_en) rdwe <= 1'b1;
         else if(rd_en) rdwe <= 1'b0;
       end
       
       assign rd_tte_data = rdwe ? wr_tte_data_d : rd_tte_data_temp;

endmodule

`else

module bw_r_tlb ( /*AUTOARG*/
   // Outputs
   tlb_rd_tte_tag, tlb_rd_tte_data, tlb_pgnum, tlb_pgnum_crit, 
   tlb_cam_hit, cache_way_hit, cache_hit, so, 
   // Inputs
   tlb_cam_vld, tlb_cam_key, tlb_cam_pid,  
   tlb_demap_key, tlb_addr_mask_l, tlb_ctxt, 
   tlb_wr_vld, tlb_wr_tte_tag, tlb_wr_tte_data, tlb_rd_tag_vld, 
   tlb_rd_data_vld, tlb_rw_index, tlb_rw_index_vld, tlb_demap, 
   tlb_demap_auto, tlb_demap_all, cache_ptag_w0, cache_ptag_w1, 
   cache_ptag_w2, cache_ptag_w3, cache_set_vld, tlb_bypass_va, 
   tlb_bypass, se, si, hold, adj, arst_l, rst_soft_l, rclk,
   rst_tri_en
   ) ;	


input			tlb_cam_vld ;		// ld/st requires xlation. 
input	[40:0]		tlb_cam_key ;		// cam data for loads/stores;includes vld 
						// CHANGE : add real bit for cam.
input	[2:0]		tlb_cam_pid ;		// NEW: pid for cam. 
input	[40:0]		tlb_demap_key ;		// cam data for demap; includes vlds. 
						// CHANGE : add real bit for demap
input			tlb_addr_mask_l ;	// address masking occurs
input	[12:0]		tlb_ctxt ;		// context for cam xslate/demap. 
input			tlb_wr_vld;		// write to tlb. 
input	[58:0]		tlb_wr_tte_tag;		// CHANGE:tte tag to be written (55+4-1)
						// R(+1b),PID(+3b),G(-1b). 
input	[42:0]		tlb_wr_tte_data;	// tte data to be written.
						// No change(!!!) - G bit becomes spare
input			tlb_rd_tag_vld ;	// read tag
input			tlb_rd_data_vld ;	// read data
input	[5:0]		tlb_rw_index ;		// index to read/write tlb.
input			tlb_rw_index_vld ;	// indexed write else use algorithm.
input			tlb_demap ;		// demap : page/ctxt/all/auto.  
input			tlb_demap_auto ;	// demap is of type auto 
input			tlb_demap_all;		// demap-all operation : encoded separately.
input  	[29:0]    	cache_ptag_w0;       	// way1 30b(D)/29b(I) tag.
input  	[29:0]    	cache_ptag_w1;       	// way2 30b(D)/29b(I) tag.
input  	[29:0]     	cache_ptag_w2;       	// way0 30b(D)/29b(I) tag.
input  	[29:0]     	cache_ptag_w3;       	// way3 30b(D)/29b(I) tag.
input	[3:0]		cache_set_vld;       	// set vld-4 ways
input	[12:10]		tlb_bypass_va;	   	// bypass va.other va bits from cam-data
input			tlb_bypass;		// bypass tlb xslation

input			se ;			// scan-enable ; unused
input			si ;			// scan data in ; unused
input			hold ;			// scan hold signal
input	[7:0]		adj ;			// self-time adjustment ; unused
input			arst_l ;		// synchronous for tlb ; unused	
input			rst_soft_l ;		// software reset - asi
input			rclk;
input			rst_tri_en ;

output	[58:0]		tlb_rd_tte_tag;		// CHANGE: tte tag read from tlb.
output	[42:0]		tlb_rd_tte_data;	// tte data read from tlb.
// Need two ports for tlb_pgnum - critical and non-critical.
output	[39:10]		tlb_pgnum ;		// bypass or xslated pgnum
output	[39:10]		tlb_pgnum_crit ;	// bypass or xslated pgnum - critical
output			tlb_cam_hit ;		// xlation hits in tlb.
output	[3:0]		cache_way_hit;		// tag comparison results.
output			cache_hit;		// tag comparison result - 'or' of above.

//output			tlb_writeable ;		// tlb can be written in current cycle.

output			so ;		// scan data out ; unused

wire	[53:0]		tlb_cam_data ;
wire	[58:0]		wr_tte_tag ;	// CHANGE
wire	[42:0]		wr_tte_data ;
wire	[29:3]		phy_pgnum_m;
wire	[29:0]		pgnum_m;
wire 	[63:0]		used ;
wire			tlb_not_writeable ;
wire	[40:25] 	tlb_cam_key_masked ;
wire	[26:0]		tlb_cam_comp_key ;
wire			cam_vld ;
wire			demap_other ;
wire	[3:0]   	cache_way_hit ;

reg			tlb_not_writeable_d1 ;
reg			tlb_writeable ;
reg	[58:0]		tte_tag_ram  [63:0] ;	// CHANGE
reg	[42:0]		tte_data_ram [63:0] ;
reg	[63:0]		tlb_entry_vld ;
reg	[63:0]		tlb_entry_locked ;
reg	[63:0]		ademap_hit ;
reg	[58:0]		rd_tte_tag ;	// CHANGE
reg	[42:0]		rd_tte_data ;	
reg	[58:0]		tlb_rd_tte_tag ; // CHANGE	
reg	[42:0]		tlb_rd_tte_data ;	
reg			cam_vld_tmp ;
reg	[2:0]		cam_pid ;
reg	[53:0]		cam_data ;
reg			demap_auto, demap_other_tmp, demap_all ;
reg	[63:0]		mismatch ;
reg	[63:0]		cam_hit ;
reg	[63:0]		demap_hit ;
reg	[63:0]		demap_all_but_locked_hit ;
reg	[63:0]		mismatch_va_b47_28 ;
reg	[63:0]		mismatch_va_b27_22 ;
reg	[63:0]		mismatch_va_b21_16 ;
reg	[63:0]		mismatch_va_b15_13 ;
reg	[63:0]		mismatch_ctxt ;
reg	[63:0]		mismatch_pid ;
reg	[58:0]		tag ;	// CHANGE
reg	[63:0]		rw_wdline ;
reg	[63:0]		tlb_entry_used ;
reg	[63:0]		tlb_entry_replace ;
reg	[63:0]		tlb_entry_replace_d2 ;
reg	[29:0]		pgnum_g ;
reg     [3:0]		cache_set_vld_g;
reg	[29:0]		cache_ptag_w0_g,cache_ptag_w1_g;
reg	[29:0]		cache_ptag_w2_g,cache_ptag_w3_g;
reg			wr_vld_tmp;
reg			rd_tag; 
reg			rd_data;
reg			rw_index_vld;
reg	[5:0]		rw_index;
reg	[63:0]		sat ;

wire	[29:0] 		vrtl_pgnum_m;
wire			bypass ;

wire			wr_vld ;

integer	i,j,k,l,m,n,p,r,s,t,u,w;

/*AUTOWIRE*/
// Beginning of automatic wires (for undeclared instantiated-module outputs)
// End of automatics

// Some bits are removed from the tag and data. 
// 'U' must be defined as a '1' on a write.
// 'L' required for demap all function.
// Do not need an internal valid bit for va range 47:22.
// These bits are always valid for a page. 
// 
// TTE STLB_TAG
//
//`define	STLB_TAG_PID_HI		58	: NEW PID - bit2
//`define	STLB_TAG_PID_LO		56	: NEW PID - bit0
//`define	STLB_TAG_R		55	: NEW Real bit
//`define 	STLB_TAG_PARITY		54	// Parity kept in same posn to avoid having
//`define	STLB_TAG_VA_47_28_HI 	53	// to redo interface
//`define	STLB_TAG_VA_47_28_LO 	34
//`define	STLB_TAG_VA_27_22_HI 	33	
//`define	STLB_TAG_VA_27_22_LO 	28
//`define	STLB_TAG_27_22_V	27	
//`define	STLB_TAG_V		26	: valid for entry. Write of 0 resets it.
//`define	STLB_TAG_L		25
//`define	STLB_TAG_U		24	
//`define	STLB_TAG_VA_21_16_HI 	23
//`define	STLB_TAG_VA_21_16_LO  	18
//`define	STLB_TAG_VA_21_16_V  	17	  	
//`define	STLB_TAG_VA_15_13_HI 	16
//`define	STLB_TAG_VA_15_13_LO  	14
//`define	STLB_TAG_VA_15_13_V  	13
//`define	STLB_TAG_CTXT_12_0_HI  	12	// removed Global bit
//`define	STLB_TAG_CTXT_12_0_LO  	0
//// 				Total - 59b
////
//// TTE STLB_DATA
////
//// Soft[12:7] & Soft2[58:50] are removed.
//// Diag[49:41] are removed. Used bit used for Diag[0] on read.
//// CV is included for software correctness.
//// PA<40> is removed as it is not used.
//// G/L present in data even though present in tag : can't read out simultaneously.
//   (Unfortunately this is no longer correct. For data read, tag is also read
//   simultaneously to get valid bit, used bits).
//`define 	STLB_DATA_PARITY  	42 
//`define 	STLB_DATA_PA_39_28_HI 	41	// CHANGE
//`define 	STLB_DATA_PA_39_28_LO 	30
//`define 	STLB_DATA_PA_27_22_HI 	29	// CHANGE
//`define 	STLB_DATA_PA_27_22_LO 	24
//`define 	STLB_DATA_27_22_SEL	23
//`define 	STLB_DATA_PA_21_16_HI 	22	// CHANGE
//`define 	STLB_DATA_PA_21_16_LO 	17
//`define 	STLB_DATA_21_16_SEL	16
//`define 	STLB_DATA_PA_15_13_HI 	15	
//`define 	STLB_DATA_PA_15_13_LO 	13
//`define 	STLB_DATA_15_13_SEL	12
//`define 	STLB_DATA_V  		11	: static, does not get modified.
//`define 	STLB_DATA_NFO  		10
//`define 	STLB_DATA_IE   		9
//`define 	STLB_DATA_L 		8 	: added for read.
//`define 	STLB_DATA_CP 		7 
//`define 	STLB_DATA_CV 		6 
//`define 	STLB_DATA_E  		5 
//`define 	STLB_DATA_P  		4 
//`define 	STLB_DATA_W  		3 
//`define 	STLB_DATA_SPARE_HI  	2	: Global bit has been removed
//`define 	STLB_DATA_SPARE_LO	0  	 
// 				Total - 43b

// Valid bits for key(tlb_cam_key/tlb_demap_key).
// Total - 41b
//`define	CAM_VA_47_28_HI  	40
//`define	CAM_VA_47_28_LO  	21
//`define	CAM_VA_47_28_V  	20	// b47-28 participate in match
//`define	CAM_VA_27_22_HI  	19
//`define	CAM_VA_27_22_LO  	14
//`define	CAM_VA_27_22_V  	13	// b27-22 participate in match
//`define	CAM_VA_21_16_HI  	12
//`define	CAM_VA_21_16_LO  	7
//`define	CAM_VA_21_16_V  	6	// b21-16 participate in match
//`define	CAM_VA_15_13_HI 	5	
//`define	CAM_VA_15_13_LO 	3	
//`define	CAM_VA_15_13_V 	 	2	// b15-13 participate in match
//`define	CAM_CTXT_GK 		1	// Context participates in match
//`define	CAM_REAL_V 		0	// cam/demap applies to real mapping
					

// ctxt port is different from cam key port even though both are
// required for cam. (tlb_ctxt)
// If Gk is set then ctxt will not participate in match.
// Total - 14b
`define	CAM_CTXT_12_0_HI 	12 	// 13b ctxt
`define	CAM_CTXT_12_0_LO 	0 		


//=========================================================================================
//	What's Left :
//=========================================================================================

// Scan Insertion - scan to be ignored in formal verification for now.

//=========================================================================================
//	Design Notes.
//=========================================================================================

// - Supported Demap Operations - By Page, By Context, All But
// Locked, Autodemap, Invalidate-All i.e., reset. Demap Partition is
// not supported - it is mapped to demap-all by logic. 
// - Interpretation of demap inputs
//	- tlb_demap - this is used to signal demap by page, by ctxt
//	,all, and autodemap. 
//	- tlb_demap_ctxt - If a demap_by_ctxt operation is occuring then
//	this signal and tlb_demap must be active.
//	- tlb_demap_all - demap all operation. If a demap_all operation is
//	occuring, then tlb_demap_all must be asserted with tlb_demap. 
// - Reset is similar to demap-all except that *all* entries
// are invalidated. The action is initiated by software. The reset occurs
// on the negedge and is synchronous with the clk.
// - TTE Tag and Data
// 	- The TTE tag and data can be read together. Each will have its 
//	own bus and the muxing will occur externally. The tag needs to
//	be read on a data request to supply the valid bit.
// 	- The TTE tag and data can be written together.
// - The cam hit is a separate output signal based on the 
// the match signals.
// - Read/Write may occur based on supplied index. If not valid
// then use replacement way determined by algorithm to write.
// - Only write can use replacement way determined by algorithm.
// - Data is formatted appr. on read or write in the MMU. 
// - The TLB will generate a signal which reports whether the 
// tlb can be filled in the current cycle or not.
// **Physical Tag Comparison**
// For I-SIDE, comparison is of 28b, whereas for D-side, comparison is of 29b. The actual
// comparison, due to legacy, is for 30b.
// For the I-TLB, va[11:10] must be hardwired to the same value as the lsb of the 4 tags
// at the port level. Since the itag it only 28b, add two least significant bits to extend it to 30b.
// Similarly, for the dside, va[10] needs to be made same.	
// **Differentiating among Various TLB Operations**
// Valid bits are now associated with the key to allow selective incorporation of
// match results. The 5 valid bits are : v4(b47-28),v3(b27-22),v2(21-16),v1(b15-13)
// and Gk(G bit for auto-demap). The rules of use are :
//	- cam: v4-v1 are set high. G=~cam_real=0/1.
//	- demap_by_page : v4-v1 are set high. G=1. cam_real=0.
// 	- demap_by_ctxt : v4-v1 are low. G=1. cam_real=0
//	- demap_all : v4-v1 are don't-care. G=x. cam_real=x
//	- autodemap : v4-v1 are based on page size of incoming tte. G=~cam_real=0/1.
// Note : Gk is now used only to void a context match on a Real Translation.
// In general, if a valid bit is low then the corresponding va field will not take
// part in the match. Similarly, for the ctxt, if Gk=1, the ctxt will participate
// in the match.
//
// Demap Table (For Satya) :
// Note : To include a context match, Gk must be set to 1.
//--------------------------------------------------------------------------------------------------------
//tlb_demap tlb_demap_all  tlb_ctxt Gk	Vk4 Vk3	Vk2 Vk1 Real	Operation
//--------------------------------------------------------------------------------------------------------
//0		x		x   x	x   x	x   x   0	No demap operation
//1		0		0   1	1   1	1   1	0	Demap by page
//1		0		0   1	1   0	0   0	0/1	256M demap(auto demap)
//1		0		0   0	1   0	0   0	0	256M demap(auto demap) (*Illgl*)
//1		0		0   1	1   1	0   0	0/1	4M demap(auto demap)
//1		0		0   0	1   1	0   0	0	4M demap(auto demap) (*Illgl*)
//1		0		0   1	1   1	1   0	0/1	64k demap(auto demap)
//1		0		0   0	1   1	1   0	0	64k demap(auto demap) (*Illgl*)
//1		0		0   1	1   1	1   1	0/1	8k demap(auto demap)
//1		0		0   0	1   1	1   1	0	8k demap(auto demap) (*Illgl*)
//1		0		1   1	0   0	0   0	0	demap by ctxt
//1		1		x   x	x   x	x   x	0	demap_all
//------------------------------------------------------------------------------------------
//-----
//All other are illegal combinations
//
//=========================================================================================
//	Changes related to Hypervisor/Legacy Compatibility
//=========================================================================================
//
// - Add PID. PID does not effect demap-all. Otherwise it is included in cam, other demap
// operations and auto-demap.
// - Add R. Real translation ignores context. This is controlled externally by Gk.
// - Remove G bit for tte. Input remains in demap-key/cam-key to allow for disabling
//   of context match Real Translation  
// - Final Page Size support - 8KB,64KB,4M,256M
// - SPARC_HPV_EN has been defined to enable new tlb design support. 
// Issues : 
// -Max ptag size is now 28b. Satya, will this help the speed at all. I doubt it !

//=========================================================================================
//	Miscellaneous
//=========================================================================================
   wire clk;
   assign clk = rclk;
   
wire async_reset, sync_reset ;
assign	async_reset = ~arst_l ; 			// hardware
assign	sync_reset = (~rst_soft_l & ~rst_tri_en) ;	// software

wire rw_disable ;
// INNO - wr/rd gated off. Note required as rst_tri_en is
// asserted, but implemented in addition in schematic.
assign	rw_disable = ~arst_l | rst_tri_en ;

//=========================================================================================
// 	Stage Data
//=========================================================================================
// Apply address masking
assign	tlb_cam_key_masked[40:25]
	= {16{tlb_addr_mask_l}} & 
		tlb_cam_key[`CAM_VA_47_28_HI:`CAM_VA_47_28_LO+4] ;

// Reconstitute cam data CHANGE : add additional bit for real mapping
assign	tlb_cam_data[53:13] = tlb_demap ? 
	tlb_demap_key[40:0] :
	{tlb_cam_key_masked[40:25],tlb_cam_key[`CAM_VA_47_28_LO+3:0]} ; 

assign tlb_cam_comp_key[26:0] = 
		tlb_demap ?
			{tlb_demap_key[32:21], tlb_demap_key[19:14],tlb_demap_key[12:7],
			tlb_demap_key[5:3]} :
			{tlb_cam_key_masked[32:25],tlb_cam_key[24:21],
			tlb_cam_key[19:14],tlb_cam_key[12:7],tlb_cam_key[5:3]} ;

assign	tlb_cam_data[12:0] = tlb_ctxt[12:0] ;

// These signals are flow-thru.
assign	wr_tte_tag[58:0] 	= tlb_wr_tte_tag[58:0] ;	// CHANGE
assign	wr_tte_data[42:0] 	= tlb_wr_tte_data[42:0] ;

// CHANGE(SATYA) - Currently the rw_index/rw_index_vld are shared by both reads
// and writes. However, writes are done in the cycle of broadcast, whereas
// the reads are done a cycle later, as given in the model(incorrect) 
// They have to be treated uniformly. To make the model work, I've assumed the read/write 
// are done in the cycle the valids are broadcast. 
always @ (posedge clk)
	begin
	if (hold)
		begin
		cam_pid[2:0]		<= cam_pid[2:0] ;
		cam_vld_tmp		<= cam_vld_tmp ;
		cam_data[53:0] 		<= cam_data[53:0] ;
		demap_other_tmp		<= demap_other_tmp ;
		demap_auto		<= demap_auto ;
		demap_all		<= demap_all ;
		wr_vld_tmp 		<= wr_vld_tmp ;
		rd_tag 			<= rd_tag ;
		rd_data			<= rd_data ;
		rw_index_vld		<= rw_index_vld ;
		rw_index[5:0]		<= rw_index[5:0] ; 	
		end
	else
		begin
		cam_pid[2:0]		<= tlb_cam_pid[2:0] ;
		cam_vld_tmp		<= tlb_cam_vld ;
		cam_data[53:0] 		<= tlb_cam_data[53:0] ;
		demap_other_tmp		<= tlb_demap ;
		demap_auto		<= tlb_demap_auto ;
		demap_all		<= tlb_demap_all ;
		wr_vld_tmp 		<= tlb_wr_vld ;
		rd_tag 			<= tlb_rd_tag_vld ;
		rd_data			<= tlb_rd_data_vld ;
		rw_index_vld		<= tlb_rw_index_vld ;
		rw_index[5:0]		<= tlb_rw_index[5:0] ; 	
		end

	end

// INNO - gate cam,demap,wr with rst_tri_en.
reg rst_tri_en_lat;

 always        @ (clk)
 rst_tri_en_lat = rst_tri_en;

assign	cam_vld = cam_vld_tmp & ~rst_tri_en_lat ;
assign	demap_other = demap_other_tmp & ~rst_tri_en ;
assign	wr_vld = wr_vld_tmp & ~rst_tri_en ;

//=========================================================================================
//	Generate Write Wordlines
//=========================================================================================

// Based on static rw index	
// This generates the wordlines for a read/write to the tlb based on index. Wordlines for
// the write based on replacement alg. are muxed in later.
always	@ (/*AUTOSENSE*/rd_data or rd_tag or rw_index or rw_index_vld
           or wr_vld_tmp)
	begin
		for (i=0;i<64;i=i+1)
			if ((rw_index[5:0] == i) & ((wr_vld_tmp & rw_index_vld) | rd_tag | rd_data))
				rw_wdline[i] = 1'b1 ;
			else	rw_wdline[i] = 1'b0 ;
					
	end

//=========================================================================================
//	Write TLB
//=========================================================================================

reg	[58:0]	tmp_tag ;
reg	[42:0]	tmp_data ;

// Currently TLB_TAG and TLB_DATA RAMs are written in the B phase. 
// Used bit is set on write in later code as it is also effected by read of tlb.
always	@ (negedge clk)
	begin
		for (j=0;j<64;j=j+1)
			if (((rw_index_vld & rw_wdline[j]) | (~rw_index_vld & tlb_entry_replace_d2[j])) & wr_vld_tmp & ~rw_disable)
				begin
				if (~rst_tri_en)
					begin
					tte_tag_ram[j] <= wr_tte_tag[58:0];	// CHANGE
					tte_data_ram[j] <= wr_tte_data[42:0];
					//tlb_entry_vld[j] <= wr_tte_tag[`STLB_TAG_V] ;
					tlb_entry_used[j] <= wr_tte_tag[`STLB_TAG_U] ;
					tlb_entry_locked[j] = wr_tte_tag[`STLB_TAG_L] ;
					// write-thru 
					rd_tte_tag[58:0]  <= wr_tte_tag[58:0] ;	// CHANGE 
					rd_tte_data[42:0] <=  wr_tte_data[42:0];

					end
				else
					begin
					tmp_tag[58:0]=tte_tag_ram[j]; // use non-blocking
					tmp_data[42:0]=tte_data_ram[j];
					// INNO - read wins.
					rd_tte_tag[58:0] <=	
					{tmp_tag[58:27], tlb_entry_vld[j],tlb_entry_locked[j], 
					tlb_entry_used[j], tmp_tag[23:0]}  ;
					rd_tte_data[42:0] <= {tmp_data[42:12],tmp_data[11:0]} ;
					end
			
			end

//=========================================================================================
//	Read STLB
//=========================================================================================

		for (m=0;m<64;m=m+1)
			if (rw_wdline[m] & (rd_tag | rd_data) & ~rw_disable)
				begin
					tmp_tag  = tte_tag_ram[m] ;
					tmp_data = tte_data_ram[m] ;
					if (rd_tag)
						rd_tte_tag[58:0] <=	// CHANGE - Bug 2185
						{tmp_tag[58:27], tlb_entry_vld[m],tlb_entry_locked[m], 
						tlb_entry_used[m], tmp_tag[23:0]}  ;
						//{tmp_tag[58:29], tlb_entry_vld[m],tlb_entry_locked[m], 
						//tlb_entry_used[m], tmp_tag[25:0]}  ;
					if (rd_data) begin
						rd_tte_data[42:0] <= {tmp_data[42:12],tmp_data[11:0]} ;
					end

				end

		if (cam_vld & ~rw_disable)
  		begin
    			//Checking for no hit and multiple hits
    			sat = 64'd0;
    			for (w=0;w<64;w=w+1)
    			begin
      				if(cam_hit[w])
      				begin
        				sat = sat + 64'd1 ;
      				end
    			end
			// Only one hit occur read the data
    			if(sat == 64'd1)
    			begin
                        	for (p=0;p<64;p=p+1)
				begin
                                	if (cam_hit[p])
                                	begin
                                        	rd_tte_data[42:0] <= tte_data_ram[p] ;
                                	end
				end
			end
			else
			begin
				// INNO - just to keep the tool happy.
				// ram cell will not be corrupted.
				for (k=0;k<64;k=k+1)
				begin
					if (cam_hit[k])
                        		tte_data_ram[k] <= 43'bx ;
				end
                        	rd_tte_data[42:0] <= 43'bx ;
			end
		end

                for (s=0;s<64;s=s+1)
                        begin
                                if (cam_hit[s])
                                        tlb_entry_used[s] <= 1'b1;
                        end

// Clear on following edge if necessary.
// CHANGE(SATYA) : tlb_entry_used qualified with valid needs to be used to determine
// whether the Used bits are to be cleared. This allows invalid entries created
// by a demap to be used for replacement. Else we will ignore these entries
// for replacement

                //if (tlb_not_writeable)
                if (~tlb_writeable & ~cam_vld & ~wr_vld & ~rd_tag & ~rst_tri_en)
                        begin
                                for (t=0;t<64;t=t+1)
                                        begin
                                                //if (~tlb_entry_locked[t])
                                                if (~tlb_entry_locked[t] & ~cam_vld & ~wr_vld)
                                                        tlb_entry_used[t] <= 1'b0;
                                        end
                        end
	end

// Stage to next cycle.
always	@ (posedge clk)
	begin
		tlb_rd_tte_tag[58:0] 	<= rd_tte_tag[58:0] ;	// CHANGE
		tlb_rd_tte_data[42:0] 	<= rd_tte_data[42:0] ;
	end

//=========================================================================================
//	CAM/DEMAP STLB for xlation
//=========================================================================================

//  no_hit logic does not work because it is set in multiple clock
//  domains and is reset before ever having a chance to be effective
//reg	no_hit ;


// Demap and CAM operation are mutually exclusive.

always  @ ( negedge clk )
	begin
	
		for (n=0;n<64;n=n+1)
			begin
                        /*if (demap_all)  begin
                                if (demap_auto & demap_other) ademap_hit[n]   =
                                        (~mismatch[n] & demap_all_but_locked_hit[n] & demap_other
                                                & tlb_entry_vld[n]) ;
                                end
                        else    begin */
                                if (demap_auto & demap_other) ademap_hit[n]    =
                                        (~mismatch[n] & demap_other & tlb_entry_vld[n]) ;
                                //end
			end

	end  // always

always	@ (/*AUTOSENSE*/ /*memory or*/ 
           cam_data or cam_pid or cam_vld or demap_all
           or demap_other or tlb_entry_vld)
	begin
	
		for (n=0;n<64;n=n+1)
			begin
			tag[58:0] = tte_tag_ram[n] ;	// CHANGE

			mismatch_va_b47_28[n] = 
			(tag[`STLB_TAG_VA_47_28_HI:`STLB_TAG_VA_47_28_LO] 
			!= cam_data[`CAM_VA_47_28_HI+13:`CAM_VA_47_28_LO+13]);

			mismatch_va_b27_22[n] = 
			(tag[`STLB_TAG_VA_27_22_HI:`STLB_TAG_VA_27_22_LO] 
			!= cam_data[`CAM_VA_27_22_HI+13:`CAM_VA_27_22_LO+13]);

			mismatch_va_b21_16[n] = 
			(tag[`STLB_TAG_VA_21_16_HI:`STLB_TAG_VA_21_16_LO]
			!= cam_data[`CAM_VA_21_16_HI+13:`CAM_VA_21_16_LO+13]) ;

			mismatch_va_b15_13[n] = 
			(tag[`STLB_TAG_VA_15_13_HI:`STLB_TAG_VA_15_13_LO]
			!= cam_data[`CAM_VA_15_13_HI+13:`CAM_VA_15_13_LO+13]) ;

			mismatch_ctxt[n] = 
			(tag[`STLB_TAG_CTXT_12_0_HI:`STLB_TAG_CTXT_12_0_LO] 
			!= cam_data[`CAM_CTXT_12_0_HI:`CAM_CTXT_12_0_LO]) ;
			
			mismatch_pid[n] = (tag[`STLB_TAG_PID_HI:`STLB_TAG_PID_LO] != cam_pid[2:0]) ;

			mismatch[n] =
			(mismatch_va_b47_28[n] & cam_data[`CAM_VA_47_28_V+13]) 				|
			(mismatch_va_b27_22[n] & tag[`STLB_TAG_VA_27_22_V] & cam_data[`CAM_VA_27_22_V+13]) 	|
			(mismatch_va_b21_16[n] & tag[`STLB_TAG_VA_21_16_V] & cam_data[`CAM_VA_21_16_V+13]) 	|
			(mismatch_va_b15_13[n] & tag[`STLB_TAG_VA_15_13_V] & cam_data[`CAM_VA_15_13_V+13]) 	|
			(mismatch_ctxt[n] & ~cam_data[`CAM_CTXT_GK+13])	|
			// mismatch is request type not equal to entry type. types are real/virtual.
			((tag[`STLB_TAG_R] ^ cam_data[`CAM_REAL_V+13]) & ~demap_all)  	| 
			//(mismatch_real[n] & cam_data[`CAM_REAL_V+13])  	|
			mismatch_pid[n] ;	// pid always included in mismatch calculations

			demap_all_but_locked_hit[n] = 
			~tag[`STLB_TAG_L] & demap_all ;

			cam_hit[n] 	= 
				~mismatch[n] & cam_vld   & tlb_entry_vld[n] ;

                        if (demap_all)  begin
                                // Satya(10/3) - I've simplified the demap-all equation
                                // Pls confirm that this is okay. Otherwise we will nee
                                // qualifying bits for the pid and r fields.
                                /*demap_hit[n]  =
                                        (demap_all_but_locked_hit[n] & demap_other) ;*/
                                demap_hit[n]    =
                                        (~mismatch[n] & demap_all_but_locked_hit[n] & demap_other
                                                & tlb_entry_vld[n]) ;
				// qualification with demap_auto to prevent ademap_hit from
				// being cleared. Satya-we could get rid of this.
                                // ademap_hit[n] is a phase A device and needs to be in a clocked always block
                                //if (demap_auto & demap_other & clk) ademap_hit[n]   =
                                //        (~mismatch[n] & demap_all_but_locked_hit[n] & demap_other
                                //                & tlb_entry_vld[n]) ;
                                end
                        else    begin
                                demap_hit[n]    =
                                        (~mismatch[n] & demap_other & tlb_entry_vld[n]) ;
				// qualification with demap_auto to prevent ademap_hit from
				// being cleared. Satya-this is the only one we need.
                                //if (demap_auto & demap_other & clk) ademap_hit[n]    =
                                //        (~mismatch[n] & demap_other & tlb_entry_vld[n]) ;
                                end
//			no_hit = cam_vld ;
			end

	end  // always

assign	tlb_cam_hit = |cam_hit[63:0] ;

// Read on CAM hit occurs on negedge.
/* MOVED TO COMMON ALWAYS BLOCK
always @ (negedge clk)
	begin
		if (|cam_hit[63:0])	
			begin
			for (p=0;p<64;p=p+1)
				if (cam_hit[p])	
				begin
					rd_tte_data[42:0] <= tte_data_ram[p] ;
				end
//				no_hit = 1'b0 ;
			end
//		else	if (no_hit) begin
//			rd_tte_data[42:0] <= {43{1'bx}};
//			no_hit = 1'b0 ;
//			end
	end
*/
// Change tlb_entry_vld handling for multi-threaded tlb writes.
// A write is always preceeded by an autodemap. The intent is to make the result of autodemap
// (clearing of vld bit if hit) invisible until write occurs. In the same cycle that the write
// occurs, the vld bit for an entry will be cleared if there is an autodemap hit. The write
// and admp action may even be to same entry. The write must dominate. There is no need to
// clear the dmp latches after the write/clear has occurred as the subsequent admp will set
// up new state in the latches.

// Define valid bit based on write/demap/reset. 
always @ (negedge clk)
	begin
	for (r=0;r<64;r=r+1)
	begin // for
	if (((rw_index_vld & rw_wdline[r]) | (~rw_index_vld & tlb_entry_replace_d2[r])) & 
		wr_vld & ~rw_disable)
			tlb_entry_vld[r] <= wr_tte_tag[`STLB_TAG_V] ;	// write
	else	begin
		if (ademap_hit[r] & wr_vld)			// autodemap specifically
			tlb_entry_vld[r] <= 1'b0 ;		
		end
	  if ((demap_hit[r] & ~demap_auto) | sync_reset)	// non-auto-demap, reset
			tlb_entry_vld[r] <= 1'b0 ;	
	end // for
	end


// async reset.
always  @ (async_reset) 
	begin
	for (l=0;l<64;l=l+1)
		begin
	  	tlb_entry_vld[l] <= 1'b0 ;
		end
	end

//=========================================================================================
//	TAG COMPARISON
//=========================================================================================

reg [30:0] va_tag_plus ;

// Stage to m
always @(posedge clk)
		begin
		// INNO - add hold to this input
		if (hold)
			va_tag_plus[30:0] <= va_tag_plus[30:0] ;
		else
			va_tag_plus[30:0] 
			<= {tlb_cam_comp_key[26:0],tlb_bypass_va[12:10],tlb_bypass}; 
		end
			
assign vrtl_pgnum_m[29:0] = va_tag_plus[30:1] ;
assign bypass = va_tag_plus[0] ;

// Mux to bypass va or form pa tag based on tte-data.

assign	phy_pgnum_m[29:3] = 
	{rd_tte_data[`STLB_DATA_PA_39_28_HI:`STLB_DATA_PA_39_28_LO],
		rd_tte_data[`STLB_DATA_PA_27_22_HI:`STLB_DATA_PA_27_22_LO],
			rd_tte_data[`STLB_DATA_PA_21_16_HI:`STLB_DATA_PA_21_16_LO],
				rd_tte_data[`STLB_DATA_PA_15_13_HI:`STLB_DATA_PA_15_13_LO]};

// Derive the tlb-based physical address.
assign pgnum_m[2:0] = vrtl_pgnum_m[2:0];
assign pgnum_m[5:3] = (~rd_tte_data[`STLB_DATA_15_13_SEL] & ~bypass)
				? phy_pgnum_m[5:3] : vrtl_pgnum_m[5:3] ;
assign pgnum_m[11:6] = (~rd_tte_data[`STLB_DATA_21_16_SEL] & ~bypass)  
				? phy_pgnum_m[11:6] : vrtl_pgnum_m[11:6] ;
assign pgnum_m[17:12] = (~rd_tte_data[`STLB_DATA_27_22_SEL] & ~bypass)
				? phy_pgnum_m[17:12] : vrtl_pgnum_m[17:12] ;
assign pgnum_m[29:18] = ~bypass ? phy_pgnum_m[29:18] : vrtl_pgnum_m[29:18];

// Stage to g
// Flop tags in tlb itself and do comparison immediately after rising edge.
// Similarly stage va/pa tag to g
always @(posedge clk)
		begin
			pgnum_g[29:0] <= pgnum_m[29:0];
			// rm hold on these inputs.
			cache_set_vld_g[3:0]  	<= cache_set_vld[3:0] ;
			cache_ptag_w0_g[29:0] 	<= cache_ptag_w0[29:0] ;
			cache_ptag_w1_g[29:0] 	<= cache_ptag_w1[29:0] ;
			cache_ptag_w2_g[29:0] 	<= cache_ptag_w2[29:0] ;
			cache_ptag_w3_g[29:0] 	<= cache_ptag_w3[29:0] ;
		end


// Need to stage by a cycle where used.
assign	tlb_pgnum[39:10] = pgnum_g[29:0] ;
// Same cycle as cam - meant for one load on critical path
assign	tlb_pgnum_crit[39:10] = pgnum_m[29:0] ;


assign	cache_way_hit[0] = 
	(cache_ptag_w0_g[29:0] == pgnum_g[29:0]) & cache_set_vld_g[0];
assign	cache_way_hit[1] = 
	(cache_ptag_w1_g[29:0] == pgnum_g[29:0]) & cache_set_vld_g[1];
assign	cache_way_hit[2] = 
	(cache_ptag_w2_g[29:0] == pgnum_g[29:0]) & cache_set_vld_g[2];
assign	cache_way_hit[3] = 
	(cache_ptag_w3_g[29:0] == pgnum_g[29:0]) & cache_set_vld_g[3];

assign	cache_hit = |cache_way_hit[3:0];


//=========================================================================================
//	TLB ENTRY REPLACEMENT
//=========================================================================================

// A single Used bit is used to track the replacement state of each entry.
// Only an unused entry can be replaced.
// An Unused entry is :
//			- an invalid entry
//			- a valid entry which has had its Used bit cleared.
//				- on write of a valid entry, the Used bit is set.
//				- The Used bit of a valid entry is cleared if all
//				entries have their Used bits set and the entry itself is not Locked.
// A locked entry should always appear to be Used.
// A single priority-encoder is required to evaluate the used status. Priority is static
// and used entry0 is of the highest priority if unused.

// Timing :
// Used bit gets updated by cam-hit or hit on negedge.
// After Used bit gets updated off negedge, the replacement entry can be generated in
// Phase2. In parallel, it is determined whether all Used bits are set or not. If
// so, then they are cleared on the next negedge with the replacement entry generated
// in the related Phase1 

// Choosing replacement entry
// Replacement entry is integer k

assign	tlb_not_writeable = &used[63:0] ;
/*
// Used bit can be set because of write or because of cam-hit.
always @(negedge clk)
	begin
		for (s=0;s<64;s=s+1)
			begin
				if (cam_hit[s]) 
					tlb_entry_used[s] <= 1'b1;			
			end

// Clear on following edge if necessary.
// CHANGE(SATYA) : tlb_entry_used qualified with valid needs to be used to determine
// whether the Used bits are to be cleared. This allows invalid entries created
// by a demap to be used for replacement. Else we will ignore these entries
// for replacement

		if (tlb_not_writeable)
			begin
				for (t=0;t<64;t=t+1)
					begin
						if (~tlb_entry_locked[t])
							tlb_entry_used[t] <= 1'b0;
					end
			end
	end
*/

// Determine whether entry should be squashed.

assign	used[63:0] = tlb_entry_used[63:0] & tlb_entry_vld[63:0] ;

/*assign squash[0] = 1'b0 ;
assign squash[1] = ~used[0] ;
assign squash[2] = |(~used[1:0]) ;
assign squash[3] = |(~used[2:0]) ;
assign squash[4] = |(~used[3:0]) ;
assign squash[5] = |(~used[4:0]) ;
assign squash[6] = |(~used[5:0]) ;
assign squash[7] = |(~used[6:0]) ;
assign squash[8] = |(~used[7:0]) ;
assign squash[9] = |(~used[8:0]) ;
assign squash[10] = |(~used[9:0]) ;
assign squash[11] = |(~used[10:0]) ;
assign squash[12] = |(~used[11:0]) ;
assign squash[13] = |(~used[12:0]) ;
assign squash[14] = |(~used[13:0]) ;
assign squash[15] = |(~used[14:0]) ;
assign squash[16] = |(~used[15:0]) ;
assign squash[17] = |(~used[16:0]) ;
assign squash[18] = |(~used[17:0]) ;
assign squash[19] = |(~used[18:0]) ;
assign squash[20] = |(~used[19:0]) ;
assign squash[21] = |(~used[20:0]) ;
assign squash[22] = |(~used[21:0]) ;
assign squash[23] = |(~used[22:0]) ;
assign squash[24] = |(~used[23:0]) ;
assign squash[25] = |(~used[24:0]) ;
assign squash[26] = |(~used[25:0]) ;
assign squash[27] = |(~used[26:0]) ;
assign squash[28] = |(~used[27:0]) ;
assign squash[29] = |(~used[28:0]) ;
assign squash[30] = |(~used[29:0]) ;
assign squash[31] = |(~used[30:0]) ;
assign squash[32] = |(~used[31:0]) ;
assign squash[33] = |(~used[32:0]) ;
assign squash[34] = |(~used[33:0]) ;
assign squash[35] = |(~used[34:0]) ;
assign squash[36] = |(~used[35:0]) ;
assign squash[37] = |(~used[36:0]) ;
assign squash[38] = |(~used[37:0]) ;
assign squash[39] = |(~used[38:0]) ;
assign squash[40] = |(~used[39:0]) ;
assign squash[41] = |(~used[40:0]) ;
assign squash[42] = |(~used[41:0]) ;
assign squash[43] = |(~used[42:0]) ;
assign squash[44] = |(~used[43:0]) ;
assign squash[45] = |(~used[44:0]) ;
assign squash[46] = |(~used[45:0]) ;
assign squash[47] = |(~used[46:0]) ;
assign squash[48] = |(~used[47:0]) ;
assign squash[49] = |(~used[48:0]) ;
assign squash[50] = |(~used[49:0]) ;
assign squash[51] = |(~used[50:0]) ;
assign squash[52] = |(~used[51:0]) ;
assign squash[53] = |(~used[52:0]) ;
assign squash[54] = |(~used[53:0]) ;
assign squash[55] = |(~used[54:0]) ;
assign squash[56] = |(~used[55:0]) ;
assign squash[57] = |(~used[56:0]) ;
assign squash[58] = |(~used[57:0]) ;
assign squash[59] = |(~used[58:0]) ;
assign squash[60] = |(~used[59:0]) ;
assign squash[61] = |(~used[60:0]) ;
assign squash[62] = |(~used[61:0]) ;
assign squash[63] = |(~used[62:0]) ; */

// Based on updated Used state, generate replacement entry.
// So, replacement entries can be generated on a cycle-by-cycle basis. 
//always @(/*AUTOSENSE*/squash or used)

	reg	[63:0]	tlb_entry_replace_d1;
	reg		tlb_replace_flag;
	always @(/*AUTOSENSE*/used)
	begin
  	  tlb_replace_flag=1'b0;
  	  tlb_entry_replace_d1 = 64'b0;
  	  // Priority is given to entry0
   	  for (u=0;u<64;u=u+1)
  	  begin
    	    if(~tlb_replace_flag & ~used[u])
    	    begin
      	      tlb_entry_replace_d1[u] = ~used[u] ;
      	      tlb_replace_flag=1'b1; 
    	    end
  	  end
  	  if(~tlb_replace_flag) begin
      	     tlb_entry_replace_d1[63] = 1'b1;
 	  end
	end
	always @(posedge clk)
	begin
	  // named in this manner to keep arch model happy.
  	  tlb_entry_replace <= tlb_entry_replace_d1 ;
	end
	// INNO - 2 stage delay before update is visible
	always @(posedge clk)
	begin
  	  tlb_entry_replace_d2 <= tlb_entry_replace ;
	end

//=========================================================================================
//	TLB WRITEABLE DETECTION
//=========================================================================================

// 2-cycles later, tlb become writeable
always @(posedge clk)
	begin
		tlb_not_writeable_d1 <= tlb_not_writeable ;
	end

always @(posedge clk)
	begin
		tlb_writeable <= ~tlb_not_writeable_d1 ;
	end

endmodule

`endif

