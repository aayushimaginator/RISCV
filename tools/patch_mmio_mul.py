import re, sys

def sub(path, pairs):
    s = open(path).read()
    for old, new in pairs:
        n = s.count(old)
        if n != 1:
            print("ABORT %s: expected exactly 1 match of %r, found %d" % (path, old, n))
            sys.exit(1)
        s = s.replace(old, new)
    open(path, "w").write(s)

decode = """    wire io_seg_dp      = io_region && (dmem_addr[11:0] == 12'h010);
"""
decode_new = decode + """    wire io_cycle       = io_region && (dmem_addr[11:0] == 12'h014);
    wire io_mul_a       = io_region && (dmem_addr[11:0] == 12'h020);
    wire io_mul_b       = io_region && (dmem_addr[11:0] == 12'h024);
    wire io_mul_lo      = io_region && (dmem_addr[11:0] == 12'h028);
    wire io_mul_hi      = io_region && (dmem_addr[11:0] == 12'h02C);
    wire io_mul_status  = io_region && (dmem_addr[11:0] == 12'h030);
"""

inst = """        .d1_seg  (d1_seg)
    );
"""
inst_new = inst + """
    // -------------------------------------------------------------------------
    // Cycle counter and multiplier peripheral
    // -------------------------------------------------------------------------

    reg [31:0] cycle_cnt;

    initial begin
        cycle_cnt = 32'h0000_0000;
    end

    always @(posedge clk_sys) begin
        if (reset_active)
            cycle_cnt <= 32'h0000_0000;
        else
            cycle_cnt <= cycle_cnt + 32'h0000_0001;
    end

    wire [31:0] mul_lo;
    wire [31:0] mul_hi;
    wire        mul_busy;

    mul32 u_mul32 (
        .clk   (clk_sys),
        .rst   (reset_active),
        .we_a  (io_mul_a && (|dmem_wstrb)),
        .we_b  (io_mul_b && (|dmem_wstrb)),
        .wdata (dmem_wdata),
        .lo    (mul_lo),
        .hi    (mul_hi),
        .busy  (mul_busy)
    );
"""

rd = """            dmem_rdata_i = {24'h000000, seg_dp_reg};
        end
"""
rd_new = rd + """        else if (io_cycle) begin
            dmem_rdata_i = cycle_cnt;
        end
        else if (io_mul_lo) begin
            dmem_rdata_i = mul_lo;
        end
        else if (io_mul_hi) begin
            dmem_rdata_i = mul_hi;
        end
        else if (io_mul_status) begin
            dmem_rdata_i = {31'b0, mul_busy};
        end
"""
if "u_mul32" in open("rtl/soc_top_rv32i.v").read():
    print("soc_top_rv32i.v already patched, skipping")
else:
    sub("rtl/soc_top_rv32i.v", [(decode, decode_new), (inst, inst_new), (rd, rd_new)])

for p in ["build_rv32i.tcl", "tools/run_selftest.sh", "tools/run_mathdemo.sh", "tools/run_seg7.sh"]:
    s = open(p).read()
    if "rtl/mul32.v" in s:
        continue
    anchor = "rtl/uart_tx.v rtl/seg7_driver.v"
    if s.count(anchor) != 1:
        print("ABORT: expected exactly 1 occurrence of %r in %s, found %d" % (anchor, p, s.count(anchor)))
        sys.exit(1)
    open(p, "w").write(s.replace(anchor, anchor + " rtl/mul32.v"))
print("patched: soc_top_rv32i.v, build_rv32i.tcl and the three runner scripts")
