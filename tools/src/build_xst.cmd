run
-ifn $FILELIST_XST
-ofn s1_top.ngc
-ifmt MIXED
-ofmt NGC
-top s1_top
-opt_mode SPEED
-opt_level 1
-p xc3s500e-fg320
-vlgincdir { $S1_ROOT/hdl/rtl/sparc_core/include $S1_ROOT/hdl/rtl/s1_top }
