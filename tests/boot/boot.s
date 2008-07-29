/*
 * Simply RISC S1 Core - Boot code
 *
 * Cutdown version from the original OpenSPARC T1:
 *
 *   $T1_ROOT/verif/diag/assembly/include/hred_reset_handler.s
 *
 * Main changes:
 * - L1 and L2 cache handling are not enabled;
 * - Interrupt Queues handling currently commented out since causes troubles in S1 Core.
 *
 * Sun Microsystems' copyright notices follow:
 */

/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T1 Processor File: hred_reset_handler.s
* Copyright (c) 2006 Sun Microsystems, Inc.  All Rights Reserved.
* DO NOT ALTER OR REMOVE COPYRIGHT NOTICES.
* 
* The above named program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License version 2 as published by the Free Software Foundation.
* 
* The above named program is distributed in the hope that it will be 
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
* 
* You should have received a copy of the GNU General Public
* License along with this work; if not, write to the Free Software
* Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.
* 
* ========== Copyright Header End ============================================
*/

	!! Enable L2-ucache: Unused in S1 Core
/*
	setx	cregs_l2_ctl_reg_r64, %g1, %l1				!! aka "wr  %g0, 5, %asr26" "clr  %l1"
	mov	0xa9, %g1
	sllx	%g1, 32, %g1

	stx	%l1, [%g1 + 0x00]
	stx	%l1, [%g1 + 0x40]
	stx	%l1, [%g1 + 0x80]
	stx	%l1, [%g1 + 0xc0]
*/

	!! Set LSU Diagnostic Register to use all ways for L1-icache and L1-dcache
	
        !!setx	cregs_lsu_diag_reg_r64, %g1, %l1
	!! cregs_lsu_diag_reg_r64 has value 0 in file defines.h;
	!! this instruction has been expanded to:
	sethi %hh(0x0),%g1
	or    %g1,%hm(0x0),%g1
	sllx  %g1,32,%g1
	sethi %hi(0x0),%l1
	or    %l1,%g1,%l1
	or    %l1,%lo(0x0),%l1

	!! clear to zero the register ASI_LSU_DIAG_REG thus enabling all ways of cache and using the "random replacement" algorithm
	mov	0x10, %g1							
	stxa %l1, [%g1] (66)

	!! Set LSU Control Register to enable L1-icache and L1-dcache: not enabled in S1 Core
/*
 	setx	(CREGS_LSU_CTL_REG_IC | (CREGS_LSU_CTL_REG_DC << 1)), %g1, %l1	!! aka "mov  3, %l1"
	stxa  %l1, [ %g0 ] (69)							!! aka "stxa	%l1, [%g0] ASI_LSU_CTL_REG"
*/

	!! Set hpstate.red = 0 and hpstate.enb = 1
	rdhpr	%hpstate, %l1 
	and %l1,0x820,%l2
	xor %l2,0x800,%l2
	wrhpr %l1,%l2,%hpstate		!! this mechanism should ensure red=0 and enb=1 leaving the other 2 bits of the register unchanged;
	!!wrhpr	%l1, 0x820, %hpstate    !! with the old instruction we got red=0 and enb=1 only if previously they were red=1 and enb=0
 
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!! Instructions added from file hboot_tlb_init.s !!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  
!! Init all itlb entries
    mov	0x30, %g1
    mov	%g0, %g2
itlb_init_loop:                  
        !! clear data and tag entries of the TLB buffer
        stxa	%g0, [ %g1 ] 0x50  	!! IMMU TLB Tag Access register=0
        stxa	%g0, [ %g2 ] 0x55  	!! IMMU TLB Data Access register=0, g2 values from 0x000 to 0x7f8

	add	%g2, 8, %g2    		!! increment the g2 register 8 bytes every time (64 bits)
	cmp	%g2, 0x200 		!! compare g2 with 512 (512*8=4096=0x1000), but max VA=0x7F8
	bne	itlb_init_loop  	!! if (g2!=512) then run another loop
	nop

!! Init all dtlb entries
        mov	0x30, %g1  
	mov	%g0, %g2
dtlb_init_loop:
        stxa	%g0, [ %g1 ] 0x58  	!! DMMU TLB Tag Access register=0
        stxa	%g0, [ %g2 ] 0x5d  	!! ASI_DTLB_DATA_ACCESS_REG(DMMU TLB Data Access) is 0, g2 values from 0x000 to 0x7f8

	add	%g2, 8, %g2 		!! increment the g2 register 8 bytes every time (64 bits)
	cmp	%g2, 0x200  		!! compare g2 with 512
	bne	dtlb_init_loop 		!! if (g2!=512) then run another loop
	nop

