`timescale 1ns / 1ps
// emy_im2col : feature map [C, H, W] (int8, C order) -> one window (patch) per output pixel, raster order (ho, wo)
//
//   dOut[k] = x[c, ho*STRIDE + kh - PAD, wo*STRIDE + kw - PAD]     (outside the map: 0, or -128 with PAD_MIN)
//   k = (c*K + kh)*K + kw                        default: C order of weight.npy [O, Cg, K, K] -> weights used as is
//   k = (kw*K + kh)*C + c          PATCH_S2D = 1 : only for K = S = 2, P = 0. The patch of (i, j) is then the
//                                  SpaceToDepth output vector out[q*C + c, i, j], q = dh + 2*dw (offsets (0,0),
//                                  (1,0), (0,1), (1,1)), so the following 1x1 weights [2C, 4C] are used as is.
//
// Line buffer, not the whole map: NUM_ROWS = K + S row RAMs (one word = one column = C bytes, the block RAM
//   shape), the input rows in them in turn (row r in RAM r mod NUM_ROWS, counted over frames), and a K x K window of
//   columns that slides along the row:
//   Input side  (consumer, Linear_Transform_Dynamic_WB handshake): one pixel vector dIn[0:C-1] per s_valid & s_ready,
//               raster order (h, w). s_ready (from registers only) holds the input back to the rows the window has
//               not finished with: row r is written only when r < (lowest row of the output row in progress) + NUM_ROWS,
//               so the producer runs S rows ahead while the current output row is produced.
//   Output side (producer): for output row ho, the input columns c = -P .. W-1+P are walked one per cycle (tick):
//               column c of the K rows ho*S-P .. ho*S-P+K-1 is read from the RAMs (zero / -128 outside the map) and
//               shifted into the window; after the column wo*S - P + K - 1 the window is the patch of (ho, wo) and
//               goes into dOut a cycle later (m_valid / m_ready; the walk pauses while dOut is held). Output row ho starts once
//               the input rows it touches (min(ho*S - P + K - 1, H - 1)) are in, so a layer runs row by row behind
//               its producer. One patch per S cycles at most.
//   Frames stream continuously after one ps_start: the row counters wrap at H / NUM_HO and the RAM slot counts on
//   over the frames. ps_start (synchronous) clears everything (abort / power-up). Contract: no s_valid in the cycle
//   ps_start is 1.
module emy_im2col import emy_pkg::*; #(
    parameter integer NUM_CH     = 3,
    parameter integer NUM_HEIGHT = 640,
    parameter integer NUM_WIDTH  = 640,
    parameter integer KERNEL     = 3,
    parameter integer STRIDE     = 2,
    parameter integer PAD        = 1,
    parameter bit     PATCH_S2D  = 1'b0,   // SpaceToDepth patch order (see header)
    parameter bit     PAD_MIN    = 1'b0,   // outside taps = most negative int8 (max pool) instead of 0 (conv)

    localparam integer NUM_HO    = (NUM_HEIGHT + 2*PAD - KERNEL) / STRIDE + 1,
    localparam integer NUM_WO    = (NUM_WIDTH  + 2*PAD - KERNEL) / STRIDE + 1,
    localparam integer PATCH_LEN = NUM_CH * KERNEL * KERNEL
)(
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic signed [ACT_W-1:0] dIn  [0:NUM_CH-1],
    input  logic s_valid,
    output logic s_ready,

    output logic signed [ACT_W-1:0] dOut [0:PATCH_LEN-1],
    input  logic m_ready,
    output logic m_valid
);

// ---------- Local Parameters ---------- //
localparam integer K        = KERNEL;
localparam integer S        = STRIDE;
localparam integer P        = PAD;
localparam integer NUM_ROWS = K + S;                       // row RAMs
localparam integer CW       = NUM_CH * ACT_W;              // one column (pixel vector)
localparam integer H_W      = $clog2(NUM_HEIGHT + 1);
localparam integer W_W      = $clog2(NUM_WIDTH + 1);
localparam integer HO_W     = $clog2(NUM_HO + 1);
localparam integer WO_W     = $clog2(NUM_WO + 1);
localparam integer C_W      = $clog2(NUM_WIDTH + 2*P + 1) + 1;   // tick column -P .. W-1+P, signed
localparam integer SLOT_W   = ($clog2(NUM_ROWS) > 0) ? $clog2(NUM_ROWS) : 1;
localparam integer ABS_W    = 32;                          // row counters over the frames
localparam logic [CW-1:0] PAD_COL = {NUM_CH{PAD_MIN ? {1'b1, {(ACT_W-1){1'b0}}} : {ACT_W{1'b0}}}};

initial begin
    if (PATCH_S2D && !(KERNEL == 2 && STRIDE == 2 && PAD == 0))
        $fatal(1, "emy_im2col: PATCH_S2D needs KERNEL = STRIDE = 2, PAD = 0 (got %0d, %0d, %0d)", KERNEL, STRIDE, PAD);
    if (KERNEL < 1 || STRIDE < 1 || PAD < 0 || PAD >= KERNEL)
        $fatal(1, "emy_im2col: KERNEL %0d, STRIDE %0d, PAD %0d", KERNEL, STRIDE, PAD);
end

// ---------- Input side: pixel stream -> row RAMs ---------- //
logic [CW-1:0]     din_v;
logic [H_W-1:0]    wr_h;
logic [W_W-1:0]    wr_w;
logic [SLOT_W-1:0] wr_slot;
logic [ABS_W-1:0]  rows_done;          // input rows completed, over the frames
logic [ABS_W-1:0]  low_abs;            // lowest input row the output row in progress needs (over the frames)
logic              s_handshaking;

genvar g;
generate
    for (g = 0; g < NUM_CH; g = g + 1) begin : Pack
        assign din_v[g*ACT_W +: ACT_W] = dIn[g];
    end
endgenerate

assign s_ready       = (rows_done < low_abs + NUM_ROWS);
assign s_handshaking = s_valid & s_ready;

always @(posedge clk) begin
    if (!nRst || ps_start) begin
        wr_h      <= #1 '0;
        wr_w      <= #1 '0;
        wr_slot   <= #1 '0;
        rows_done <= #1 '0;
    end else if (s_handshaking) begin
        if (wr_w == NUM_WIDTH - 1) begin
            wr_w      <= #1 '0;
            wr_h      <= #1 (wr_h == NUM_HEIGHT - 1) ? '0 : wr_h + 1'b1;
            wr_slot   <= #1 (wr_slot == NUM_ROWS - 1) ? '0 : wr_slot + 1'b1;
            rows_done <= #1 rows_done + 1'b1;
        end else begin
            wr_w      <= #1 wr_w + 1'b1;
            wr_h      <= #1 wr_h;
            wr_slot   <= #1 wr_slot;
            rows_done <= #1 rows_done;
        end
    end else begin
        wr_h      <= #1 wr_h;
        wr_w      <= #1 wr_w;
        wr_slot   <= #1 wr_slot;
        rows_done <= #1 rows_done;
    end
end

// ---------- Output side: the column walk ---------- //
logic                    adv;                 // the walk moves (dOut free or being taken)
logic [HO_W-1:0]         ho;                  // output row in progress
logic [WO_W-1:0]         wo;                  // next patch of the row
logic signed [C_W-1:0]   c;                   // tick column, -P .. W-1+P
logic [ABS_W-1:0]        frame_base;          // first input row of the frame being read (over the frames)
logic [SLOT_W-1:0]       frame_slot;          // its RAM slot
logic [ABS_W-1:0]        need_abs;            // rows_done needed for row ho
logic                    row_ready, tick, in_map, emit0, last_tick;
logic [SLOT_W-1:0]       row_slot [0:K-1];    // RAM slot of window row kh
logic                    row_pad  [0:K-1];    // window row kh is outside the map
logic [CW-1:0]           rd_q [0:NUM_ROWS-1];
// T1: the tick registered (with the slots of its rows: ho may already have moved on)
logic                    v1, in_map1, emit1, emit2;
logic [SLOT_W-1:0]       slot1 [0:K-1];
logic                    pad1  [0:K-1];
logic [CW-1:0]           win [0:K-1][0:K-1];  // win[kh][kw]: column (wo*S - P + kw) of row (ho*S - P + kh)
logic signed [ACT_W-1:0] patch [0:PATCH_LEN-1];
logic                    m_handshaking;

assign m_handshaking = m_valid & m_ready;
assign adv           = !m_valid || m_ready;

// the rows of output row ho: h = ho*S - P + kh; the last one needed is min(ho*S - P + K - 1, H - 1)
always_comb begin
    int h0, h_need, h;
    h0     = int'(ho) * S - P;
    h_need = (h0 + K - 1 > NUM_HEIGHT - 1) ? NUM_HEIGHT - 1 : h0 + K - 1;
    need_abs = frame_base + ABS_W'(h_need + 1);
    low_abs  = frame_base + ABS_W'((h0 > 0) ? h0 : 0);
    for (int kh = 0; kh < K; kh++) begin
        h = h0 + kh;
        row_pad[kh]  = (h < 0) || (h >= NUM_HEIGHT);
        row_slot[kh] = row_pad[kh] ? '0 : SLOT_W'((int'(frame_slot) + h) % NUM_ROWS);
    end
end

assign row_ready = (rows_done >= need_abs);
assign tick      = adv && row_ready;
assign in_map    = (c >= 0) && (c < NUM_WIDTH);
// the column that completes patch wo: c = wo*S - P + K - 1
assign emit0     = (wo < NUM_WO) && (c == C_W'(int'(wo) * S - P + K - 1));
assign last_tick = (c == NUM_WIDTH - 1 + P);

// the RAMs: one per row slot, written by the input side, all read at column c on a tick
generate
    for (g = 0; g < NUM_ROWS; g = g + 1) begin : Slot
        logic [CW-1:0] lb [0:NUM_WIDTH-1];
        always @(posedge clk) if (s_handshaking && wr_slot == g) lb[wr_w] <= #1 din_v;
        always @(posedge clk) if (tick && in_map) rd_q[g] <= #1 lb[c[W_W-1:0]];
    end
endgenerate

// walk counters
always @(posedge clk) begin
    if (!nRst || ps_start) begin
        ho         <= #1 '0;
        wo         <= #1 '0;
        c          <= #1 C_W'(-P);
        frame_base <= #1 '0;
        frame_slot <= #1 '0;
    end else if (tick) begin
        if (emit0) wo <= #1 wo + 1'b1;
        if (last_tick) begin
            c  <= #1 C_W'(-P);
            wo <= #1 '0;
            if (ho == NUM_HO - 1) begin
                ho         <= #1 '0;
                frame_base <= #1 frame_base + NUM_HEIGHT;
                frame_slot <= #1 SLOT_W'((int'(frame_slot) + NUM_HEIGHT) % NUM_ROWS);
            end else begin
                ho <= #1 ho + 1'b1;
            end
        end else begin
            c <= #1 c + 1'b1;
        end
    end else begin
        ho         <= #1 ho;
        wo         <= #1 wo;
        c          <= #1 c;
        frame_base <= #1 frame_base;
        frame_slot <= #1 frame_slot;
    end
end

// T1: the column lands, the window shifts; T2: the patch (the window after that shift) goes into dOut
always @(posedge clk) begin
    if (!nRst || ps_start) begin
        v1      <= #1 1'b0;
        in_map1 <= #1 1'b0;
        emit1   <= #1 1'b0;
        emit2   <= #1 1'b0;
    end else if (adv) begin
        v1      <= #1 tick;
        in_map1 <= #1 in_map;
        emit1   <= #1 emit0;
        emit2   <= #1 v1 && emit1;
    end else begin
        v1      <= #1 v1;
        in_map1 <= #1 in_map1;
        emit1   <= #1 emit1;
        emit2   <= #1 emit2;
    end
end

always @(posedge clk) begin
    if (adv && tick) begin
        slot1 <= #1 row_slot;
        pad1  <= #1 row_pad;
    end
end

always @(posedge clk) begin
    if (adv && v1) begin
        for (int kh = 0; kh < K; kh++) begin
            for (int kw = 0; kw < K - 1; kw++) win[kh][kw] <= #1 win[kh][kw + 1];
            win[kh][K-1] <= #1 (!in_map1 || pad1[kh]) ? PAD_COL : rd_q[slot1[kh]];
        end
    end
end

// the patch in the weight order
always_comb begin
    for (int ch = 0; ch < NUM_CH; ch++)
        for (int kh = 0; kh < K; kh++)
            for (int kw = 0; kw < K; kw++)
                patch[PATCH_S2D ? ((kw*K + kh)*NUM_CH + ch) : ((ch*K + kh)*K + kw)] = win[kh][kw][ch*ACT_W +: ACT_W];
end

always @(posedge clk) begin
    if (!nRst) begin
        dOut <= #1 '{default:'0};
    end else if (adv && emit2) begin
        dOut <= #1 patch;
    end else begin
        dOut <= #1 dOut;
    end
end

always @(posedge clk) begin
    if (!nRst || ps_start) begin
        m_valid <= #1 1'b0;
    end else if (adv) begin
        m_valid <= #1 emit2;
    end else begin
        m_valid <= #1 m_valid;
    end
end

endmodule
