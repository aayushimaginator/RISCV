`default_nettype none
`timescale 1ns/1ps

module rv32i_regfile_tb;

    reg         clk = 1'b0;
    reg         we;
    reg  [4:0]  raddr1;
    reg  [4:0]  raddr2;
    reg  [4:0]  waddr;
    reg  [31:0] wdata;

    wire [31:0] rdata1;
    wire [31:0] rdata2;

    rv32i_regfile dut (
        .clk    (clk),
        .we     (we),
        .raddr1 (raddr1),
        .raddr2 (raddr2),
        .waddr  (waddr),
        .wdata  (wdata),
        .rdata1 (rdata1),
        .rdata2 (rdata2)
    );

    always #5 clk = ~clk;

    integer errors;
    integer i;

    reg [31:0] exp1;
    reg [31:0] exp2;

    initial begin
        errors = 0;

        we     = 1'b0;
        raddr1 = 5'd0;
        raddr2 = 5'd0;
        waddr  = 5'd0;
        wdata  = 32'h0000_0000;

        // ---------------------------------------------------------------------
        // Write unique values into x1..x31.
        // Drive on negedge to avoid a race with the posedge write logic.
        // ---------------------------------------------------------------------
        for (i = 1; i < 32; i = i + 1) begin
            @(negedge clk);
            we    = 1'b1;
            waddr = i[4:0];
            wdata = 32'hA5A5_0000 | i;
        end

        // One extra negedge allows the final write to occur, then deassert we.
        @(negedge clk);
        we = 1'b0;

        // ---------------------------------------------------------------------
        // Read back through both ports.
        // ---------------------------------------------------------------------
        for (i = 1; i < 32; i = i + 1) begin
            raddr1 = i[4:0];
            raddr2 = 32 - i;

            #1;

            exp1 = 32'hA5A5_0000 | i;
            exp2 = 32'hA5A5_0000 | (32 - i);

            if (rdata1 !== exp1) begin
                errors = errors + 1;
                if (errors <= 10) begin
                    $display("FAIL regfile port1 x%0d: got %h exp %h",
                             i, rdata1, exp1);
                end
            end

            if (rdata2 !== exp2) begin
                errors = errors + 1;
                if (errors <= 10) begin
                    $display("FAIL regfile port2 x%0d: got %h exp %h",
                             32 - i, rdata2, exp2);
                end
            end
        end

        // ---------------------------------------------------------------------
        // x0 must always read as zero.
        // ---------------------------------------------------------------------
        raddr1 = 5'd0;
        raddr2 = 5'd0;

        #1;

        if (rdata1 !== 32'h0000_0000) begin
            errors = errors + 1;
            if (errors <= 10) begin
                $display("FAIL regfile x0 port1: got %h exp 00000000", rdata1);
            end
        end

        if (rdata2 !== 32'h0000_0000) begin
            errors = errors + 1;
            if (errors <= 10) begin
                $display("FAIL regfile x0 port2: got %h exp 00000000", rdata2);
            end
        end

        // ---------------------------------------------------------------------
        // Attempt to write x0. It must remain zero.
        // ---------------------------------------------------------------------
        @(negedge clk);
        we    = 1'b1;
        waddr = 5'd0;
        wdata = 32'hDEAD_BEEF;

        @(negedge clk);
        we = 1'b0;

        raddr1 = 5'd0;
        raddr2 = 5'd0;

        #1;

        if (rdata1 !== 32'h0000_0000) begin
            errors = errors + 1;
            if (errors <= 10) begin
                $display("FAIL regfile x0 was written: got %h", rdata1);
            end
        end

        if (rdata2 !== 32'h0000_0000) begin
            errors = errors + 1;
            if (errors <= 10) begin
                $display("FAIL regfile x0 was written: got %h", rdata2);
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
