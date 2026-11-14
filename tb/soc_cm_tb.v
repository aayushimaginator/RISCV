`timescale 1ns/1ps
`ifndef HEXFILE
`define HEXFILE "build/coremark/coremark.hex"
`endif
`ifndef MAX_TB_CLKS
`define MAX_TB_CLKS 4000000
`endif
// CoreMark SoC sim. A 1-iteration run is shorter than EEMBC's 10 s minimum, so CoreMark
// itself prints "ERROR! Must execute for at least 10 secs" and "Errors detected"; that is
// expected here. The gate checks the CRCs instead: they must equal EEMBC's known values
// (the same values a native host build prints), proving the core executed CoreMark exactly.
module soc_cm_tb;
    localparam UART_DIV   = 16;
    localparam BIT_CYCLES = UART_DIV * 2;   // TB clock is 2x the SoC clock

    reg clk = 0, rst_btn = 1;
    wire [15:0] led;
    wire uart_txd;
    soc_top_rv32i #(.RST_ACTIVE_HIGH(1), .UART_DIVISOR(UART_DIV), .LED_W(16),
                    .MEM_FILE(`HEXFILE)) dut (
        .clk_100mhz(clk), .rst_btn(rst_btn), .led(led),
        .uart_rxd(1'b1), .uart_txd(uart_txd));
    always #5 clk = ~clk;

    reg [7:0] cap [0:8191];
    integer ncap = 0, k, fails = 0;
    reg [7:0] rb;
    reg finished = 0;
    reg [8*28-1:0] w28 = 0;
    reg [8*15-1:0] w15 = 0;
    integer drain = -1;
    integer clks = 0;
    reg [31:0] sim_cycles_start = 0;

    initial begin repeat (20) @(posedge clk); rst_btn = 0; end

    always @(posedge clk) begin
        clks <= clks + 1;
        if (clks % 50000000 == 0 && clks != 0) $display("[tb] %0d M TB clocks", clks / 1000000);
    end

    // UART capture
    initial begin
        wait (rst_btn === 1'b0);
        forever begin
            @(negedge uart_txd);
            repeat (BIT_CYCLES + BIT_CYCLES/2) @(posedge clk);
            for (k = 0; k < 8; k = k + 1) begin
                rb[k] = uart_txd; repeat (BIT_CYCLES) @(posedge clk);
            end
            cap[ncap] = rb; ncap = ncap + 1;
            $write("%c", rb);
            w28 = {w28[8*27-1:0], rb};
            w15 = {w15[8*14-1:0], rb};
            if (drain < 0 && (w15 == "Errors detected" || w28 == "Correct operation validated."))
                drain = 0;
        end
    end

    task has(input [8*24-1:0] pat);
        integer s, j; reg hit; reg [7:0] pc;
        begin
            hit = 0;
            for (s = 0; s + 23 <= ncap; s = s + 1) begin
                if (!hit) begin
                    hit = 1;
                    for (j = 0; j < 23; j = j + 1) begin
                        pc = pat[8*(22-j) +: 8];
                        if (cap[s+j] !== pc) hit = 0;
                    end
                end
            end
            if (!hit) begin $display("\nFAIL missing: %0s", pat[8*23-1:0]); fails = fails + 1; end
        end
    endtask

    // after the verdict line, let the remaining few characters drain, then judge
    always @(posedge clk) if (drain >= 0 && !finished) begin
        drain = drain + 1;
        if (drain > BIT_CYCLES * 10 * 30) begin
            finished = 1;
            $display("");
            $display("COREMARK SIM tb_clks=%0d (sys clks ~ %0d)", clks, clks / 2);
            has("seedcrc          : 0xe9f5");
            has("[0]crclist       : 0xe714");
            has("[0]crcmatrix     : 0x1fd7");
            has("[0]crcstate      : 0x8e3a");
            if (fails == 0) $display("COREMARK SIM PASS"); else $display("COREMARK SIM FAIL");
            $finish;
        end
    end

    always @(posedge clk) if (clks > `MAX_TB_CLKS && !finished) begin
        finished = 1;
        $display("\nCOREMARK SIM FAIL timeout after %0d TB clocks", clks);
        $finish;
    end
endmodule
