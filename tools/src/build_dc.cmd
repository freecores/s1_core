
# The Tcl script under $S1_ROOT/tools/src/build_dc.cmd is attached at the end of the filelist for DC;
# if you modify this file *REMEMBER* to run 'update_filelist' or you'll run the old version!!!

elaborate s1_top
link
uniquify
check_design

# Constraints

create_clock -name "sys_clock_i" -period 4.0 -waveform {0 2.0} [get_ports "sys_clock_i"]
set_dont_touch_network [get_clocks "sys_clock_i"]
set_input_delay 2.50 -max -rise -clock "sys_clock_i" [get_ports "sys_reset_i"]
set_input_delay 2.50 -max -fall -clock "sys_clock_i" [get_ports "sys_reset_i"]
set_output_delay 2.50 -clock sys_clock_i -max -rise [all_outputs]
set_output_delay 2.50 -clock sys_clock_i -max -fall [all_outputs]
set_wire_load_mode "enclosed" 

# Compile

compile

# Export

write -format ddc -hierarchy -output "s1_top.ddc"
write -format verilog -hierarchy -output "s1_top.v"

# Report

report_area -hierarchy > report_area.txt
report_timing > report_timing.txt
report_constraint -all_violators > report_constraint.txt

quit

