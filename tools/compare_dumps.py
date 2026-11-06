#!/usr/bin/env python3
import sys

def load(p):
    d = {}
    for line in open(p):
        t = line.split()
        if len(t) == 2:
            k = t[0]
            if k[0] == 'm' and len(k) > 1:
                k = 'm%04x' % int(k[1:], 16)
            d[k] = t[1].lower()
    return d

core, iss = load(sys.argv[1]), load(sys.argv[2])
keys = ["x%d" % i for i in range(1, 32)] + ["pc"] + ["m%04x" % i for i in range(2048)]
errs = [(k, core.get(k), iss.get(k)) for k in keys if core.get(k) is None or core.get(k) != iss.get(k)]
for k, a, b in errs[:10]:
    print("MISMATCH %s core=%s iss=%s" % (k, a, b))
if errs:
    print("FAIL (%d mismatches)" % len(errs))
    sys.exit(1)
print("PASS")
