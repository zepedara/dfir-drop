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

# --- AppCompatProcessor: needs python2 (not in Debian 12) -----------------
# Provide a wrapper that uses python2 if the user layers it in; otherwise it
# explains the limitation. Source is baked at /opt/appcompatprocessor.
w appcompat '#!/usr/bin/env bash' \
  'if command -v python2 >/dev/null 2>&1; then' \
  '  exec python2 /opt/appcompatprocessor/AppCompatProcessor.py "$@"' \
  'else' \
  '  echo "AppCompatProcessor source is baked at /opt/appcompatprocessor but" >&2' \
  '  echo "requires a Python2 interpreter (removed from Debian 12). See report." >&2' \
  '  exit 2' \
  'fi'

# --- vol: ensure venv volatility on PATH (already linked, add alias) -------
ln -sf /opt/venv/bin/vol "$BIN/vol" 2>/dev/null || true
ln -sf /opt/venv/bin/vol "$BIN/volatility3" 2>/dev/null || true
ln -sf /opt/venv/bin/capa "$BIN/capa" 2>/dev/null || true
ln -sf /opt/venv/bin/floss "$BIN/floss" 2>/dev/null || true
ln -sf /opt/venv/bin/regipy-dump "$BIN/regipy-dump" 2>/dev/null || true
ln -sf /opt/venv/bin/registry-diff "$BIN/registry-diff" 2>/dev/null || true
ln -sf /opt/venv/bin/olevba "$BIN/olevba" 2>/dev/null || true

echo "[wrappers] $(ls -1 $BIN | wc -l) commands on PATH"
