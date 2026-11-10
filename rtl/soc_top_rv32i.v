`default_nettype none

// -----------------------------------------------------------------------------
// soc_top_rv32i
//
// New SoC top-level replacing picorv32 and the bus adapter with the
// single-cycle rv32i_core.
//
// Same ports, parameters, and XDC constraints as soc_top.v.
// -----------------------------------------------------------------------------

module soc_top_rv32i #(
    parameter RST_ACTIVE_HIGH = 1,
    parameter UART_DIVISOR    = 651,
    parameter LED_W           = 16,
    parameter MEM_FILE        = "firmware.hex"
) (
    input  wire        clk_100mhz,
    input  wire        rst_btn,
    output wire [15:0] led,
    output wire        uart_txd,
    output wire [3:0]  d0_an,
    output wire [7:0]  d0_seg,
    output wire [3:0]  d1_an,
    output wire [7:0]  d1_seg
);

    // -------------------------------------------------------------------------
    // Reset synchronization and hold
    // -------------------------------------------------------------------------

    // 100 MHz pin -> 75 MHz system clock (MMCM in synthesis, /2 toggle in sim)
    wire clk_sys, clk_locked;
`ifdef SYNTHESIS
    wire clk_fb, clk_mmcm;
    MMCME2_BASE #(
        .CLKIN1_PERIOD(10.0), .DIVCLK_DIVIDE(1),
        .CLKFBOUT_MULT_F(7.5), .CLKOUT0_DIVIDE_F(10.0)
    ) u_mmcm (
        .CLKIN1(clk_100mhz), .CLKFBIN(clk_fb), .CLKFBOUT(clk_fb),
        .CLKOUT0(clk_mmcm), .LOCKED(clk_locked), .PWRDWN(1'b0), .RST(1'b0)
    );
    BUFG u_bufg (.I(clk_mmcm), .O(clk_sys));
