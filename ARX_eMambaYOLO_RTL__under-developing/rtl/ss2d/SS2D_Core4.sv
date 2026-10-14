`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: SS2D_Core4
// Description: steps 14-16 for the four CrossScan directions, one direction at a time (SS2D scans them
//              one after another):
//                  u -> 14 XProj  (d -> dt_low[R], B[N], C[N])
//                    -> 15 DtProj (dt_low -> delta[d], + bias, ReLU)
//                    -> 16 SelectiveScan of direction dir (u, delta, B, C -> y[d])
//              One XProj and one DtProj serve the four directions: their weights, biases and shifts
//              are four banks (Linear_Transform_PerCh NUM_BANK = 4), the bank = dir.  SelectiveScan
//              stays one per direction, as its shifts are parameters that differ between directions.
//              Same arithmetic and token flow as four SS2D_Core; dir must not change while a token is
//              in the module (SS2D changes it between directions).
//
//   WB: the four SS2D_Core windows of SS2D, unchanged -- direction k's at WB_BASE + k * CORE_SIZE, each
//     XProj  weight [R+2N][d] (rows padded to a word), rshift [R+2N]
//     DtProj weight [d][R] (rows padded to a word), bias [d] (int32), rshift [d]
//     SelectiveScan A [d][N], D [d]
//
// Dependencies: Linear_Transform_PerCh.sv, SelectiveScan.sv
//////////////////////////////////////////////////////////////////////////////////
module SS2D_Core4 #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_SEQLEN = 400,
    parameter integer NUM_DIM    = 512,
    parameter integer NUM_R      = 16,
    parameter integer NUM_N      = 16,

    // core shifts, direction k
    parameter integer K0_S_U = 4, K0_S_DELTA = 5, K0_S_A = 6, K0_S_DA = 7, K0_S_B = 7, K0_S_DB = 5, K0_S_C = 7, K0_S_D = 10, K0_S_Y = 5,
    parameter integer K1_S_U = 4, K1_S_DELTA = 5, K1_S_A = 6, K1_S_DA = 7, K1_S_B = 7, K1_S_DB = 5, K1_S_C = 7, K1_S_D = 10, K1_S_Y = 5,
    parameter integer K2_S_U = 4, K2_S_DELTA = 5, K2_S_A = 6, K2_S_DA = 7, K2_S_B = 7, K2_S_DB = 5, K2_S_C = 7, K2_S_D = 10, K2_S_Y = 5,
    parameter integer K3_S_U = 4, K3_S_DELTA = 5, K3_S_A = 6, K3_S_DA = 7, K3_S_B = 7, K3_S_DB = 5, K3_S_C = 7, K3_S_D = 10, K3_S_Y = 5,

    parameter integer WB_ADDR_W  = 24,
    parameter integer WB_BASE    = 0,       // direction 0's window
    parameter integer CORE_SIZE  = 0        // bytes from one direction's window to the next
)(
    clk,
    nRst,
    ps_start,

    wb_valid,
    wb_addr,
    wb_data,

    dir,

    dIn,
    s_valid,
    s_ready,

    dOut,
    m_valid,
    m_ready
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer NUM_DBC = NUM_R + 2 * NUM_N;

// one direction's window, as SS2D_Core
localparam integer XP_W = WB_BASE;
localparam integer XP_S = XP_W + NUM_DBC * (((NUM_DIM + 3) / 4) * 4);   // rows padded to a word
localparam integer DT_W = XP_S + ((NUM_DBC + 3) / 4) * 4;
localparam integer DT_B = DT_W + NUM_DIM * (((NUM_R + 3) / 4) * 4);
localparam integer DT_S = DT_B + NUM_DIM * 4;
localparam integer SC_A = DT_S + ((NUM_DIM + 3) / 4) * 4;
localparam integer SC_D = SC_A + NUM_DIM * NUM_N;

localparam F_IDLE = 3'd0,
           F_XP   = 3'd1,
           F_XPW  = 3'd2,
           F_DT   = 3'd3,
           F_DTW  = 3'd4,
           F_SS   = 3'd5;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input  logic clk, nRst, ps_start;

input  logic                 wb_valid;
input  logic [WB_ADDR_W-1:0] wb_addr;
input  logic [31:0]          wb_data;

input  logic [1:0]           dir;

input  logic signed [DATA_WIDTH-1:0] dIn  [0:NUM_DIM-1];   // u
input  logic s_valid;
output logic s_ready;

output logic signed [DATA_WIDTH-1:0] dOut [0:NUM_DIM-1];   // y
output logic m_valid;
input  logic m_ready;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic [2:0] fstate;

logic signed [DATA_WIDTH-1:0] u_q     [0:NUM_DIM-1];
logic signed [DATA_WIDTH-1:0] dt_q    [0:NUM_R-1];
logic signed [DATA_WIDTH-1:0] B_q     [0:NUM_N-1];
logic signed [DATA_WIDTH-1:0] C_q     [0:NUM_N-1];
logic signed [DATA_WIDTH-1:0] delta_q [0:NUM_DIM-1];

logic signed [7:0] xp_out [0:NUM_DBC-1];
logic signed [7:0] dt_out [0:NUM_DIM-1];
logic signed [7:0] ss_y   [0:3][0:NUM_DIM-1];

logic       xp_s_ready, xp_m_valid, dt_s_ready, dt_m_valid;
logic [3:0] ss_s_ready, ss_m_valid;

genvar k;

assign s_ready = (fstate == F_IDLE);

// ---------- ---------- ---------- ---------- Token feeder ---------- ---------- ---------- ----------
always @(posedge clk) begin
    if (!nRst || ps_start) begin
        fstate <= #1 F_IDLE;
    end else begin
        case (fstate)
            F_IDLE: if (s_valid) begin
                u_q    <= #1 dIn;
                fstate <= #1 F_XP;
            end
            F_XP:  if (xp_s_ready) fstate <= #1 F_XPW;
            F_XPW: if (xp_m_valid) begin
                for (int r = 0; r < NUM_R; r++) dt_q[r] <= #1 xp_out[r];
                for (int n = 0; n < NUM_N; n++) begin
                    B_q[n] <= #1 xp_out[NUM_R + n];
                    C_q[n] <= #1 xp_out[NUM_R + NUM_N + n];
                end
                fstate <= #1 F_DT;
            end
            F_DT:  if (dt_s_ready) fstate <= #1 F_DTW;
            F_DTW: if (dt_m_valid) begin
                delta_q <= #1 dt_out;
                fstate  <= #1 F_SS;
            end
            F_SS:  if (ss_s_ready[dir]) fstate <= #1 F_IDLE;
            default: fstate <= #1 F_IDLE;
        endcase
    end
end

// ---------- ---------- ---------- ---------- 14 XProj, four banks ---------- ---------- ---------- ----------
Linear_Transform_PerCh #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_DIM_IN(NUM_DIM),
    .NUM_DIM_OUT(NUM_DBC),
    .USE_BIAS(1'b0),
    .USE_RELU(1'b0),
    .WB_ADDR_W(WB_ADDR_W),
    .WB_BASE_W(XP_W),
    .WB_BASE_B(XP_S),
    .WB_BASE_S(XP_S),
    .NUM_BANK(4),
    .BANK_STRIDE(CORE_SIZE)
) XProj (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),
    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),
    .bank(dir),
    .dIn(u_q),
    .dOut(xp_out),
    .s_valid(fstate == F_XP),
    .s_ready(xp_s_ready),
    .m_valid(xp_m_valid),
    .m_ready(fstate == F_XPW)
);

// ---------- ---------- ---------- ---------- 15 DtProj + ReLU, four banks ---------- ---------- ----------
Linear_Transform_PerCh #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_DIM_IN(NUM_R),
    .NUM_DIM_OUT(NUM_DIM),
    .USE_BIAS(1'b1),
    .USE_RELU(1'b1),
    .WB_ADDR_W(WB_ADDR_W),
    .WB_BASE_W(DT_W),
    .WB_BASE_B(DT_B),
    .WB_BASE_S(DT_S),
    .NUM_BANK(4),
    .BANK_STRIDE(CORE_SIZE)
) DtProj (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),
    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),
    .bank(dir),
    .dIn(dt_q),
    .dOut(dt_out),
    .s_valid(fstate == F_DT),
    .s_ready(dt_s_ready),
    .m_valid(dt_m_valid),
    .m_ready(fstate == F_DTW)
);

// ---------- ---------- ---------- ---------- 16 SelectiveScan, one per direction ---------- ---------- ----------
`define SCAN_DIR(K, SU, SDL, SA, SDA, SB, SDB, SC, SD, SY)                                              \
    SelectiveScan #(                                                                                    \
        .DATA_WIDTH(DATA_WIDTH), .NUM_SEQLEN(NUM_SEQLEN), .NUM_DIM(NUM_DIM), .NUM_N(NUM_N),               \
        .S_U(SU), .S_DELTA(SDL), .S_A(SA), .S_DA(SDA), .S_B(SB), .S_DB(SDB), .S_C(SC), .S_D(SD), .S_Y(SY), \
        .WB_ADDR_W(WB_ADDR_W), .WB_BASE_A(SC_A + K * CORE_SIZE), .WB_BASE_D(SC_D + K * CORE_SIZE)        \
    ) Scan_``K (                                                                                        \
        .clk(clk), .nRst(nRst), .ps_start(ps_start),                                                    \
        .wb_valid(wb_valid), .wb_addr(wb_addr), .wb_data(wb_data),                                      \
        .dIn(u_q), .delta(delta_q), .matrix_B(B_q), .matrix_C(C_q), .dOut(ss_y[K]),                     \
        .s_valid(fstate == F_SS && dir == K), .s_ready(ss_s_ready[K]),                                  \
        .m_valid(ss_m_valid[K]), .m_ready(m_ready && dir == K)                                          \
    );
`SCAN_DIR(0, K0_S_U, K0_S_DELTA, K0_S_A, K0_S_DA, K0_S_B, K0_S_DB, K0_S_C, K0_S_D, K0_S_Y)
`SCAN_DIR(1, K1_S_U, K1_S_DELTA, K1_S_A, K1_S_DA, K1_S_B, K1_S_DB, K1_S_C, K1_S_D, K1_S_Y)
`SCAN_DIR(2, K2_S_U, K2_S_DELTA, K2_S_A, K2_S_DA, K2_S_B, K2_S_DB, K2_S_C, K2_S_D, K2_S_Y)
`SCAN_DIR(3, K3_S_U, K3_S_DELTA, K3_S_A, K3_S_DA, K3_S_B, K3_S_DB, K3_S_C, K3_S_D, K3_S_Y)
`undef SCAN_DIR

assign m_valid = ss_m_valid[dir];
assign dOut    = ss_y[dir];

endmodule
