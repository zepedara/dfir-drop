# DFIR-AIO — All-in-One Digital Forensics & Incident Response Toolbox

A single Docker container with the core DFIR toolkit pre-installed and **fully offline**. Drop your evidence in a folder, run the container, and every tool is there. No installs, no internet needed after download.

---

## Quick start

**Option A — public release (no login):**
1. Download all 7 `dfir-aio.part.*` files from the [latest release](../../releases/tag/dfir-aio-v1).
2. Reassemble + load:
   ```bash
   cat dfir-aio.part.* > dfir-aio.tar.gz
   docker load < dfir-aio.tar.gz
   ```
3. Run it, mounting your evidence folder to `/data`:
   ```bash
   docker run -it --rm -v "$PWD":/data dfir-aio
   ```
4. Inside the container, type **`dfir`** to print the tool menu. Your evidence is at `/data`.

**Option B — one-line pull (if the GHCR package is set public):**
```bash
docker pull ghcr.io/zepedara/dfir-aio:latest
docker run -it --rm -v "$PWD":/data ghcr.io/zepedara/dfir-aio
```

> **The `/data` mount is the bridge:** whatever folder you mount shows up as `/data` inside. Put evidence in, write CSV/JSON output there, review it on your own machine.

---

## What's inside — by investigation type

### 🪟 Windows Event Logs — find attacker activity in `.evtx`
| Tool | What it does | Example |
|---|---|---|
| **chainsaw** | Hunt event logs with **Sigma** detection rules | `chainsaw hunt /data -s /opt/chainsaw/sigma --mapping /opt/chainsaw/repo/mappings/sigma-event-logs-all.yml` |
| **hayabusa** | Fast event-log **timeline** + threat detection | `hayabusa csv-timeline -d /data -o /data/hayabusa.csv` |
| **EvtxECmd** | Parse `.evtx` → clean CSV/JSON | `EvtxECmd -d /data --csv /data` |

### ▶️ Program Execution — what ran on the system
| Tool | What it does | Example |
|---|---|---|
| **AmcacheParser** | `Amcache.hve` — installed/executed programs | `AmcacheParser -f Amcache.hve --csv /data` |
| **AppCompatCacheParser** | ShimCache — execution evidence | `AppCompatCacheParser -f SYSTEM --csv /data` |
| **PECmd** | Prefetch (`.pf`) — what ran, when, how often | `PECmd -d /data --csv /data` |
| **AppCompatProcessor** | Correlate Amcache/ShimCache **at scale** | `python2 /opt/appcompatprocessor/AppCompatProcessor.py <db>` |

### 💽 File System & Disk
| Tool | What it does | Example |
|---|---|---|
| **MFTECmd** | Parse NTFS `$MFT` — every file's metadata + timestamps | `MFTECmd -f '$MFT' --csv /data` |
| **Sleuth Kit** | Disk image forensics + file recovery | `mmls image.dd` · `fls` · `icat` · `tsk_recover` |

### 🗂️ Registry & User Activity
| Tool | Artifact |
|---|---|
| **RECmd** | Registry hives (run keys, persistence, config) |
| **SBECmd** | ShellBags — folders the user browsed |
| **RBCmd** | Recycle Bin — deleted files |
| **LECmd** / **JLECmd** | LNK shortcuts / Jump Lists — recently opened files |
| **SrumECmd** | SRUM — per-app network + resource usage |
| **WxTCmd** | Windows Timeline activity |

### 🧠 Memory Forensics
| Tool | What it does | Example |
|---|---|---|
| **vol** (Volatility 3) | Analyze RAM dumps (processes, network, injected code) | `vol -f memdump.raw windows.info` → then `windows.pslist`, `windows.netscan`, `windows.malfind` |

### 🦠 Malware / Strings
| Tool | What it does | Example |
|---|---|---|
| **yara** | Pattern-scan files for malware signatures | `yara -r /opt/yara-rules/index.yar /data` |
| **bstrings** | Smart string extraction | `bstrings -f file.bin` |

---

## Typical workflow
1. Collect evidence (EVTX logs, `$MFT`, `Amcache.hve`, a memory dump, a disk image, registry hives…) into one folder.
2. `cd` into that folder and run: `docker run -it --rm -v "$PWD":/data dfir-aio`
3. Pick the tool for your evidence type (tables above), send output CSVs to `/data`.
4. Open the CSVs on your host (Timeline Explorer, Excel, etc.).

Everything is offline and self-contained. Type **`dfir`** anytime inside the container to reprint the menu.
