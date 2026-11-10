import sys

def sub(path, pairs):
    s = open(path).read()
    for old, new, count in pairs:
        n = s.count(old)
        if n != count:
            print("ABORT %s: expected %d match(es) of %r, found %d" % (path, count, old, n))
            sys.exit(1)
        s = s.replace(old, new)
    open(path, "w").write(s)

old_map = """        3'b111,
        3'b110,
        3'b101,
        3'b100,
        3'b011,
        3'b010,
        3'b001,
        3'b000
"""
new_map = """        3'b000,
        3'b001,
        3'b010,
        3'b011,
        3'b100,
        3'b101,
        3'b110,
        3'b111
"""
sub("rtl/seg7_driver.v", [(old_map, new_map, 1)])
sub("tb/seg7_tb.v", [
    ("digit0_r = phase_p;", "digit0_r = 3'd7 - phase_p;", 1),
    ("digit1_r = p + 4;", "digit1_r = 3'd3 - phase_p;", 1),
])
sub("tb/soc_seg_tb.v", [
    ("got_dp[g]", "got_dp[7-g]", 2),
    ("got[g]", "got[7-g]", 3),
])
print("patched: digit 0 is now the rightmost digit on the board")
