#!/usr/bin/env bash
# Stage 1 of the AppCompatProcessor runtime: build Python 2.7.18 WITHOUT OpenSSL
# (so hashlib.md5 uses the always-present builtin _md5 — the lab's "broken md5"
# came from a Py2 linked to OpenSSL 3, which disables md5 in the default provider).
set -euo pipefail
PY_VER=2.7.18
SRC=/usr/src
mkdir -p "$SRC"

echo "[py2] installing build deps"
apt-get update
# zlib -> zipimport/ensurepip ; libsqlite3 -> sqlite3 (ACP appDB) ; readline/ffi -> nice-to-have
apt-get install -y --no-install-recommends \
    build-essential wget ca-certificates pkg-config \
    zlib1g-dev libsqlite3-dev libffi-dev libreadline-dev
# NB: deliberately NO libssl-dev (keep md5 on the builtin implementation)

echo "[py2] building Python ${PY_VER} from source"
cd "$SRC"
wget -q "https://www.python.org/ftp/python/${PY_VER}/Python-${PY_VER}.tgz"
tar xf "Python-${PY_VER}.tgz"
cd "Python-${PY_VER}"
# --enable-shared: produce libpython2.7.so so the pyregf C extension can link
# against it (a static libpython2.7.a is not -fPIC and fails to link a .so).
./configure --prefix=/usr/local --enable-unicode=ucs4 --enable-shared \
    --with-ensurepip=install LDFLAGS=-Wl,-rpath,/usr/local/lib \
    >/tmp/py2_configure.log 2>&1
make -j"$(nproc)" >/tmp/py2_make.log 2>&1
make altinstall  >/tmp/py2_install.log 2>&1
ln -sf /usr/local/bin/python2.7 /usr/local/bin/python2
# register /usr/local/lib so the shared libpython is found at runtime
echo /usr/local/lib > /etc/ld.so.conf.d/usr-local-lib.conf
ldconfig

echo "[py2] verifying md5 + sqlite3"
/usr/local/bin/python2.7 - <<'PY'
import hashlib, sqlite3, zlib
md5 = hashlib.md5(b"abc").hexdigest()
assert md5 == "900150983cd24fb0d6963f7d28e17f72", "MD5 BROKEN: %s" % md5
print("[py2]   md5(abc)=%s OK ; sqlite3=%s ; zlib=%s" % (md5, sqlite3.sqlite_version, zlib.ZLIB_VERSION))
PY

rm -rf "$SRC"/Python-${PY_VER}*
echo "[py2] done"
