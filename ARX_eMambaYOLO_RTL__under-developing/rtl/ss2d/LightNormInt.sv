`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: LightNormInt
// Description: integer LightNorm over the channels of one token -- steps 08 and 22 and
//              18 out_norm (SS2D).  The golden uses this integer form (layers_int8_emamba.
//              SW.LightNormInt), not the mean-division + divider of U_LightNorm, which drifts
//              from the golden from the first LightNorm on.  C = NUM_DIM = 2^k channels:
//                  S   = sum_c q[c],   R = max_c q - min_c q          (R in 0..255)
//                  d   = C*q[c] - S                                   (= C*(q - mean), exact)
//                  z   = trunc0(d * LUT[R] / 2^k)                     (toward zero)
//                  acc = z * w[c] + (b[c] << NUM_LSH_BIAS)            NUM_LSH_BIAS = F + s_w - s_b
//                  dOut = sat8(rshr(acc, NUM_RSH_DOUT))               NUM_RSH_DOUT = F + s_w - s_out
//              LUT[R] = floor(2^F / (0.32*R + eps*2^s_in)), LUT[0] = 0, F = 20 (SW.ln_recip_table).
//
//   Widths: |d| <= C*255 (DATA_WIDTH + k + 1 bits, whatever the table), and |d*LUT| < C*2^F/0.32
//   (< 2^31 at C = 512); 40 bits are kept for d*LUT and acc.
//
//   NUM_LANE (P) channels per cycle: the token is NCH = NUM_DIM / P chunks.  Token in, token out
//   (registered), s_valid/s_ready and m_valid/m_ready.  Per token:
//     STAT  NCH + STEPS + 1 cycles: the chunks one per cycle through a registered tree of 4:1
//           reductions (S, max, min; P -> P/4 -> ... -> 1, STEPS levels), summed over the chunks
//     LUT   2 cycles: LUT[R] out of its RAM, then a register (no RAM -> multiplier path)
//     NORM  NCH + 5 cycles: d | d * LUT | trunc | z * w | + (b << LSH) | rshr + sat8, a chunk per
//           cycle, each stage registered; the chunks build the output token
//     DONE  until m_ready
//   The token waits in a register that rotates by one chunk per STAT / NORM cycle (no chunk mux;
//   NCH rotations bring it back).  Only the schedule depends on P; the arithmetic is the one above.
//
//   WB window (byte addresses, 4 bytes per word, lowest byte = lowest index), sent in ascending
//   word order (Wb_Row_Loader counts the words; NUM_LANE % 4 == 0 unless NUM_LANE == NUM_DIM):
//     WB_BASE_W : w[c], one byte each (padded to a word)
//     WB_BASE_B : b[c], one byte each (padded to a word)
//     WB_BASE_L : LUT[r], r = 0..255, one word each (unsigned)
//
// Dependencies: Requant_Lane.sv -> shifter_right.sv, shifter_left.sv (U_eMamba/RTL), Wb_Row_Loader.sv
//////////////////////////////////////////////////////////////////////////////////
module LightNormInt #(
    parameter integer DATA_WIDTH   = 8,
    parameter integer NUM_DIM      = 64,
    parameter integer NUM_LANE     = NUM_DIM,
    parameter integer NUM_LSH_BIAS = 17,
    parameter integer NUM_RSH_DOUT = 21,

    parameter integer WB_ADDR_W    = 24,
    parameter integer WB_BASE_W    = 0,
    parameter integer WB_BASE_B    = WB_BASE_W + ((NUM_DIM + 3) / 4) * 4,
    parameter integer WB_BASE_L    = WB_BASE_B + ((NUM_DIM + 3) / 4) * 4
)(
    clk,
    nRst,
    ps_start,

    wb_valid,
    wb_addr,
    wb_data,

    dIn,
    dOut,

    s_valid,
    s_ready,
    m_valid,
    m_ready
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam IDLE = 3'd0,
           STAT = 3'd1,
           LUT  = 3'd2,
           NORM = 3'd3,
           DONE = 3'd4;

localparam integer P      = NUM_LANE;
localparam integer NCH    = NUM_DIM / NUM_LANE;
localparam integer K      = $clog2(NUM_DIM);
localparam integer KP     = $clog2(NUM_LANE);
localparam integer WIDE   = 40;
localparam integer SUM_W  = DATA_WIDTH + K + 1;
localparam integer D_W    = DATA_WIDTH + K + 2;     // |d| <= C * 255
localparam integer STEPS  = (KP + 1) / 2 > 0 ? (KP + 1) / 2 : 1;   // 4:1 levels over a chunk
localparam integer CNT_W  = $clog2(NCH + STEPS + 6);
localparam integer CW     = P * DATA_WIDTH;
localparam integer TW     = NUM_DIM * DATA_WIDTH;
localparam integer CH_W   = ($clog2(NCH) > 0) ? $clog2(NCH) : 1;
localparam integer V_WORDS = (P + 3) / 4;
localparam logic signed [DATA_WIDTH-1:0] Q_MAX = {1'b0, {(DATA_WIDTH-1){1'b1}}};
localparam logic signed [DATA_WIDTH-1:0] Q_MIN = {1'b1, {(DATA_WIDTH-1){1'b0}}};

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input  logic clk, nRst, ps_start;

input  logic                 wb_valid;
input  logic [WB_ADDR_W-1:0] wb_addr;
input  logic [31:0]          wb_data;

input  logic signed [DATA_WIDTH-1:0] dIn  [0:NUM_DIM-1];
output logic signed [7:0]            dOut [0:NUM_DIM-1];

input  logic s_valid, m_ready;
output logic s_ready, m_valid;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic [2:0]       state;
logic [CNT_W-1:0] cnt;

// w, b: one row per chunk;  LUT: one word per entry
logic [CW-1:0]    w_mem [0:NCH-1];
logic [CW-1:0]    b_mem [0:NCH-1];
logic [31:0]      lut_mem [0:255];
logic             w_we, b_we;
logic [CH_W-1:0]  w_row, b_row;
logic [CW-1:0]    w_data, b_data;
logic [CW-1:0]    w_q, b_q;

logic [TW-1:0]           q;              // the token; chunk j at the low bits after j rotations
logic signed [SUM_W-1:0] sum_q, acc_sum;
logic signed [DATA_WIDTH-1:0] acc_max, acc_min;
logic [DATA_WIDTH:0]     range_q;
logic [31:0]             lut_raw, lut_q;

// reduction levels over a chunk: level 0 is the chunk, level s + 1 holds ceil(n_s / 4) partial results
logic signed [SUM_W-1:0]      lv_sum [0:STEPS][0:P-1];
logic signed [DATA_WIDTH-1:0] lv_max [0:STEPS][0:P-1];
logic signed [DATA_WIDTH-1:0] lv_min [0:STEPS][0:P-1];

// NORM pipeline, one chunk per stage
logic                   n1, n2, n3, n4, n5;
logic [CH_W-1:0]        k1, k2, k3, k4, k5;
logic signed [D_W-1:0]  d1   [0:P-1];
logic signed [WIDE-1:0] p2   [0:P-1];
logic signed [WIDE-1:0] z3   [0:P-1];
logic signed [WIDE-1:0] m4   [0:P-1];
logic signed [WIDE-1:0] acc5 [0:P-1];
logic signed [7:0]      y5   [0:P-1];
logic [CW-1:0]          y_chunk;
logic [(NCH > 1 ? TW - CW : 1)-1:0] asm_q;
logic [TW-1:0]          out_q;

// ---------- ---------- ---------- ---------- Parameter guards ---------- ---------- ---------- ----------
generate
    if ((1 << K) != NUM_DIM)
        $error("LightNormInt: NUM_DIM must be a power of two (the mean is taken as a shift by K)");
    if (DATA_WIDTH != 8)
        $error("LightNormInt: DATA_WIDTH must be 8 (the reciprocal table has 256 entries, R = max - min)");
    if (NUM_LSH_BIAS < 0)
        $error("LightNormInt: NUM_LSH_BIAS = F + s_w - s_b must be >= 0 (a right-shifted bias is not implemented)");
    if (NUM_DIM % NUM_LANE != 0)
        $error("LightNormInt: NUM_LANE = %0d must divide NUM_DIM = %0d", NUM_LANE, NUM_DIM);
    if (NCH > 1 && NUM_LANE % 4 != 0)
        $error("LightNormInt: NUM_LANE must be a multiple of 4 (a chunk of w / b starts on a word)");
    if (64'(WB_BASE_L) + 256 * 4 > (64'd1 << WB_ADDR_W))
        $error("LightNormInt: the LUT window does not fit the %0d-bit WB address", WB_ADDR_W);
endgenerate

assign s_ready = (state == IDLE);
assign m_valid = (state == DONE);

// ---------- ---------- ---------- ---------- Weight Broadcast ---------- ---------- ---------- ----------
Wb_Row_Loader #(.WB_ADDR_W(WB_ADDR_W), .BASE(WB_BASE_W), .ROWS(NCH), .ROW_WORDS(V_WORDS), .ROW_BITS(CW))
    load_w (.clk(clk), .nRst(nRst), .wb_valid(wb_valid), .wb_addr(wb_addr), .wb_data(wb_data),
            .we(w_we), .row(w_row), .data(w_data));
Wb_Row_Loader #(.WB_ADDR_W(WB_ADDR_W), .BASE(WB_BASE_B), .ROWS(NCH), .ROW_WORDS(V_WORDS), .ROW_BITS(CW))
    load_b (.clk(clk), .nRst(nRst), .wb_valid(wb_valid), .wb_addr(wb_addr), .wb_data(wb_data),
            .we(b_we), .row(b_row), .data(b_data));

always @(posedge clk) begin
    if (w_we) w_mem[w_row] <= #1 w_data;
    if (b_we) b_mem[b_row] <= #1 b_data;
    if (wb_valid && wb_addr >= WB_BASE_L && wb_addr < WB_BASE_L + 256 * 4)
        lut_mem[(wb_addr - WB_BASE_L) >> 2] <= #1 wb_data;
end

// ---------- ---------- ---------- ---------- Token register ---------- ---------- ---------- ----------
// loaded at the handshake; rotated one chunk per cycle while chunks go into STAT and NORM
wire rotate = (state == STAT || state == NORM) && (cnt < NCH);
logic [TW-1:0] q_rot;
generate
    if (NCH > 1) begin: Rot
        assign q_rot = {q[CW-1:0], q[TW-1:CW]};
    end else begin: No_Rot
        assign q_rot = q;
    end
endgenerate
always @(posedge clk) begin
    if (state == IDLE && s_valid)
        for (int ch = 0; ch < NUM_DIM; ch++) q[ch * DATA_WIDTH +: DATA_WIDTH] <= #1 dIn[ch];
    else if (rotate)
        q <= #1 q_rot;
end

// ---------- ---------- ---------- ---------- STAT: S, max, min ---------- ---------- ---------- ----------
// chunk j enters level 1 at cnt = j and leaves level STEPS at cnt = j + STEPS; the levels load
// during STAT only (idle the rest of the time: power, and simulation time)
genvar g, lv;
generate
    for (g = 0; g < P; g = g + 1) begin: Level0
        assign lv_sum[0][g] = SUM_W'($signed(q[g * DATA_WIDTH +: DATA_WIDTH]));
        assign lv_max[0][g] = q[g * DATA_WIDTH +: DATA_WIDTH];
        assign lv_min[0][g] = q[g * DATA_WIDTH +: DATA_WIDTH];
    end
    for (lv = 0; lv < STEPS; lv = lv + 1) begin: Level
        localparam integer N_IN  = (P + (1 << (2 * lv)) - 1) >> (2 * lv);
        localparam integer N_OUT = (N_IN + 3) / 4;
        for (g = 0; g < N_OUT; g = g + 1) begin: Group
            always @(posedge clk) if (state == STAT) begin
                automatic logic signed [SUM_W-1:0]      vs [0:3];
                automatic logic signed [DATA_WIDTH-1:0] vx [0:3];
                automatic logic signed [DATA_WIDTH-1:0] vn [0:3];
                for (int j = 0; j < 4; j++) begin
                    vs[j] = (g * 4 + j < N_IN) ? lv_sum[lv][g * 4 + j] : '0;
                    vx[j] = (g * 4 + j < N_IN) ? lv_max[lv][g * 4 + j] : Q_MIN;
                    vn[j] = (g * 4 + j < N_IN) ? lv_min[lv][g * 4 + j] : Q_MAX;
                end
                for (int w = 1; w < 4; w = w * 2) begin          // balanced: 2 levels for 4 inputs
                    for (int j = 0; j + w < 4; j = j + 2 * w) begin
                        vs[j] = vs[j] + vs[j + w];
                        if (vx[j + w] > vx[j]) vx[j] = vx[j + w];
                        if (vn[j + w] < vn[j]) vn[j] = vn[j + w];
                    end
                end
                lv_sum[lv + 1][g] <= #1 vs[0];
                lv_max[lv + 1][g] <= #1 vx[0];
                lv_min[lv + 1][g] <= #1 vn[0];
            end
        end
    end
endgenerate

// over the chunks: the first result loads, the next ones add in
always @(posedge clk) begin
    if (state == STAT && cnt >= STEPS && cnt < STEPS + NCH) begin
        if (cnt == STEPS) begin
            acc_sum <= #1 lv_sum[STEPS][0];
            acc_max <= #1 lv_max[STEPS][0];
            acc_min <= #1 lv_min[STEPS][0];
        end else begin
            acc_sum <= #1 acc_sum + lv_sum[STEPS][0];
            if (lv_max[STEPS][0] > acc_max) acc_max <= #1 lv_max[STEPS][0];
            if (lv_min[STEPS][0] < acc_min) acc_min <= #1 lv_min[STEPS][0];
        end
    end
end

// ---------- ---------- ---------- ---------- LUT[R]: RAM read, then a register ---------- ---------- ----------
always @(posedge clk) begin
    if (state == LUT) begin
        if (cnt == 0) lut_raw <= #1 lut_mem[range_q];
        else          lut_q   <= #1 lut_raw;
    end
end

// ---------- ---------- ---------- ---------- NORM: five stages per chunk ---------- ---------- ----------
//   1: d = C*q - S             2: p = d * LUT[R]        3: z = trunc0(p / 2^K), w of the chunk
//   4: m = z * w, b of the chunk                        5: acc = m + (b << NUM_LSH_BIAS)
//   6: rshr + sat8 -> output token
always @(posedge clk) begin
    if (!nRst || ps_start) begin
        {n1, n2, n3, n4, n5} <= #1 '0;
    end else begin
        n1 <= #1 (state == NORM) && (cnt < NCH);
        n2 <= #1 n1;
        n3 <= #1 n2;
        n4 <= #1 n3;
        n5 <= #1 n4;
    end
end

always @(posedge clk) begin
    k1 <= #1 cnt[CH_W-1:0];   k2 <= #1 k1;   k3 <= #1 k2;   k4 <= #1 k3;   k5 <= #1 k4;
    if (n2) w_q <= #1 w_mem[k2];
    if (n3) b_q <= #1 b_mem[k3];
end

generate
    for (g = 0; g < P; g = g + 1) begin: Norm
        always @(posedge clk) begin
            automatic logic signed [WIDE-1:0] ap;
            if ((state == NORM) && (cnt < NCH))
                d1[g] <= #1 (D_W'($signed(q[g * DATA_WIDTH +: DATA_WIDTH])) <<< K) - sum_q;
            if (n1)
                p2[g] <= #1 d1[g] * $signed({1'b0, lut_q});
            if (n2) begin
                ap      = (p2[g] < 0) ? -p2[g] : p2[g];
                z3[g]  <= #1 (p2[g] < 0) ? -(ap >>> K) : (ap >>> K);
            end
            if (n3)
                m4[g]   <= #1 z3[g] * $signed(w_q[g * DATA_WIDTH +: DATA_WIDTH]);
            if (n4)
                acc5[g] <= #1 m4[g] + (WIDE'($signed(b_q[g * DATA_WIDTH +: DATA_WIDTH])) <<< NUM_LSH_BIAS);
        end

        Requant_Lane #(
            .DATA_WIDTH_DIN(WIDE),
            .NUM_SHIFT(NUM_RSH_DOUT)
        ) requant (
            .dIn(acc5[g]),
            .dOut(y5[g])
        );
        assign y_chunk[g * DATA_WIDTH +: DATA_WIDTH] = y5[g];
    end
endgenerate

// output token: chunks shift in from the top; the last one completes it
generate
    if (NCH > 1) begin: Assemble
        always @(posedge clk) begin
            if (n5 && k5 != NCH - 1) asm_q <= #1 ({y_chunk, asm_q} >> CW);
            if (n5 && k5 == NCH - 1) out_q <= #1 {y_chunk, asm_q};
        end
    end else begin: Whole
        always @(posedge clk) if (n5) out_q <= #1 y_chunk;
    end
    for (g = 0; g < NUM_DIM; g = g + 1) begin: Out
        assign dOut[g] = out_q[g * DATA_WIDTH +: 8];
    end
endgenerate

// ---------- ---------- ---------- ---------- FSM ---------- ---------- ---------- ----------
always @(posedge clk) begin
    if (!nRst || ps_start) begin
        state <= #1 IDLE;
        cnt   <= #1 '0;
    end else begin
        case (state)
            IDLE: if (s_valid) begin
                cnt   <= #1 '0;
                state <= #1 STAT;
            end
            STAT: begin
                if (cnt == STEPS + NCH) begin
                    sum_q   <= #1 acc_sum;
                    range_q <= #1 acc_max - acc_min;
                    cnt     <= #1 '0;
                    state   <= #1 LUT;
                end else begin
                    cnt <= #1 cnt + 1'b1;
                end
            end
            LUT: begin
                if (cnt == 1) begin
                    cnt   <= #1 '0;
                    state <= #1 NORM;
                end else begin
                    cnt <= #1 cnt + 1'b1;
                end
            end
            NORM: begin
                if (n5 && k5 == NCH - 1) begin
                    cnt   <= #1 '0;
                    state <= #1 DONE;
                end else if (cnt < NCH) begin
                    cnt <= #1 cnt + 1'b1;
                end
            end
            DONE: if (m_ready) state <= #1 IDLE;
            default: state <= #1 IDLE;
        endcase
    end
end

endmodule
