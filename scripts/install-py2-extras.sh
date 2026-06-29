#!/usr/bin/env bash
# AppCompatProcessor Python2 extra deps — psutil (memory governor) and
# python-Levenshtein (the `leven` module).  [v3 addition]
# The sdists are fetched by the py2deps stage (which has TLS); here we compile
# them against the from-source Python 2.7 (gcc/build-essential present). wheel
# is installed first (.whl) so pip produces a proper flat install (a zipped
# easy_install egg cannot load a C extension).
set -euo pipefail
PY2=/usr/local/bin/python2.7
SDIST=/opt/py2-sdists

echo "[py2x] installing wheel into Python2"
"$PY2" -m pip install --no-index --find-links="$SDIST" wheel

echo "[py2x] compiling + installing psutil + python-Levenshtein"
"$PY2" -m pip install --no-build-isolation --no-index --find-links="$SDIST" \
    psutil python-Levenshtein

echo "[py2x] verify (md5 still builtin, both C exts import)"
PYTHONPATH=/opt/py2-site "$PY2" - <<'PY'
import hashlib, psutil, Levenshtein
assert hashlib.md5(b"abc").hexdigest() == "900150983cd24fb0d6963f7d28e17f72"
print("[py2x]   psutil=%s ; Levenshtein.distance(kitten,sitting)=%d ; md5 OK"
      % (psutil.__version__, Levenshtein.distance("kitten", "sitting")))
PY
rm -rf "$SDIST"
echo "[py2x] done."
