`timescale 1ns/1ps

module mul32_tb;

    reg         clk = 1'b0;
    reg         rst = 1'b1;
    reg         we_a = 1'b0;
    reg         we_b = 1'b0;
    reg  [31:0] wdata = 32'd0;
    wire [31:0] lo;
    wire [31:0] hi;
    wire        busy;

    mul32 dut (
        .clk   (clk),
        .rst   (rst),
        .we_a  (we_a),
        .we_b  (we_b),
        .wdata (wdata),
        .lo    (lo),
        .hi    (hi),
        .busy  (busy)
    );

    always #5 clk = ~clk;

    integer    errors;
    integer    i;
    integer    ncheck;
    reg [63:0] expv;

    task do_mul;
        input [31:0] ta;
        input [31:0] tb;
        begin
            expv = {32'd0, ta} * {32'd0, tb};

            @(negedge clk);
            we_a  = 1'b1;
            wdata = ta;
            @(negedge clk);
            we_a  = 1'b0;
            we_b  = 1'b1;
            wdata = tb;
            @(negedge clk);
            we_b  = 1'b0;
            wdata = 32'd0;

            if (busy !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL busy not set one cycle after write (a=%h b=%h)", ta, tb);
            end

            @(negedge clk);
            if (busy !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL busy dropped early (a=%h b=%h)", ta, tb);
            end

            @(negedge clk);
            if (busy !== 1'b0) begin
                errors = errors + 1;
                $display("FAIL busy still set after 3 cycles (a=%h b=%h)", ta, tb);
            end

            if ({hi, lo} !== expv) begin
                errors = errors + 1;
                $display("FAIL %h * %h = %h_%h expected %h_%h",
                         ta, tb, hi, lo, expv[63:32], expv[31:0]);
            end

            ncheck = ncheck + 1;
        end
    endtask

    initial begin
        errors = 0;
        ncheck = 0;

        repeat (4) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);

        do_mul(32'h00000000, 32'h00000000);
        do_mul(32'h00000001, 32'h00000001);
        do_mul(32'hFFFFFFFF, 32'hFFFFFFFF);
        do_mul(32'h80000000, 32'h80000000);
        do_mul(32'h80000000, 32'h00000002);
        do_mul(32'hFFFFFFFF, 32'h00000001);
        do_mul(32'h0000FFFF, 32'h0000FFFF);
        do_mul(32'hFFFF0000, 32'hFFFF0000);
        do_mul(32'h12345678, 32'h9ABCDEF0);
        do_mul(32'hDEADBEEF, 32'hCAFEBABE);

        for (i = 0; i < 3000; i = i + 1) begin
            do_mul($random, $random);
        end

        if (errors == 0)
            $display("MUL32 TB PASS (%0d products)", ncheck);
        else
            $display("MUL32 TB FAIL errors=%0d", errors);
        $finish;
    end

    initial begin
        #50000000;
        $display("MUL32 TB FAIL timeout");
        $finish;
    end

endmodule
