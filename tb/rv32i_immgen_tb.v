`default_nettype none
`timescale 1ns/1ps

module rv32i_immgen_tb;

    reg [31:0] instr;
    wire [31:0] imm;

    rv32i_immgen dut (.instr(instr), .imm(imm));

    integer errors;

    task check;
        input [31:0] i;
        input [31:0] exp;
        begin
            instr = i; #1;
            if (imm !== exp) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("FAIL immgen: instr=%h got=%h exp=%h", i, imm, exp);
            end
        end
    endtask

    initial begin
        errors = 0;

        // I-type (OP-IMM, opcode 0010011)
        // ADDI x1, x0, 5  -> imm = 5
        check(32'h00500093, 32'h0000_0005);
        // ADDI x1, x0, -1 -> imm = -1 (0xFFF)
        check(32'hFFF00093, 32'hFFFF_FFFF);

        // S-type (STORE, opcode 0100011)
        // SW x1, 8(x0) -> imm = 8
        check(32'h00102423, 32'h0000_0008);
        // SW x1, -4(x0) -> imm = -4 (0xFFC)
        check(32'hFE102E23, 32'hFFFF_FFFC);

        // B-type (BRANCH, opcode 1100011)
        // BEQ x0, x0, +8 -> imm = 8
        check(32'h00000463, 32'h0000_0008);
        // BEQ x0, x0, -8 -> imm = -8 (0xFF8)
        check(32'hFE000CE3, 32'hFFFF_FFF8);

        // U-type (LUI, opcode 0110111)
        // LUI x1, 0x12345 -> imm = 0x12345000
        check(32'h123450B7, 32'h1234_5000);

        // J-type (JAL, opcode 1101111)
        // JAL x1, +4 -> imm = 4
        check(32'h004000EF, 32'h0000_0004);
        // JAL x1, -4 -> imm = -4
        check(32'hFFDFF0EF, 32'hFFFF_FFFC);

        if (errors == 0) $display("PASS");
        else $display("FAIL");
        $finish;
    end

endmodule

`default_nettype wire
