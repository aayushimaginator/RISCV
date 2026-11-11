`timescale 1ns/1ps
module uart_rx_tb;
    localparam D = 16;
    reg clk = 0, reset = 1, rxd = 1;
    wire valid, ferr; wire [7:0] data;
    uart_rx #(.DIVISOR(D)) dut(.clk(clk), .reset(reset), .rxd(rxd),
                               .valid(valid), .frame_err(ferr), .data(data));
    always #5 clk = ~clk;

    integer got_n = 0, err_n = 0, fails = 0;
    reg [7:0] got [0:15];
    always @(posedge clk) begin
        if (valid) begin got[got_n] <= data; got_n <= got_n + 1; end
        if (ferr) err_n <= err_n + 1;
    end

    task send(input [7:0] b, input stop);
        integer i;
        begin
            rxd = 0; repeat (D) @(posedge clk);
            for (i = 0; i < 8; i = i + 1) begin
                rxd = b[i]; repeat (D) @(posedge clk);
            end
            rxd = stop; repeat (D) @(posedge clk);
            rxd = 1;
        end
    endtask

    task expect_byte(input integer idx, input [7:0] e);
        begin
            if (got[idx] !== e) begin
                $display("FAIL byte %0d: got %h expected %h", idx, got[idx], e);
                fails = fails + 1;
            end
        end
    endtask

    initial begin
        repeat (5) @(posedge clk); reset = 0;
        repeat (20) @(posedge clk);
        send(8'h55, 1);                 // alternating bits
        repeat (7) @(posedge clk);
        send(8'hA3, 1);
        send(8'h00, 1);                 // back to back, all zeros
        send(8'hFF, 1);
        // glitch: 3-clk low pulse must be ignored
        rxd = 0; repeat (3) @(posedge clk); rxd = 1;
        repeat (D * 3) @(posedge clk);
        send(8'h7E, 0);                 // bad stop bit -> frame error, no valid
        repeat (D * 2) @(posedge clk);
        send(8'h31, 1);                 // recovers afterwards
        repeat (D * 3) @(posedge clk);

        if (got_n !== 5) begin $display("FAIL count %0d != 5", got_n); fails = fails + 1; end
        if (err_n !== 1) begin $display("FAIL frame errors %0d != 1", err_n); fails = fails + 1; end
        expect_byte(0, 8'h55); expect_byte(1, 8'hA3); expect_byte(2, 8'h00);
        expect_byte(3, 8'hFF); expect_byte(4, 8'h31);
        if (fails == 0) $display("UART_RX UNIT PASS");
        else $display("UART_RX UNIT FAIL");
        $finish;
    end
    initial begin #2000000; $display("UART_RX UNIT FAIL timeout"); $finish; end
endmodule
