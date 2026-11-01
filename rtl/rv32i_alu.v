`default_nettype none

// -----------------------------------------------------------------------------
// rv32i_alu
//
// OP encoding = {funct7[5], funct3}
//
//   0000 ADD
//   0001 SLL
//   0010 SLT
//   0011 SLTU
//   0100 XOR
//   0101 SRL
//   0110 OR
//   0111 AND
//   1000 SUB
//   1101 SRA
//
// All other opcodes produce y = 0.
// Shift amount is b[4:0].
// -----------------------------------------------------------------------------

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
            4'b0000: begin
                y = a + b;
            end

            4'b0001: begin
                y = a << shamt;
            end

            4'b0010: begin
                y = {31'b0, a_s < b_s};
            end

            4'b0011: begin
                y = {31'b0, a < b};
            end

            4'b0100: begin
                y = a ^ b;
            end

            4'b0101: begin
                y = a >> shamt;
            end

            4'b0110: begin
                y = a | b;
            end

            4'b0111: begin
                y = a & b;
            end

            4'b1000: begin
                y = a - b;
            end

            4'b1101: begin
                y = a_s >>> shamt;
            end

            default: begin
                y = 32'h0000_0000;
            end
        endcase
    end

endmodule

// -----------------------------------------------------------------------------
// rv32i_branch_cmp
//
// funct3:
//   000 BEQ
//   001 BNE
//   010 reserved -> 0
//   011 reserved -> 0
//   100 BLT  signed
//   101 BGE  signed
//   110 BLTU unsigned
//   111 BGEU unsigned
// -----------------------------------------------------------------------------

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
            3'b000: begin
                taken = (a == b);
            end

            3'b001: begin
                taken = (a != b);
            end

            3'b010: begin
                taken = 1'b0;
            end

            3'b011: begin
                taken = 1'b0;
            end

            3'b100: begin
                taken = (a_s < b_s);
            end

            3'b101: begin
                taken = (a_s >= b_s);
            end

            3'b110: begin
                taken = (a < b);
            end

            3'b111: begin
                taken = (a >= b);
            end

            default: begin
                taken = 1'b0;
            end
        endcase
    end

endmodule

`default_nettype wire
