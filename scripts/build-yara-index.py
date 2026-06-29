#!/usr/bin/env python3
"""Build a *compiling* index.yar that `include`s every rule under ROOT, validated
with the SAME `yara` CLI the README uses (`yara -r index.yar /data`, no externals).

Community YARA collections contain duplicate identifiers, broken rules, rules
needing modules/external variables the CLI doesn't define, etc. We:
  1. parallel pre-filter: keep only files that compile standalone with the CLI,
  2. iteratively drop the offending file the CLI reports until the combined
     index compiles cleanly.
So `yara -r index.yar /data` always works offline, exactly as documented.
"""
import os
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

root = sys.argv[1]
out = sys.argv[2]
NULL = "/dev/null"

def compiles(rulefile):
    # yara returns non-zero on a compile error; 0 on a clean scan (no match).
    r = subprocess.run(["yara", rulefile, NULL],
                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    return r.returncode == 0, r.stderr.decode("utf-8", "replace")

files = []
for dp, _dn, fns in os.walk(root):
    for f in fns:
        if f.lower().endswith((".yar", ".yara")) and "index" not in f.lower():
            files.append(os.path.join(dp, f))
files = sorted(set(files))

# 1. Parallel standalone pre-filter.
def ok(p):
    return p if compiles(p)[0] else None

with ThreadPoolExecutor(max_workers=min(32, (os.cpu_count() or 8))) as ex:
    standalone = [p for p in ex.map(ok, files) if p]

# 2. Iterative combined compile; drop the file named in the first error.
path_re = re.compile(r"in (\S+\.ya?ra?)\(")
dropped = set()
for _ in range(5000):
    cur = [p for p in standalone if p not in dropped]
    with open(out, "w") as fh:
        for p in cur:
            fh.write('include "%s"\n' % p)
    good, err = compiles(out)
    if good:
        print("[yara-index] %s : %d files included, %d dropped (standalone-fail %d)"
              % (out, len(cur), len(dropped), len(files) - len(standalone)))
        break
    m = path_re.search(err)
    if m and m.group(1) not in dropped:
        dropped.add(m.group(1))
    elif cur:
        dropped.add(cur[-1])
    else:
        print("[yara-index] FATAL: empty set\n", err[:500])
        break
else:
    print("[yara-index] WARN: iteration cap hit for", out)
