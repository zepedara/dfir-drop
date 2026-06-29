#!/usr/bin/env bash
# Stage 2 of the AppCompatProcessor runtime: build libregf + its Python 2
# bindings (pyregf) against the from-source Python 2.7. Verbose on purpose so
# any failure is visible in the build log.
set -euo pipefail
LIBREGF_VER=20260526
SRC=/usr/src
mkdir -p "$SRC"
PY2=/usr/local/bin/python2.7

trap 'echo "=== libregf FAILURE — config.log tail ==="; tail -n 60 "$SRC"/libregf-*/config.log 2>/dev/null' ERR

echo "[regf] downloading libregf ${LIBREGF_VER}"
cd "$SRC"
wget -q "https://github.com/libyal/libregf/releases/download/${LIBREGF_VER}/libregf-alpha-${LIBREGF_VER}.tar.gz" -O libregf.tar.gz
tar xf libregf.tar.gz
cd "libregf-${LIBREGF_VER}"

echo "[regf] configure --enable-python (PYTHON=$PY2)"
PYTHON="$PY2" PYTHON_CONFIG="${PY2}-config" \
  ./configure --prefix=/usr/local --enable-python 2>&1 | tail -n 25
echo "[regf] make"
make -j"$(nproc)" 2>&1 | tail -n 15
echo "[regf] make install"
make install 2>&1 | tail -n 10
ldconfig

echo "[regf] verifying pyregf + python-registry under Python 2"
PYTHONPATH=/opt/py2-site "$PY2" - <<'PY'
import pyregf
from Registry import Registry
import hashlib, sqlite3
print("[regf]   pyregf=%s ; python-registry OK ; md5 ok" % pyregf.get_version())
PY

rm -rf "$SRC"/libregf*
echo "[regf] done"
