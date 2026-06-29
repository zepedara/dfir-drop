#!/usr/bin/env bash
# Plaso / log2timeline — super-timeline engine.  [v3 addition]
# Installed in its OWN venv (/opt/plaso-venv) so plaso's pinned dependency
# graph (dfvfs, dfwinreg, ~40 libyal bindings, protobuf, pyparsing ...) cannot
# perturb the volatility3/capa/floss venv at /opt/venv. Defensive timelining.
set -euo pipefail

echo "[plaso] installing build headers for the libyal/pytsk3 C extensions"
apt-get update
# libtsk-dev -> pytsk3 ; build-essential/python3-dev/pkg-config already present.
apt-get install -y --no-install-recommends libtsk-dev pkg-config
rm -rf /var/lib/apt/lists/*

echo "[plaso] creating isolated venv + installing plaso"
python3 -m venv /opt/plaso-venv
/opt/plaso-venv/bin/pip install --no-cache-dir --upgrade pip wheel setuptools
/opt/plaso-venv/bin/pip install --no-cache-dir plaso

# Plaso ships its CLI entry points WITHOUT the .py suffix (log2timeline,
# psort, pinfo). The lab/README invoke the classic *.py names, so expose both.
for t in log2timeline psort pinfo; do
  ln -sf "/opt/plaso-venv/bin/${t}" "/opt/tools/bin/${t}"
  ln -sf "/opt/plaso-venv/bin/${t}" "/opt/tools/bin/${t}.py"
done

echo "[plaso] verify"
/opt/tools/bin/log2timeline.py --version
echo "[plaso] plaso version: $(/opt/plaso-venv/bin/python -c "import plaso; print(plaso.__version__)")"
echo "[plaso] done."
