`timescale 1ns/1ps

`ifndef HEXFILE
`define HEXFILE "build/seg7/segtest.hex"
`endif

module soc_seg_tb;

    localparam [31:0] EXPECT = 32'hCBF43926;

    reg  clk = 1'b0;
    reg  rst_btn = 1'b1;

    wire [15:0] led;
    wire        uart_txd;
    wire [3:0]  d0_an;
    wire [7:0]  d0_seg;
    wire [3:0]  d1_an;
    wire [7:0]  d1_seg;

    soc_top_rv32i #(
        .RST_ACTIVE_HIGH (1),
        .UART_DIVISOR    (16),
        .LED_W           (16),
        .MEM_FILE        (`HEXFILE)
    ) dut (
        .clk_100mhz (clk),
        .rst_btn    (rst_btn),
        .led        (led),
        .uart_txd   (uart_txd),
        .d0_an      (d0_an),
        .d0_seg     (d0_seg),
        .d1_an      (d1_an),
        .d1_seg     (d1_seg)
    );

    always #5 clk = ~clk;

    reg [4:0] got   [0:7];
    reg       got_dp[0:7];
    integer   errors;
    integer   g;
    integer   n;

    function [4:0] dec;
        input [6:0] s;
        begin
            case (~s)
                7'h3F: dec = {1'b1, 4'h0};
                7'h06: dec = {1'b1, 4'h1};
                7'h5B: dec = {1'b1, 4'h2};
                7'h4F: dec = {1'b1, 4'h3};
                7'h66: dec = {1'b1, 4'h4};
                7'h6D: dec = {1'b1, 4'h5};
                7'h7D: dec = {1'b1, 4'h6};
                7'h07: dec = {1'b1, 4'h7};
                7'h7F: dec = {1'b1, 4'h8};
                7'h6F: dec = {1'b1, 4'h9};
                7'h77: dec = {1'b1, 4'hA};
                7'h7C: dec = {1'b1, 4'hB};
                7'h39: dec = {1'b1, 4'hC};
                7'h5E: dec = {1'b1, 4'hD};
                7'h79: dec = {1'b1, 4'hE};
                7'h71: dec = {1'b1, 4'hF};
                default: dec = 5'b00000;
            endcase
        end
    endfunction

    function integer an_idx;
        input [3:0] an;
        begin
            case (an)
                4'b1110: an_idx = 0;
                4'b1101: an_idx = 1;
                4'b1011: an_idx = 2;
                4'b0111: an_idx = 3;
                default: an_idx = -1;
            endcase
        end
    endfunction

    integer a0;
    integer a1;

    always @(posedge dut.clk_sys) begin
        #1;
        a0 = an_idx(d0_an);
        a1 = an_idx(d1_an);

        if (d0_an != 4'b1111 && a0 < 0) begin
            errors = errors + 1;
            $display("FAIL d0_an has several digits on: %b", d0_an);
        end
        if (d1_an != 4'b1111 && a1 < 0) begin
            errors = errors + 1;
            $display("FAIL d1_an has several digits on: %b", d1_an);
        end

        if (a0 >= 0) begin
            got[a0]    = dec(d0_seg[6:0]);
            got_dp[a0] = ~d0_seg[7];
        end
        if (a1 >= 0) begin
            got[4 + a1]    = dec(d1_seg[6:0]);
            got_dp[4 + a1] = ~d1_seg[7];
        end
    end

    initial begin
        errors = 0;
        for (n = 0; n < 8; n = n + 1) begin
            got[n]    = 5'b00000;
            got_dp[n] = 1'b0;
        end

        repeat (20) @(posedge clk);
        rst_btn = 1'b0;

        repeat (700000) @(posedge dut.clk_sys);

        for (g = 0; g < 8; g = g + 1) begin
            if (got[7-g] !== {1'b1, EXPECT[4*g +: 4]}) begin
                errors = errors + 1;
                $display("FAIL digit %0d got valid=%b nibble=%h expected %h",
                         g, got[7-g][4], got[7-g][3:0], EXPECT[4*g +: 4]);
            end
            if (got_dp[7-g] !== (g == 4)) begin
                errors = errors + 1;
                $display("FAIL dp digit %0d got %b", g, got_dp[7-g]);
            end
        end

        if (led !== 16'hAAAA) begin
            errors = errors + 1;
            $display("FAIL led=%h expected aaaa", led);
        end

        if (errors == 0)
            $display("SEG7 SOC PASS");
        else
            $display("SEG7 SOC FAIL errors=%0d", errors);
        $finish;
    end

endmodule
