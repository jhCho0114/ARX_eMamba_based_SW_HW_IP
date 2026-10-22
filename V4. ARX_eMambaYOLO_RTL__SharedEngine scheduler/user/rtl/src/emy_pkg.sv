// emy_pkg : number rules shared by every eMamba-YOLO INT8 module (spec: share_work/layers_int8_emamba.py)
//
//   real  = int * 2^-shift              (activation: one shift per tensor, weight: one per output channel)
//   rshr(x, s) = (x + 2^(s-1)) >>> s    round half up, s > 0.   s <= 0 : x <<< -s (exact)
//   sat8(x)    = clip(x, -128, 127)
//   requant(q, s_from, s_to) = sat8(rshr(q, s_from - s_to))
//
// The functions below are 64-bit reference versions for testbenches and constant evaluation.
// Synthesizable datapath: emy_requant.sv (parameterized widths).
package emy_pkg;

    localparam int ACT_W  = 8;     // int8 activations / weights
    localparam int BIAS_W = 32;    // conv bias (int32, shift = s_in + weight_shift)
    localparam int WIDE_W = 16;    // Add / Mul / CrossMerge / Concat wide integers: measured <= 14 bit

    // weight / bias broadcast (U_eMamba wb_broadcast_loader): byte address, one 32-bit word per wb_valid
    localparam int WB_ADDR_W = 24;  // image 4.6 MB (tools/wb_map.py, emy_wb_map_pkg::WB_TOTAL_ADDR_W = 23)
    localparam int WB_DATA_W = 32;

    // window sizes in bytes, same layout as tools/wb_map.py
    function automatic int ceil4(input int n);
        return (n + 3) / 4 * 4;
    endfunction

    function automatic int conv_wb_bytes(input int num_out, input int num_k, input bit use_bias);
        return num_out * ceil4(num_k) + (use_bias ? 4 * num_out : 0) + ceil4(num_out);
    endfunction

    function automatic int ln_wb_bytes(input int num_ch);
        return 2 * ceil4(num_ch) + 4 * 256;
    endfunction

    function automatic longint rshr(input longint x, input int s);
        if (s <= 0) return x <<< (-s);
        return (x + (64'sd1 <<< (s - 1))) >>> s;
    endfunction

    function automatic longint sat(input longint x, input int bits = 8);
        longint lo, hi;
        lo = -(64'sd1 <<< (bits - 1));
        hi = (64'sd1 <<< (bits - 1)) - 1;
        return (x < lo) ? lo : (x > hi) ? hi : x;
    endfunction

    function automatic longint requant(input longint q, input int s_from, input int s_to);
        return sat(rshr(q, s_from - s_to), 8);
    endfunction

endpackage
