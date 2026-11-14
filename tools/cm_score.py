#!/usr/bin/env python3
import os
import re
import sys
import tempfile

CLK = 75000000


def parse(path):
    txt = open(path, errors="replace").read()
    errors = "Errors detected" in txt
    mt = re.search(r"Total ticks\s*:\s*(\d+)", txt)
    mi = re.search(r"Iterations\s*:\s*(\d+)", txt)
    ticks = int(mt.group(1)) if mt else None
    iters = int(mi.group(1)) if mi else None
    return errors, ticks, iters


def write_tmp(s):
    fd, p = tempfile.mkstemp()
    os.write(fd, s.encode())
    os.close(fd)
    return p


def unit():
    ok = write_tmp("Total ticks : 750000000\nIterations : 1000\nCorrect operation validated.\n")
    e, t, i = parse(ok)
    assert not e and t == 750000000 and i == 1000
    score = i * CLK / t
    print("unit ok-run: CoreMark=%.4f CoreMark/MHz=%.6f" % (score, score / 75.0))
    os.unlink(ok)

    bad = write_tmp("Errors detected\nTotal ticks : 750000000\nIterations : 1000\n")
    e2, _, _ = parse(bad)
    assert e2
    os.unlink(bad)

    short = write_tmp("Total ticks : 1000\nIterations : 1\nCorrect operation validated.\n")
    e3, t3, _ = parse(short)
    assert (not e3) and t3 < 10 * CLK
    os.unlink(short)

    print("CM_SCORE UNIT PASS")
    return 0


def main():
    if len(sys.argv) < 2:
        print("usage: cm_score.py LOG | --unit", file=sys.stderr)
        return 2
    if sys.argv[1] == "--unit":
        return unit()
    errors, ticks, iters = parse(sys.argv[1])
    if errors:
        print("REFUSE: 'Errors detected' present")
        return 1
    if ticks is None or iters is None:
        print("REFUSE: missing Total ticks / Iterations")
        return 1
    if ticks < 10 * CLK:
        print("REFUSE: ticks=%d < %d (run shorter than 10s; invalid per EEMBC)" % (ticks, 10 * CLK))
        return 1
    score = iters * CLK / ticks
    print("CoreMark = %.4f" % score)
    print("CoreMark/MHz = %.6f" % (score / 75.0))
    return 0


if __name__ == "__main__":
    sys.exit(main())
