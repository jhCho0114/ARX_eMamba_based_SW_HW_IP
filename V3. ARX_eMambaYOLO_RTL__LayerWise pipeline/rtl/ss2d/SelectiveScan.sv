`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: SelectiveScan
// Description: step 16 -- one eMamba core call (one CrossScan direction), token by token
//              (layers_int8_emamba.SW.SelectiveScan):
//                  dA[d][n] = EXP_PWL(delta[d] * A[d][n])                    (Exp_piecewise_WB)
//                  dB[d][n] = sat8(rshr(delta[d] * B[n], S_DELTA + S_B - S_DB)) (U_Dim_expand_delta_B)
//                  x'       = wrap(dA * x) + (dB * u << S_DA),  x <- rshr(x', S_DA)
//                  y[d]     = sat8(rshr(sum_n C[n] * x' + (D[d] * u << ...), ...))  (U_SSM_Computation)
//              The state starts at 0 and starts again at 0 after NUM_SEQLEN tokens.
//
//   One channel stream: the channels d = 0 .. NUM_DIM-1 of a token go one per cycle through a
//   single pipeline that computes dA[d][:], dB[d][:], the state update of channel d and y[d], so
//   no [NUM_DIM][NUM_N] array of dA, dB or x is held in registers and no NUM_DIM:1 selection is
//   needed (the eMamba modules hand a whole token over; their pipelined copies held dA and dB twice
//   and the state as ~430k flip-flops at NUM_DIM = 512, NUM_N = 16).  Same arithmetic, through the
//   same submodules: Dim_expand_delta_A_compute (delta * A), Exp_PWL_Pipe (the chord8 exp),
//   eMamba's shifter_right / saturator (dB), SSM_xkP1_compute (x'), SSM_y_compute_Pipe (y).
//
//   Storage:  A [d][n]  RAM of NUM_DIM rows (WB)      D [d]  RAM of 32-bit words, 4 channels each (WB)
//             x [d][n]  RAM of NUM_DIM rows, read at issue, written back 7 cycles later; the first
//                       token of a sequence reads 0 instead (no clear of the RAM)
//             u, delta  the token's vectors as shift registers, one channel out per issue
//             y         shift register, channel 0 ends at the bottom after the last channel
//   The next token waits in its own registers (s_ready = slot free), so the producer can deliver
//   it while this one is scanned.  A token is issued once the previous output has been taken.
//
//   Pipeline, k = cycles after the issue of channel d (the data marches every cycle; v[k] marks it):
//     1  A row, D word, x row read (RAM registers); u[d], delta[d]
//     2  RAM output registers
//     3  delta * A[d][n], delta * B[n] registered; D[d] picked from its word
//     4  exp stage A (segment); dB = sat8(rshr(delta * B))
//     5  exp stage B (chord)
//     6  operands of the state update registered: dA (exp out), dB, u, x (0 on the first token), D, C
//     7  SSM_xkP1_compute products registered; x' -> x RAM[d]; operands of y registered
//     8 .. 7 + Y_LAT  SSM_y_compute_Pipe;  at PIPE_TOT = 7 + Y_LAT + 1: y -> output shift register
//
//   WB window (byte addresses): WB_BASE_A: A[d][n], n fastest (NUM_N % 4 == 0),
//                               WB_BASE_D: D[d], one byte each (padded to a word).
//
// Dependencies (U_eMamba/RTL): Dim_expand_delta_A_compute, SSM_xkP1_compute, shifter_left,
//   shifter_right, saturator;  here: Exp_PWL_Pipe.sv (constants of the v002 chord8 exp),
//   SSM_y_compute_Pipe.sv, Wb_Row_Loader.sv
//////////////////////////////////////////////////////////////////////////////////
module SelectiveScan #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_SEQLEN = 400,
    parameter integer NUM_DIM    = 512,
    parameter integer NUM_N      = 16,

    parameter integer S_U        = 4,
    parameter integer S_DELTA    = 5,
    parameter integer S_A        = 6,
    parameter integer S_DA       = 7,
    parameter integer S_B        = 7,
    parameter integer S_DB       = 5,
    parameter integer S_C        = 7,
    parameter integer S_D        = 10,
    parameter integer S_Y        = 5,

    parameter integer WB_ADDR_W  = 24,
    parameter integer WB_BASE_A  = 0,
    parameter integer WB_BASE_D  = WB_BASE_A + NUM_DIM * NUM_N
)(
    clk,
    nRst,
    ps_start,

    wb_valid,
    wb_addr,
    wb_data,

    dIn,
    delta,
    matrix_B,
    matrix_C,
    dOut,

    s_valid,
    s_ready,
    m_valid,
    m_ready
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer W        = DATA_WIDTH;
localparam integer ED_W     = ($clog2(NUM_DIM) > 0) ? $clog2(NUM_DIM) : 1;
localparam integer SEQ_W    = ($clog2(NUM_SEQLEN) > 0) ? $clog2(NUM_SEQLEN) : 1;
localparam integer D_WORDS  = (NUM_DIM + 3) / 4;
localparam integer DW_W     = ($clog2(D_WORDS) > 0) ? $clog2(D_WORDS) : 1;
localparam integer A_BITS   = NUM_N * W;

// widths of SSM_Computation (eMamba)
localparam integer DATA_WIDTH_BU       = W * 2;
localparam integer DATA_WIDTH_BU_LSH   = DATA_WIDTH_BU + S_DA;
localparam integer DATA_WIDTH_AX       = DATA_WIDTH_BU_LSH;
localparam integer DATA_WIDTH_XKP1     = DATA_WIDTH_AX + 1;
localparam integer DATA_WIDTH_XKP1_RSH = DATA_WIDTH_XKP1 - S_DA;
localparam integer X_BITS              = NUM_N * DATA_WIDTH_XKP1_RSH;

// dB (U_Dim_expand_delta_B)
localparam integer DB_RSH    = S_DELTA + S_B - S_DB;
localparam integer DB_RSH_W  = 2 * W - DB_RSH;

// SSM_y_compute_Pipe: prod_q, one register per tree level, the final + Du
localparam integer Y_STAGE   = ($clog2(NUM_N) > 0) ? $clog2(NUM_N) : 1;
localparam integer Y_LAT     = Y_STAGE + 2;
localparam integer K_X       = 7;                        // stage of the x write-back
localparam integer PIPE_TOT  = K_X + 1 + Y_LAT;          // stage of the y write

localparam IDLE = 2'd0,
           RUN  = 2'd1,
           DRAIN = 2'd2,
           DONE = 2'd3;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input  logic clk, nRst, ps_start;

input  logic                 wb_valid;
input  logic [WB_ADDR_W-1:0] wb_addr;
input  logic [31:0]          wb_data;

input  logic signed [W-1:0] dIn      [0:NUM_DIM-1];   // u
input  logic signed [W-1:0] delta    [0:NUM_DIM-1];
input  logic signed [W-1:0] matrix_B [0:NUM_N-1];
input  logic signed [W-1:0] matrix_C [0:NUM_N-1];
output logic signed [W-1:0] dOut     [0:NUM_DIM-1];   // y

input  logic s_valid, m_ready;
output logic s_ready, m_valid;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// token slots: next (waiting) and current (u, delta shifted out one channel per issue)
logic [NUM_DIM*W-1:0]  u_n, dl_n, u_sh, dl_sh;
logic signed [W-1:0]   B_n [0:NUM_N-1], C_n [0:NUM_N-1], B_q [0:NUM_N-1], C_q [0:NUM_N-1];
logic                  n_full, tok_first, start;
logic [SEQ_W-1:0]      seq;
logic [1:0]            state;
logic [ED_W-1:0]       col;

// RAMs
logic [A_BITS-1:0]     a_mem [0:NUM_DIM-1];
logic [31:0]           d_mem [0:D_WORDS-1];
logic [X_BITS-1:0]     x_mem [0:NUM_DIM-1];
logic                  a_we, d_we;
logic [ED_W-1:0]       a_row;
logic [DW_W-1:0]       d_row;
logic [A_BITS-1:0]     a_data;
logic [31:0]           d_data;

// pipeline
logic                  v   [1:PIPE_TOT];
logic                  lst [1:PIPE_TOT];
logic [ED_W-1:0]       c1, c2, c3, c4, c5, c6, c7;
logic [A_BITS-1:0]     a_r, a_q;
logic [X_BITS-1:0]     x_r, x_q, x3, x4, x5;
logic [31:0]           dw_r, dw_q;
logic signed [W-1:0]   u1, u2, u3, u4, u5, dl1, dl2, d3, d4, d5;
logic signed [W-1:0]   a_row_q [0:NUM_N-1];
logic signed [2*W-1:0] pa_c [0:NUM_N-1], pa_q [0:NUM_N-1], pb_q [0:NUM_N-1];
logic signed [DB_RSH_W-1:0] pb_rsh [0:NUM_N-1];
logic signed [W-1:0]   db_c [0:NUM_N-1], db4 [0:NUM_N-1], db5 [0:NUM_N-1];
logic signed [W-1:0]   exp_y [0:NUM_N-1];

// state update (A0 / A1 / A2 of U_SSM_Computation) and y
logic signed [W-1:0]                   u_s, d_s, dA_s [0:NUM_N-1], dB_s [0:NUM_N-1], C_s [0:NUM_N-1];
logic signed [DATA_WIDTH_XKP1_RSH-1:0] xk_s [0:NUM_N-1];
logic signed [DATA_WIDTH_XKP1-1:0]     xkP1 [0:NUM_N-1];
logic signed [DATA_WIDTH_XKP1_RSH-1:0] xkP1_rsh [0:NUM_N-1];
logic [X_BITS-1:0]                     xkP1_rsh_v;
logic signed [W-1:0]                   u_y1, u_y2, d_y1, d_y2, C_y1 [0:NUM_N-1], C_y2 [0:NUM_N-1];
logic signed [DATA_WIDTH_XKP1-1:0]     xkP1_y2 [0:NUM_N-1];
logic signed [W-1:0]                   y_out;
logic [NUM_DIM*W-1:0]                  y_sh;

// ---------- ---------- ---------- ---------- Parameter guards ---------- ---------- ---------- ----------
// What the eMamba submodules assume of the shifts (a violation would silently give X or wrong values).
generate
    if (S_DELTA + S_B - S_DB < 1)
        $error("SelectiveScan: S_DELTA + S_B - S_DB must be >= 1 (dB right shift)");
    if (S_U + S_DA + S_DB + S_C - S_Y < 1)
        $error("SelectiveScan: S_U + S_DA + S_DB + S_C - S_Y must be >= 1 (y right shift, SSM_y_compute)");
    if (S_DA + S_DB + S_C - S_D < 0)
        $error("SelectiveScan: S_DA + S_DB + S_C - S_D must be >= 0 (D*u left shift, SSM_y_compute)");
    if (2 * (S_DELTA + S_A) - S_DA < 1)
        $error("SelectiveScan: 2*(S_DELTA + S_A) - S_DA must be >= 1 (exp output shift)");
    if (S_DELTA + S_A > 15)
        $error("SelectiveScan: S_DELTA + S_A must be <= 15 (the exp constants are 32-bit)");
    if (NUM_N % 4 != 0)
        $error("SelectiveScan: NUM_N must be a multiple of 4 (A is loaded 4 bytes per WB word)");
endgenerate

// ---------- ---------- ---------- ---------- Weight Broadcast ---------- ---------- ---------- ----------
Wb_Row_Loader #(.WB_ADDR_W(WB_ADDR_W), .BASE(WB_BASE_A), .ROWS(NUM_DIM), .ROW_WORDS(NUM_N / 4), .ROW_BITS(A_BITS))
    load_a (.clk(clk), .nRst(nRst), .wb_valid(wb_valid), .wb_addr(wb_addr), .wb_data(wb_data),
            .we(a_we), .row(a_row), .data(a_data));
Wb_Row_Loader #(.WB_ADDR_W(WB_ADDR_W), .BASE(WB_BASE_D), .ROWS(D_WORDS), .ROW_WORDS(1), .ROW_BITS(32))
    load_d (.clk(clk), .nRst(nRst), .wb_valid(wb_valid), .wb_addr(wb_addr), .wb_data(wb_data),
            .we(d_we), .row(d_row), .data(d_data));

always @(posedge clk) begin
    if (a_we) a_mem[a_row] <= #1 a_data;
    if (d_we) d_mem[d_row] <= #1 d_data;
end

// ---------- ---------- ---------- ---------- Token slots ---------- ---------- ---------- ----------
// the next token waits in its slot; it moves to the current one when the scan starts it
assign s_ready = !n_full;
assign m_valid = (state == DONE);
assign start   = n_full && ((state == IDLE) || (state == DONE && m_ready));

always @(posedge clk) begin
    if (!nRst || ps_start)       n_full <= #1 1'b0;
    else if (s_valid && s_ready) n_full <= #1 1'b1;
    else if (start)              n_full <= #1 1'b0;
end

always @(posedge clk) begin
    if (s_valid && s_ready) begin
        for (int c = 0; c < NUM_DIM; c++) begin
            u_n [c*W +: W] <= #1 dIn[c];
            dl_n[c*W +: W] <= #1 delta[c];
        end
        B_n <= #1 matrix_B;
        C_n <= #1 matrix_C;
    end
end

// ---------- ---------- ---------- ---------- Channel walk ---------- ---------- ---------- ----------
always @(posedge clk) begin
    if (!nRst || ps_start) begin
        state     <= #1 IDLE;
        col       <= #1 '0;
        seq       <= #1 '0;
        tok_first <= #1 1'b1;
    end else begin
        case (state)
            IDLE, DONE: begin
                if (start) begin
                    state     <= #1 RUN;
                    col       <= #1 '0;
                    tok_first <= #1 (seq == 0);
                    seq       <= #1 (seq == NUM_SEQLEN - 1) ? '0 : seq + 1'b1;
                end else if (state == DONE && m_ready) begin
                    state     <= #1 IDLE;
                end
            end
            RUN: begin
                col <= #1 col + 1'b1;
                if (col == NUM_DIM - 1) state <= #1 DRAIN;
            end
            DRAIN: if (v[PIPE_TOT] && lst[PIPE_TOT]) state <= #1 DONE;    // the last y lands on this edge
        endcase
    end
end

// the current token: loaded at start, one channel shifted out per issue
always @(posedge clk) begin
    if (start) begin
        u_sh  <= #1 u_n;
        dl_sh <= #1 dl_n;
        B_q   <= #1 B_n;
        C_q   <= #1 C_n;
    end else if (state == RUN) begin
        u_sh  <= #1 u_sh  >> W;
        dl_sh <= #1 dl_sh >> W;
    end
end

// ---------- ---------- ---------- ---------- Pipeline control ---------- ---------- ---------- ----------
always @(posedge clk) begin
    if (!nRst || ps_start) begin
        for (int k = 1; k <= PIPE_TOT; k++) begin
            v[k]   <= #1 1'b0;
            lst[k] <= #1 1'b0;
        end
    end else begin
        v[1]   <= #1 (state == RUN);
        lst[1] <= #1 (state == RUN) && (col == NUM_DIM - 1);
        for (int k = 2; k <= PIPE_TOT; k++) begin
            v[k]   <= #1 v[k-1];
            lst[k] <= #1 lst[k-1];
        end
    end
end

// ---------- ---------- ---------- ---------- Stages 1-2: operands ---------- ---------- ---------- ----------
always @(posedge clk) begin
    // 1: RAM reads at the channel, the channel's u and delta
    a_r  <= #1 a_mem[col];
    x_r  <= #1 x_mem[col];
    dw_r <= #1 d_mem[col >> 2];
    u1   <= #1 u_sh[W-1:0];
    dl1  <= #1 dl_sh[W-1:0];
    c1   <= #1 col;
    // 2: RAM output registers
    a_q  <= #1 a_r;
    x_q  <= #1 x_r;
    dw_q <= #1 dw_r;
    u2   <= #1 u1;
    dl2  <= #1 dl1;
    c2   <= #1 c1;
end

// ---------- ---------- ---------- ---------- Stage 3: delta * A, delta * B ---------- ---------- ----------
genvar n;
generate
    for (n = 0; n < NUM_N; n = n + 1) begin: Row
        assign a_row_q[n] = a_q[n * W +: W];
    end
endgenerate

Dim_expand_delta_A_compute #(
    .DATA_WIDTH(W),
    .NUM_ED(NUM_N)
) Dim_expand_delta_A_compute (
    .delta(dl2),
    .matrix(a_row_q),
    .dOut(pa_c)
);

always @(posedge clk) begin
    for (int i = 0; i < NUM_N; i++) begin
        pa_q[i] <= #1 pa_c[i];
        pb_q[i] <= #1 dl2 * B_q[i];
    end
    u3 <= #1 u2;
    x3 <= #1 x_q;
    d3 <= #1 dw_q[(c2 % 4) * 8 +: 8];
    c3 <= #1 c2;
end

// ---------- ---------- ---------- ---------- Stages 4-5: exp, dB ---------- ---------- ---------- ----------
Exp_PWL_Pipe #(
    .DATA_WIDTH(W),
    .NUM_N(NUM_N),
    .NUM_SCALE_DIN(S_DELTA + S_A),
    .NUM_SCALE_DOUT(S_DA)
) Exp_piecewise_compute (
    .clk(clk),
    .en1(1'b1),
    .en2(1'b1),
    .dIn(pa_q),
    .dOut_8bit(exp_y)
);

generate
    for (n = 0; n < NUM_N; n = n + 1) begin: Lane_dB
        shifter_right #(
            .DATA_WIDTH(2 * W),
            .NUM_SHIFT(DB_RSH)
        ) shifter_dB (
            .dIn(pb_q[n]),
            .dOut(pb_rsh[n])
        );
        saturator #(
            .DATA_WIDTH(DB_RSH_W)
        ) saturator_dB (
            .dIn(pb_rsh[n]),
            .dOut(db_c[n])
        );
    end
endgenerate

always @(posedge clk) begin
    db4 <= #1 db_c;
    db5 <= #1 db4;
    u4  <= #1 u3;  u5 <= #1 u4;
    x4  <= #1 x3;  x5 <= #1 x4;
    d4  <= #1 d3;  d5 <= #1 d4;
    c4  <= #1 c3;  c5 <= #1 c4;
end

// ---------- ---------- ---------- ---------- Stage 6: operands of the state update ---------- ----------
// (A0 of U_SSM_Computation; the first token of a sequence starts from x = 0)
always @(posedge clk) begin
    dA_s <= #1 exp_y;
    dB_s <= #1 db5;
    u_s  <= #1 u5;
    d_s  <= #1 d5;
    C_s  <= #1 C_q;
    for (int i = 0; i < NUM_N; i++)
        xk_s[i] <= #1 tok_first ? '0 : x5[i * DATA_WIDTH_XKP1_RSH +: DATA_WIDTH_XKP1_RSH];
    c6   <= #1 c5;
end

// ---------- ---------- ---------- ---------- Stage 7: x' and its write-back ---------- ---------- ----------
SSM_xkP1_compute #(
    .DATA_WIDTH(W),
    .NUM_N(NUM_N),
    .NUM_SCALE_DIN(S_U),
    .NUM_SCALE_DELTA_A(S_DA),
    .NUM_SCALE_DELTA_B(S_DB),
    .NUM_SCALE_DOUT(S_Y),
    .DATA_WIDTH_BU(DATA_WIDTH_BU),
    .DATA_WIDTH_BU_LSH(DATA_WIDTH_BU_LSH),
    .DATA_WIDTH_AX(DATA_WIDTH_AX),
    .DATA_WIDTH_XKP1(DATA_WIDTH_XKP1),
    .DATA_WIDTH_XKP1_RSH(DATA_WIDTH_XKP1_RSH)
) SSM_xkP1_compute (
    .clk                (clk),
    .nRst               (nRst),
    .dIn                (u_s),
    .delta_A            (dA_s),
    .delta_B            (dB_s),
    .xk                 (xk_s),
    .xkP1               (xkP1),
    .xkP1_right_shifted (xkP1_rsh)
);

generate
    for (n = 0; n < NUM_N; n = n + 1) begin: Pack_x
        assign xkP1_rsh_v[n * DATA_WIDTH_XKP1_RSH +: DATA_WIDTH_XKP1_RSH] = xkP1_rsh[n];
    end
endgenerate

always @(posedge clk) begin
    c7 <= #1 c6;
    if (v[K_X]) x_mem[c7] <= #1 xkP1_rsh_v;
end

// operands of y (the delayed_1 / delayed_2 registers of U_SSM_Computation)
always @(posedge clk) begin
    u_y1    <= #1 u_s;   u_y2 <= #1 u_y1;
    d_y1    <= #1 d_s;   d_y2 <= #1 d_y1;
    C_y1    <= #1 C_s;   C_y2 <= #1 C_y1;
    xkP1_y2 <= #1 xkP1;
end

// ---------- ---------- ---------- ---------- Stage Y: y ---------- ---------- ---------- ----------
SSM_y_compute_Pipe #(
    .DATA_WIDTH(W),
    .NUM_N(NUM_N),
    .NUM_SCALE_DIN(S_U),
    .NUM_SCALE_DELTA_A(S_DA),
    .NUM_SCALE_DELTA_B(S_DB),
    .NUM_SCALE_C(S_C),
    .NUM_SCALE_D(S_D),
    .NUM_SCALE_DOUT(S_Y),
    .DATA_WIDTH_XKP1(DATA_WIDTH_XKP1)
) SSM_y_compute (
    .clk       (clk),
    .dIn       (u_y2),
    .matrix_C  (C_y2),
    .matrix_D  (d_y2),
    .xkP1      (xkP1_y2),
    .dOut_8bit (y_out)
);

// channels arrive in order 0 .. NUM_DIM-1: after the last one, channel c is at y_sh[c*W +: W]
generate
    if (NUM_DIM > 1) begin: Out_Shift
        always @(posedge clk) if (v[PIPE_TOT]) y_sh <= #1 {y_out, y_sh[NUM_DIM*W-1:W]};
    end else begin: Out_One
        always @(posedge clk) if (v[PIPE_TOT]) y_sh <= #1 y_out;
    end
endgenerate

generate
    for (n = 0; n < NUM_DIM; n = n + 1) begin: Out
        assign dOut[n] = y_sh[n * W +: W];
    end
endgenerate

endmodule
