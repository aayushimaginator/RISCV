`default_nettype none

module uart_tx #(
    parameter DIVISOR = 868
) (
    input  wire       clk,
    input  wire       reset,
    input  wire       start,
    input  wire [7:0] data,
    output reg        busy,
    output reg        txd
);

    reg [31:0] cnt;
    reg [3:0]  phase;
    reg [7:0]  sh;

    initial begin
        busy  = 1'b0;
        txd   = 1'b1;
        cnt   = 32'h0000_0000;
        phase = 4'd0;
        sh    = 8'h00;
    end

    always @(posedge clk) begin
        if (reset) begin
            busy  <= 1'b0;
            txd   <= 1'b1;
            cnt   <= 32'h0000_0000;
            phase <= 4'd0;
            sh    <= 8'h00;
        end
        else begin
            if (!busy) begin
                txd <= 1'b1;

                if (start) begin
                    busy  <= 1'b1;
                    sh    <= data;
                    phase <= 4'd0;
                    cnt   <= DIVISOR - 1;
                    txd   <= 1'b0;
                end
            end
            else begin
                if (cnt == 32'h0000_0000) begin
                    cnt <= DIVISOR - 1;

                    if (phase == 4'd9) begin
                        busy <= 1'b0;
                        txd  <= 1'b1;
                    end
                    else begin
                        phase <= phase + 4'd1;

                        if (phase == 4'd0) begin
                            txd <= sh[0];
                        end
                        else if (phase == 4'd1) begin
                            txd <= sh[1];
                        end
                        else if (phase == 4'd2) begin
                            txd <= sh[2];
                        end
                        else if (phase == 4'd3) begin
                            txd <= sh[3];
                        end
                        else if (phase == 4'd4) begin
                            txd <= sh[4];
                        end
                        else if (phase == 4'd5) begin
                            txd <= sh[5];
                        end
                        else if (phase == 4'd6) begin
                            txd <= sh[6];
                        end
                        else if (phase == 4'd7) begin
                            txd <= sh[7];
                        end
                        else begin
                            txd <= 1'b1;
                        end
                    end
                end
                else begin
                    cnt <= cnt - 32'h0000_0001;
                end
            end
        end
    end

endmodule

`default_nettype wire
