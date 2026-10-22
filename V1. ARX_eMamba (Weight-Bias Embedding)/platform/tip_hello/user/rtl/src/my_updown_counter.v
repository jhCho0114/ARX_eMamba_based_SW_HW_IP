`timescale 1ns / 1ps

module my_updown_counter #(
    parameter WIDTH = 8
)(
    input  wire             clk,
    input  wire             rst_n,   // Active-low reset
    input  wire             en,      // Enable signal
    input  wire             up_down, // 1: Up, 0: Down
    output reg  [WIDTH-1:0] count
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= {WIDTH{1'b0}};
        end else if (en) begin
            if (up_down)
                count <= count + 1'b1;
            else
                count <= count - 1'b1;
        end
    end

endmodule