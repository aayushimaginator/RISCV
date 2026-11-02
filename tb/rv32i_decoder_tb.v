`default_nettype none
`timescale 1ns/1ps

module rv32i_decoder_tb;

    reg  [31:0] instr;

    wire        reg_write;
    wire        a_sel;
    wire        b_sel;
    wire [3:0]  alu_op;
    wire        mem_read;
    wire        mem_write;
    wire [1:0]  wb_sel;
    wire        is_branch;
    wire        is_jal;
    wire        is_jalr;
    wire        halt;

    rv32i_decoder dut (
        .instr     (instr),
        .reg_write (reg_write),
        .a_sel     (a_sel),
        .b_sel     (b_sel),
        .alu_op    (alu_op),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .wb_sel    (wb_sel),
        .is_branch (is_branch),
        .is_jal    (is_jal),
        .is_jalr   (is_jalr),
        .halt      (halt)
    );

    // Pack all outputs for easy comparison.
    wire [14:0] got = {
        halt,
        is_jalr,
        is_jal,
        is_branch,
        wb_sel,
        mem_write,
        mem_read,
        alu_op,
        b_sel,
        a_sel,
        reg_write
    };

    integer errors;
    integer seed;

    integer op_i;
    integer f3_i;
    integer f7_i;
    integer n;

    reg [4:0] rs2;
    reg [4:0] rs1;
    reg [4:0] rd;

    reg [31:0] instr_val;
    reg [14:0] exp;

    // -------------------------------------------------------------------------
    // Independent behavioral reference model, written from the specification.
    // -------------------------------------------------------------------------
    function [14:0] ref_decoder;
        input [31:0] i;

        reg [6:0] opcode;
        reg [2:0] funct3;
        reg [6:0] funct7;

        reg rw;
        reg as;
        reg bs;
        reg mr;
        reg mw;
        reg br;
        reg jal;
        reg jalr;
        reg h;

        reg [3:0] aop;
        reg [1:0] wb;

        begin
            opcode = i[6:0];
            funct3 = i[14:12];
            funct7 = i[31:25];

            rw   = 1'b0;
            as   = 1'b0;
            bs   = 1'b0;
            mr   = 1'b0;
            mw   = 1'b0;
            br   = 1'b0;
            jal  = 1'b0;
            jalr = 1'b0;
            h    = 1'b0;

            aop = 4'b0000;
            wb  = 2'b00;

            if (i[1:0] != 2'b11) begin
                h = 1'b1;
            end
            else begin
                case (opcode)

                    7'b0110111: begin // LUI
                        rw = 1'b1;
                        wb = 2'b11;
                    end

                    7'b0010111: begin // AUIPC
                        rw  = 1'b1;
                        as  = 1'b1;
                        bs  = 1'b1;
                        aop = 4'b0000;
                        wb  = 2'b00;
                    end

                    7'b1101111: begin // JAL
                        rw  = 1'b1;
                        wb  = 2'b10;
                        jal = 1'b1;
                    end

                    7'b1100111: begin // JALR
                        if (funct3 == 3'b000) begin
                            rw   = 1'b1;
                            bs   = 1'b1;
                            aop  = 4'b0000;
                            wb   = 2'b10;
                            jalr = 1'b1;
                        end
                        else begin
                            h = 1'b1;
                        end
                    end

                    7'b1100011: begin // BRANCH
                        case (funct3)
                            3'b000,
                            3'b001,
                            3'b100,
                            3'b101,
                            3'b110,
                            3'b111: begin
                                br  = 1'b1;
                                aop = 4'b0000;
                            end

                            default: begin
                                h = 1'b1;
                            end
                        endcase
                    end

                    7'b0000011: begin // LOAD
                        case (funct3)
                            3'b000,
                            3'b001,
                            3'b010,
                            3'b100,
                            3'b101: begin
                                rw  = 1'b1;
                                bs  = 1'b1;
                                aop = 4'b0000;
                                mr  = 1'b1;
                                wb  = 2'b01;
                            end

                            default: begin
                                h = 1'b1;
                            end
                        endcase
                    end

                    7'b0100011: begin // STORE
                        case (funct3)
                            3'b000,
                            3'b001,
                            3'b010: begin
                                mw  = 1'b1;
                                bs  = 1'b1;
                                aop = 4'b0000;
                            end

                            default: begin
                                h = 1'b1;
                            end
                        endcase
                    end

                    7'b0010011: begin // OP-IMM
                        case (funct3)
                            3'b000,
                            3'b010,
                            3'b011,
                            3'b100,
                            3'b110,
                            3'b111: begin
                                rw  = 1'b1;
                                bs  = 1'b1;
                                wb  = 2'b00;
                                aop = {1'b0, funct3};
                            end

                            3'b001: begin // SLLI
                                if (funct7 == 7'b0000000) begin
                                    rw  = 1'b1;
                                    bs  = 1'b1;
                                    wb  = 2'b00;
                                    aop = 4'b0001;
                                end
                                else begin
                                    h = 1'b1;
                                end
                            end

                            3'b101: begin // SRLI / SRAI
                                if (funct7 == 7'b0000000) begin
                                    rw  = 1'b1;
                                    bs  = 1'b1;
                                    wb  = 2'b00;
                                    aop = 4'b0101;
                                end
                                else if (funct7 == 7'b0100000) begin
                                    rw  = 1'b1;
                                    bs  = 1'b1;
                                    wb  = 2'b00;
                                    aop = 4'b1101;
                                end
                                else begin
                                    h = 1'b1;
                                end
                            end

                            default: begin
                                h = 1'b1;
                            end
                        endcase
                    end

                    7'b0110011: begin // OP
                        if (funct7 == 7'b0000000) begin
                            rw  = 1'b1;
                            wb  = 2'b00;
                            aop = {1'b0, funct3};
                        end
                        else if (funct7 == 7'b0100000) begin
                            if (funct3 == 3'b000) begin
                                rw  = 1'b1;
                                wb  = 2'b00;
                                aop = 4'b1000;
                            end
                            else if (funct3 == 3'b101) begin
                                rw  = 1'b1;
                                wb  = 2'b00;
                                aop = 4'b1101;
                            end
                            else begin
                                h = 1'b1;
                            end
                        end
                        else begin
                            h = 1'b1;
                        end
                    end

                    7'b0001111: begin // FENCE / FENCE.I as NOP
                        // All outputs remain zero.
                    end

                    7'b1110011: begin // SYSTEM
                        h = 1'b1;
                    end

                    default: begin
                        h = 1'b1;
                    end

                endcase
            end

            if (h) begin
                rw   = 1'b0;
                as   = 1'b0;
                bs   = 1'b0;
                aop  = 4'b0000;
                mr   = 1'b0;
                mw   = 1'b0;
                wb   = 2'b00;
                br   = 1'b0;
                jal  = 1'b0;
                jalr = 1'b0;
            end

            ref_decoder = {h, jalr, jal, br, wb, mw, mr, aop, bs, as, rw};
        end
    endfunction

    // -------------------------------------------------------------------------
    // Check task
    // -------------------------------------------------------------------------
    task check;
        input [31:0] i;
        begin
            instr = i;
            #1;

            exp = ref_decoder(i);

            if (got !== exp) begin
                errors = errors + 1;

                if (errors <= 10) begin
                    $display("MISMATCH decoder instr=%h got=%b exp=%b",
                             i, got, exp);
                end
            end

            // Explicitly check that halt=1 implies all other outputs are zero.
            if (halt) begin
                if (reg_write || a_sel || b_sel ||
                    (alu_op != 4'b0000) ||
                    mem_read || mem_write ||
                    (wb_sel != 2'b00) ||
                    is_branch || is_jal || is_jalr) begin
                    errors = errors + 1;

                    if (errors <= 10) begin
                        $display("MISMATCH decoder halt not clean instr=%h", i);
                    end
                end
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Main test
    // -------------------------------------------------------------------------
    initial begin
        errors = 0;
        seed   = 32'h00dec0de;

        // Directed SYSTEM / illegal instructions.
        check(32'h00000073); // ECALL
        check(32'h00100073); // EBREAK
        check(32'h00000000); // illegal: instr[1:0] != 2'b11

        // Directed random FENCE / FENCE.I fields.
        for (n = 0; n < 100; n = n + 1) begin
            rs2 = $random(seed) & 32'h1F;
            rs1 = $random(seed) & 32'h1F;
            rd  = $random(seed) & 32'h1F;
            f3_i = $random(seed) & 32'h07;
            f7_i = $random(seed) & 32'h7F;

            instr_val = {
                f7_i[6:0],
                rs2,
                rs1,
                f3_i[2:0],
                rd,
                7'b0001111
            };

            check(instr_val);
        end

        // Exhaustive sweep:
        //   opcode 128 values
        //   funct3 8 values
        //   instr[31:25] 128 values
        // Other fields randomized.
        for (op_i = 0; op_i < 128; op_i = op_i + 1) begin
            for (f3_i = 0; f3_i < 8; f3_i = f3_i + 1) begin
                for (f7_i = 0; f7_i < 128; f7_i = f7_i + 1) begin
                    rs2 = $random(seed) & 32'h1F;
                    rs1 = $random(seed) & 32'h1F;
                    rd  = $random(seed) & 32'h1F;

                    instr_val = {
                        f7_i[6:0],
                        rs2,
                        rs1,
                        f3_i[2:0],
                        rd,
                        op_i[6:0]
                    };

                    check(instr_val);
                end
            end
        end

        if (errors == 0) begin
            $display("PASS");
        end
        else begin
            $display("FAIL");
        end

        $finish;
    end

endmodule

`default_nettype wire
