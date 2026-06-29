#!/usr/bin/env bash
# Download Eric Zimmerman .NET tools (net9 builds) and create PATH wrappers.
# Some tool zips wrap everything in a single top-level folder (EvtxeCmd/, RECmd/)
# carrying Maps/ or BatchExamples/ — we flatten that so the README paths
# (e.g. /opt/eztools/RECmd/BatchExamples/) are correct, and locate the managed
# dll recursively.
set -euo pipefail
shopt -s nullglob

BASE="https://download.ericzimmermanstools.com/net9"
DEST="/opt/eztools"
BIN="/opt/tools/bin"
mkdir -p "$DEST" "$BIN"

TOOLS="PECmd AmcacheParser AppCompatCacheParser MFTECmd EvtxECmd RECmd SBECmd RBCmd LECmd JLECmd SrumECmd SumECmd WxTCmd RecentFileCacheParser VSCMount bstrings"

for t in $TOOLS; do
  echo "[EZ] fetching $t"
  curl -fsSL --retry 4 --retry-delay 3 "$BASE/$t.zip" -o "/tmp/$t.zip"
  rm -rf "/tmp/ez_$t"; mkdir -p "/tmp/ez_$t"
  unzip -oq "/tmp/$t.zip" -d "/tmp/ez_$t"

  # Flatten a single wrapping directory if present.
  entries=( /tmp/ez_$t/* )
  if [ "${#entries[@]}" -eq 1 ] && [ -d "${entries[0]}" ]; then
    src="${entries[0]}"
  else
    src="/tmp/ez_$t"
  fi
  mkdir -p "$DEST/$t"
  cp -a "$src"/. "$DEST/$t"/
  rm -rf "/tmp/$t.zip" "/tmp/ez_$t"

  dll="$(find "$DEST/$t" -iname "$t.dll" | head -1)"
  if [ -z "${dll:-}" ] || [ ! -f "$dll" ]; then
    echo "WARN: $t.dll not found after extract" >&2
    continue
  fi
  cat > "$BIN/$t" <<EOF
#!/usr/bin/env bash
exec dotnet "$dll" "\$@"
EOF
  chmod +x "$BIN/$t"
  echo "[EZ]   -> wrapper $t  (dll: $dll)"
done

echo "[EZ] installed: $(ls -1 $BIN | tr '\n' ' ')"
