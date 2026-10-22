`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/29/2024 10:36:50 PM
// Design Name: 
// Module Name: comparator
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


module comparator #(
    parameter integer DATA_WIDTH = 8
)(
    dIn_1,
    dIn_2,

    dOut_max,
    dOut_min
);

input logic signed [DATA_WIDTH-1:0] dIn_1, dIn_2;

output logic signed [DATA_WIDTH-1:0] dOut_max, dOut_min;

always @(*) begin
    if (dIn_1 >= dIn_2) begin
        dOut_max = dIn_1;
        dOut_min = dIn_2;
    end else begin
        dOut_max = dIn_2;
        dOut_min = dIn_1;
    end
end

endmodule