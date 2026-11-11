`default_nettype none

// 8N1 UART receiver. Samples each bit at its middle.
// valid pulses for one clk when a good frame (stop bit high) arrives;
// frame_err pulses for one clk when the stop bit is low. data holds the byte.
module uart_rx #(
    parameter DIVISOR = 651
) (
    input  wire       clk,
    input  wire       reset,
    input  wire       rxd,
    output reg        valid,
    output reg        frame_err,
    output reg  [7:0] data
);

    reg [1:0]  sync;
    reg [1:0]  state;      // 0 idle, 1 start check, 2 data, 3 stop
    reg [31:0] cnt;
    reg [2:0]  bitn;
    reg [7:0]  sh;

    initial begin
        sync = 2'b11; state = 2'd0; cnt = 32'd0; bitn = 3'd0;
        sh = 8'h00; valid = 1'b0; frame_err = 1'b0; data = 8'h00;
    end

    wire rx = sync[1];

    always @(posedge clk) begin
        sync      <= {sync[0], rxd};
        valid     <= 1'b0;
        frame_err <= 1'b0;

        if (reset) begin
            state <= 2'd0;
            cnt   <= 32'd0;
            bitn  <= 3'd0;
        end
        else begin
            case (state)
                2'd0: begin
                    if (!rx) begin
                        cnt   <= (DIVISOR / 2) - 1;
                        state <= 2'd1;
                    end
                end
                2'd1: begin
                    if (cnt == 32'd0) begin
                        if (!rx) begin
                            cnt   <= DIVISOR - 1;
                            bitn  <= 3'd0;
                            state <= 2'd2;
                        end
                        else state <= 2'd0;   // glitch, not a start bit
                    end
                    else cnt <= cnt - 32'd1;
                end
                2'd2: begin
                    if (cnt == 32'd0) begin
                        sh   <= {rx, sh[7:1]};
                        cnt  <= DIVISOR - 1;
                        bitn <= bitn + 3'd1;
                        if (bitn == 3'd7) state <= 2'd3;
                    end
                    else cnt <= cnt - 32'd1;
                end
                default: begin
                    if (cnt == 32'd0) begin
                        if (rx) begin
                            data  <= sh;
                            valid <= 1'b1;
                        end
                        else frame_err <= 1'b1;
                        state <= 2'd0;
                    end
                    else cnt <= cnt - 32'd1;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
