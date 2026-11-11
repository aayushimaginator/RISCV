import math, subprocess, sys

# typed text -> expected angle (None = no result). \x08 is backspace.
CASES = [
    ("0\n", 0), ("30\n", 30), ("90\n", 90), ("180\n", 180), ("270\n", 270),
    ("359\n", 359), ("360\n", 0), ("725\n", 5), ("12\x083\n", 13),
    ("\n", None), ("ab\n", None), ("4x5\n", 45), ("9999\n", 279),
    ("7\x08\x08\n", None), ("007\n", 7), ("\r45\r", 45),
]
text = "".join(c[0] for c in CASES)
out = subprocess.run(["build/calc/host"], input=text, capture_output=True,
                     text=True, check=True).stdout
rows = [l.split() for l in out.splitlines() if l.startswith("SCR")]
want = [c[1] for c in CASES if c[1] is not None]
if len(rows) != 2 * len(want):
    print("expected %d screens, got %d" % (2 * len(want), len(rows))); sys.exit(1)
bad = 0
for i, a in enumerate(want):
    for j, fn in enumerate((0xC, 0x5)):
        _, f, ang, data, dp = rows[2 * i + j]
        f = int(f); ang = int(ang); data = int(data, 16); dp = int(dp, 16)
        d = [(data >> (4 * q)) & 15 for q in range(8)]
        t = (math.cos if fn == 0xC else math.sin)(math.radians(a))
        exp = round(abs(t) * 1000)
        neg = t < -0.0005
        shown = d[3] * 1000 + d[2] * 100 + d[1] * 10 + d[0]
        if (f != fn or ang != a or d[7] != fn or d[6] * 100 + d[5] * 10 + d[4] != a
                or abs(shown - exp) > 1 or ((dp & 0x10) != 0) != neg or not (dp & 8)):
            bad += 1
            print("BAD angle", a, "fn", hex(fn), hex(data), hex(dp), "exp", exp, neg)
print("check_calc: %s (%d inputs, %d bad)" % ("PASS" if bad == 0 else "FAIL", len(want), bad))
sys.exit(1 if bad else 0)
