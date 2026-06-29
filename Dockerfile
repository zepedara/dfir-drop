# DFIR-AIO — All-in-One Offline Digital Forensics & Incident Response Toolbox
# Builds the image specified by the dfir-drop README. 100% offline at runtime:
# every Sigma/YARA/capa rule set, RegRipper plugin and Volatility symbol pack is
# baked in at build time. Defensive / educational DFIR training toolkit.
#
# Build:  docker build -t dfir-aio:latest -t dfir-aio:v2 .
# Run:    docker run -it --rm -v "$PWD":/data dfir-aio:v2
#
# Layer order: stable/heavy layers (OS, .NET, pip, ~900MB Vol symbols) first;
# tools + rule packs + wrappers (more likely to be re-tweaked) last, so a
# rebuild after editing a wrapper does not re-pull the symbol packs.
FROM debian:12-slim

LABEL org.opencontainers.image.title="dfir-aio" \
      org.opencontainers.image.description="All-in-one offline DFIR toolbox (Chainsaw, Hayabusa, EZ Tools, Volatility3+symbols, Sleuth Kit, YARA, capa, RegRipper, regipy, Didier Stevens, exiftool)" \
      org.opencontainers.image.source="https://github.com/zepedara/dfir-drop"

ENV DEBIAN_FRONTEND=noninteractive \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    PIP_NO_CACHE_DIR=1 \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PATH="/opt/tools/bin:/opt/venv/bin:$PATH"

# ---------------------------------------------------------------------------
# 1. Base OS packages: native forensic tools + language runtimes + libs
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget unzip p7zip-full git xz-utils gnupg \
      tzdata locales procps less file vim-tiny \
      sleuthkit yara \
      perl libimage-exiftool-perl libparse-win32registry-perl \
      python3 python3-pip python3-venv python3-dev build-essential \
      libhivex-bin python3-hivex libscca-utils \
      libicu72 libssl3 \
    && sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /opt/tools/bin /opt/eztools /data

# ---------------------------------------------------------------------------
# 2. .NET 9 runtime — required by the Eric Zimmerman tools
# ---------------------------------------------------------------------------
RUN wget -q https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O /tmp/ms.deb \
    && dpkg -i /tmp/ms.deb && rm /tmp/ms.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends dotnet-runtime-9.0 \
    && rm -rf /var/lib/apt/lists/* \
    && dotnet --info | head -5

# ---------------------------------------------------------------------------
# 3. Python tooling (isolated venv): Volatility3, capa, FLOSS, regipy, oletools
# ---------------------------------------------------------------------------
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --upgrade pip wheel setuptools \
    && /opt/venv/bin/pip install \
        "volatility3" \
        "regipy[full]" \
        "flare-capa" \
        "flare-floss" \
        "oletools" \
        "yara-python" \
        "pefile" \
    && /opt/venv/bin/vol --help >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# 4. Volatility 3 symbol packs (Windows/Mac/Linux ~900MB)  [baked, offline]
#    Heavy + stable -> placed early so tool/rule edits don't re-pull it.
# ---------------------------------------------------------------------------
COPY scripts/get-symbols.sh /build/get-symbols.sh
RUN bash /build/get-symbols.sh

# ---------------------------------------------------------------------------
# 5. Chainsaw (binary + mappings) + SigmaHQ rules (3,700+)  [baked, offline]
# ---------------------------------------------------------------------------
ARG CHAINSAW_VER=2.16.0
RUN curl -fsSL "https://github.com/WithSecureLabs/chainsaw/releases/download/v${CHAINSAW_VER}/chainsaw_x86_64-unknown-linux-gnu.tar.gz" \
      | tar xz -C /opt \
    && ln -sf /opt/chainsaw/chainsaw /opt/tools/bin/chainsaw \
    && mkdir -p /opt/chainsaw/repo \
    && ln -sf /opt/chainsaw/mappings /opt/chainsaw/repo/mappings \
    && git clone --depth 1 https://github.com/SigmaHQ/sigma.git /opt/sigma \
    && mkdir -p /opt/chainsaw/sigma \
    && cp -r /opt/sigma/rules /opt/chainsaw/sigma/rules \
    && cp -r /opt/sigma/rules-emerging-threats /opt/chainsaw/sigma/rules-emerging-threats \
    && cp -r /opt/sigma/rules-threat-hunting /opt/chainsaw/sigma/rules-threat-hunting \
    && rm -rf /opt/sigma \
    && echo "Sigma rule count:" $(find /opt/chainsaw/sigma -name '*.yml' | wc -l)

# ---------------------------------------------------------------------------
# 6. Hayabusa (binary + bundled rules 4,900+)  [baked, offline]
#    Use the static musl build: the -gnu build needs GLIBC_2.38 (Debian 12 has
#    2.36) and would fail to run. musl is fully portable (also ideal for WSL2).
# ---------------------------------------------------------------------------
ARG HAYABUSA_VER=3.9.0
RUN curl -fsSL "https://github.com/Yamato-Security/hayabusa/releases/download/v${HAYABUSA_VER}/hayabusa-${HAYABUSA_VER}-lin-x64-musl.zip" -o /tmp/hb.zip \
    && mkdir -p /opt/hayabusa \
    && unzip -oq /tmp/hb.zip -d /opt/hayabusa \
    && rm /tmp/hb.zip \
    && chmod +x "/opt/hayabusa/hayabusa-${HAYABUSA_VER}-lin-x64-musl" \
    && ln -sf "/opt/hayabusa/hayabusa-${HAYABUSA_VER}-lin-x64-musl" /opt/tools/bin/hayabusa \
    && echo "Hayabusa rule count:" $(find /opt/hayabusa/rules -name '*.yml' | wc -l)

# ---------------------------------------------------------------------------
# 7. Eric Zimmerman tools (.NET) + PATH wrappers
# ---------------------------------------------------------------------------
COPY scripts/install-eztools.sh /build/install-eztools.sh
RUN bash /build/install-eztools.sh

# ---------------------------------------------------------------------------
# 8. Rule packs: YARA (Yara-Rules + Neo23x0), capa (Mandiant), RegRipper,
#    Didier Stevens suite, AppCompatProcessor source.  [all baked, offline]
# ---------------------------------------------------------------------------
COPY scripts/get-rules.sh /build/get-rules.sh
COPY scripts/build-yara-index.py /build/build-yara-index.py
RUN bash /build/get-rules.sh

# ---------------------------------------------------------------------------
# 9. Command wrappers (prefetch, regripper, capa-offline, didier suite, dfir)
# ---------------------------------------------------------------------------
COPY scripts/make-wrappers.sh /build/make-wrappers.sh
COPY scripts/dfir-menu.sh /opt/tools/bin/dfir
RUN bash /build/make-wrappers.sh && chmod +x /opt/tools/bin/dfir \
    && printf 'export PATH=/opt/tools/bin:/opt/venv/bin:$PATH\n' > /etc/profile.d/00-dfir-path.sh

# Friendly banner + clean build dir
COPY scripts/banner.txt /etc/dfir-banner
RUN rm -rf /build && echo 'cat /etc/dfir-banner 2>/dev/null' >> /root/.bashrc

WORKDIR /data
CMD ["/bin/bash"]
