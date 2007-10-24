
/* If you modify this file remember to run update_filelist so that filelist.dc gets updated!!! */

elaborate s1_top
link
uniquify
/* check_design */

create_clock -period 2.0 -name sys_clock_i find(port, "sys_clock_i")
set_input_delay  -max -clock sys_clock_i 1 all_inputs () find (port, "sys_clock_i")
set_output_delay 1 -max -clock sys_clock_i all_outputs()

compile -map_effort high

write -output s1_top.db  -format ddc  -hierarchy
write -output s1_top.v  -format verilog  -hierarchy

report_area > report_area.txt
report_timing > report_timing.txt
report_constraint -all_violators > report_constraint.txt

quit

