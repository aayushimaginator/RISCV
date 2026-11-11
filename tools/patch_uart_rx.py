#!/usr/bin/env python3
"""Wire uart_rx into the SoC (MMIO 0x10000034), TBs, runners, tcl, xdc. Idempotent."""
import glob, re, sys

def rd(p):
    return open(p).read()

def wr(p, s):
    open(p, "w").write(s)

def once(s, anchor, new, where="before"):
    if anchor not in s:
        sys.exit("anchor not found: %r" % anchor[:60])
    if s.count(anchor) != 1:
        sys.exit("anchor not unique: %r" % anchor[:60])
    return s.replace(anchor, new + anchor if where == "before" else anchor + new)

# ---- SoC ----
p = "rtl/soc_top_rv32i.v"
s = rd(p)
if "u_uart_rx" not in s:
    s = once(s, "    output wire        uart_txd,\n",
             "    input  wire        uart_rxd,\n", "after")
    s = once(s, "    wire io_mul_status  = io_region && (dmem_addr[11:0] == 12'h030);\n",
             "    wire io_uart_rx     = io_region && (dmem_addr[11:0] == 12'h034);\n", "after")
    block = """    // -------------------------------------------------------------------------
    // UART receiver + MMIO latch (0x10000034)
    //   read : {22'b0, overrun, valid, data[7:0]}
    //   write: any value with wstrb[0] clears valid and overrun (read has no
    //          side effect, so stalls or re-reads cannot lose a byte)
    // -------------------------------------------------------------------------

    wire       rx_pulse;
    wire       rx_ferr;
    wire [7:0] rx_byte;

    uart_rx #(
        .DIVISOR (UART_DIVISOR)
    ) u_uart_rx (
        .clk       (clk_sys),
        .reset     (reset_active),
        .rxd       (uart_rxd),
        .valid     (rx_pulse),
        .frame_err (rx_ferr),
        .data      (rx_byte)
    );

    reg       rx_valid;
    reg       rx_overrun;
    reg [7:0] rx_data;

    initial begin
        rx_valid   = 1'b0;
        rx_overrun = 1'b0;
        rx_data    = 8'h00;
    end

    always @(posedge clk_sys) begin
        if (reset_active) begin
            rx_valid   <= 1'b0;
            rx_overrun <= 1'b0;
        end
        else if (rx_pulse) begin
            rx_data    <= rx_byte;
            rx_valid   <= 1'b1;
            if (rx_valid) rx_overrun <= 1'b1;
        end
        else if (io_uart_rx && dmem_wstrb[0]) begin
            rx_valid   <= 1'b0;
            rx_overrun <= 1'b0;
        end
    end

"""
    s = once(s, "    // -------------------------------------------------------------------------\n    // 7-segment driver", block)
    s = once(s, "        else if (io_seg_data) begin\n            dmem_rdata_i = seg_data_reg;",
             "        else if (io_uart_rx) begin\n            dmem_rdata_i = {22'b0, rx_overrun, rx_valid, rx_data};\n        end\n")
    wr(p, s)
    print("patched", p)

# ---- testbenches that instantiate the SoC ----
for p in glob.glob("tb/*.v"):
    s = rd(p)
    if "soc_top_rv32i" in s and "uart_rxd" not in s:
        s2 = re.sub(r"(\.uart_txd\s*\(uart_txd\))", r".uart_rxd   (1'b1),\n        \1", s, count=1)
        if s2 == s:
            sys.exit("could not patch " + p)
        wr(p, s2); print("patched", p)

# ---- file lists ----
for p in glob.glob("tools/run_*.sh") + ["build_rv32i.tcl"]:
    s = rd(p)
    if "rtl/uart_tx.v" in s and "rtl/uart_rx.v" not in s and "rtl/soc_top_rv32i.v" in s:
        wr(p, s.replace("rtl/uart_tx.v", "rtl/uart_tx.v rtl/uart_rx.v")); print("patched", p)

# ---- pin ----
p = "constraints/urbana.xdc"
s = rd(p)
if "uart_rxd" not in s:
    a = "set_property -dict {PACKAGE_PIN A16 IOSTANDARD LVCMOS33} [get_ports uart_txd]\n"
    s = once(s, a, "set_property -dict {PACKAGE_PIN B16 IOSTANDARD LVCMOS33} [get_ports uart_rxd]\n", "after")
    wr(p, s); print("patched", p)
