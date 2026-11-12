#!/usr/bin/env python3
"""Replace the 1-byte RX latch in soc_top_rv32i.v with a 16-entry FIFO. Idempotent."""
import sys
p = "rtl/soc_top_rv32i.v"
s = open(p).read()
if "rx_mem" in s:
    print("already patched"); sys.exit(0)

old_hdr = """    // UART receiver + MMIO latch (0x10000034)
    //   read : {22'b0, overrun, valid, data[7:0]}
    //   write: any value with wstrb[0] clears valid and overrun (read has no
    //          side effect, so stalls or re-reads cannot lose a byte)
"""
new_hdr = """    // UART receiver + 16-byte FIFO (0x10000034)
    //   read : {22'b0, overrun, valid, head[7:0]}   (valid = FIFO not empty)
    //   write: any value with wstrb[0] pops the head and clears overrun.
    //          Reads have no side effect, so stalls or re-reads cannot lose a
    //          byte. A byte arriving while the FIFO is full is dropped and
    //          sets overrun (sticky until the next write).
"""
a = s.index("    reg       rx_valid;\n")
b = s.index("    // -------------------------------------------------------------------------\n    // 7-segment driver")
new_blk = """    reg [7:0] rx_mem [0:15];
    reg [3:0] rx_wp;
    reg [3:0] rx_rp;
    reg [4:0] rx_count;
    reg       rx_overrun;

    wire       rx_valid = (rx_count != 5'd0);
    wire       rx_full  = (rx_count == 5'd16);
    wire [7:0] rx_data  = rx_valid ? rx_mem[rx_rp] : 8'h00;
    wire       rx_pop   = io_uart_rx && dmem_wstrb[0] && rx_valid;
    wire       rx_push  = rx_pulse && (!rx_full || rx_pop);

    initial begin
        rx_wp      = 4'd0;
        rx_rp      = 4'd0;
        rx_count   = 5'd0;
        rx_overrun = 1'b0;
    end

    always @(posedge clk_sys) begin
        if (reset_active) begin
            rx_wp      <= 4'd0;
            rx_rp      <= 4'd0;
            rx_count   <= 5'd0;
            rx_overrun <= 1'b0;
        end
        else begin
            if (io_uart_rx && dmem_wstrb[0])
                rx_overrun <= 1'b0;
            if (rx_push) begin
                rx_mem[rx_wp] <= rx_byte;
                rx_wp         <= rx_wp + 4'd1;
            end
            else if (rx_pulse)
                rx_overrun <= 1'b1;
            if (rx_pop)
                rx_rp <= rx_rp + 4'd1;
            rx_count <= rx_count + {4'b0, rx_push} - {4'b0, rx_pop};
        end
    end

"""
assert old_hdr in s
s = s.replace(old_hdr, new_hdr)
a = s.index("    reg       rx_valid;\n")
b = s.index("    // -------------------------------------------------------------------------\n    // 7-segment driver")
s = s[:a] + new_blk + s[b:]
open(p, "w").write(s)
print("patched", p)
