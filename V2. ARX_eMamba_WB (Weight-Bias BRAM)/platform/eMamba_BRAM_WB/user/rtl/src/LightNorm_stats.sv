`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: LightNorm_stats
// Description: LightNorm용 1-pass reduction.
//              sum / max / min / range를 dIn[D]에서 동시에 계산 (combinational).
//              NUM_DIM이 2의 거듭제곱이 아니면 leaf를 0(max/min sentinel) 패딩.
//////////////////////////////////////////////////////////////////////////////////

module LightNorm_stats #(
    parameter integer DATA_WIDTH = 13,
    parameter integer NUM_DIM    = 20
)(
    dIn,

    sum,
    max_val,
    min_val,
    range
);

// ---------- Local Parameters ---------- //
localparam integer NUM_STAGE = ($clog2(NUM_DIM) > 0) ? $clog2(NUM_DIM) : 1;
localparam integer NUM_LEAF  = 1 << NUM_STAGE;
localparam integer DATA_WIDTH_SUM = DATA_WIDTH + NUM_STAGE;

localparam signed [DATA_WIDTH-1:0] PAD_MAX =
    {1'b1, {(DATA_WIDTH-1){1'b0}}}; // signed minimum
localparam signed [DATA_WIDTH-1:0] PAD_MIN =
    {1'b0, {(DATA_WIDTH-1){1'b1}}}; // signed maximum

// ---------- I/O Ports ---------- //
input  logic signed [DATA_WIDTH-1:0] dIn [0:NUM_DIM-1];

output logic signed [DATA_WIDTH_SUM-1:0] sum;
output logic signed [DATA_WIDTH-1:0]     max_val;
output logic signed [DATA_WIDTH-1:0]     min_val;
output logic        [DATA_WIDTH-1:0]     range;

// ---------- Internal Variables ---------- //
logic signed [31:0]                  tree_sum [0:NUM_STAGE][0:NUM_LEAF-1];
logic signed [DATA_WIDTH-1:0]        tree_max [0:NUM_STAGE][0:NUM_LEAF-1];
logic signed [DATA_WIDTH-1:0]        tree_min [0:NUM_STAGE][0:NUM_LEAF-1];

genvar s, i;

// ---------- Leaf assignment ---------- //
generate
    for (i = 0; i < NUM_LEAF; i = i + 1) begin : LEAF
        if (i < NUM_DIM) begin : LEAF_ACTIVE
            assign tree_sum[0][i] = dIn[i];
            assign tree_max[0][i] = dIn[i];
            assign tree_min[0][i] = dIn[i];
        end else begin : LEAF_PAD
            assign tree_sum[0][i] = '0;
            assign tree_max[0][i] = PAD_MAX;
            assign tree_min[0][i] = PAD_MIN;
        end
    end

    // ---------- Sum reduction tree ---------- //
    for (s = 1; s <= NUM_STAGE; s = s + 1) begin : SUM_STAGE
        localparam integer STW = NUM_LEAF >> s;

        for (i = 0; i < STW; i = i + 1) begin : SUM_NODE
            CLA_32 u_add (
                .dIn_1(tree_sum[s-1][2*i]),
                .dIn_2(tree_sum[s-1][2*i+1]),
                .carryIn(1'b0),
                .dOut   (tree_sum[s][i])
            );
        end
    end

    // ---------- Max reduction tree ---------- //
    for (s = 1; s <= NUM_STAGE; s = s + 1) begin : MAX_STAGE
        localparam integer STW = NUM_LEAF >> s;

        for (i = 0; i < STW; i = i + 1) begin : MAX_NODE
            comparator #(.DATA_WIDTH(DATA_WIDTH)) u_cmp (
                .dIn_1   (tree_max[s-1][2*i]),
                .dIn_2   (tree_max[s-1][2*i+1]),
                .dOut_max(tree_max[s][i]),
                .dOut_min()
            );
        end
    end

    // ---------- Min reduction tree ---------- //
    for (s = 1; s <= NUM_STAGE; s = s + 1) begin : MIN_STAGE
        localparam integer STW = NUM_LEAF >> s;

        for (i = 0; i < STW; i = i + 1) begin : MIN_NODE
            comparator #(.DATA_WIDTH(DATA_WIDTH)) u_cmp (
                .dIn_1   (tree_min[s-1][2*i]),
                .dIn_2   (tree_min[s-1][2*i+1]),
                .dOut_max(),
                .dOut_min(tree_min[s][i])
            );
        end
    end
endgenerate

// ---------- Outputs ---------- //
assign sum     = tree_sum[NUM_STAGE][0][DATA_WIDTH_SUM-1:0];
assign max_val = tree_max[NUM_STAGE][0];
assign min_val = tree_min[NUM_STAGE][0];
assign range   = max_val - min_val;

endmodule