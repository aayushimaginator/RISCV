`timescale 1ns/1ps
module rv32i_decoder_vec_tb;
    reg  [31:0] vec [0:524287];
    reg  [31:0] instr;
    wire        reg_write, a_sel, b_sel, mem_read, mem_write, is_branch, is_jal, is_jalr, halt;
    wire [1:0]  wb_sel;
    wire [3:0]  alu_op;
    reg  [14:0] expv;
    integer     n, errors;

    rv32i_decoder dut (
        .instr(instr), .reg_write(reg_write), .a_sel(a_sel), .b_sel(b_sel),
        .alu_op(alu_op), .mem_read(mem_read), .mem_write(mem_write), .wb_sel(wb_sel),
        .is_branch(is_branch), .is_jal(is_jal), .is_jalr(is_jalr), .halt(halt));

    wire [14:0] got = {halt, is_jalr, is_jal, is_branch, wb_sel, mem_write, mem_read,
                       alu_op, b_sel, a_sel, reg_write};

    initial begin
        $readmemh("tb/decoder_vectors.hex", vec);
        errors = 0;
        n = 0;
        while (n < 262144 && vec[2*n] !== 32'hxxxxxxxx) begin
            instr = vec[2*n];
            expv  = vec[2*n+1];
            #1;
            if (got !== expv) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("MISMATCH instr=%h got=%b exp=%b", instr, got, expv);
            end
            n = n + 1;
        end
        if (n == 0)           $display("FAIL: no vectors read");
        else if (errors == 0) $display("PASS (%0d vectors)", n);
        else                  $display("FAIL (%0d of %0d)", errors, n);
        $finish;
    end
endmodule
