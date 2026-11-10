#!/usr/bin/env python3
import argparse
import re
import sys

THEORY = {
    "EMPTY":   (2, 3),
    "ADD4":    (6, 7),
    "LW4":     (6, 7),
    "SW4":     (6, 7),
    "NOTAKEN": (6, 7),
    "LOADUSE": (6, 9),
}
TOL = 64

def parse(path):
    out = {}
    pat = re.compile(r"CPI (\w+) n=(\d+) cycles=(\d+)")
    with open(path, errors="replace") as f:
        for line in f:
            m = pat.search(line)
            if m:
                out[m.group(1)] = (int(m.group(2)), int(m.group(3)))
    return out

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", required=True)
    ap.add_argument("--compare", default=None)
    a = ap.parse_args()

    got = parse(a.log)
    if not got:
        print("check_cpi: no CPI lines in", a.log)
        return 1

    ok = True
    print("bench     I   cycles     CPI  theory  verdict")
    for name in ("EMPTY", "ADD4", "LW4", "SW4", "NOTAKEN", "LOADUSE"):
        if name not in got:
            print(name, "missing"); ok = False; continue
        n, cyc = got[name]
        i, cpi_iter = THEORY[name]
        exp = n * cpi_iter
        good = abs(cyc - exp) <= TOL
        ok = ok and good
        print("%-8s %2d %8d %7.3f %7.3f  %s" % (
            name, i, cyc, cyc / (n * i), cpi_iter / i,
            "OK" if good else "FAIL exp %d..%d" % (exp - TOL, exp + TOL)))

    if a.compare:
        other = parse(a.compare)
        diffs = 0
        for name, (_, cyc) in got.items():
            if name in other and other[name][1] != cyc:
                print("MISMATCH", name, "log=", cyc, "compare=", other[name][1])
                diffs += 1
        if diffs:
            ok = False
            print("compare: %d differences" % diffs)
        else:
            print("compare: cycle counts identical")

    print("CPI CHECK PASS" if ok else "CPI CHECK FAIL")
    return 0 if ok else 1

if __name__ == "__main__":
    sys.exit(main())
