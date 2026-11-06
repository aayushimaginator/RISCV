`default_nettype none

module rv32i_alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  op,
    output reg  [31:0] y
);

    wire [4:0]         shamt;
    wire signed [31:0] a_s;
    wire signed [31:0] b_s;

    assign shamt = b[4:0];
    assign a_s   = a;
    assign b_s   = b;

    always @* begin
        case (op)
            4'b0000: y = a + b;
            4'b0001: y = a << shamt;
            4'b0010: y = {31'b0, a_s < b_s};
            4'b0011: y = {31'b0, a < b};
            4'b0100: y = a ^ b;
            4'b0101: y = a >> shamt;
            4'b0110: y = a | b;
            4'b0111: y = a & b;
            4'b1000: y = a - b;
            4'b1101: y = a_s >>> shamt;
            default: y = 32'h0000_0000;
        endcase
    end

endmodule

`default_nettype wire
