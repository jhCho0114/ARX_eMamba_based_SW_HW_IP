set verilog_module_list [concat_file_list $verilog_module_list ${PLATFORM_DIR}/user/rtl/src/*.v]
set verilog_module_list [concat_file_list $verilog_module_list ${PLATFORM_DIR}/user/rtl/src/*/*.v]
# SV packages must be read before the modules that import them; the *.sv glob sorts them after emy_buf / emy_dw
# (emy_head_rom_pkg.sv: ROMs of emy_dfl_side / emy_head_math, U_504 DET mode)
set user_rtl_pkg_list [list ${PLATFORM_DIR}/user/rtl/src/emy_pkg.sv ${PLATFORM_DIR}/user/rtl/src/emy_engine_pkg.sv ${PLATFORM_DIR}/user/rtl/src/emy_head_rom_pkg.sv]
foreach f $user_rtl_pkg_list {
	lappend verilog_module_list $f
}
foreach f [lsort [glob -nocomplain ${PLATFORM_DIR}/user/rtl/src/*.sv]] {
	if {[lsearch -exact $user_rtl_pkg_list $f] < 0} {
		lappend verilog_module_list $f
	}
}
set verilog_module_list [concat_file_list $verilog_module_list ${PLATFORM_DIR}/user/rtl/src/*/*.sv]
lappend verilog_include_list ${PLATFORM_DIR}/user/rtl/include

set vhdl_module_list [concat_file_list $vhdl_module_list ${PLATFORM_DIR}/user/rtl/src/*.{vhd,vhdl}]
set vhdl_module_list [concat_file_list $vhdl_module_list ${PLATFORM_DIR}/user/rtl/src/*/*.{vhd,vhdl}]
