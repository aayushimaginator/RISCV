`default_nettype none

// -----------------------------------------------------------------------------
// rv32i_lsu
//
// RV32I load/store unit data-path logic.
//
// Purely combinational.
//
// Little-endian byte lanes:
//   lane 0 = bits [7:0]
//   lane 1 = bits [15:8]
//   lane 2 = bits [23:16]
//   lane 3 = bits [31:24]
//
// Misaligned accesses are undefined:
//   - LH / LHU ignore addr_lo[0]
//   - LW ignores addr_lo[1:0]
// -----------------------------------------------------------------------------

module rv32i_lsu (
    // Load path
    input  wire [31:0] rdata_word,
    input  wire [1:0]  addr_lo,
    input  wire [2:0]  funct3,
    output reg  [31:0] load_data,

    // Store path
    input  wire [31:0] store_data,
    input  wire        mem_write,
    output reg  [31:0] wdata_out,
    output reg  [3:0]  wstrb
);

    reg [7:0]  byte_lane;
    reg [15:0] half_word;

    // -------------------------------------------------------------------------
    // Load path
    // -------------------------------------------------------------------------
    always @* begin
        // Select byte lane.
        case (addr_lo)
            2'd0: byte_lane = rdata_word[7:0];
            2'd1: byte_lane = rdata_word[15:8];
            2'd2: byte_lane = rdata_word[23:16];
            2'd3: byte_lane = rdata_word[31:24];
        endcase

        // Select halfword. addr_lo[0] is intentionally ignored.
        if (addr_lo[1]) begin
            half_word = rdata_word[31:16];
        end
        else begin
            half_word = rdata_word[15:0];
        end

        case (funct3)
            3'b000: begin // LB
                load_data = {{24{byte_lane[7]}}, byte_lane};
            end

            3'b100: begin // LBU
                load_data = {24'b0, byte_lane};
            end

            3'b001: begin // LH
                load_data = {{16{half_word[15]}}, half_word};
            end

            3'b101: begin // LHU
                load_data = {16'b0, half_word};
            end

            3'b010: begin // LW
                load_data = rdata_word;
            end

            default: begin
                load_data = 32'h0000_0000;
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // Store path
    // -------------------------------------------------------------------------
    always @* begin
        if (!mem_write) begin
            wdata_out = 32'h0000_0000;
            wstrb     = 4'b0000;
        end
        else begin
            case (funct3)
                3'b000: begin // SB
                    wdata_out = {4{store_data[7:0]}};
                    wstrb     = (4'b0001 << addr_lo);
                end

                3'b001: begin // SH
                    wdata_out = {2{store_data[15:0]}};

                    if (addr_lo[1]) begin
                        wstrb = 4'b1100;
                    end
                    else begin
                        wstrb = 4'b0011;
                    end
                end

                3'b010: begin // SW
                    wdata_out = store_data;
                    wstrb     = 4'b1111;
                end

                default: begin
                    wdata_out = 32'h0000_0000;
                    wstrb     = 4'b0000;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
