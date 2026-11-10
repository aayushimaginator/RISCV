`timescale 1ns/1ps

`ifndef HEXFILE
`define HEXFILE "build/selftest/selftest.hex"
`endif

module soc_selftest_tb;

    localparam CLK_PERIOD   = 10;
    localparam UART_DIV     = 16;
    localparam BIT_CYCLES   = UART_DIV * 2;
    localparam TIMEOUT_CYC  = 6_000_000;

    reg  clk = 1'b0;
    reg  rst_btn = 1'b1;

    wire [15:0] led;
    wire        uart_txd;

    soc_top_rv32i #(
        .RST_ACTIVE_HIGH (1),
        .UART_DIVISOR    (UART_DIV),
        .LED_W           (16),
        .MEM_FILE        (`HEXFILE)
    ) dut (
        .clk_100mhz (clk),
        .rst_btn    (rst_btn),
        .led        (led),
        .uart_txd   (uart_txd)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    reg        pass_seen;
    reg        fail_seen;
    reg [63:0] win;
    reg [7:0]  rx;
    integer    k;
    integer    nchars;

    initial begin
        pass_seen = 1'b0;
        fail_seen = 1'b0;
        win       = 64'd0;
        nchars    = 0;
        repeat (20) @(posedge clk);
        rst_btn = 1'b0;
    end

    initial begin
        wait (rst_btn === 1'b0);
        forever begin
            @(negedge uart_txd);
            repeat (BIT_CYCLES + BIT_CYCLES/2) @(posedge clk);
            for (k = 0; k < 8; k = k + 1) begin
                rx[k] = uart_txd;
                repeat (BIT_CYCLES) @(posedge clk);
            end
            nchars = nchars + 1;
            $write("%c", rx);
            win = {win[55:0], rx};
            if (win == 64'h414C4C2050415353) pass_seen = 1'b1;
            if (win[31:0] == 32'h4641494C)   fail_seen = 1'b1;
        end
    end

    initial begin
        repeat (TIMEOUT_CYC) begin
            @(posedge clk);
            if (pass_seen || fail_seen) begin
                repeat (BIT_CYCLES * 40) @(posedge clk);
                report;
            end
        end
        report;
    end

    task report;
        begin
            $display("");
            $display("chars=%0d led=%h", nchars, led);
            if (pass_seen && !fail_seen && led === 16'hAAAA)
                $display("SELFTEST SIM PASS");
            else if (fail_seen)
                $display("SELFTEST SIM FAIL");
            else
                $display("SELFTEST SIM TIMEOUT");
            $finish;
        end
    endtask

endmodule