!! Clear itlb/dtlb valid
	stxa	%g0, [%g0] 0x60		!! ASI_ITLB_INVALIDATE_ALL(IMMU TLB Invalidate register)=0
	mov	0x8, %g1
	stxa	%g0, [%g0 + %g1] 0x60	!! ASI_DTLB_INVALIDATE_ALL(DMMU TLB Invalidate register)=0


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!! End of instrted instructions, from here we are again in old file boot.s !!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	!! Initialize Interrupt Queue Registers: Currently disabled in S1 Core
/*
	wr %g0, 0x25, %asi

	stxa %g0, [0x3c0] %asi
	stxa %g0, [0x3c8] %asi
	stxa %g0, [0x3d0] %asi
	stxa %g0, [0x3d8] %asi

	stxa %g0, [0x3e0] %asi
	stxa %g0, [0x3e8] %asi
	stxa %g0, [0x3f0] %asi
	stxa %g0, [0x3f8] %asi

	wrpr	0, %tl
	wrpr	0, %g0, %gl
	wr	%g0, cregs_fprs_imm, %fprs
	wr	%g0, cregs_ccr_imm, %ccr

	wr	%g0, cregs_asi_imm, %asi
	setx	cregs_tick_r64, %g1, %g2
	!! FIXME set other ticks also
	wrpr	%g2, %tick
	setx	cregs_stick_r64, %g1, %g2

	wr	%g2, %g0, %sys_tick
	mov     0x1, %g2
	sllx    %g2, 63, %g2
	wr	%g2, %g0, %tick_cmpr

	wr	%g2, %g0, %sys_tick_cmpr
	wrhpr	%g2, %g0, %hsys_tick_cmpr
	mov	%g0, %y
	wrpr	cregs_pil_imm, %pil

	wrpr	cregs_cwp_imm, %cwp
	wrpr	cregs_cansave_imm, %cansave
	wrpr	cregs_canrestore_imm, %canrestore
	wrpr	cregs_otherwin_imm, %otherwin

	wrpr	cregs_cleanwin_imm, %cleanwin
	wrpr	cregs_wstate_imm, %wstate
*/

	!! Clear L1-icache and L1-dcache SFSR
	mov 	0x18, %g1
	stxa	%g0, [%g0 + %g1] 0x50 !IMMU Synchronous Fault Status register=0
	stxa	%g0, [%g0 + %g1] 0x58 !DMMU Synchronous Fault Status register=0

	!! Enable error trap
	!! setx	cregs_sparc_error_en_reg_r64, %g1, %l1
	!! this instruction has been expanded using constant value cregs_sparc_error_en_reg_r64=3 (from file defines.h)
	!! so the effect should be "trap on correctable error" and "trap on uncorrectable error"
	sethi %hh(0x3),%g1
	or    %g1,%hm(0x3),%g1
	sllx  %g1,32,%g1
	sethi %hi(0x3),%l1
	or    %l1,%g1,%l1
	or    %l1,%lo(0x3),%l1
	stxa  %l1, [%g0] (75)       			!! copy the content of the l1 register into the "SPARC Error Enable reg"

	!! Enable L2-ucache error trap:	Unused in S1 Core
