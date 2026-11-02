`timescale 1ns/1ps
module rv32i_regfile_tb;
    reg         clk;
    reg         we;
    reg  [4:0]  raddr1, raddr2, waddr;
    reg  [31:0] wdata;
    wire [31:0] rdata1, rdata2;
    integer     i, errors;

    rv32i_regfile dut (.clk(clk), .we(we), .raddr1(raddr1), .raddr2(raddr2),
                       .waddr(waddr), .wdata(wdata), .rdata1(rdata1), .rdata2(rdata2));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    function [31:0] pat;
        input [31:0] n;
        begin
            pat = 32'hC0DE0000 + n * 32'h00010101;
        end
    endfunction

    // Inputs change on negedge, the DUT samples on posedge: no race.
    task write_reg;
        input [4:0]  a;
        input [31:0] d;
        begin
            @(negedge clk);
            we = 1'b1; waddr = a; wdata = d;
            @(negedge clk);
            we = 1'b0;
        end
    endtask

    task check_read;
        input [4:0]  a;
        input [31:0] want;
        begin
            raddr1 = a; raddr2 = a; #1;
            if (rdata1 !== want || rdata2 !== want) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("FAIL x%0d: port1=%h port2=%h want=%h", a, rdata1, rdata2, want);
            end
        end
    endtask

    initial begin
        errors = 0; we = 0; waddr = 0; wdata = 0; raddr1 = 0; raddr2 = 0;

        for (i = 1; i < 32; i = i + 1) write_reg(i[4:0], pat(i));
        for (i = 1; i < 32; i = i + 1) check_read(i[4:0], pat(i));

        raddr1 = 5'd3; raddr2 = 5'd17; #1;
        if (rdata1 !== pat(3) || rdata2 !== pat(17)) begin
            errors = errors + 1;
            $display("FAIL: read ports not independent");
        end

        write_reg(5'd0, 32'hDEADBEEF);
        check_read(5'd0, 32'h0);

        @(negedge clk); we = 1'b0; waddr = 5'd5; wdata = 32'hFFFFFFFF;
        @(negedge clk);
        check_read(5'd5, pat(5));

        write_reg(5'd5, 32'h12345678);
        check_read(5'd5, 32'h12345678);
        check_read(5'd4, pat(4));
        check_read(5'd6, pat(6));

        @(negedge clk);
        we = 1'b1; waddr = 5'd9; wdata = 32'hCAFEF00D; raddr1 = 5'd9; #1;
        if (rdata1 !== pat(9)) begin
            errors = errors + 1;
            $display("FAIL: old value not visible before the clock edge");
        end
        @(negedge clk);
        we = 1'b0; raddr1 = 5'd9; #1;
        if (rdata1 !== 32'hCAFEF00D) begin
            errors = errors + 1;
            $display("FAIL: write did not land");
        end

        if (errors == 0) $display("PASS");
        else             $display("FAIL (%0d errors)", errors);
        $finish;
    end
endmodule
