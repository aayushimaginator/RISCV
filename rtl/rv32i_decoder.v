`default_nettype none

// -----------------------------------------------------------------------------
// rv32i_decoder
//
// RV32I base-only decoder.
//
// No M extension.
// No CSR extension.
// No compressed instructions.
//
// Output semantics:
//   a_sel  : 0 = rs1, 1 = pc
//   b_sel  : 0 = rs2, 1 = imm
//   wb_sel : 00 = ALU result
//            01 = memory load data
//            10 = PC + 4
//            11 = immediate
//
// Illegal instruction behavior:
//   halt = 1, and ALL other outputs are forced to 0.
//
// SYSTEM opcode behavior:
//   halt = 1 for ANY instruction with opcode 1110011.
//
// FENCE / FENCE.I behavior:
//   treated as NOP: all outputs 0, halt = 0.
// -----------------------------------------------------------------------------

module rv32i_decoder (
    input  wire [31:0] instr,

    output reg         reg_write,
    output reg         a_sel,
    output reg         b_sel,
    output reg  [3:0]  alu_op,
    output reg         mem_read,
    output reg         mem_write,
    output reg  [1:0]  wb_sel,
    output reg         is_branch,
    output reg         is_jal,
    output reg         is_jalr,
    output reg         halt
);

    // ALU operation encoding, matching the existing rv32i_alu.
    localparam [3:0] ALU_ADD = 4'b0000;
    localparam [3:0] ALU_SLL = 4'b0001;
    localparam [3:0] ALU_SRL = 4'b0101;
    localparam [3:0] ALU_SUB = 4'b1000;
    localparam [3:0] ALU_SRA = 4'b1101;

    // RV32I base opcodes.
    localparam [6:0] OPC_LUI    = 7'b0110111;
    localparam [6:0] OPC_AUIPC  = 7'b0010111;
    localparam [6:0] OPC_JAL    = 7'b1101111;
    localparam [6:0] OPC_JALR   = 7'b1100111;
    localparam [6:0] OPC_BRANCH = 7'b1100011;
    localparam [6:0] OPC_LOAD   = 7'b0000011;
    localparam [6:0] OPC_STORE  = 7'b0100011;
    localparam [6:0] OPC_OP_IMM = 7'b0010011;
    localparam [6:0] OPC_OP     = 7'b0110011;
    localparam [6:0] OPC_FENCE  = 7'b0001111;
    localparam [6:0] OPC_SYSTEM = 7'b1110011;

    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];

    always @* begin
        // Safe defaults.
        reg_write  = 1'b0;
        a_sel      = 1'b0;
        b_sel      = 1'b0;
        alu_op     = 4'b0000;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        wb_sel     = 2'b00;
        is_branch  = 1'b0;
        is_jal     = 1'b0;
        is_jalr    = 1'b0;
        halt       = 1'b0;

        // A 32-bit RV32I instruction must have instr[1:0] == 2'b11.
        if (instr[1:0] != 2'b11) begin
            halt = 1'b1;
        end
        else begin
            case (opcode)

                // -------------------------------------------------------------
                // LUI
                // -------------------------------------------------------------
                OPC_LUI: begin
                    reg_write = 1'b1;
                    wb_sel    = 2'b11;
                end

                // -------------------------------------------------------------
                // AUIPC
                // -------------------------------------------------------------
                OPC_AUIPC: begin
                    reg_write = 1'b1;
                    a_sel     = 1'b1;
                    b_sel     = 1'b1;
                    alu_op    = ALU_ADD;
                    wb_sel    = 2'b00;
                end

                // -------------------------------------------------------------
                // JAL
                // -------------------------------------------------------------
                OPC_JAL: begin
                    reg_write = 1'b1;
                    wb_sel    = 2'b10;
                    is_jal    = 1'b1;
                end

                // -------------------------------------------------------------
                // JALR
                // -------------------------------------------------------------
                OPC_JALR: begin
                    if (funct3 == 3'b000) begin
                        reg_write = 1'b1;
                        b_sel     = 1'b1;
                        alu_op    = ALU_ADD;
                        wb_sel    = 2'b10;
                        is_jalr   = 1'b1;
                    end
                    else begin
                        halt = 1'b1;
                    end
                end

                // -------------------------------------------------------------
                // BRANCH
                // -------------------------------------------------------------
                OPC_BRANCH: begin
                    case (funct3)
                        3'b000, // BEQ
                        3'b001, // BNE
                        3'b100, // BLT
                        3'b101, // BGE
                        3'b110, // BLTU
                        3'b111: // BGEU
                            begin
                                is_branch = 1'b1;
                                alu_op    = ALU_ADD;
                            end

                        default:
                            halt = 1'b1;
                    endcase
                end

                // -------------------------------------------------------------
                // LOAD
                // -------------------------------------------------------------
                OPC_LOAD: begin
                    case (funct3)
                        3'b000, // LB
                        3'b001, // LH
                        3'b010, // LW
                        3'b100, // LBU
                        3'b101: // LHU
                            begin
                                reg_write = 1'b1;
                                b_sel     = 1'b1;
                                alu_op    = ALU_ADD;
                                mem_read  = 1'b1;
                                wb_sel    = 2'b01;
                            end

                        default:
                            halt = 1'b1;
                    endcase
                end

                // -------------------------------------------------------------
                // STORE
                // -------------------------------------------------------------
                OPC_STORE: begin
                    case (funct3)
                        3'b000, // SB
                        3'b001, // SH
                        3'b010: // SW
                            begin
                                mem_write = 1'b1;
                                b_sel     = 1'b1;
                                alu_op    = ALU_ADD;
                            end

                        default:
                            halt = 1'b1;
                    endcase
                end

                // -------------------------------------------------------------
                // OP-IMM
                // -------------------------------------------------------------
                OPC_OP_IMM: begin
                    case (funct3)
                        3'b000, // ADDI
                        3'b010, // SLTI
                        3'b011, // SLTIU
                        3'b100, // XORI
                        3'b110, // ORI
                        3'b111: // ANDI
                            begin
                                reg_write = 1'b1;
                                b_sel     = 1'b1;
                                wb_sel    = 2'b00;
                                alu_op    = {1'b0, funct3};
                            end

                        3'b001: begin // SLLI
                            if (funct7 == 7'b0000000) begin
                                reg_write = 1'b1;
                                b_sel     = 1'b1;
                                wb_sel    = 2'b00;
                                alu_op    = ALU_SLL;
                            end
                            else begin
                                halt = 1'b1;
                            end
                        end

                        3'b101: begin // SRLI / SRAI
                            if (funct7 == 7'b0000000) begin
                                reg_write = 1'b1;
                                b_sel     = 1'b1;
                                wb_sel    = 2'b00;
                                alu_op    = ALU_SRL;
                            end
                            else if (funct7 == 7'b0100000) begin
                                reg_write = 1'b1;
                                b_sel     = 1'b1;
                                wb_sel    = 2'b00;
                                alu_op    = ALU_SRA;
                            end
                            else begin
                                halt = 1'b1;
                            end
                        end

                        default: begin
                            halt = 1'b1;
                        end
                    endcase
                end

                // -------------------------------------------------------------
                // OP
                // -------------------------------------------------------------
                OPC_OP: begin
                    if (funct7 == 7'b0000000) begin
                        reg_write = 1'b1;
                        wb_sel    = 2'b00;
                        alu_op    = {1'b0, funct3};
                    end
                    else if (funct7 == 7'b0100000) begin
                        if (funct3 == 3'b000) begin
                            reg_write = 1'b1;
                            wb_sel    = 2'b00;
                            alu_op    = ALU_SUB;
                        end
                        else if (funct3 == 3'b101) begin
                            reg_write = 1'b1;
                            wb_sel    = 2'b00;
                            alu_op    = ALU_SRA;
                        end
                        else begin
                            halt = 1'b1;
                        end
                    end
                    else begin
                        halt = 1'b1;
                    end
                end

                // -------------------------------------------------------------
                // FENCE / FENCE.I
                //
                // Treated as NOP.
                // -------------------------------------------------------------
                OPC_FENCE: begin
                    // All outputs remain zero, halt remains zero.
                end

                // -------------------------------------------------------------
                // SYSTEM
                //
                // ECALL, EBREAK, and all CSR instructions halt this core.
                // -------------------------------------------------------------
                OPC_SYSTEM: begin
                    halt = 1'b1;
                end

                default: begin
                    halt = 1'b1;
                end

            endcase
        end

        // Whenever halt is asserted, all other outputs must be zero.
        if (halt) begin
            reg_write = 1'b0;
            a_sel     = 1'b0;
            b_sel     = 1'b0;
            alu_op    = 4'b0000;
            mem_read  = 1'b0;
            mem_write = 1'b0;
            wb_sel    = 2'b00;
            is_branch = 1'b0;
            is_jal    = 1'b0;
            is_jalr   = 1'b0;
        end
    end

endmodule

`default_nettype wire