/*
	setx	cregs_l2_error_en_reg_r64, %g1, %l1

	mov	0xaa, %g1
	sllx	%g1, 32, %g1
	stx	%l1, [%g1 + 0x00]
	stx	%l1, [%g1 + 0x40]

	stx	%l1, [%g1 + 0x80]
	stx	%l1, [%g1 + 0xc0]
*/
	
	!! Load Partition ID (permits to multiple OSs to share the same TLB)
        rd      %asr26, %l1				!! %asr26 corresponds to the "Strand Status and Control register"
        set     0x0300, %g1				!! same as "sethi %hi(0x1c00), %g1" "or  %g1, 0x300, %g1"
        and     %l1, %g1, %l1

        srlx    %l1, 8, %l1				!! %l1 has thread ID

	!!setx	part_id_list, %g1, %g2  (part_id_list is defined in file hboot.s)
	!! this instruction is expanded as:
	sethi  %hi(0), %g1
	sethi  %hi(0x4c000), %g2
	mov  %g1, %g1
	mov  %g2, %g2
	sllx  %g1, 0x20, %g1
	or  %g2, %g1, %g2

        sllx    %l1, 3, %l1					!! offset - partition list
        ldx     [%g2 + %l1], %g2				!! %g2 contains partition ID
	mov	0x80, %g1
	stxa	%g2, [%g1] 0x58					!! I/DMMU Partition ID=g2

	!! Set Hypervisor Trap Base Address
	!! setx HV_TRAP_BASE_PA, %l0, %l7
	!! being HV_TRAP_BASE_PA=0x80000 it expands to:
	sethi %hh(0x80000),%g1
	or    %g1,%hm(0x80000),%g1
	sllx  %g1,32,%g1
	sethi %hi(0x80000),%l1
	or    %l1,%g1,%l1
	or    %l1,%lo(0x80000),%l1

	wrhpr %l7, %g0, %htba                          		!! bits 63-14 select the trap vector for a trap served in Hyperprivileged mode

	!! Load TSB config/base from memory and write to corresponding ASI's
	!! set tsb-reg (4 at present) for one partition
	!! 2 i-config, 2-dconfig

	!!setx	tsb_config_base_list, %l0, %g1		
	!! this instructions expands as
	sethi  %hi(0), %l0
	sethi  %hi(0x4c000), %g1
	mov  %l0, %l0
	or  %g1, 0x140, %g1
	sllx  %l0, 0x20, %l0
	or  %g1, %l0, %g1

	sllx	%g2, 7, %g2					!! %g2 contains offset to tsb_config_base_list
	add	%g1, %g2, %g1					!! %g1 contains pointer to tsb_config_base_list

	!! IMMU_CXT_Z_CONFIG   (0x37, VA=0x00)
	ldx	[%g1], %l1
	stxa	%l1, [%g0] 0x37

	!! IMMU_CXT_NZ_CONFIG  (0x3f, VA=0x00)
	ldx	[%g1+8], %l1
	stxa	%l1, [%g0] 0x3f

	!! IMMU_CXT_Z_PS0_TSB  (0x35, VA=0x0)
	!! IMMU_CXT_Z_PS1_TSB  (0x36, VA=0x0)
	ldx	[%g1+16], %l1
	stxa	%l1, [%g0] 0x35
	ldx	[%g1+32], %l1
	stxa	%l1, [%g0] 0x36

	!! IMMU_CXT_NZ_PS0_TSB (0x3d, VA=0x00)
	!! IMMU_CXT_NZ_PS1_TSB (0x3e, VA=0x00)
	ldx	[%g1+24], %l1
	stxa	%l1, [%g0] 0x3d
	ldx	[%g1+40], %l1
	stxa	%l1, [%g0] 0x3e
		
	!! DMMU_CXT_Z_CONFIG   (0x33, VA=0x00)
	ldx	[%g1+64], %l1
	stxa	%l1, [%g0] 0x33

	!! DMMU_CXT_NZ_CONFIG  (0x3b, VA=0x00)
	ldx	[%g1+72], %l1
	stxa	%l1, [%g0] 0x3b

	!! DMMU_CXT_Z_PS0_TSB  (0x31, VA=0x00)
	!! DMMU_CXT_Z_PS1_TSB  (0x32, VA=0x00)
	ldx	[%g1+80], %l1
	stxa	%l1, [%g0] 0x31
	ldx	[%g1+96], %l1
	stxa	%l1, [%g0] 0x32
	
	!! DMMU_CXT_NZ_PS0_TSB (0x39, VA=0x00)
	!! DMMU_CXT_NZ_PS0_TSB (0x3a, VA=0x00)
	ldx	[%g1+88], %l1
	stxa	%l1, [%g0] 0x39
	ldx	[%g1+104], %l1
	stxa	%l1, [%g0] 0x3a

	!! Demap all itlb and dtlb
	mov	0x80, %o2
	stxa	%g0, [%o2] 0x57			!!registro ASI_IMMU_DEMAP=0 (IMMU TLB demap)
	stxa	%g0, [%o2] 0x5f			!!registro ASI_DMMU_DEMAP=0 (DMMU TLB demap)

	!! Initialize primary context register
	mov 0x8, %l1
	stxa %g0, [%l1] 0x21

	!! Initialize secondary context register
	mov 0x10, %l1
	stxa %g0, [%l1] 0x21	

	!! Initialize dtsb entry for i context zero ps0, ps1
/*
	!! Set LSU Control Register to enable icache, dcache, immu, dmmu
	setx	cregs_lsu_ctl_reg_r64, %g1, %l1					!! aka "mov  0xf, %l1"
*/
	!! Set LSU Control Register to enable immu, dmmu but NOT icache, dcache
	mov  0xc, %l1
	stxa  %l1, [%g0] (69)
	!! Register 69 is "Load/Store Unit Control Register", and value 0xC=1100 corresponds to:
	!! .dm=1 (DMMU ENABLE)
	!! .Im=1 (IMMU ENABLE)
	!! .dc=0 (dcache not enabled)
	!! .ic=0 (icache not enabled)

        !! setx	HPriv_Reset_Handler, %g1, %g2
	!! this instructions expands as
	sethi  %hi(0), %g1
	sethi  %hi(0x144000), %g2
	mov  %g1, %g1
	mov  %g2, %g2
	sllx  %g1, 0x20, %g1
	or  %g2, %g1, %g2
	
	rdhpr	%hpstate, %g3
	wrpr	1, %tl             			!! current trap level = 1

	!! setx	cregs_htstate_r64, %g1, %g4
	!! this instructions expands as
	sethi %hh(0x0),%g1
	or    %g1,%hm(0x0),%g1
	sllx  %g1,32,%g1
	sethi %hi(0x0),%l1
	or    %l1,%g1,%l1
	or    %l1,%lo(0x0),%l1

	wrhpr	%g4, %g0, %htstate	!! it should reset the HTSTATE register that store the hyperpriviliged state after a trap
	wrpr	0, %tl			!! current trap level corrente = 0 (No Trap)
	mov     0x0, %o0		!! aka "clr %o0", don't delete since used in customized IMMU miss trap
        jmp	%g2
	wrhpr	%g0, 0x800, %hpstate    !! ensure bit 11 of the HPSTATE register is set (to avoid unwanted behaviors)
        nop
        nop

