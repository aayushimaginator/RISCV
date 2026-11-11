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

    integer fails = 0;

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
        // 0x7E makes the firmware stall; the next two bytes must overrun the latch
        send(8'h7E);
        repeat (64) @(posedge clk);
        send(8'h11);
        send(8'h22);
        repeat (BIT_CYCLES * 2) @(posedge clk);
        // firmware finishes its delay and shows raw reg: overrun|valid|last byte
        repeat (200000) @(posedge clk);
        if (led !== 16'h0322) begin
            $display("FAIL overrun: led=%h expected 0322", led); fails = fails + 1;
        end
        if (fails == 0) $display("SOC RX SIM PASS"); else $display("SOC RX SIM FAIL");
        $finish;
    end
    initial begin #50000000; $display("SOC RX SIM FAIL timeout"); $finish; end
endmodule
