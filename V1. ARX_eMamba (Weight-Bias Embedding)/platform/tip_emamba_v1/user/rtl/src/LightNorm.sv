`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/29/2024 09:29:40 PM
// Design Name: 
// Module Name: LightNorm
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module LightNorm #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_SEQLEN = 16,
    parameter integer NUM_DIM    = 20,

    parameter integer NUM_SCALE_DIN    = 5,
    parameter integer NUM_SCALE_WEIGHT = 7,
    parameter integer NUM_SCALE_BIAS   = 7,
    parameter integer NUM_SCALE_DOUT   = 6,

    // 0: 1st MAMBA, 1: 2nd MAMBA, 2: Outputhead
    parameter integer LAYER_ID = 0
)(
    clk,
    nRst,

    ps_start,

    dIn,
    dOut,

    prev_layer_ready,
    next_layer_ready,
    layer_ready,
    dOut_ready
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer NUM_LSH_DIN     = 5;
localparam integer DATA_WIDTH_DIN  = DATA_WIDTH + NUM_LSH_DIN;
localparam integer DATA_WIDTH_NORM = DATA_WIDTH_DIN + DATA_WIDTH + 4;
localparam integer DATA_WIDTH_DOUT = DATA_WIDTH_NORM - NUM_LSH_DIN + 1;

localparam INIT           = 'd0,
           IDLE           = 'd1,
           COMPUTING_MEAN = 'd2,
           COMPUTING_DOUT = 'd3;

localparam integer NUM_RSH_DOUT        = NUM_SCALE_WEIGHT + 3 - NUM_SCALE_DOUT;
localparam integer DATA_WIDTH_DOUT_RSH = DATA_WIDTH_DOUT - NUM_RSH_DOUT;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input clk, nRst;

input ps_start;

input  logic signed [DATA_WIDTH-1:0] dIn  [0:NUM_DIM-1];
output logic signed [DATA_WIDTH-1:0] dOut [0:NUM_DIM-1];

input  prev_layer_ready, next_layer_ready;
output layer_ready, dOut_ready;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic signed [DATA_WIDTH-1:0] weight [0:NUM_DIM-1]; // 20
logic signed [DATA_WIDTH-1:0] bias   [0:NUM_DIM-1]; // 20

logic [2:0] curr_state,
            next_state;

logic signed [DATA_WIDTH_DIN-1:0] dIn_lsh [0:NUM_DIM-1];
logic signed [DATA_WIDTH_DIN-1:0] dIn_mem [0:NUM_DIM-1];

logic signed [DATA_WIDTH_DIN-1:0] dIn_mean;
logic        [DATA_WIDTH_DIN-1:0] dIn_range;

logic signed [DATA_WIDTH_DIN-1:0] compute_dIn    [0:NUM_DIM-1];
logic signed [DATA_WIDTH-1:0]     compute_weight [0:NUM_DIM-1];
logic signed [DATA_WIDTH-1:0]     compute_bias   [0:NUM_DIM-1];

logic compute_start;
logic compute_valid [0:NUM_DIM-1];
logic compute_valid_all;
logic signed [DATA_WIDTH_DOUT-1:0] compute_dOut [0:NUM_DIM-1];

logic signed [DATA_WIDTH_DOUT_RSH-1:0] compute_dOut_shifted [0:NUM_DIM-1];

logic signed [DATA_WIDTH-1:0] compute_dOut_saturated [0:NUM_DIM-1];

genvar n, m;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Submodules
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
generate
    for (n = 0; n < NUM_DIM; n = n + 1) begin: dIn_upScaling
        shifter_left #(
            .DATA_WIDTH(DATA_WIDTH),
            .NUM_SHIFT(NUM_LSH_DIN)
        ) shifter_left_dIn (
            .dIn(dIn[n]),
            .dOut(dIn_lsh[n])
        );
    end
endgenerate

calculator_mean #(
    .DATA_WIDTH(DATA_WIDTH_DIN),
    .NUM_DIM(NUM_DIM)
) calculator_mean (
    .clk(clk),
    .nRst(nRst),

    .dIn(dIn_mem),
    .dOut(dIn_mean)
);

calculator_range #(
    .DATA_WIDTH(DATA_WIDTH_DIN),
    .NUM_DIM(NUM_DIM)
) calculator_range (
    .dIn(dIn_mem),
    .dIn_mean(dIn_mean),
    .dOut(dIn_range)
);

generate
    for (m = 0; m < NUM_DIM; m = m + 1) begin: LightNorm_compute
        LightNorm_compute #(
            .DATA_WIDTH(DATA_WIDTH), // weight, bias
            .DATA_WIDTH_DIN(DATA_WIDTH_DIN), // upScaled dIn
            .NUM_DIM(NUM_DIM),
            .NUM_LSH_DIN(NUM_LSH_DIN),
            .NUM_SCALE_WEIGHT(NUM_SCALE_WEIGHT),
            .NUM_SCALE_BIAS(NUM_SCALE_BIAS)
        ) LightNorm_compute (
            .clk(clk),
            .nRst(nRst),

            .start(compute_start),

            .dIn(compute_dIn[m]),
            .weight(compute_weight[m]),
            .bias(compute_bias[m]),

            .dIn_mean(dIn_mean),
            .dIn_range(dIn_range),

            .valid(compute_valid[m]),
            .dOut(compute_dOut[m])
        );
    end

    for (m = 0; m < NUM_DIM; m = m + 1) begin: dOut_downScaling
        shifter_right #(
            .DATA_WIDTH(DATA_WIDTH_DOUT),
            .NUM_SHIFT(NUM_RSH_DOUT)
        ) shifter_right_dOut (
            .dIn(compute_dOut[m]),
            .dOut(compute_dOut_shifted[m])
        );
    end

    for (m = 0; m < NUM_DIM; m = m + 1) begin: dOut_saturation
        saturator #(
            .DATA_WIDTH(DATA_WIDTH_DOUT_RSH)
        ) saturator (
            .dIn(compute_dOut_shifted[m]),
            .dOut(compute_dOut_saturated[m])
        );
    end
endgenerate

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Main Code
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// FSM
always @(posedge clk) begin
    if (!nRst || ps_start)
        curr_state <= #1 INIT;
    else
        curr_state <= #1 next_state;
end

always @(*) begin
    next_state = curr_state;

    case (curr_state)
        INIT, IDLE: begin
            if (prev_layer_ready & next_layer_ready)
                next_state = COMPUTING_MEAN;
            else
                next_state = curr_state;
        end

        COMPUTING_MEAN: next_state = COMPUTING_DOUT;

        COMPUTING_DOUT: begin
            if (compute_valid_all)
                next_state = IDLE;
            else
                next_state = curr_state;
        end

        default: next_state = curr_state;
    endcase
end

always @(*) begin
    if (curr_state == COMPUTING_MEAN)
        compute_start = 1;
    else
        compute_start = 0;
end

// Matrix multiplier data
generate
    for (m = 0; m < NUM_DIM; m = m + 1) begin
        always @(*) begin
            compute_dIn[m]    = dIn_mem[m];
            compute_weight[m] = weight[m];
            compute_bias[m]   = bias[m];
        end
    end
endgenerate

// Final output
always @(posedge clk) begin
    if (!nRst) begin
        dOut[0]  <= #1 0;
        dOut[1]  <= #1 0;
        dOut[2]  <= #1 0;
        dOut[3]  <= #1 0;
        dOut[4]  <= #1 0;
        dOut[5]  <= #1 0;
        dOut[6]  <= #1 0;
        dOut[7]  <= #1 0;
        dOut[8]  <= #1 0;
        dOut[9]  <= #1 0;
        dOut[10] <= #1 0;
        dOut[11] <= #1 0;
        dOut[12] <= #1 0;
        dOut[13] <= #1 0;
        dOut[14] <= #1 0;
        dOut[15] <= #1 0;
        dOut[16] <= #1 0;
        dOut[17] <= #1 0;
        dOut[18] <= #1 0;
        dOut[19] <= #1 0;
    end else begin
        if (compute_valid_all) begin
            dOut[0]  <= #1 compute_dOut_saturated[0];
            dOut[1]  <= #1 compute_dOut_saturated[1];
            dOut[2]  <= #1 compute_dOut_saturated[2];
            dOut[3]  <= #1 compute_dOut_saturated[3];
            dOut[4]  <= #1 compute_dOut_saturated[4];
            dOut[5]  <= #1 compute_dOut_saturated[5];
            dOut[6]  <= #1 compute_dOut_saturated[6];
            dOut[7]  <= #1 compute_dOut_saturated[7];
            dOut[8]  <= #1 compute_dOut_saturated[8];
            dOut[9]  <= #1 compute_dOut_saturated[9];
            dOut[10] <= #1 compute_dOut_saturated[10];
            dOut[11] <= #1 compute_dOut_saturated[11];
            dOut[12] <= #1 compute_dOut_saturated[12];
            dOut[13] <= #1 compute_dOut_saturated[13];
            dOut[14] <= #1 compute_dOut_saturated[14];
            dOut[15] <= #1 compute_dOut_saturated[15];
            dOut[16] <= #1 compute_dOut_saturated[16];
            dOut[17] <= #1 compute_dOut_saturated[17];
            dOut[18] <= #1 compute_dOut_saturated[18];
            dOut[19] <= #1 compute_dOut_saturated[19];
        end else begin
            dOut <= #1 dOut;
        end
    end
end

// Input FF
always @(posedge clk) begin
    if (prev_layer_ready && next_layer_ready && (curr_state == INIT || curr_state == IDLE))
        dIn_mem <= #1 dIn_lsh;
    else
        dIn_mem <= #1 dIn_mem;
end

// All the parallel computation results valid
assign compute_valid_all = compute_valid[0]  && compute_valid[1]  &&
                           compute_valid[2]  && compute_valid[3]  &&
                           compute_valid[4]  && compute_valid[5]  &&
                           compute_valid[6]  && compute_valid[7]  &&
                           compute_valid[8]  && compute_valid[9]  &&
                           compute_valid[10] && compute_valid[11] &&
                           compute_valid[12] && compute_valid[13] &&
                           compute_valid[14] && compute_valid[15] &&
                           compute_valid[16] && compute_valid[17] &&
                           compute_valid[18] && compute_valid[19];

// Ready signal
assign layer_ready = ((curr_state == INIT || curr_state == IDLE) && next_layer_ready) ? 1'b1 : 1'b0;
assign dOut_ready = ((curr_state == IDLE) && prev_layer_ready) ? 1'b1 : 1'b0;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Hard Coding
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
generate
    if (LAYER_ID == 0) begin
        // weight
        assign weight[0]  = 103;
        assign weight[1]  = 105;
        assign weight[2]  = 103;
        assign weight[3]  = 117;
        assign weight[4]  = 106;
        assign weight[5]  = 127;
        assign weight[6]  = 94;
        assign weight[7]  = 127;
        assign weight[8]  = 89;
        assign weight[9]  = 127;
        assign weight[10] = 100;
        assign weight[11] = 89;
        assign weight[12] = 116;
        assign weight[13] = 120;
        assign weight[14] = 106;
        assign weight[15] = 127;
        assign weight[16] = 109;
        assign weight[17] = 120;
        assign weight[18] = 100;
        assign weight[19] = 119;

        // bias
        assign bias[0]  = -9;
        assign bias[1]  = 5;
        assign bias[2]  = 7;
        assign bias[3]  = 2;
        assign bias[4]  = -4;
        assign bias[5]  = -2;
        assign bias[6]  = 1;
        assign bias[7]  = -6;
        assign bias[8]  = -1;
        assign bias[9]  = 1;
        assign bias[10] = -1;
        assign bias[11] = -13;
        assign bias[12] = -1;
        assign bias[13] = -3;
        assign bias[14] = -10;
        assign bias[15] = -6;
        assign bias[16] = 1;
        assign bias[17] = 2;
        assign bias[18] = -12;
        assign bias[19] = -1;
    end

    else if (LAYER_ID == 1) begin
        assign weight[0]  = 127;
        assign weight[1]  = 127;
        assign weight[2]  = 127;
        assign weight[3]  = 118;
        assign weight[4]  = 127;
        assign weight[5]  = 127;
        assign weight[6]  = 124;
        assign weight[7]  = 127;
        assign weight[8]  = 114;
        assign weight[9]  = 127;
        assign weight[10] = 127;
        assign weight[11] = 127;
        assign weight[12] = 127;
        assign weight[13] = 127;
        assign weight[14] = 127;
        assign weight[15] = 127;
        assign weight[16] = 123;
        assign weight[17] = 127;
        assign weight[18] = 123;
        assign weight[19] = 127;

        assign bias[0]  = 21;
        assign bias[1]  = -24;
        assign bias[2]  = 21;
        assign bias[3]  = -13;
        assign bias[4]  = -1;
        assign bias[5]  = -25;
        assign bias[6]  = -6;
        assign bias[7]  = 5;
        assign bias[8]  = 15;
        assign bias[9]  = -4;
        assign bias[10] = 17;
        assign bias[11] = -19;
        assign bias[12] = -20;
        assign bias[13] = 10;
        assign bias[14] = 3;
        assign bias[15] = 24;
        assign bias[16] = -16;
        assign bias[17] = 18;
        assign bias[18] = -20;
        assign bias[19] = 3;
    end

    else if (LAYER_ID == 2) begin
        assign weight[0]  = 127;
        assign weight[1]  = 127;
        assign weight[2]  = 127;
        assign weight[3]  = 127;
        assign weight[4]  = 127;
        assign weight[5]  = 117;
        assign weight[6]  = 123;
        assign weight[7]  = 125;
        assign weight[8]  = 127;
        assign weight[9]  = 116;
        assign weight[10] = 127;
        assign weight[11] = 123;
        assign weight[12] = 121;
        assign weight[13] = 127;
        assign weight[14] = 127;
        assign weight[15] = 127;
        assign weight[16] = 127;
        assign weight[17] = 110;
        assign weight[18] = 125;
        assign weight[19] = 127;

        assign bias[0]  = 10;
        assign bias[1]  = -17;
        assign bias[2]  = 8;
        assign bias[3]  = 13;
        assign bias[4]  = -15;
        assign bias[5]  = 4;
        assign bias[6]  = 1;
        assign bias[7]  = -11;
        assign bias[8]  = -11;
        assign bias[9]  = 4;
        assign bias[10] = 14;
        assign bias[11] = -12;
        assign bias[12] = 7;
        assign bias[13] = 13;
        assign bias[14] = 19;
        assign bias[15] = 13;
        assign bias[16] = 13;
        assign bias[17] = -1;
        assign bias[18] = -5;
        assign bias[19] = -15;
    end
endgenerate


endmodule