`else
    reg clk_div = 1'b0;
    always @(posedge clk_100mhz) clk_div <= ~clk_div;
    assign clk_sys    = clk_div;
    assign clk_locked = 1'b1;
`endif

    wire rst_async = (RST_ACTIVE_HIGH ? rst_btn : ~rst_btn) | ~clk_locked;

    (* async_reg = "true" *)
    reg [2:0] rst_sync;

    initial begin
        rst_sync = 3'b000;
    end

    always @(posedge clk_sys) begin
        rst_sync <= {rst_sync[1:0], rst_async};
    end

    wire rst_synced = rst_sync[2];

    reg [7:0] rst_hold;

    initial begin
        rst_hold = 8'hFF;
    end

    always @(posedge clk_sys) begin
        if (rst_synced) begin
            rst_hold <= 8'hFF;
        end
        else if (rst_hold != 8'h00) begin
            rst_hold <= rst_hold - 8'h01;
        end
    end

    wire reset_active = rst_synced || (rst_hold != 8'h00);
    wire resetn       = !reset_active;

    // -------------------------------------------------------------------------
    // Core signals
    // -------------------------------------------------------------------------

    wire [31:0] imem_addr;
    wire [31:0] imem_rdata;

    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [3:0]  dmem_wstrb;
    wire        dmem_re;
    wire [31:0] dmem_rdata;

    wire        halted;

    // -------------------------------------------------------------------------
    // Core instantiation
    // -------------------------------------------------------------------------

    rv32i_core #(
        .RESET_PC (32'h0000_0000)
    ) u_core (
        .clk        (clk_sys),
        .resetn     (resetn),

        .imem_addr  (imem_addr),
        .imem_rdata (imem_rdata),

        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_wstrb (dmem_wstrb),
        .dmem_re    (dmem_re),
        .dmem_rdata (dmem_rdata),

        .halted     (halted)
    );

    // -------------------------------------------------------------------------
    // Memory region decode
    // -------------------------------------------------------------------------

    // RAM region: byte addresses 0x0000 to 0x1FFF
    // Word address bits [31:13] must be 0.
    wire ram_region = (dmem_addr[31:13] == 19'h00000);

    // IO region: high nibble is 0x1
    wire io_region  = (dmem_addr[31:28] == 4'h1);

    // IO register decode on lower 12 bits
    wire io_led         = io_region && (dmem_addr[11:0] == 12'h000);
    wire io_uart_tx     = io_region && (dmem_addr[11:0] == 12'h004);
    wire io_uart_status = io_region && (dmem_addr[11:0] == 12'h008);
    wire io_seg_data    = io_region && (dmem_addr[11:0] == 12'h00C);
    wire io_seg_dp      = io_region && (dmem_addr[11:0] == 12'h010);

    // -------------------------------------------------------------------------
    // RAM write control
    // -------------------------------------------------------------------------

    wire [3:0] ram_wstrb = ram_region ? dmem_wstrb : 4'b0000;
    wire       ram_we    = |ram_wstrb;

    // -------------------------------------------------------------------------
    // RAM instantiation
    // -------------------------------------------------------------------------

    wire [31:0] ram_rdata;

    ram_lutram #(
        .INIT_FILE (MEM_FILE)
    ) u_ram (
        .clk     (clk_sys),
        .we      (ram_we),
        .wstrb   (ram_wstrb),
        .addr    (dmem_addr),
        .wdata   (dmem_wdata),
        .rdata   (ram_rdata),

        .r1_addr (imem_addr),
        .r1_data (imem_rdata)
    );

    // -------------------------------------------------------------------------
    // LED register
    // -------------------------------------------------------------------------

    reg [31:0] led_reg;

    initial begin
        led_reg = 32'h0000_0000;
    end

    wire led_we = io_led && (|dmem_wstrb);

    always @(posedge clk_sys) begin
        if (reset_active) begin
            led_reg <= 32'h0000_0000;
        end
        else if (led_we) begin
            if (dmem_wstrb[0]) led_reg[7:0]   <= dmem_wdata[7:0];
            if (dmem_wstrb[1]) led_reg[15:8]  <= dmem_wdata[15:8];
            if (dmem_wstrb[2]) led_reg[23:16] <= dmem_wdata[23:16];
            if (dmem_wstrb[3]) led_reg[31:24] <= dmem_wdata[31:24];
        end
    end

    // LED output mapping
    generate
        if (LED_W < 16) begin : gen_led_small
            assign led = {{(16-LED_W){1'b0}}, led_reg[LED_W-1:0]};
        end
        else begin : gen_led_16
            assign led = led_reg[15:0];
        end
    endgenerate

    // -------------------------------------------------------------------------
    // 7-segment registers
    // -------------------------------------------------------------------------

    reg [31:0] seg_data_reg;
    reg [7:0]  seg_dp_reg;

    initial begin
        seg_data_reg = 32'h0000_0000;
        seg_dp_reg   = 8'h00;
    end

    wire seg_data_we = io_seg_data && (|dmem_wstrb);
    wire seg_dp_we   = io_seg_dp && dmem_wstrb[0];

    always @(posedge clk_sys) begin
        if (reset_active) begin
            seg_data_reg <= 32'h0000_0000;
            seg_dp_reg   <= 8'h00;
        end
        else begin
            if (seg_data_we) begin
                if (dmem_wstrb[0]) seg_data_reg[7:0]   <= dmem_wdata[7:0];
                if (dmem_wstrb[1]) seg_data_reg[15:8]  <= dmem_wdata[15:8];
                if (dmem_wstrb[2]) seg_data_reg[23:16] <= dmem_wdata[23:16];
                if (dmem_wstrb[3]) seg_data_reg[31:24] <= dmem_wdata[31:24];
            end

            if (seg_dp_we) begin
                seg_dp_reg <= dmem_wdata[7:0];
            end
        end
    end

    // -------------------------------------------------------------------------
    // UART transmitter
    // -------------------------------------------------------------------------

    wire uart_busy;
    wire uart_start = io_uart_tx && dmem_wstrb[0];

    uart_tx #(
        .DIVISOR (UART_DIVISOR)
    ) u_uart_tx (
        .clk   (clk_sys),
        .reset (reset_active),
        .start (uart_start),
        .data  (dmem_wdata[7:0]),
        .busy  (uart_busy),
        .txd   (uart_txd)
    );

    // -------------------------------------------------------------------------
    // 7-segment driver
    // -------------------------------------------------------------------------

    seg7_driver u_seg7 (
        .clk     (clk_sys),
        .rst     (reset_active),
        .data    (seg_data_reg),
        .dp      (seg_dp_reg),
        .d0_an   (d0_an),
        .d0_seg  (d0_seg),
        .d1_an   (d1_an),
        .d1_seg  (d1_seg)
    );

    // -------------------------------------------------------------------------
    // Data memory read mux
    // -------------------------------------------------------------------------

    reg [31:0] dmem_rdata_i;

    always @* begin
        dmem_rdata_i = 32'h0000_0000;

        if (ram_region) begin
            dmem_rdata_i = ram_rdata;
        end
        else if (io_led) begin
            dmem_rdata_i = led_reg;
        end
        else if (io_uart_status) begin
            dmem_rdata_i = {31'b0, uart_busy};
        end
        else if (io_seg_data) begin
            dmem_rdata_i = seg_data_reg;
        end
        else if (io_seg_dp) begin
            dmem_rdata_i = {24'h000000, seg_dp_reg};
        end
        else begin
            dmem_rdata_i = 32'h0000_0000;
        end
    end

    assign dmem_rdata = dmem_rdata_i;

endmodule

`default_nettype wire
