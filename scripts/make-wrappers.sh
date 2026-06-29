#!/usr/bin/env bash
# Create the remaining PATH command wrappers the README documents.
set -euo pipefail
BIN="/opt/tools/bin"
mkdir -p "$BIN"

w() { # w <name> <content...>
  local name="$1"; shift
  printf '%s\n' "$@" > "$BIN/$name"
  chmod +x "$BIN/$name"
}

# --- prefetch: libscca parser (sccainfo) ----------------------------------
w prefetch '#!/usr/bin/env bash' \
  '# Prefetch (.pf) parser via libscca (libyal). For rich CSV use PECmd.' \
  'exec sccainfo "$@"'

# --- regripper: RegRipper3.0 (perl) ---------------------------------------
w regripper '#!/usr/bin/env bash' \
  'exec perl /opt/regripper/rip.pl "$@"'

# --- capa-offline: capa pinned to the baked Mandiant rule set -------------
w capa-offline '#!/usr/bin/env bash' \
  'exec /opt/venv/bin/capa -r /opt/capa-rules "$@"'

# --- Didier Stevens suite -------------------------------------------------
for t in oledump pdfid pdf-parser emldump zipdump base64dump; do
  src="/opt/didierstevens/${t}.py"
  w "$t" '#!/usr/bin/env bash' \
    "exec /opt/venv/bin/python \"$src\" \"\$@\""
done

# --- AppCompatProcessor: bundled Python2 + pyregf + python-registry --------
# Fully functional ShimCache/Amcache stacking (module-04). The Python2 build,
# pyregf bindings and pure-python deps (/opt/py2-site) are baked by
# install-python2.sh / install-libregf.sh; psutil + python-Levenshtein by
# install-py2-extras.sh.  Exposed as appcompat / appcompatprocessor / acp.
w appcompat '#!/usr/bin/env bash' \
  'export PYTHONPATH=/opt/py2-site${PYTHONPATH:+:$PYTHONPATH}' \
  'exec /usr/local/bin/python2.7 /opt/appcompatprocessor/AppCompatProcessor.py "$@"'
ln -sf "$BIN/appcompat" "$BIN/appcompatprocessor"
ln -sf "$BIN/appcompat" "$BIN/acp"

# --- yara-scan: scan a path with the baked Neo23x0 signature-base rules ----
# Default rule set = signature-base index (override with $YARA_RULES, e.g.
# /opt/yara-rules/index.yar for the Yara-Rules community set). Externals are
# pre-defined so signature-base rules that reference them compile cleanly.
w yara-scan '#!/usr/bin/env bash' \
  '# yara-scan [yara-opts] <file|dir>  — recursive scan with bundled rules' \
  'RULES="${YARA_RULES:-/opt/yara-signature-base/index.yar}"' \
  'exec yara -r -w -d filename=x -d filepath=x -d extension=x -d filetype=x -d md5=x -d owner=x "$RULES" "$@"'

# --- vol: ensure venv volatility on PATH (already linked, add alias) -------
ln -sf /opt/venv/bin/vol "$BIN/vol" 2>/dev/null || true
ln -sf /opt/venv/bin/vol "$BIN/volatility3" 2>/dev/null || true
ln -sf /opt/venv/bin/capa "$BIN/capa" 2>/dev/null || true
ln -sf /opt/venv/bin/floss "$BIN/floss" 2>/dev/null || true
ln -sf /opt/venv/bin/regipy-dump "$BIN/regipy-dump" 2>/dev/null || true
ln -sf /opt/venv/bin/registry-diff "$BIN/registry-diff" 2>/dev/null || true
ln -sf /opt/venv/bin/olevba "$BIN/olevba" 2>/dev/null || true

echo "[wrappers] $(ls -1 $BIN | wc -l) commands on PATH"
