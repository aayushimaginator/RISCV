`default_nettype none

module ram_lutram #(
    parameter INIT_FILE = "firmware.hex"
) (
    input  wire        clk,
    input  wire        we,
    input  wire [3:0]  wstrb,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output wire [31:0] rdata,

    input  wire [31:0] r1_addr,
    output wire [31:0] r1_data
);

    localparam DEPTH_WORDS = 4096;

    (* ram_style = "distributed" *)
    reg [31:0] mem [0:DEPTH_WORDS-1];

    wire [11:0] a0 = addr[13:2];
    wire [11:0] a1 = r1_addr[13:2];

    integer i;

    initial begin
        for (i = 0; i < DEPTH_WORDS; i = i + 1) begin
            mem[i] = 32'h0000_0000;
        end
        $readmemh(INIT_FILE, mem);
    end

    assign rdata   = mem[a0];
    assign r1_data = mem[a1];

    always @(posedge clk) begin
        if (we) begin
            if (wstrb[0]) mem[a0][7:0]   <= wdata[7:0];
            if (wstrb[1]) mem[a0][15:8]  <= wdata[15:8];
            if (wstrb[2]) mem[a0][23:16] <= wdata[23:16];
            if (wstrb[3]) mem[a0][31:24] <= wdata[31:24];
        end
    end

endmodule

`default_nettype wire
