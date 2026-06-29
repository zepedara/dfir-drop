#!/usr/bin/env bash
# Bake Volatility 3 symbol packs (Windows/Mac/Linux ~900MB) into the image.
# Volatility 3 reads .zip symbol packs placed directly in its symbols dir,
# so we keep them zipped (compact + officially supported).
set -euo pipefail

SYMDIR="$(/opt/venv/bin/python -c 'import os,volatility3 as v; print(os.path.join(os.path.dirname(v.__file__),"symbols"))')"
mkdir -p "$SYMDIR"
echo "[symbols] target: $SYMDIR"

BASE="https://downloads.volatilityfoundation.org/volatility3/symbols"
for pack in windows mac linux; do
  echo "[symbols] downloading $pack.zip"
  curl -fsSL --retry 4 --retry-delay 5 "$BASE/$pack.zip" -o "$SYMDIR/$pack.zip"
  ls -lh "$SYMDIR/$pack.zip"
done

# Also expose a stable path + env-independent location.
mkdir -p /opt/volatility3
ln -sfn "$SYMDIR" /opt/volatility3/symbols

echo "[symbols] total:" "$(du -sh "$SYMDIR" | cut -f1)"
