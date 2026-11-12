`timescale 1ns/1ps
`ifndef HEXFILE
`define HEXFILE "build/rxsoc/rxstub.hex"
`endif
// SoC-level RX test: types bytes into uart_rxd, checks the LED register the stub drives.
module soc_rx_tb;
    localparam UART_DIV   = 16;
    localparam BIT_CYCLES = UART_DIV * 2;   // 100 MHz TB clock, SoC runs at half rate

    reg clk = 0, rst_btn = 1, rxd = 1;
    wire [15:0] led;
    wire uart_txd;
    soc_top_rv32i #(.RST_ACTIVE_HIGH(1), .UART_DIVISOR(UART_DIV), .LED_W(16),
                    .MEM_FILE(`HEXFILE)) dut (
        .clk_100mhz(clk), .rst_btn(rst_btn), .led(led),
        .uart_rxd(rxd), .uart_txd(uart_txd));
    always #5 clk = ~clk;

    integer fails = 0, n, nlog = 0;
    reg [15:0] exp_b;
    reg [15:0] ledlog [0:63];
    always @(led) begin ledlog[nlog] = led; nlog = nlog + 1; end

    task send(input [7:0] b);
        integer i;
        begin
            rxd = 0; repeat (BIT_CYCLES) @(posedge clk);
            for (i = 0; i < 8; i = i + 1) begin rxd = b[i]; repeat (BIT_CYCLES) @(posedge clk); end
            rxd = 1; repeat (BIT_CYCLES) @(posedge clk);
        end
    endtask

    task expect_led(input [15:0] e, input [255:0] what);
        begin
            repeat (BIT_CYCLES * 4) @(posedge clk);
            if (led !== e) begin
                $display("FAIL %0s: led=%h expected %h", what, led, e);
                fails = fails + 1;
            end
        end
    endtask

    // after the firmware acked, the latch must be empty again
    task expect_cleared(input [255:0] what);
        begin
            if (dut.rx_valid !== 1'b0 || dut.rx_overrun !== 1'b0) begin
                $display("FAIL %0s: latch not cleared (valid=%b overrun=%b)",
                         what, dut.rx_valid, dut.rx_overrun);
                fails = fails + 1;
            end
        end
    endtask

    initial begin
        repeat (20) @(posedge clk); rst_btn = 0;
        repeat (2000) @(posedge clk);   // outlast the SoC reset hold (255 sys clks)
        send(8'h41); expect_led(16'h0041, "byte A"); expect_cleared("after A");
        send(8'h42); expect_led(16'h0042, "byte B"); expect_cleared("after B");
        send(8'hFF); expect_led(16'h00FF, "byte FF"); expect_cleared("after FF");
        // 0x7E makes the firmware stall while 20 more bytes arrive: the 16-byte FIFO
        // keeps the first 16, drops the last 4 and flags overrun.
        send(8'h7E);
        repeat (64) @(posedge clk);
        send(8'h11); send(8'h22);
        for (n = 0; n < 18; n = n + 1) send(8'h30 + n);
        repeat (BIT_CYCLES * 2) @(posedge clk);
        if (dut.rx_count !== 5'd16 || dut.rx_overrun !== 1'b1) begin
            $display("FAIL fifo state: count=%0d overrun=%b (want 16, 1)", dut.rx_count, dut.rx_overrun);
            fails = fails + 1;
        end
        repeat (200000) @(posedge clk);
        // log: ... 7E, raw 0311, then 16 drained bytes in arrival order, then nothing
        if (nlog < 18) begin $display("FAIL led log too short: %0d", nlog); fails = fails + 1; end
        if (ledlog[nlog-17] !== 16'h0311) begin $display("FAIL raw register %h, want 0311", ledlog[nlog-17]); fails = fails + 1; end
        for (n = 0; n < 16; n = n + 1) begin
            exp_b = (n == 0) ? 16'h0011 : (n == 1) ? 16'h0022 : (16'h0030 + n - 2);
            if (ledlog[nlog-16+n] !== exp_b) begin
                $display("FAIL drain[%0d]=%h want %h", n, ledlog[nlog-16+n], exp_b); fails = fails + 1;
            end
        end
        if (dut.rx_count !== 5'd0) begin $display("FAIL fifo not empty after drain"); fails = fails + 1; end
        if (fails == 0) $display("SOC RX SIM PASS"); else $display("SOC RX SIM FAIL");
        $finish;
    end
    initial begin #50000000; $display("SOC RX SIM FAIL timeout"); $finish; end
endmodule
