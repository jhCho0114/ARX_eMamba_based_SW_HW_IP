`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: Gate_Lanes
// Description: step 19 gate (out_norm x SiLU(z)) with the requantisation into step 20, as a
//              stream stage on NUM_LANE (P) channels per cycle; the arithmetic of eMamba's
//              ElementWise_Prod_Dynamic (vector mode), with its shifter_right and saturator:
//                  dOut[c] = sat8(rshr(dIn_1[c] * dIn_2[c], S1 + S2 - SO))
//              A token pair is NCH = NUM_DIM / P chunks, one per cycle through three stages:
//                S1  the chunk of both inputs, registered      S2  P products, registered
//                S3  rshr + sat8 -> output token (registered when its last chunk is done)
//
//   The inputs are read in place while s_valid is high, chunk by chunk, so they must hold still
//   until the handshake (the AXI-Stream rule; out_norm and the Z buffer of SS2D do).  s_ready
//   comes with the last chunk, once the output register is free for it (no token waiting in it or
//   on its way).
//
// Dependencies: shifter_right.sv, saturator.sv (U_eMamba/RTL)
//////////////////////////////////////////////////////////////////////////////////
module Gate_Lanes #(
    parameter integer DATA_WIDTH      = 8,
    parameter integer NUM_DIM         = 64,
    parameter integer NUM_LANE        = NUM_DIM,
    parameter integer NUM_SCALE_DIN_1 = 2,
    parameter integer NUM_SCALE_DIN_2 = 4,
    parameter integer NUM_SCALE_DOUT  = 3
)(
    clk,
    nRst,
    ps_start,

    dIn_1,
    dIn_2,
    dOut,

    s_valid,
    s_ready,
    m_valid,
    m_ready
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer P               = NUM_LANE;
localparam integer NCH             = NUM_DIM / NUM_LANE;
localparam integer CW              = P * DATA_WIDTH;
localparam integer TW              = NUM_DIM * DATA_WIDTH;
localparam integer CH_W            = ($clog2(NCH) > 0) ? $clog2(NCH) : 1;
localparam integer DATA_WIDTH_PROD = DATA_WIDTH * 2;
localparam integer NUM_RSH_DOUT    = NUM_SCALE_DIN_1 + NUM_SCALE_DIN_2 - NUM_SCALE_DOUT;
localparam integer DATA_WIDTH_RSH  = DATA_WIDTH_PROD - NUM_RSH_DOUT;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input  logic clk, nRst, ps_start;

input  logic signed [DATA_WIDTH-1:0] dIn_1 [0:NUM_DIM-1];
input  logic signed [DATA_WIDTH-1:0] dIn_2 [0:NUM_DIM-1];
output logic signed [DATA_WIDTH-1:0] dOut  [0:NUM_DIM-1];

input  logic s_valid, m_ready;
output logic s_ready, m_valid;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic [CH_W-1:0]                   k, k1, k2;
logic                              v1, v2, last_ok, sel;
logic signed [DATA_WIDTH-1:0]      a_q    [0:P-1];
logic signed [DATA_WIDTH-1:0]      b_q    [0:P-1];
logic signed [DATA_WIDTH_PROD-1:0] prod_q [0:P-1];
logic signed [DATA_WIDTH_RSH-1:0]  prod_rsh [0:P-1];
logic signed [DATA_WIDTH-1:0]      y      [0:P-1];
logic [CW-1:0]                     y_chunk;
logic [(NCH > 1 ? TW - CW : 1)-1:0] asm_q;
logic [TW-1:0]                     out_q;

generate
    if (NUM_DIM % NUM_LANE != 0)
        $error("Gate_Lanes: NUM_DIM = %0d is not a multiple of NUM_LANE = %0d", NUM_DIM, NUM_LANE);
endgenerate

// the last chunk goes in only when the output register will be free for it
assign last_ok = !m_valid && !(v1 && k1 == NCH - 1) && !(v2 && k2 == NCH - 1);
assign s_ready = (k == NCH - 1) && last_ok;
assign sel     = s_valid && ((k != NCH - 1) || last_ok);

always @(posedge clk) begin
    if (!nRst || ps_start) begin
        k       <= #1 '0;
        v1      <= #1 1'b0;
        v2      <= #1 1'b0;
        m_valid <= #1 1'b0;
    end else begin
        if (sel) k <= #1 (k == NCH - 1) ? '0 : k + 1'b1;
        v1 <= #1 sel;
        v2 <= #1 v1;
        if (v2 && k2 == NCH - 1) m_valid <= #1 1'b1;
        else if (m_ready)        m_valid <= #1 1'b0;
    end
end

always @(posedge clk) begin
    k1 <= #1 k;
    k2 <= #1 k1;
end

genvar l;
generate
    for (l = 0; l < P; l = l + 1) begin: Lane
        // S1: the chunk;  S2: the product;  S3: rshr + sat8
        always @(posedge clk) begin
            if (sel) begin
                a_q[l] <= #1 (NCH > 1) ? dIn_1[k * P + l] : dIn_1[l];
                b_q[l] <= #1 (NCH > 1) ? dIn_2[k * P + l] : dIn_2[l];
            end
            if (v1) prod_q[l] <= #1 a_q[l] * b_q[l];
        end

        shifter_right #(
            .DATA_WIDTH(DATA_WIDTH_PROD),
            .NUM_SHIFT(NUM_RSH_DOUT)
        ) shifter_dOut (
            .dIn(prod_q[l]),
            .dOut(prod_rsh[l])
        );
        saturator #(
            .DATA_WIDTH(DATA_WIDTH_RSH)
        ) saturator_dOut (
            .dIn(prod_rsh[l]),
            .dOut(y[l])
        );
        assign y_chunk[l * DATA_WIDTH +: DATA_WIDTH] = y[l];
    end
endgenerate

generate
    if (NCH > 1) begin: Assemble
        always @(posedge clk) begin
            if (v2 && k2 != NCH - 1) asm_q <= #1 ({y_chunk, asm_q} >> CW);
            if (v2 && k2 == NCH - 1) out_q <= #1 {y_chunk, asm_q};
        end
    end else begin: Whole
        always @(posedge clk) if (v2) out_q <= #1 y_chunk;
    end
    for (l = 0; l < NUM_DIM; l = l + 1) begin: Out
        assign dOut[l] = out_q[l * DATA_WIDTH +: DATA_WIDTH];
    end
endgenerate

endmodule
