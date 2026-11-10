import math, subprocess, sys

out = subprocess.run(["build/mathdisp/host"], capture_output=True, text=True, check=True).stdout
rows = [l.split() for l in out.splitlines() if l.startswith("SCR")]
if len(rows) != 48:
    print("expected 48 screens, got", len(rows)); sys.exit(1)
bad = 0
for _, fn, ang, data, dp in rows:
    fn = int(fn); ang = int(ang); data = int(data, 16); dp = int(dp, 16)
    d = [(data >> (4 * i)) & 15 for i in range(8)]
    ok_digits = all(x <= 9 for x in d[:7]) and d[7] in (0xC, 5)
    shown_angle = d[6] * 100 + d[5] * 10 + d[4]
    shown_val = d[3] * 1000 + d[2] * 100 + d[1] * 10 + d[0]
    f = math.cos if fn == 0xC else math.sin
    t = f(math.radians(ang))
    exp = round(abs(t) * 1000)
    neg = t < -0.0005
    if (not ok_digits or d[7] != fn or shown_angle != ang
            or abs(shown_val - exp) > 1 or ((dp & 0x10) != 0) != neg or not (dp & 0x08)):
        bad += 1
        print("BAD", fn, ang, hex(data), hex(dp), "expected value", exp, "neg", neg)
print("check_mathdisp: %s (%d screens, %d bad)" % ("PASS" if bad == 0 else "FAIL", len(rows), bad))
sys.exit(1 if bad else 0)
