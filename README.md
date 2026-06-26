# DFIR-AIO — All-in-One Offline Digital Forensics & Incident Response Toolbox

A single Docker container with a complete DFIR toolkit pre-installed and **100% offline**. Every Sigma/YARA rule set, capa rule, registry plugin, and Volatility memory-symbol pack is **baked into the image** — no tool ever reaches the internet to work on your evidence. Build once, run it air-gapped forever.

> **Why this exists:** spinning up forensic tooling normally means installing a dozen tools, chasing dependencies, and downloading rule/symbol packs at the worst time. This is all of it, pre-wired, in one `docker run`.

---

## Contents
- [Offline guarantee](#offline-guarantee)
- [Prerequisites](#prerequisites)
- [Quick start](#quick-start)
- [How evidence flows (the `/data` mount)](#how-evidence-flows)
- [First 10 minutes of an incident](#first-10-minutes)
- [Cheat sheet: which tool for which artifact](#cheat-sheet)
- [Tool reference (in depth)](#tool-reference)
  - [1. Windows event logs](#1-event-logs) · [2. Program execution](#2-execution) · [3. Filesystem & disk](#3-filesystem) · [4. Registry & user activity](#4-registry) · [5. Memory](#5-memory) · [6. Malware, docs & metadata](#6-malware)
- [Investigation workflows](#workflows)
- [⚠️ Handling malware safely](#safety)
- [Troubleshooting](#troubleshooting)
- [What's bundled (inventory & sizes)](#inventory)

---

<a name="offline-guarantee"></a>
## Offline guarantee — what's baked in
| Bundled data | Size | Means you can… |
|---|---|---|
| Volatility 3 symbols (Windows/Mac/Linux) | ~900 MB | analyze **any** standard memory dump, no symbol download |
| Sigma rules (Chainsaw) | 4,200+ | hunt event logs offline |
| Hayabusa rules | 4,900+ | timeline + detect offline |
| YARA — Yara-Rules + Neo23x0 signature-base | 1,000s | malware scanning offline |
| capa rules (Mandiant) | full set | binary capability ID offline |
| RegRipper plugins | full set | registry analysis offline |

Pull the network cable after `docker load` — everything still works.

---

<a name="prerequisites"></a>
## Prerequisites
- **Docker** (Engine or Desktop). On Ubuntu: `sudo apt install docker.io` (or Docker's official repo). Verify: `docker --version`.
- ~5 GB free disk for the loaded image.
- Your **evidence files** (triage collection, hives, `$MFT`, memory dump, disk image, suspect files).

> No GPU needed. Runs on Linux, macOS, or Windows (WSL2) hosts.

---

<a name="quick-start"></a>
## Quick start

**Option A — public release (no login, works on locked-down networks):**
```bash
# Download all dfir-aio.part.* files from the latest release, then:
cat dfir-aio.part.* > dfir-aio.tar.gz
docker load < dfir-aio.tar.gz          # imports the image
docker images | grep dfir-aio          # verify it loaded
```

**Option B — one-line pull (if the GHCR package is public):**
```bash
docker pull ghcr.io/zepedara/dfir-aio:latest
```

**Run it** (from the folder that holds your evidence):
```bash
docker run -it --rm -v "$PWD":/data dfir-aio
```
Inside the container type **`dfir`** for the menu. Done.

Flags explained: `-it` interactive shell · `--rm` auto-clean the container on exit (your evidence/output on the host is untouched) · `-v "$PWD":/data` mounts the current host folder as `/data` inside.

---

<a name="how-evidence-flows"></a>
## How evidence flows — the `/data` mount
`/data` is a **shared folder** between your machine and the container:
```
  host:  ~/case123/   <-->   container: /data
         Amcache.hve          /data/Amcache.hve
         $MFT                 /data/$MFT
         mem.raw              /data/mem.raw
         (tool output CSVs land here too, readable on your host)
```
1. Put evidence in a host folder. 2. `cd` into it. 3. `docker run … -v "$PWD":/data dfir-aio`. 4. Run tools with input/output under `/data`. 5. Open the resulting CSVs on your host (e.g., in **Eric Zimmerman's Timeline Explorer** or Excel).

> **Windows host (PowerShell):** use `-v ${PWD}:/data`. **cmd.exe:** `-v %cd%:/data`.

---

<a name="first-10-minutes"></a>
## First 10 minutes of an incident (Windows host triage)
You have a KAPE/triage collection. Get the story fast:
```bash
# 1) What malicious things fired in the event logs?
chainsaw hunt /data -s /opt/chainsaw/sigma --mapping /opt/chainsaw/repo/mappings/sigma-event-logs-all.yml --csv --output /data/_chainsaw

# 2) One chronological timeline of notable events:
hayabusa csv-timeline -d /data -o /data/_hayabusa.csv

# 3) What executed on the box?
PECmd -d /data --csv /data --csvf _prefetch.csv
AmcacheParser -f /data/Amcache.hve --csv /data --csvf _amcache.csv -i

# 4) Persistence?
regripper -r /data/SOFTWARE -p runkeys
```
Read `_chainsaw` + `_hayabusa.csv` first — they point you at the timeframe and accounts to dig into.

---

<a name="cheat-sheet"></a>
## Cheat sheet — which tool for which artifact
| You have… | Use |
|---|---|
| `.evtx` event logs | `chainsaw`, `hayabusa`, `EvtxECmd` |
| `Amcache.hve` | `AmcacheParser` |
| `SYSTEM` hive (ShimCache) | `AppCompatCacheParser` |
| Prefetch `.pf` | `PECmd` |
| `$MFT`, `$J` (USN) | `MFTECmd` |
| Registry hives | `regripper`, `RECmd`, `regipy` |
| `NTUSER.DAT` shellbags | `SBECmd` |
| `$I` recycle bin | `RBCmd` |
| `.lnk` / jump lists | `LECmd` / `JLECmd` |
| `SRUDB.dat` | `SrumECmd` |
| Memory dump (`.raw/.mem/.dmp`) | `vol` (Volatility 3) |
| Disk image (`.dd/.E01`) | Sleuth Kit (`mmls`/`fls`/`icat`/`tsk_recover`) |
| Suspect EXE/DLL | `capa-offline`, `floss`, `yara` |
| Office doc / PDF / EML | `oledump` / `pdfid`,`pdf-parser` / `emldump` |
| Any file's metadata | `exiftool` |

---

<a name="tool-reference"></a>
# Tool reference (in depth)
Each tool: **the forensic question it answers → command → how to read the output → gotchas.**

<a name="1-event-logs"></a>
## 1. Windows Event Logs

### `chainsaw` — *"What attacker behavior fired in the logs?"*
Searches `.evtx` with 4,200+ Sigma rules.
```bash
chainsaw hunt /data -s /opt/chainsaw/sigma --mapping /opt/chainsaw/repo/mappings/sigma-event-logs-all.yml --csv --output /data/_chainsaw
chainsaw search "mimikatz" -i /data          # keyword across all logs
```
**Reading it:** each hit = rule name + matched event + timestamp. Sort by time, pivot on the account/host. **Gotcha:** needs the original `.evtx`, not exported text logs.

### `hayabusa` — *"Give me one ranked timeline of this host."*
```bash
hayabusa csv-timeline -d /data -o /data/_hayabusa.csv
hayabusa metrics -d /data                     # event-id frequency
```
**Reading it:** columns include `Timestamp, Level (crit/high…), RuleTitle, Details`. Filter to `high`/`crit` first. **Gotcha:** large log sets take a minute — that's normal.

### `EvtxECmd` — *"Give me the raw events as clean CSV."* (no detections — the data itself)
```bash
EvtxECmd -d /data --csv /data --csvf _events.csv
EvtxECmd -f /data/Security.evtx --json /data
```
**Gotcha:** uses event "maps" to label fields; unmapped events still parse, just less pretty.

<a name="2-execution"></a>
## 2. Program Execution — "what ran here"

### `PECmd` — Prefetch — *"What ran, when, how often, from where?"*
```bash
PECmd -d /data --csv /data --csvf _prefetch.csv
```
**Reading it:** `LastRun` + `RunCount` + loaded files. **Gotcha:** Prefetch is on Windows **client** OS, often disabled on servers/SSDs.

### `AmcacheParser` — Amcache.hve — *"What programs existed/ran (with SHA1)?"*
```bash
AmcacheParser -f /data/Amcache.hve --csv /data --csvf _amcache.csv -i
```
**Reading it:** SHA1 lets you hunt the same binary elsewhere / check threat intel. **Gotcha:** presence ≠ execution; corroborate with Prefetch/ShimCache.

### `AppCompatCacheParser` — ShimCache (in `SYSTEM`) — *"What executables did the OS record?"*
```bash
AppCompatCacheParser -f /data/SYSTEM --csv /data --csvf _shimcache.csv
```

### `appcompat` (AppCompatProcessor) — *"Find the one weird binary across many hosts."*
```bash
python2 /opt/appcompatprocessor/AppCompatProcessor.py case.db --load /data/hosts/
python2 /opt/appcompatprocessor/AppCompatProcessor.py case.db stomp
```

<a name="3-filesystem"></a>
## 3. Filesystem & Disk

### `MFTECmd` — `$MFT` / `$J` — *"Every file's metadata + a create/delete history."*
```bash
MFTECmd -f '/data/$MFT' --csv /data --csvf _mft.csv
MFTECmd -f '/data/$J'   --csv /data --csvf _usn.csv
```
**Reading it:** compare `$STANDARD_INFO` vs `$FILE_NAME` timestamps → spot **timestomping**. **Gotcha:** quote `'$MFT'` so the shell doesn't treat `$M` as a variable.

### Sleuth Kit — disk images & **file recovery**
```bash
mmls /data/disk.dd                        # partitions + offsets
fls -r -o 2048 /data/disk.dd              # recursive listing (offset from mmls)
icat -o 2048 /data/disk.dd 12345 > /data/file.out   # extract by inode
tsk_recover -e -o 2048 /data/disk.dd /data/recovered  # recover ALL incl. deleted
```
**Gotcha:** `.E01` images — convert/mount first, or work on a raw `.dd`.

<a name="4-registry"></a>
## 4. Registry & User Activity

### `regripper` — *"Pull persistence/USB/network/accounts from a hive."* (plugins bundled)
```bash
regripper -r /data/SYSTEM   -f system   > /data/_system.txt
regripper -r /data/NTUSER.DAT -f ntuser > /data/_ntuser.txt
regripper -r /data/SOFTWARE -p runkeys              # one plugin
```

### `RECmd` — EZ registry engine with batch files
```bash
RECmd --d /data --bn /opt/eztools/RECmd/BatchExamples/Kroll_Batch.reb --csv /data
```

### `regipy` — scriptable offline registry parsing (Python). `registry-diff`, `regipy-dump`.

### Other EZ artifact parsers (each is a command on PATH)
- **`SBECmd`** ShellBags (folders browsed, incl. deleted) · **`RBCmd`** Recycle Bin (`$I`) · **`LECmd`** LNK · **`JLECmd`** Jump Lists · **`SrumECmd`** SRUM (per-app net/runtime ~30 days) · **`WxTCmd`** Windows Timeline · **`SumECmd`** SUM access logs · **`RecentFileCacheParser`** · **`VSCMount`** mount Volume Shadow Copies · **`bstrings`** regex string search.
  ```bash
  SrumECmd -f /data/SRUDB.dat -r /data/SOFTWARE --csv /data
  SBECmd -d /data --csv /data
  ```

<a name="5-memory"></a>
## 5. Memory Forensics — Volatility 3 (`vol`)
Symbols for Windows/Mac/Linux are baked in (~900 MB) → identifies the kernel and runs offline on any standard dump.
```bash
vol -f /data/mem.raw windows.info            # ALWAYS first: confirm OS/build
vol -f /data/mem.raw windows.pslist          # processes
vol -f /data/mem.raw windows.pstree          # parent/child (spot suspicious parents)
vol -f /data/mem.raw windows.netscan         # network connections
vol -f /data/mem.raw windows.malfind         # injected/hidden code
vol -f /data/mem.raw windows.cmdline         # process command lines
vol -f /data/mem.raw windows.dlllist --pid 1234
vol -f /data/mem.raw windows.dumpfiles --pid 1234   # carve a process's files
vol -f /data/mem.raw windows.hashdump        # local hashes
```
Swap `windows.` → `linux.` / `mac.` for those dumps. **Reading it:** start at `pstree` (odd parent→child), then `netscan` + `malfind` + `cmdline`. **Gotcha:** the dump must be a full physical memory image, not a pagefile/hiberfil alone.

<a name="6-malware"></a>
## 6. Malware, Documents & Metadata

### `capa-offline` — *"What can this binary DO?"* (rules bundled)
```bash
capa-offline /data/suspicious.exe
capa-offline -v /data/sample.dll        # verbose: rules + addresses
```
Output groups capabilities (e.g., *"encrypt data using RC4"*, *"create a service"*, *"inject process"*) → fast read on intent without running it.

### `floss` — deobfuscated/stacked strings (C2, keys malware hides). *(present if its native dep compiled)*
```bash
floss /data/sample.exe > /data/_floss.txt
```

### `yara` — signature scanning (two rule sets bundled)
```bash
yara -r /opt/yara-rules/index.yar /data                          # community set
yara -r /opt/yara-signature-base/index.yar -s /data/sample.exe   # Neo23x0; -s shows matched strings
```

### Didier Stevens suite — malicious documents
```bash
oledump /data/invoice.doc            # list streams/macros; then: oledump -s A4 -v /data/invoice.doc
pdfid /data/file.pdf                  # quick PDF risk triage (JS/OpenAction)
pdf-parser -a /data/file.pdf          # dig into objects/streams
emldump /data/phish.eml               # analyze an email
```

### `exiftool` — file metadata (author, timestamps, GPS, software)
```bash
exiftool /data/photo.jpg
exiftool -r -csv /data/images/ > /data/_meta.csv
```

---

<a name="workflows"></a>
## Investigation workflows

**Windows triage collection (KAPE output):** `chainsaw hunt` + `hayabusa csv-timeline` → narrow the timeframe → `PECmd`/`AmcacheParser`/`AppCompatCacheParser` for execution → `regripper`/`RECmd` for persistence → `MFTECmd` for the file timeline around the incident → pivot on the malicious binary's SHA1/path.

**Memory dump:** `vol windows.info` → `windows.pstree`/`netscan`/`malfind`/`cmdline` → `windows.dumpfiles` to carve the suspicious process → `capa-offline` + `floss` + `yara` on the carved file.

**Suspicious file/doc:** `exiftool` (origin) → `capa-offline` (capabilities) → `floss`/`yara` (IOCs/family); Office/PDF → `oledump`/`pdfid`/`pdf-parser`; pivot any extracted C2/hash into your event-log and memory findings.

**Full disk image:** `mmls` → `fls`/`tsk_recover` (recover incl. deleted) → `bstrings`/`yara` on recovered files → mount/extract artifacts and run the Windows tools above.

---

<a name="safety"></a>
## ⚠️ Handling malware safely
This container **analyzes** files; it does **not** sandbox **execution**. Do **not** run suspect samples. Treat the analysis box as untrusted:
- Work on an isolated/air-gapped host or disposable VM.
- The `--rm` container is ephemeral, but `/data` is your real folder — keep samples zipped/password-protected (`infected`) until you intentionally analyze them.
- Don't mount sensitive host folders; mount only the case folder.

---

<a name="troubleshooting"></a>
## Troubleshooting
- **`$MFT: No such file`** → quote it: `'/data/$MFT'` (shell ate the `$M`).
- **Permission denied writing to `/data`** → the container runs as root; output is root-owned on the host. `sudo chown -R $USER:$USER .` after, or run docker with `--user $(id -u):$(id -g)`.
- **EZ tool prints nothing** → point `-f` at the exact artifact, or `-d /data` for a folder; check the path exists inside `/data`.
- **`vol` can't find symbols** → confirm it's a full physical memory image; run `windows.info` first to see what it detected.
- **`docker: permission denied`** → add yourself to the `docker` group or use `sudo`.
- **Large image won't `docker load`** → ensure all parts downloaded and reassembled (`sha256sum` the reassembled tar.gz against the release note).

---

<a name="inventory"></a>
## What's bundled (inventory)
**Event logs:** Chainsaw(+Sigma), Hayabusa(+rules), EvtxECmd · **Execution:** PECmd, AmcacheParser, AppCompatCacheParser, AppCompatProcessor · **Filesystem:** MFTECmd, Sleuth Kit · **Registry/user:** RegRipper, RECmd, regipy, SBECmd, RBCmd, LECmd, JLECmd, SrumECmd, SumECmd, WxTCmd, RecentFileCacheParser, VSCMount, bstrings · **Memory:** Volatility 3 (+ win/mac/linux symbols) · **Malware/docs:** capa(+rules), FLOSS, YARA (Yara-Rules + Neo23x0), Didier Stevens suite, exiftool.

*Everything offline & self-contained. Inside the container, `dfir` reprints the menu. Reports go to `/data`.*
