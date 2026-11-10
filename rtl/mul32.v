`default_nettype none

module mul32 (
    input  wire        clk,
    input  wire        rst,
    input  wire        we_a,
    input  wire        we_b,
    input  wire [31:0] wdata,
    output wire [31:0] lo,
    output wire [31:0] hi,
    output wire        busy
);

    reg [31:0] a;
    reg [31:0] b;
    reg [31:0] p_ll;
    reg [31:0] p_lh;
    reg [31:0] p_hl;
    reg [31:0] p_hh;
    reg [63:0] prod;
    reg [1:0]  cnt;

    initial begin
        a    = 32'd0;
        b    = 32'd0;
        p_ll = 32'd0;
        p_lh = 32'd0;
        p_hl = 32'd0;
        p_hh = 32'd0;
        prod = 64'd0;
        cnt  = 2'd0;
    end

    always @(posedge clk) begin
        if (rst) begin
            a   <= 32'd0;
            b   <= 32'd0;
            cnt <= 2'd0;
        end
        else begin
            if (we_a) a <= wdata;
            if (we_b) b <= wdata;

            if (we_a || we_b)
                cnt <= 2'd2;
            else if (cnt != 2'd0)
                cnt <= cnt - 2'd1;
        end
    end

    always @(posedge clk) begin
        p_ll <= a[15:0]  * b[15:0];
        p_lh <= a[15:0]  * b[31:16];
        p_hl <= a[31:16] * b[15:0];
        p_hh <= a[31:16] * b[31:16];

        prod <= {32'd0, p_ll}
              + {16'd0, p_lh, 16'd0}
              + {16'd0, p_hl, 16'd0}
              + {p_hh, 32'd0};
    end

    assign lo   = prod[31:0];
    assign hi   = prod[63:32];
    assign busy = (cnt != 2'd0);

endmodule

`default_nettype wire
