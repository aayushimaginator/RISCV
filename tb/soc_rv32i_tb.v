`timescale 1ns/1ps

module soc_tb;

    localparam CLK_PERIOD   = 10;
    localparam BIT_CYCLES   = 868;
    localparam UART_TIMEOUT = 2_000_000;
    localparam LED_TIMEOUT  = 5_000_000;

    reg  clk = 1'b0;
    reg  rst_btn = 1'b0;

    wire [15:0] led;
    wire        uart_txd;

    soc_top_rv32i #(
        .RST_ACTIVE_HIGH (1),
        .UART_DIVISOR    (BIT_CYCLES),
        .LED_W           (16),
        .MEM_FILE        ("firmware/firmware.hex")
    ) dut (
        .clk_100mhz (clk),
        .rst_btn    (rst_btn),
        .led        (led),
        .uart_txd   (uart_txd)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    reg fail;

    reg [7:0] rx_byte;
    reg       rx_ok;

    task uart_get_byte;
        integer t;
        integer j;
        begin
            rx_ok   = 1'b0;
            rx_byte = 8'h00;

            t = 0;
            while (uart_txd !== 1'b0 && t < UART_TIMEOUT) begin
                @(posedge clk);
                t = t + 1;
            end

            if (uart_txd !== 1'b0) begin
                rx_ok = 1'b0;
            end
            else begin
                repeat (BIT_CYCLES/2) @(posedge clk);

                if (uart_txd !== 1'b0) begin
                    rx_ok = 1'b0;
                end
                else begin
                    for (j = 0; j < 8; j = j + 1) begin
                        repeat (BIT_CYCLES) @(posedge clk);
                        rx_byte[j] = uart_txd;
                    end

                    repeat (BIT_CYCLES) @(posedge clk);

                    if (uart_txd === 1'b1) begin
                        rx_ok = 1'b1;
                    end
                    else begin
                        rx_ok = 1'b0;
                    end
                end
            end
        end
    endtask

    reg [7:0] exp [0:14];

    integer i;
    integer t;
    integer led_changes;
    reg [15:0] led_prev;

    initial begin
        exp[0]  = "H";
        exp[1]  = "e";
        exp[2]  = "l";
        exp[3]  = "l";
        exp[4]  = "o";
        exp[5]  = ",";
        exp[6]  = " ";
        exp[7]  = "R";
        exp[8]  = "V";
        exp[9]  = "3";
        exp[10] = "2";
        exp[11] = "I";
        exp[12] = "!";
        exp[13] = 8'd13;
        exp[14] = 8'd10;

        fail = 1'b0;

        rst_btn = 1'b1;
        repeat (32) @(posedge clk);
        rst_btn = 1'b0;

        for (i = 0; i < 15; i = i + 1) begin
            uart_get_byte;

            if (!rx_ok) begin
                $display("FAIL: UART receive error at byte %0d", i);
                fail = 1'b1;
                i = 15;
            end
            else if (rx_byte !== exp[i]) begin
                $display("FAIL: UART byte %0d got 0x%02x expected 0x%02x",
                         i, rx_byte, exp[i]);
                fail = 1'b1;
                i = 15;
            end
        end

        if (!fail) begin
            t = 0;

            while (led == 16'h0000 && t < LED_TIMEOUT) begin
                @(posedge clk);
                t = t + 1;
            end

            if (led == 16'h0000) begin
                $display("FAIL: LED never became non-zero");
                fail = 1'b1;
            end
            else begin
                led_prev    = led;
                led_changes   = 0;

                while (led_changes < 3 && t < LED_TIMEOUT) begin
                    @(posedge clk);
                    t = t + 1;

                    if (led !== led_prev) begin
                        led_changes = led_changes + 1;
                        led_prev    = led;
                    end
                end

                if (led_changes < 3) begin
                    $display("FAIL: LED changed only %0d times", led_changes);
                    fail = 1'b1;
                end
            end
        end

        if (fail) begin
            $display("FAIL");
        end
        else begin
            $display("PASS");
        end

        $finish;
    end

endmodule
