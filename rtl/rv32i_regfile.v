`default_nettype none

module rv32i_regfile (
    input  wire        clk,
    input  wire        we,
    input  wire [4:0]  raddr1,
    input  wire [4:0]  raddr2,
    input  wire [4:0]  waddr,
    input  wire [31:0] wdata,
    output wire [31:0] rdata1,
    output wire [31:0] rdata2
);

    // Request distributed RAM (LUTRAM) for the register file.
    // 32x32 = 1024 bits, which fits easily into a few dozen LUTs.
    (* ram_style = "distributed" *)
    reg [31:0] rf [0:31];

    // Asynchronous reads. x0 is hardwired to 0.
    assign rdata1 = (raddr1 == 5'd0) ? 32'h0000_0000 : rf[raddr1];
    assign rdata2 = (raddr2 == 5'd0) ? 32'h0000_0000 : rf[raddr2];

    // Synchronous writes. Writes to x0 are ignored.
    always @(posedge clk) begin
        if (we && (waddr != 5'd0)) begin
            rf[waddr] <= wdata;
        end
    end

endmodule

`default_nettype wire
