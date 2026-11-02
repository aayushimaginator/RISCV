`timescale 1ns/1ps
module rv32i_immgen_vec_tb;
    reg  [31:0] vec [0:65535];
    reg  [31:0] instr;
    wire [31:0] imm;
    integer n, errors;

    rv32i_immgen dut (.instr(instr), .imm(imm));

    initial begin
        $readmemh("tb/immgen_vectors.hex", vec);
        errors = 0;
        n = 0;
        while (n < 32768 && vec[2*n] !== 32'hxxxxxxxx) begin
            instr = vec[2*n]; #1;
            if (imm !== vec[2*n+1]) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("MISMATCH instr=%h got=%h want=%h", instr, imm, vec[2*n+1]);
            end
            n = n + 1;
        end
        if (n == 0)           $display("FAIL: no vectors read");
        else if (errors == 0) $display("PASS (%0d vectors)", n);
        else                  $display("FAIL (%0d of %0d)", errors, n);
        $finish;
    end
endmodule
