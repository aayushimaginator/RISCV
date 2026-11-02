`default_nettype none

module rv32i_immgen (
    input  wire [31:0] instr,
    output reg  [31:0] imm
);

    // Extract the 5-bit opcode field (bits 6:2)
    wire [6:0] opcode = instr[6:0];

    always @* begin
        case (opcode[6:2])
            5'b00000, // LOAD (I-type)
            5'b00100, // OP-IMM (I-type)
            5'b11001: // JALR (I-type)
                imm = {{20{instr[31]}}, instr[31:20]};

            5'b01000: // STORE (S-type)
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            5'b11000: // BRANCH (B-type)
                imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

            5'b01101, // LUI (U-type)
            5'b00101: // AUIPC (U-type)
                imm = {instr[31:12], 12'b0};

            5'b11011: // JAL (J-type)
                imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

            default:
                imm = 32'h0000_0000;
        endcase
    end

endmodule

`default_nettype wire
