`default_nettype none
`timescale 1ns/1ps

module rv32i_alu_tb;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------

    reg  [31:0] a;
    reg  [31:0] b;
    reg  [3:0]  op;
    wire [31:0] y;

    reg  [2:0]  funct3;
    wire        taken;

    rv32i_alu u_alu (
        .a  (a),
        .b  (b),
        .op (op),
        .y  (y)
    );

    rv32i_branch_cmp u_branch_cmp (
        .a       (a),
        .b       (b),
        .funct3  (funct3),
        .taken   (taken)
    );

    // -------------------------------------------------------------------------
    // Counters and helpers
    // -------------------------------------------------------------------------

    integer errors;
    integer seed;

    // -------------------------------------------------------------------------
    // Behavioral reference model: ALU
    // -------------------------------------------------------------------------

    function [31:0] ref_alu;
        input [31:0] fa;
        input [31:0] fb;
        input [3:0]  fop;

        reg signed [31:0] sa;
        reg signed [31:0] sb;
        reg [4:0]         sh;

        begin
            sa = fa;
            sb = fb;
            sh = fb[4:0];

            case (fop)
                4'b0000: begin
                    ref_alu = fa + fb;
                end

                4'b0001: begin
                    ref_alu = fa << sh;
                end

                4'b0010: begin
                    ref_alu = {31'b0, sa < sb};
                end

                4'b0011: begin
                    ref_alu = {31'b0, fa < fb};
                end

                4'b0100: begin
                    ref_alu = fa ^ fb;
                end

                4'b0101: begin
                    ref_alu = fa >> sh;
                end

                4'b0110: begin
                    ref_alu = fa | fb;
                end

                4'b0111: begin
                    ref_alu = fa & fb;
                end

                4'b1000: begin
                    ref_alu = fa - fb;
                end

                4'b1101: begin
                    ref_alu = sa >>> sh;
                end

                default: begin
                    ref_alu = 32'h0000_0000;
                end
            endcase
        end
    endfunction

    // -------------------------------------------------------------------------
    // Behavioral reference model: branch comparator
    // -------------------------------------------------------------------------

    function [0:0] ref_branch;
        input [31:0] fa;
        input [31:0] fb;
        input [2:0]  f3;

        reg signed [31:0] sa;
        reg signed [31:0] sb;

        begin
            sa = fa;
            sb = fb;

            case (f3)
                3'b000: begin
                    ref_branch = (fa == fb);
                end

                3'b001: begin
                    ref_branch = (fa != fb);
                end

                3'b010: begin
                    ref_branch = 1'b0;
                end

                3'b011: begin
                    ref_branch = 1'b0;
                end

                3'b100: begin
                    ref_branch = (sa < sb);
                end

                3'b101: begin
                    ref_branch = (sa >= sb);
                end

                3'b110: begin
                    ref_branch = (fa < fb);
                end

                3'b111: begin
                    ref_branch = (fa >= fb);
                end

                default: begin
                    ref_branch = 1'b0;
                end
            endcase
        end
    endfunction

    // -------------------------------------------------------------------------
    // Check tasks
    // -------------------------------------------------------------------------

    task check_alu;
        input [31:0] a_val;
        input [31:0] b_val;
        input [3:0]  op_val;

        reg [31:0] exp;

        begin
            a  = a_val;
            b  = b_val;
            op = op_val;

            #1;

            exp = ref_alu(a_val, b_val, op_val);

            if (y !== exp) begin
                errors = errors + 1;

                if (errors <= 10) begin
                    $display("MISMATCH ALU op=%b a=%h b=%h got=%h exp=%h",
                             op_val, a_val, b_val, y, exp);
                end
            end
        end
    endtask

    task check_branch;
        input [31:0] a_val;
        input [31:0] b_val;
        input [2:0]  f3_val;

        reg exp;

        begin
            a      = a_val;
            b      = b_val;
            funct3 = f3_val;

            #1;

            exp = ref_branch(a_val, b_val, f3_val);

            if (taken !== exp) begin
                errors = errors + 1;

                if (errors <= 10) begin
                    $display("MISMATCH BRANCH funct3=%b a=%h b=%h got=%b exp=%b",
                             f3_val, a_val, b_val, taken, exp);
                end
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Directed value tables
    // -------------------------------------------------------------------------

    reg [31:0] edge_a [0:4];
    reg [31:0] edge_b [0:7];

    integer i;
    integer j;
    integer op_i;
    integer f_i;
    integer n;

    // -------------------------------------------------------------------------
    // Main test
    // -------------------------------------------------------------------------

    initial begin
        errors = 0;
        seed   = 32'h00c0_ffee;

        // Directed a values:
        //   0
        //   1
        //  -1
        //   0x7FFFFFFF
        //   0x80000000
        edge_a[0] = 32'h0000_0000;
        edge_a[1] = 32'h0000_0001;
        edge_a[2] = 32'hFFFF_FFFF;
        edge_a[3] = 32'h7FFF_FFFF;
        edge_a[4] = 32'h8000_0000;

        // Directed b values:
        //   0, 1, 31 for explicit shift amounts
        //   32, 33 for b values with upper bits set
        //  -1
        //   0x7FFFFFFF
        //   0x80000000
        edge_b[0] = 32'h0000_0000;
        edge_b[1] = 32'h0000_0001;
        edge_b[2] = 32'h0000_001F;
        edge_b[3] = 32'h0000_0020;
        edge_b[4] = 32'h0000_0021;
        edge_b[5] = 32'hFFFF_FFFF;
        edge_b[6] = 32'h7FFF_FFFF;
        edge_b[7] = 32'h8000_0000;

        // ---------------------------------------------------------------------
        // Directed ALU tests
        // ---------------------------------------------------------------------
        for (op_i = 0; op_i < 16; op_i = op_i + 1) begin
            for (i = 0; i < 5; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    check_alu(edge_a[i], edge_b[j], op_i[3:0]);
                end
            end
        end

        // ---------------------------------------------------------------------
        // Directed branch comparator tests
        // ---------------------------------------------------------------------
        for (f_i = 0; f_i < 8; f_i = f_i + 1) begin
            for (i = 0; i < 5; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    check_branch(edge_a[i], edge_b[j], f_i[2:0]);
                end
            end
        end

        // ---------------------------------------------------------------------
        // Random ALU tests: 100000 vectors per 4-bit op code
        // ---------------------------------------------------------------------
        for (op_i = 0; op_i < 16; op_i = op_i + 1) begin
            for (n = 0; n < 100000; n = n + 1) begin
                a = $random(seed);
                b = $random(seed);

                check_alu(a, b, op_i[3:0]);
            end
        end

        // ---------------------------------------------------------------------
        // Random branch comparator tests: 100000 vectors per funct3
        // ---------------------------------------------------------------------
        for (f_i = 0; f_i < 8; f_i = f_i + 1) begin
            for (n = 0; n < 100000; n = n + 1) begin
                a = $random(seed);
                b = $random(seed);

                check_branch(a, b, f_i[2:0]);
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
