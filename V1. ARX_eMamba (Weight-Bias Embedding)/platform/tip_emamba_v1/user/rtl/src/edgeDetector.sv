`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/27/2024 09:44:16 PM
// Design Name: 
// Module Name: edgeDetector
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


module edgeDetector (
    clk,
    nRst,

    curr_signal,

    rising_edge,
    falling_edge
);

input clk, nRst;

input curr_signal;

output rising_edge, falling_edge;

reg next_signal;

always @(posedge clk) begin
    if (!nRst)
        next_signal <= #1 1'b0; 
    else
        next_signal <= #1 curr_signal;
end

assign rising_edge = (curr_signal & ~next_signal);
assign falling_edge = (~curr_signal & next_signal); 

endmodule