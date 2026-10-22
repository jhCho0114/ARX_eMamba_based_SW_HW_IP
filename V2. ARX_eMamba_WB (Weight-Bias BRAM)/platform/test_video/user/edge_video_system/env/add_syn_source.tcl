## ****************************************************************************
## add_syn_source.tcl (LOCAL OVERRIDE - EDIF Black Box)
## This file is loaded by set_rtl_syn_env.tcl via the LOCAL path priority:
##   ${PLATFORM_DIR}/user/edge_video_system/env/add_syn_source.tcl
## It replaces the global RTL source with pre-synthesized EDIF netlist.
## ****************************************************************************
## ****************************************************************************
lappend edf_list ${PLATFORM_DIR}/user/edge_video_system/src/EDGE_VIDEO_SYSTEM.edf

## Verilog stub for black box port declaration
lappend verilog_module_list ${PLATFORM_DIR}/user/edge_video_system/src/EDGE_VIDEO_SYSTEM_stub.v

## Include path (still needed: test_video_rtl.v uses video_module_port_mapping.vh)
lappend verilog_include_list ${PLATFORM_DIR}/user/edge_video_system/include

## Note: ERVP_DMA sources are already compiled into the EDIF netlist.
## Do NOT source ${RVX_HWLIB_HOME}/peripheral/dma/env/add_syn_source.tcl here.
