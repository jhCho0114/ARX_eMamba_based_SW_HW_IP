`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: ElementWise_Prod_Dynamic
// Description: ElementWise_Prod / Dim_expand_delta_B_compute 통합 모듈.
//              원소별 곱 + 재양자화(shifter_right + saturator).
//
//   BROADCAST_DIN_1 = 0 : dOut[i] = quant(dIn_1_vec[i] * dIn_2[i])   (벡터 x 벡터)
//   BROADCAST_DIN_1 = 1 : dOut[i] = quant(dIn_1_scalar * dIn_2[i])  (스칼라 x 벡터)
//////////////////////////////////////////////////////////////////////////////////

module ElementWise_Prod_Dynamic #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_DIM    = 40,

    parameter bit BROADCAST_DIN_1 = 1'b0,  // 0: ElementWise_Prod, 1: Dim_expand_delta_B_compute

    parameter integer NUM_SCALE_DIN_1 = 3,
    parameter integer NUM_SCALE_DIN_2 = 6,
    parameter integer NUM_SCALE_DOUT  = 5
)(
    dIn_1_scalar,  // BROADCAST_DIN_1=1일 때 사용
    dIn_1_vec,     // BROADCAST_DIN_1=0일 때 사용
    dIn_2,

    dOut
);

// ---------- Local Parameters ---------- //
localparam integer DATA_WIDTH_PROD = DATA_WIDTH * 2;
localparam integer NUM_RSH_DOUT     = NUM_SCALE_DIN_1 + NUM_SCALE_DIN_2 - NUM_SCALE_DOUT;
localparam integer DATA_WIDTH_RSH   = DATA_WIDTH_PROD - NUM_RSH_DOUT;

// ---------- I/O Ports ---------- //
input  logic signed [DATA_WIDTH-1:0] dIn_1_scalar;
input  logic signed [DATA_WIDTH-1:0] dIn_1_vec [0:NUM_DIM-1];
input  logic signed [DATA_WIDTH-1:0] dIn_2      [0:NUM_DIM-1];

output logic signed [DATA_WIDTH-1:0] dOut [0:NUM_DIM-1];

// ---------- Internal Signals ---------- //
logic signed [DATA_WIDTH_PROD-1:0] prod      [0:NUM_DIM-1];
logic signed [DATA_WIDTH_RSH-1:0]  prod_rsh  [0:NUM_DIM-1];

genvar i;

// ---------- Element-wise multiply ---------- //
generate
    for (i = 0; i < NUM_DIM; i = i + 1) begin: Mul
        if (BROADCAST_DIN_1) begin: Broadcast
            assign prod[i] = dIn_1_scalar * dIn_2[i];
        end else begin: Vector
            assign prod[i] = dIn_1_vec[i] * dIn_2[i];
        end
    end
endgenerate

// ---------- Requantize: shift + saturate ---------- //
generate
    for (i = 0; i < NUM_DIM; i = i + 1) begin: Requantize
        shifter_right #(
            .DATA_WIDTH(DATA_WIDTH_PROD),
            .NUM_SHIFT(NUM_RSH_DOUT)
        ) shifter_dOut (
            .dIn(prod[i]),
            .dOut(prod_rsh[i])
        );

        saturator #(
            .DATA_WIDTH(DATA_WIDTH_RSH)
        ) saturator_dOut (
            .dIn(prod_rsh[i]),
            .dOut(dOut[i])
        );
    end
endgenerate

endmodule