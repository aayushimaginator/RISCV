`timescale 1ns/1ps
`ifndef HEXFILE
`define HEXFILE "build/calc/calc.hex"
`endif
// Types angles into uart_rxd, captures what the firmware prints, checks the
// text and that the display alternates cos/sin with the right angle digits.
module soc_calc_tb;
    localparam UART_DIV   = 16;
    localparam BIT_CYCLES = UART_DIV * 2;   // TB clock is 2x the SoC clock

    reg clk = 0, rst_btn = 1, rxd = 1;
    wire [15:0] led;
    wire uart_txd;
    soc_top_rv32i #(.RST_ACTIVE_HIGH(1), .UART_DIVISOR(UART_DIV), .LED_W(16),
                    .MEM_FILE(`HEXFILE)) dut (
        .clk_100mhz(clk), .rst_btn(rst_btn), .led(led),
        .uart_rxd(rxd), .uart_txd(uart_txd));
    always #5 clk = ~clk;

    // ---- capture TX ----
    reg [7:0] cap [0:1023];
    integer ncap = 0, prompts = 0, k;
    reg [7:0] rb;
    initial begin
        wait (rst_btn === 1'b0);
        forever begin
            @(negedge uart_txd);
            repeat (BIT_CYCLES + BIT_CYCLES/2) @(posedge clk);
            for (k = 0; k < 8; k = k + 1) begin
                rb[k] = uart_txd; repeat (BIT_CYCLES) @(posedge clk);
            end
            cap[ncap] = rb; ncap = ncap + 1;
            if (rb == ">") prompts = prompts + 1;
            $write("%c", rb);
        end
    end

    // ---- display watch ----
    reg sawC = 0, sawS = 0;
    reg [11:0] shown_ang = 12'hFFF;
    always @(posedge clk) begin
        if (dut.seg_data_reg[31:28] == 4'hC) sawC <= 1;
        if (dut.seg_data_reg[31:28] == 4'h5) sawS <= 1;
        shown_ang <= dut.seg_data_reg[27:16];
    end

    task send(input [7:0] b);
        integer i;
        begin
            rxd = 0; repeat (BIT_CYCLES) @(posedge clk);
            for (i = 0; i < 8; i = i + 1) begin rxd = b[i]; repeat (BIT_CYCLES) @(posedge clk); end
            rxd = 1; repeat (BIT_CYCLES * 3) @(posedge clk);   // inter-byte gap
        end
    endtask

    task type3(input [7:0] a, input [7:0] b, input [7:0] c);
        begin send(a); send(b); send(c); send(8'h0D); end
    endtask

    integer fails = 0;
    task has(input [8*20-1:0] pat, input integer len);
        integer s, j; reg hit; reg [7:0] pc;
        begin
            hit = 0;
            for (s = 0; s + len <= ncap; s = s + 1) begin
                if (!hit) begin
                    hit = 1;
                    for (j = 0; j < len; j = j + 1) begin
                        pc = pat[8*(len-1-j) +: 8];
                        if (cap[s+j] !== pc) hit = 0;
                    end
                end
            end
            if (!hit) begin $display("\nFAIL missing text (len %0d): %0s", len, pat); fails = fails + 1; end
        end
    endtask

    initial begin
        repeat (2000) @(posedge clk); rst_btn = 0;
        wait (prompts == 1);
        send("0"); send("3"); send("0"); send(8'h0D);       // 030
        wait (prompts == 2);
        // let the display flip at least once (HOLD is short in the sim build)
        repeat (200000) @(posedge clk);
        if (!sawC || !sawS) begin $display("\nFAIL display did not show both cos and sin"); fails = fails + 1; end
        if (shown_ang !== 12'h030) begin $display("\nFAIL angle digits %h", shown_ang); fails = fails + 1; end
        send("1"); send("2"); send("0"); send(8'h0D);       // 120
        wait (prompts == 3);
        send("4"); send("5"); send(8'h08); repeat (2000) @(posedge clk); send("6"); send(8'h0D);   // 45, backspace, 6 -> 46
        wait (prompts == 4);
        repeat (2000) @(posedge clk);
        has("cos 030 = +0.866", 16);
        has("sin 030 = +0.500", 16);
        has("cos 120 = -0.500", 16);
        has("sin 120 = +0.866", 16);
        has("cos 046 = +0.695", 16);
        has("sin 046 = +0.719", 16);
        if (led !== 16'd46) begin $display("\nFAIL led=%0d expected 46", led); fails = fails + 1; end
        $display("");
        if (fails == 0) $display("SOC CALC SIM PASS"); else $display("SOC CALC SIM FAIL");
        $finish;
    end
    initial begin #400000000; $display("\nSOC CALC SIM FAIL timeout"); $finish; end
endmodule
