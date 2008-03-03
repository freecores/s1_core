
# The Tcl script under $S1_ROOT/tools/src/build_dc.cmd is attached at the end of the filelist for DC;
# if you modify this file *REMEMBER* to run 'update_filelist' or you'll run the old version!!!

# Technology-independent elaboration and linking

set active_design s1_top
elaborate $active_design
current_design $active_design
link
uniquify
check_design

# Constraints and mapping on target library

create_clock -period 5.0 -waveform [list 0 2.5] sys_clock_i
set_input_delay  2.0 -clock sys_clock_i -max [all_inputs]
set_output_delay 2.0 -clock sys_clock_i -max [all_outputs]
set_dont_touch_network [list sys_clock_i sys_reset_i]
set_drive 0 [list sys_clock_i sys_reset_i]
set_wire_load_mode enclosed
set_max_area 0
set_fix_multiple_port_nets -buffer_constants -all
compile

# Export the mapped design

remove_unconnected_ports [find -hierarchy cell {"*"}]
write -format ddc -hierarchy -output $active_design.ddc
write -format verilog -hierarchy -output $active_design.sv

# Report area and timing

report_area -hierarchy > report_area.rpt
report_timing > report_timing.rpt
report_constraint -all_violators > report_constraint.rpt

quit

