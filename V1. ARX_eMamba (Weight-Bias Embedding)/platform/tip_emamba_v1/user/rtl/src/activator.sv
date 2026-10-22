`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/03/2024 03:13:03 PM
// Design Name: 
// Module Name: activator
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


module activator #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_RSH_DOUT = 8
)(
    dIn,
    dOut
);

localparam integer DATA_WIDTH_DOUT = DATA_WIDTH - NUM_RSH_DOUT;

input  logic signed [DATA_WIDTH-1:0] dIn;
output logic signed [7:0] dOut; // 8-bit

logic signed [DATA_WIDTH:0] dIn_temp; // expand 1-bit for prevent overflow
logic signed [DATA_WIDTH_DOUT:0] dOut_rsh;

shifter_right #(
    .DATA_WIDTH(DATA_WIDTH + 1),
    .NUM_SHIFT(NUM_RSH_DOUT)
) shifter_right (
    .dIn(dIn_temp),
    .dOut(dOut_rsh)
);

assign dIn_temp = dIn;

// Saturation for 8-bit
always @(*) begin
    if (dOut_rsh >= 127)
        dOut = 'd127;
    else if (dOut_rsh <= -128)
        dOut = -'d128;
    else
        dOut = dOut_rsh;
end

endmodule