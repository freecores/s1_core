# The Tcl script under $S1_ROOT/tools/src/build_dc.cmd is attached at the end of the filelist for DC;
# if you modify this file *REMEMBER* to run 'update_filelist' or you'll run the old version!!!

elaborate s1_top
link
uniquify
check_design

# Constraints

create_clock -name "sys_clock_i" -period 2.0 -waveform {0 1.0} [get_ports "sys_clock_i"]
set_dont_touch_network [get_clocks "sys_clock_i"]
set_input_delay 1.25 -max -rise -clock "sys_clock_i" [get_ports "sys_reset_i"]
set_input_delay 1.25 -max -fall -clock "sys_clock_i" [get_ports "sys_reset_i"]
set_output_delay 1.25 -clock sys_clock_i -max -rise [all_outputs]
set_output_delay 1.25 -clock sys_clock_i -max -fall [all_outputs]
set_wire_load_mode "enclosed" 

# Compile

compile

# Export

write -format db -hierarchy -output "s1_top.db"
write -format verilog -hierarchy -output "s1_top.v"

# Report

report_area > report_area.txt
report_timing > report_timing.txt
report_constraint -all_violators > report_constraint.txt

quit

