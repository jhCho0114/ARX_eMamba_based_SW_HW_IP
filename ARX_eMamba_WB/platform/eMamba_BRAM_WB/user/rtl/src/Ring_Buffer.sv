`timescale 1ns / 1ps


module Ring_Buffer #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_DIM    = 384,
    parameter integer DEPTH_POWER_2      = 8      // 2's power
)(
    input  logic clk, nRst, ps_start,
    input  logic push,
    input  logic pop, 
    input  logic signed [DATA_WIDTH-1:0] dIn  [0:NUM_DIM-1],
    output logic signed [DATA_WIDTH-1:0] dOut [0:NUM_DIM-1],
    output logic full, empty
);
localparam integer PTR_W = ($clog2(DEPTH_POWER_2) > 0) ? $clog2(DEPTH_POWER_2) : 1;
localparam integer ROW_W = DATA_WIDTH * NUM_DIM; // [J-IMP]

logic [ROW_W-1:0] mem [0:DEPTH_POWER_2-1]; // [J-IMP] LUTRAM inference (do not drop the attribute)
logic [ROW_W-1:0] dIn_flat, dOut_flat;   // [J-IMP]
logic [PTR_W-1:0] wr_ptr, rd_ptr;
logic [PTR_W:0]   count;

assign full  = (count == DEPTH_POWER_2[PTR_W:0]);
assign empty = (count == 0);

// [J-IMP]
genvar g;
generate
    for (g = 0; g < NUM_DIM; g = g + 1) begin: Flat // [J-IMP] label is mandatory after "begin:"
        assign dIn_flat[g * DATA_WIDTH +: DATA_WIDTH] = dIn[g];
        assign dOut[g] = dOut_flat[g * DATA_WIDTH +: DATA_WIDTH];
    end
endgenerate
// [J-IMP] 

assign dOut_flat = mem[rd_ptr];

always @(posedge clk) begin 
    if (push)
        mem[wr_ptr] <= #1 dIn_flat; 
end

always @(posedge clk) begin
    if (!nRst || ps_start) begin
        wr_ptr <= #1 'd0;
    end
    else begin
        if (push)
            wr_ptr <= #1 wr_ptr + 1'b1;
    end
end

always @(posedge clk) begin
    if (!nRst || ps_start) begin
        rd_ptr <= #1 'd0;
    end
    else begin
        if (pop)
            rd_ptr <= #1 rd_ptr + 1'b1;
    end
end

always @(posedge clk) begin
    if (!nRst || ps_start) begin
        count  <= #1 'd0;
    end
    else begin
        case ({push, pop})
            2'b10:   count <= #1 count + 1'b1;
            2'b01:   count <= #1 count - 1'b1;
            default: ;
        endcase
    end
end

endmodule




/*
module Ring_Buffer #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_DIM    = 384,
    parameter integer DEPTH_POWER_2      = 8      // 2's power
)(
    input  logic clk, nRst, ps_start,
    input  logic push,                                 // 병렬 경로 입구 전송 (s_valid & s_ready)
    input  logic pop,                                  // 병렬 경로 출구 전송 (m_valid & m_ready)
    input  logic signed [DATA_WIDTH-1:0] dIn  [0:NUM_DIM-1],
    output logic signed [DATA_WIDTH-1:0] dOut [0:NUM_DIM-1],
    output logic full, empty
);
localparam integer PTR_W = ($clog2(DEPTH_POWER_2) > 0) ? $clog2(DEPTH_POWER_2) : 1;

logic signed [DATA_WIDTH-1:0] mem [0:DEPTH_POWER_2-1][0:NUM_DIM-1];
logic [PTR_W-1:0] wr_ptr, rd_ptr;
logic [PTR_W:0]   count;

assign full  = (count == DEPTH_POWER_2[PTR_W:0]);
assign empty = (count == 0);

always @(*) dOut = mem[rd_ptr];

always @(posedge clk) begin
    if (!nRst || ps_start) begin
        wr_ptr <= #1 'd0;
    end
    else begin
        if (push) begin
            mem[wr_ptr] <= #1 dIn;
            wr_ptr      <= #1 wr_ptr + 1'b1;
        end
    end
end

always @(posedge clk) begin
    if (!nRst || ps_start) begin
        rd_ptr <= #1 'd0;
    end
    else begin
        if (pop)
            rd_ptr <= #1 rd_ptr + 1'b1;
    end
end

always @(posedge clk) begin
    if (!nRst || ps_start) begin
        count  <= #1 'd0;
    end
    else begin
        case ({push, pop})
            2'b10:   count <= #1 count + 1'b1;
            2'b01:   count <= #1 count - 1'b1;
            default: ;
        endcase
    end
end

endmodule
*/

// always @(posedge clk) begin
//     if (!nRst || ps_start) begin
//         wr_ptr <= #1 'd0;
//         rd_ptr <= #1 'd0;
//         count  <= #1 'd0;
//     end
//     else begin
//         if (push) begin
//             mem[wr_ptr] <= #1 dIn;
//             wr_ptr      <= #1 wr_ptr + 1'b1;
//         end

//         if (pop)
//             rd_ptr <= #1 rd_ptr + 1'b1;

//         case ({push, pop})
//             2'b10:   count <= #1 count + 1'b1;
//             2'b01:   count <= #1 count - 1'b1;
//             default: ;
//         endcase
//     end
// end