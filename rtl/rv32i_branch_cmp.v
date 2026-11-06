`default_nettype none

module rv32i_branch_cmp (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  funct3,
    output reg         taken
);

    wire signed [31:0] a_s;
    wire signed [31:0] b_s;

    assign a_s = a;
    assign b_s = b;

    always @* begin
        case (funct3)
            3'b000: taken = (a == b);
            3'b001: taken = (a != b);
            3'b010: taken = 1'b0;
            3'b011: taken = 1'b0;
            3'b100: taken = (a_s < b_s);
            3'b101: taken = (a_s >= b_s);
            3'b110: taken = (a < b);
            3'b111: taken = (a >= b);
            default: taken = 1'b0;
        endcase
    end

endmodule

`default_nettype wire
