#!/usr/bin/env python3
import sys
a = [l.lower() for l in open(sys.argv[1]).read().split("\n") if l.strip()]
b = [l.lower() for l in open(sys.argv[2]).read().split("\n") if l.strip()]
n = min(len(a), len(b))
for i in range(n):
    if a[i] != b[i]:
        print("first divergence at instruction #%d   (format: pc instr rd value)" % i)
        for j in range(max(0, i - 3), i):
            print("  both : " + a[j])
        print("  core : " + a[i])
        print("  iss  : " + b[i])
        sys.exit(1)
if len(a) != len(b):
    print("traces agree for %d instructions, then lengths differ: core=%d iss=%d" % (n, len(a), len(b)))
    sys.exit(1)
print("traces identical (%d instructions)" % n)
