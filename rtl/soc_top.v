`default_nettype none

module soc_top #(
    parameter RST_ACTIVE_HIGH = 1,
    parameter UART_DIVISOR    = 868,
    parameter LED_W           = 16,
    parameter MEM_FILE        = "firmware.hex"
) (
    input  wire        clk_100mhz,
    input  wire        rst_btn,
    output wire [15:0] led,
    output wire        uart_txd
);

    wire rst_async = RST_ACTIVE_HIGH ? rst_btn : ~rst_btn;

    (* async_reg = "true" *)
    reg [2:0] rst_sync;

    initial begin
        rst_sync = 3'b000;
    end

    always @(posedge clk_100mhz) begin
        rst_sync <= {rst_sync[1:0], rst_async};
    end

    wire rst_synced = rst_sync[2];

    reg [7:0] rst_hold;

    initial begin
        rst_hold = 8'hFF;
    end

    always @(posedge clk_100mhz) begin
        if (rst_synced) begin
            rst_hold <= 8'hFF;
        end
        else if (rst_hold != 8'h00) begin
            rst_hold <= rst_hold - 8'h01;
        end
    end

    wire reset_active = rst_synced || (rst_hold != 8'h00);
    wire resetn       = !reset_active;

    wire        mem_valid;
    wire        mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    wire [31:0] mem_rdata;

    picorv32 #(
        .PROGADDR_RESET  (32'h0000_0000),
        .STACKADDR       (32'h0000_2000),
        .ENABLE_COUNTERS (0),
        .ENABLE_MUL      (0),
        .ENABLE_DIV      (0),
        .ENABLE_IRQ      (0),
        .COMPRESSED_ISA  (0)
    ) u_core (
        .clk       (clk_100mhz),
        .resetn    (resetn),

        .mem_valid (mem_valid),
        .mem_ready (mem_ready),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_wstrb (mem_wstrb),
        .mem_rdata (mem_rdata),

        .irq       (32'h0000_0000),
        .eoi       ()
    );

    reg mem_valid_d;

    initial begin
        mem_valid_d = 1'b0;
    end

    always @(posedge clk_100mhz) begin
        if (!resetn) begin
            mem_valid_d <= 1'b0;
        end
        else begin
            mem_valid_d <= mem_valid;
        end
    end

    wire new_req = mem_valid && !mem_valid_d;

    reg        req_valid;
    reg [31:0] req_addr;
    reg [31:0] req_wdata;
    reg [3:0]  req_wstrb;

    initial begin
        req_valid = 1'b0;
        req_addr  = 32'h0000_0000;
        req_wdata = 32'h0000_0000;
        req_wstrb = 4'h0;
    end

    always @(posedge clk_100mhz) begin
        if (!resetn) begin
            req_valid <= 1'b0;
            req_addr  <= 32'h0000_0000;
            req_wdata <= 32'h0000_0000;
            req_wstrb <= 4'h0;
        end
        else begin
            req_valid <= new_req;

            if (new_req) begin
                req_addr  <= mem_addr;
                req_wdata <= mem_wdata;
                req_wstrb <= mem_wstrb;
            end
        end
    end

    assign mem_ready = req_valid;

    wire req_write = (req_wstrb != 4'h0);

    wire req_ram = (req_addr[31:28] == 4'h0) &&
                   (req_addr[31:13] == 19'h00000);

    wire req_io  = (req_addr[31:28] == 4'h1);

    wire req_led         = req_io && (req_addr[11:0] == 12'h000);
    wire req_uart_tx     = req_io && (req_addr[11:0] == 12'h004);
    wire req_uart_status = req_io && (req_addr[11:0] == 12'h008);

    wire        ram_we = req_valid && req_ram && req_write;
    wire [31:0] ram_rdata;

    ram_lutram #(
        .INIT_FILE (MEM_FILE)
    ) u_ram (
        .clk     (clk_100mhz),
        .we      (ram_we),
        .wstrb   (req_wstrb),
        .addr    (req_addr),
        .wdata   (req_wdata),
        .rdata   (ram_rdata),

        .r1_addr (32'h0000_0000),
        .r1_data ()
    );

    reg [31:0] led_reg;

    initial begin
        led_reg = 32'h0000_0000;
    end

    wire led_we = req_valid && req_led && req_write;

    always @(posedge clk_100mhz) begin
        if (reset_active) begin
            led_reg <= 32'h0000_0000;
        end
        else if (led_we) begin
            if (req_wstrb[0]) led_reg[7:0]   <= req_wdata[7:0];
            if (req_wstrb[1]) led_reg[15:8]  <= req_wdata[15:8];
            if (req_wstrb[2]) led_reg[23:16] <= req_wdata[23:16];
            if (req_wstrb[3]) led_reg[31:24] <= req_wdata[31:24];
        end
    end

    generate
        if (LED_W < 16) begin : gen_led_small
            assign led = {{(16-LED_W){1'b0}}, led_reg[LED_W-1:0]};
        end
        else begin : gen_led_16
            assign led = led_reg[15:0];
        end
    endgenerate

    wire uart_busy;
    wire uart_start = req_valid && req_uart_tx && req_write;

    uart_tx #(
        .DIVISOR (UART_DIVISOR)
    ) u_uart_tx (
        .clk   (clk_100mhz),
        .reset (reset_active),
        .start (uart_start),
        .data  (req_wdata[7:0]),
        .busy  (uart_busy),
        .txd   (uart_txd)
    );

    reg [31:0] mem_rdata_i;

    always @* begin
        mem_rdata_i = 32'h0000_0000;

        if (req_valid) begin
            if (req_ram) begin
                mem_rdata_i = ram_rdata;
            end
            else if (req_io) begin
                case (req_addr[11:0])
                    12'h000: begin
                        mem_rdata_i = led_reg;
                    end

                    12'h008: begin
                        mem_rdata_i = {31'b0, uart_busy};
                    end

                    default: begin
                        mem_rdata_i = 32'h0000_0000;
                    end
                endcase
            end
        end
    end

    assign mem_rdata = mem_rdata_i;

endmodule

`default_nettype wire
