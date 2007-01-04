/*
 * Simply RISC S1 Testbench
 *
 * (C) 2007 Simply RISC LLP
 * AUTHOR: Fabrizio Fazzino <fabrizio.fazzino@srisc.com>
 *
 * LICENSE:
 * This is a Free Hardware Design; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * version 2 as published by the Free Software Foundation.
 * The above named program is distributed in the hope that it will
 * be useful, but WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 *
 * DESCRIPTION:
 * This is the testbench for the functional verification of the
 * S1 Core: it makes and instance of the S1 module to make it
 * possible to access one or more memory harnesses.
 */

`include "s1_defs.h"

module testbench ();

  /*
   * Wires
   */

  // Interrupt Requests
  wire[63:0] sys_irq;

  // Wishbone Master inputs / Wishbone Slave ouputs
  wire wb_ack;                                 // Ack
  wire[(`WB_DATA_WIDTH-1):0] wb_datain;        // Data In

  // Wishbone Master outputs / Wishbone Slave inputs
  wire wb_cycle;                               // Cycle Start
  wire wb_strobe;                              // Strobe Request
  wire wb_we_o;                                // Write Enable
  wire[`WB_ADDR_WIDTH-1:0] wb_addr;            // Address Bus
  wire[`WB_DATA_WIDTH-1:0] wb_dataout;         // Data Out
  wire[`WB_DATA_WIDTH/8-1:0] wb_sel;           // Select Output

  // Separate Cycle wires for memory harnesses
  wire wb_cycle_RED_EXT_SEC;
  wire wb_cycle_HTRAPS;
  wire wb_cycle_TRAPS;
  wire wb_cycle_HPRIV_RESET;
  wire wb_cycle_KERNEL_text;
  wire wb_cycle_KERNEL_data;
  wire wb_cycle_MAIN;
  wire wb_cycle_RED_SEC;

  // Separate Strobe wires for memory harnesses
  wire wb_strobe_RED_EXT_SEC;
  wire wb_strobe_HTRAPS;
  wire wb_strobe_TRAPS;
  wire wb_strobe_HPRIV_RESET;
  wire wb_strobe_KERNEL_text;
  wire wb_strobe_KERNEL_data;
  wire wb_strobe_MAIN;
  wire wb_strobe_RED_SEC;

  // Separate Ack wires for memory harnesses
  wire wb_ack_RED_EXT_SEC;
  wire wb_ack_HTRAPS;
  wire wb_ack_TRAPS;
  wire wb_ack_HPRIV_RESET;
  wire wb_ack_KERNEL_text;
  wire wb_ack_KERNEL_data;
  wire wb_ack_MAIN;
  wire wb_ack_RED_SEC;

  /*
   * Registers
   */

  // System signals
  reg sys_clock;
  reg sys_reset;

  /*
   * Behavior
   */

  always #1 sys_clock = ~sys_clock;
  assign sys_irq = 64'b0;

  initial begin

    // Display start message
    $display("INFO: TBENCH: Starting Simply RISC S1 Core simulation...");

    // Create VCD trace file
    $dumpfile("trace.vcd");
    $dumpvars();

    // Run the simulation
    sys_clock <= 1'b1;
    sys_reset <= 1'b1;
    #100
    sys_reset <= 1'b0;
    #9900
    $display("INFO: TBENCH: Completed Simply RISC S1 Core simulation!");
    $finish;

  end

  /*
   * Simply RISC S1 module instance
   */

  s1_top s1_top_0 (

    // System inputs
    .sys_clock_i(sys_clock),
    .sys_reset_i(sys_reset),
    .sys_irq_i(sys_irq),

    // Wishbone Master inputs
    .wbm_ack_i(wb_ack),
    .wbm_data_i(wb_datain),

    // Wishbone Master outputs
    .wbm_cycle_o(wb_cycle),
    .wbm_strobe_o(wb_strobe),
    .wbm_we_o(wb_we),
    .wbm_addr_o(wb_addr),
    .wbm_data_o(wb_dataout),
    .wbm_sel_o(wb_sel)

  );

  /*
   * Memory Harnesses with Wishbone Slave interface
   */

  // Section '.RED_EXT_SEC', segment 'text' - From PA 0000040000 to 0000047FFF and then together with
  // Section '.RED_EXT_SEC', segment 'data' - From PA 000004C000 to 000004FFFF => 16-3=13 addr_bits
  defparam mem_RED_EXT_SEC.addr_bits = 13;
  defparam mem_RED_EXT_SEC.memfilename = "mem_RED_EXT_SEC.image";
  defparam mem_RED_EXT_SEC.memdefaultcontent = 64'h0100000001000000;

  // Section '.HTRAPS', segment 'text'      - From PA 0000080000 to 0000087FFF and then together with
  // Section '.HTRAPS', segment 'data'      - From PA 000008C000 to 000008FFFF (zeroes) => 16-3=13 addr_bits
  defparam mem_HTRAPS.addr_bits = 13;
  defparam mem_HTRAPS.memfilename = "mem_HTRAPS.image";
  defparam mem_HTRAPS.memdefaultcontent = 64'h0100000001000000;

  // Section '.TRAPS', segment 'text'       - From PA 1000120000 to 1000127FFF and then together with
  // Section '.TRAPS', segment 'data'       - From PA 100012C000 to 100012FFFF (zeroes) => 16-3=13 addr_bits
  defparam mem_TRAPS.addr_bits = 13;
  defparam mem_TRAPS.memfilename = "mem_TRAPS.image";
  defparam mem_TRAPS.memdefaultcontent = 64'h0100000001000000;

  // Section '.HPRIV_RESET', segment 'text' - From PA 1000144000 to 1000144FFF => 12-3=9 addr_bits
  defparam mem_HPRIV_RESET.addr_bits = 9;
  defparam mem_HPRIV_RESET.memfilename = "mem_HPRIV_RESET.image";
  defparam mem_HPRIV_RESET.memdefaultcontent = 64'h0100000001000000;

  // Section '.KERNEL', segment 'text'      - From PA 1101834000 to 1101834FFF => 12-3=9 addr_bits
  defparam mem_KERNEL_text.addr_bits = 9;
  defparam mem_KERNEL_text.memfilename = "mem_KERNEL_text.image";
  defparam mem_KERNEL_text.memdefaultcontent = 64'h0100000001000000;

  // Section '.KERNEL', segment 'data'      - From PA 1101C34000 to 1101C34FFF => 12-3=9 addr_bits
  defparam mem_KERNEL_data.addr_bits = 9;
  defparam mem_KERNEL_data.memfilename = "mem_KERNEL_data.image";
  defparam mem_KERNEL_data.memdefaultcontent = 64'h0000000000000000;

  // Section '.MAIN', segment 'text'        - From PA 1130000000 to 113000FFFF => 16-3=13 addr_bits
  // Section '.MAIN', segment 'data'        - From PA 1170000000 but should be empty
  // Section '.USER_HEAP', segment 'data'   - From PA 1178020000 but should be empty
  // Section '.MAIN', segment 'bss'         - From PA 1178030000 but should be empty
  defparam mem_MAIN.addr_bits = 13;
  defparam mem_MAIN.memfilename = "mem_MAIN.image";
  defparam mem_MAIN.memdefaultcontent = 64'h0100000001000000;

  // Section '.RED_SEC', segment 'text'     - From PA FFF0000000 to FFF0000FFF => 12-3=9 addr_bits
  // Section '.RED_SEC', segment 'data'     - From PA FFF0010000 but should contain only an unused word
  defparam mem_RED_SEC.addr_bits = 9;
  defparam mem_RED_SEC.memfilename = "mem_RED_SEC.image";
  defparam mem_RED_SEC.memdefaultcontent = 64'h0100000001000000;

  // Decode the address and select the proper memory bank

  assign wb_cycle_RED_EXT_SEC = ( (wb_addr[39:16]==24'h000004) ? wb_cycle : 0 );
  assign wb_strobe_RED_EXT_SEC = ( (wb_addr[39:16]==24'h000004) ? wb_strobe : 0 );

  assign wb_cycle_HTRAPS = ( (wb_addr[39:16]==24'h000008) ? wb_cycle : 0 );
  assign wb_strobe_HTRAPS = ( (wb_addr[39:16]==24'h000008) ? wb_strobe : 0 );

  assign wb_cycle_TRAPS = ( (wb_addr[39:16]==24'h100012) ? wb_cycle : 0 );
  assign wb_strobe_TRAPS = ( (wb_addr[39:16]==24'h100012) ? wb_strobe : 0 );

  assign wb_cycle_HPRIV_RESET = ( (wb_addr[39:12]==28'h1000144) ? wb_cycle : 0 );
  assign wb_strobe_HPRIV_RESET = ( (wb_addr[39:12]==28'h1000144) ? wb_strobe : 0 );

  assign wb_cycle_KERNEL_text = ( (wb_addr[39:12]==28'h1101834) ? wb_cycle : 0 );
  assign wb_strobe_KERNEL_text = ( (wb_addr[39:12]==28'h1101834) ? wb_strobe : 0 );

  assign wb_cycle_KERNEL_data = ( (wb_addr[39:12]==28'h1101C34) ? wb_cycle : 0 );
  assign wb_strobe_KERNEL_data = ( (wb_addr[39:12]==28'h1101C34) ? wb_strobe : 0 );

  assign wb_cycle_MAIN = ( (wb_addr[39:16]==24'h113000) ? wb_cycle : 0 );
  assign wb_strobe_MAIN = ( (wb_addr[39:16]==24'h113000) ? wb_strobe : 0 );

  assign wb_cycle_RED_SEC = ( (wb_addr[39:12]==28'hFFF0000) ? wb_cycle : 0 );
  assign wb_strobe_RED_SEC = ( (wb_addr[39:12]==28'hFFF0000) ? wb_strobe : 0 );

  assign wb_ack = wb_ack_RED_EXT_SEC | wb_ack_HTRAPS | wb_ack_TRAPS | wb_ack_HPRIV_RESET |
    wb_ack_KERNEL_text | wb_ack_KERNEL_data | wb_ack_MAIN | wb_ack_RED_SEC;

  mem_harness mem_RED_EXT_SEC (

    // System inputs
    .sys_clock_i(sys_clock),
    .sys_reset_i(sys_reset),

    // Wishbone Slave inputs
    .wbs_addr_i(wb_addr),
    .wbs_data_i(wb_dataout),
    .wbs_cycle_i(wb_cycle_RED_EXT_SEC),
    .wbs_strobe_i(wb_strobe_RED_EXT_SEC),
    .wbs_sel_i(wb_sel),
    .wbs_we_i(wb_we),

    // Wishbone Slave outputs
    .wbs_data_o(wb_datain),
    .wbs_ack_o(wb_ack_RED_EXT_SEC)

  );

  mem_harness mem_HTRAPS (

    // System inputs
    .sys_clock_i(sys_clock),
    .sys_reset_i(sys_reset),

    // Wishbone Slave inputs
    .wbs_addr_i(wb_addr),
    .wbs_data_i(wb_dataout),
    .wbs_cycle_i(wb_cycle_HTRAPS),
    .wbs_strobe_i(wb_strobe_HTRAPS),
    .wbs_sel_i(wb_sel),
    .wbs_we_i(wb_we),

    // Wishbone Slave outputs
    .wbs_data_o(wb_datain),
    .wbs_ack_o(wb_ack_HTRAPS)

  );

  mem_harness mem_TRAPS (

    // System inputs
    .sys_clock_i(sys_clock),
    .sys_reset_i(sys_reset),

    // Wishbone Slave inputs
    .wbs_addr_i(wb_addr),
    .wbs_data_i(wb_dataout),
    .wbs_cycle_i(wb_cycle_TRAPS),
    .wbs_strobe_i(wb_strobe_TRAPS),
    .wbs_sel_i(wb_sel),
    .wbs_we_i(wb_we),

    // Wishbone Slave outputs
    .wbs_data_o(wb_datain),
    .wbs_ack_o(wb_ack_TRAPS)

  );

  mem_harness mem_HPRIV_RESET (

    // System inputs
    .sys_clock_i(sys_clock),
    .sys_reset_i(sys_reset),

    // Wishbone Slave inputs
    .wbs_addr_i(wb_addr),
    .wbs_data_i(wb_dataout),
    .wbs_cycle_i(wb_cycle_HPRIV_RESET),
    .wbs_strobe_i(wb_strobe_HPRIV_RESET),
    .wbs_sel_i(wb_sel),
    .wbs_we_i(wb_we),

    // Wishbone Slave outputs
    .wbs_data_o(wb_datain),
    .wbs_ack_o(wb_ack_HPRIV_RESET)

  );

  mem_harness mem_KERNEL_text (

    // System inputs
    .sys_clock_i(sys_clock),
    .sys_reset_i(sys_reset),

    // Wishbone Slave inputs
    .wbs_addr_i(wb_addr),
    .wbs_data_i(wb_dataout),
    .wbs_cycle_i(wb_cycle_KERNEL_text),
    .wbs_strobe_i(wb_strobe_KERNEL_text),
    .wbs_sel_i(wb_sel),
    .wbs_we_i(wb_we),

    // Wishbone Slave outputs
    .wbs_data_o(wb_datain),
    .wbs_ack_o(wb_ack_KERNEL_text)

  );

  mem_harness mem_KERNEL_data (

    // System inputs
    .sys_clock_i(sys_clock),
    .sys_reset_i(sys_reset),

    // Wishbone Slave inputs
    .wbs_addr_i(wb_addr),
    .wbs_data_i(wb_dataout),
    .wbs_cycle_i(wb_cycle_KERNEL_data),
    .wbs_strobe_i(wb_strobe_KERNEL_data),
    .wbs_sel_i(wb_sel),
    .wbs_we_i(wb_we),

    // Wishbone Slave outputs
    .wbs_data_o(wb_datain),
    .wbs_ack_o(wb_ack_KERNEL_data)

  );

  mem_harness mem_MAIN (

    // System inputs
    .sys_clock_i(sys_clock),
    .sys_reset_i(sys_reset),

    // Wishbone Slave inputs
    .wbs_addr_i(wb_addr),
    .wbs_data_i(wb_dataout),
    .wbs_cycle_i(wb_cycle_MAIN),
    .wbs_strobe_i(wb_strobe_MAIN),
    .wbs_sel_i(wb_sel),
    .wbs_we_i(wb_we),

    // Wishbone Slave outputs
    .wbs_data_o(wb_datain),
    .wbs_ack_o(wb_ack_MAIN)

  );

  mem_harness mem_RED_SEC (

    // System inputs
    .sys_clock_i(sys_clock),
    .sys_reset_i(sys_reset),

    // Wishbone Slave inputs
    .wbs_addr_i(wb_addr),
    .wbs_data_i(wb_dataout),
    .wbs_cycle_i(wb_cycle_RED_SEC),
    .wbs_strobe_i(wb_strobe_RED_SEC),
    .wbs_sel_i(wb_sel),
    .wbs_we_i(wb_we),

    // Wishbone Slave outputs
    .wbs_data_o(wb_datain),
    .wbs_ack_o(wb_ack_RED_SEC)

  );

endmodule
