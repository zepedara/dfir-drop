#!/usr/bin/env bash
# Clone / bake every rule + plugin pack the README promises (offline forever).
set -euo pipefail

clone() { # clone <url> <dest>
  echo "[rules] cloning $2"
  git clone --depth 1 "$1" "$2"
  rm -rf "$2/.git"
}

# --- YARA: Yara-Rules community set + Neo23x0 signature-base ---------------
clone https://github.com/Yara-Rules/rules.git           /opt/yara-rules
clone https://github.com/Neo23x0/signature-base.git     /opt/yara-signature-base

echo "[rules] building YARA indexes (validated, compiling)"
/opt/venv/bin/python /build/build-yara-index.py /opt/yara-rules           /opt/yara-rules/index.yar
/opt/venv/bin/python /build/build-yara-index.py /opt/yara-signature-base  /opt/yara-signature-base/index.yar

# --- capa: full Mandiant rule set -----------------------------------------
# Pin capa-rules to the tag matching the installed capa, fall back to default.
CAPA_VER="$(/opt/venv/bin/capa --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
echo "[rules] installed capa version: ${CAPA_VER:-unknown}"
if [ -n "${CAPA_VER:-}" ] && git clone --depth 1 --branch "v${CAPA_VER}" \
      https://github.com/mandiant/capa-rules.git /opt/capa-rules 2>/dev/null; then
  echo "[rules] capa-rules pinned to v${CAPA_VER}"
else
  echo "[rules] capa-rules tag v${CAPA_VER} unavailable -> using master"
  git clone --depth 1 https://github.com/mandiant/capa-rules.git /opt/capa-rules
fi
rm -rf /opt/capa-rules/.git
echo "[rules] capa rule count:" "$(find /opt/capa-rules -name '*.yml' | wc -l)"

# --- RegRipper 3.0 (full plugin set) --------------------------------------
clone https://github.com/keydet89/RegRipper3.0.git /opt/regripper
echo "[rules] regripper plugins:" "$(find /opt/regripper/plugins -name '*.pl' | wc -l)"

# --- Didier Stevens suite (oledump/pdfid/pdf-parser/emldump) ---------------
clone https://github.com/DidierStevens/DidierStevensSuite.git /opt/didierstevens

# --- AppCompatProcessor (Python2 source; see report re: runtime) -----------
clone https://github.com/mbevilacqua/AppCompatProcessor.git /opt/appcompatprocessor || \
  echo "[rules] WARN: AppCompatProcessor clone failed"

echo "[rules] done."
