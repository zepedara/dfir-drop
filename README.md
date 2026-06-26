# DFIR-AIO — All-in-One Offline Digital Forensics & Incident Response Toolbox

One Docker container with the full DFIR toolkit pre-installed and **100% offline** — every rule set, signature, and memory-symbol pack is baked in, so no tool ever reaches out to the internet to work on your evidence.

---

## Quick start

```bash
# 1. Download all parts from the latest release, reassemble, load:
cat dfir-aio.part.* > dfir-aio.tar.gz
docker load < dfir-aio.tar.gz

# 2. cd into the folder holding your evidence, then:
docker run -it --rm -v "$PWD":/data dfir-aio      # your evidence is now at /data
```
Inside, type **`dfir`** to reprint the tool menu. Send tool output to `/data` so you can read it on your host.

> **Mental model:** `/data` is a shared folder between your machine and the container. Evidence in → reports out. Nothing leaves your network.

---

# Tool reference (in depth)

Each section: **what it is → what evidence it eats → how to run it.**

---

## 1. Windows Event Logs

### `chainsaw` — Sigma-rule threat hunting over event logs
Rapidly searches Windows `.evtx` logs (and MFT, SRUM, etc.) for attacker behavior using **Sigma** detection rules (4,200+ bundled). Best first pass on a box: "what malicious things fired in the logs?"
```bash
# Hunt all event logs in /data with the full bundled Sigma set:
chainsaw hunt /data -s /opt/chainsaw/sigma \
  --mapping /opt/chainsaw/repo/mappings/sigma-event-logs-all.yml --csv --output /data/chainsaw_out
# Quick keyword search across logs:
chainsaw search "mimikatz" -i /data
# Dump a single log to readable CSV:
chainsaw dump /data/Security.evtx --csv
```

### `hayabusa` — fast event-log timeline + detections
Builds a single sortable **timeline** of notable events across all `.evtx`, scored by severity (uses its own Sigma-based 4,900+ rule set). Great for "give me one chronological story of this host."
```bash
hayabusa csv-timeline -d /data -o /data/hayabusa_timeline.csv     # all logs in /data
hayabusa csv-timeline -f /data/Security.evtx -o /data/sec.csv     # one file
hayabusa metrics -d /data                                         # event-id frequency overview
```

### `EvtxECmd` — clean EVTX → CSV/JSON parser
Converts raw `.evtx` into normalized CSV/JSON with event maps (human-readable fields). Use when you want the *raw* events, not detections.
```bash
EvtxECmd -d /data --csv /data --csvf events.csv     # whole folder
EvtxECmd -f /data/System.evtx --json /data          # one file to JSON
```

---

## 2. Program Execution — "what ran on this machine"

### `AmcacheParser` — Amcache.hve
`Amcache.hve` records programs that have existed/run, with SHA1 hashes and timestamps — gold for finding malware that ran even if deleted.
```bash
AmcacheParser -f /data/Amcache.hve --csv /data --csvf amcache.csv -i
```

### `AppCompatCacheParser` — ShimCache
ShimCache (in the `SYSTEM` hive) lists executables the OS saw, with paths and last-modified times — execution/presence evidence.
```bash
AppCompatCacheParser -f /data/SYSTEM --csv /data --csvf shimcache.csv
```

### `PECmd` — Prefetch (`.pf`)
Prefetch shows **what ran, when, how many times, and from where** (Windows client OS). One of the cleanest execution artifacts.
```bash
PECmd -d /data --csv /data --csvf prefetch.csv       # all .pf in /data
PECmd -f /data/CMD.EXE-12345678.pf                   # single file, console view
```

### `appcompat` (AppCompatProcessor) — correlate execution at scale
Ingests Amcache/ShimCache from **many hosts** into a DB and runs anomaly/stacking modules (find the one weird binary across a fleet).
```bash
python2 /opt/appcompatprocessor/AppCompatProcessor.py mycase.db --load /data/hosts/
python2 /opt/appcompatprocessor/AppCompatProcessor.py mycase.db stomp     # timestomping check
```

---

## 3. Filesystem & Disk

### `MFTECmd` — NTFS `$MFT`, `$J`, `$LogFile`
Parses the Master File Table: **every file's** name, size, and the 8 MAC timestamps (incl. `$STANDARD_INFO` vs `$FILE_NAME` to spot timestomping).
```bash
MFTECmd -f '/data/$MFT' --csv /data --csvf mft.csv
MFTECmd -f '/data/$J'   --csv /data --csvf usnjrnl.csv     # USN journal = file create/delete history
```

### Sleuth Kit — `mmls` / `fls` / `icat` / `tsk_recover`
Raw disk-image forensics and **file recovery**.
```bash
mmls /data/disk.dd                       # list partitions + offsets
fls -r -o 2048 /data/disk.dd             # recursive file listing (offset from mmls)
icat -o 2048 /data/disk.dd 12345 > out   # extract file by inode
tsk_recover -e -o 2048 /data/disk.dd /data/recovered   # recover ALL files (incl deleted)
```

### `bulk_extractor` — feature carving
Scans an image/file for emails, URLs, credit cards, PII, network packets — no filesystem needed.
```bash
bulk_extractor -o /data/bulk_out /data/disk.dd
```

---

## 4. Registry & User Activity

### `regripper` — RegRipper 3.0 (plugins bundled, offline)
Runs targeted plugins against a registry hive to pull persistence, USB history, network configs, user accounts, etc.
```bash
regripper -r /data/SYSTEM   -f system   > /data/system.txt
regripper -r /data/NTUSER.DAT -f ntuser > /data/ntuser.txt
regripper -r /data/SOFTWARE -p runkeys             # single plugin
```

### `RECmd` — Eric Zimmerman's registry engine (batch)
Power-user registry parsing with batch files (e.g., pull dozens of forensic keys at once).
```bash
RECmd --d /data --bn /opt/eztools/RECmd/BatchExamples/Kroll_Batch.reb --csv /data
```

### Other EZ artifact parsers (each is a command)
- **`SBECmd`** — ShellBags (folders a user browsed, even deleted): `SBECmd -d /data --csv /data`
- **`RBCmd`** — Recycle Bin (`$I` files): `RBCmd -d /data --csv /data`
- **`LECmd`** — LNK shortcuts (recently opened files, with origin volume): `LECmd -d /data --csv /data`
- **`JLECmd`** — Jump Lists (per-app recent items): `JLECmd -d /data --csv /data`
- **`SrumECmd`** — SRUM DB (per-app network bytes + runtime, last ~30 days): `SrumECmd -f /data/SRUDB.dat -r /data/SOFTWARE --csv /data`
- **`WxTCmd`** — Windows Timeline activity DB: `WxTCmd -f /data/ActivitiesCache.db --csv /data`
- **`bstrings`** — forensic string search with regex presets: `bstrings -f /data/file.bin --ls "password"`

---

## 5. Memory Forensics — Volatility 3 (`vol`)

Analyzes RAM dumps. **Windows/Mac/Linux symbol packs are baked in (~900MB)** so it identifies the kernel and runs offline on any standard dump.
```bash
vol -f /data/mem.raw windows.info                 # identify OS/build first
vol -f /data/mem.raw windows.pslist               # processes
vol -f /data/mem.raw windows.pstree               # parent/child tree
vol -f /data/mem.raw windows.netscan              # network connections
vol -f /data/mem.raw windows.malfind              # injected/hidden code
vol -f /data/mem.raw windows.cmdline              # process command lines
vol -f /data/mem.raw windows.dumpfiles --pid 1234 # carve a process's files
vol -f /data/mem.raw windows.hashdump             # local account hashes
```
(Swap `windows.` for `linux.` / `mac.` for those dumps.)

---

## 6. Malware, Documents & Metadata

### `capa-offline` — capability detection (rules bundled)
Tells you **what a binary can do** (e.g., "encrypt data", "create service", "inject process") by matching Mandiant capa rules — no execution, no internet.
```bash
capa-offline /data/suspicious.exe
capa-offline -v /data/sample.dll        # verbose: which rules + addresses
```

### `floss` — deobfuscated strings
Like `strings`, but also extracts **stacked/encoded/obfuscated** strings malware hides (C2 domains, keys).
```bash
floss /data/sample.exe > /data/floss.txt
```

### `yara` — signature scanning (two rule sets bundled)
```bash
yara -r /opt/yara-rules/index.yar /data                 # Yara-Rules community set
yara -r /opt/yara-signature-base/index.yar /data        # Neo23x0 signature-base (broader)
yara -r /opt/yara-signature-base/index.yar -s /data/sample.exe   # -s = show matching strings
```

### Didier Stevens suite — malicious documents
- **`oledump`** — analyze OLE/Office docs, dump macros: `oledump /data/invoice.doc` then `oledump -s A4 -v /data/invoice.doc`
- **`pdfid`** — quick PDF risk triage (JS, OpenAction…): `pdfid /data/file.pdf`
- **`pdf-parser`** — dig into PDF objects/streams: `pdf-parser -a /data/file.pdf`
- **`emldump`** — analyze `.eml` email files
- **`zipdump`** / **`base64dump`** — inspect archives / decode embedded blobs

### `exiftool` — file metadata
Author, timestamps, GPS, software, embedded data for images/docs/media.
```bash
exiftool /data/photo.jpg
exiftool -r -csv /data/images/ > /data/meta.csv
```

---

## Typical investigation flows

**"I have a triage collection (KAPE output) of a Windows host":**
`chainsaw hunt` + `hayabusa csv-timeline` for the story → `PECmd`/`AmcacheParser`/`AppCompatCacheParser` for execution → `regripper`/`RECmd` for persistence → `MFTECmd` for the file timeline.

**"I have a memory dump":**
`vol windows.info` → `windows.pstree` / `windows.netscan` / `windows.malfind` / `windows.cmdline` → `windows.dumpfiles` to carve, then `capa-offline`/`floss`/`yara` on the carved binary.

**"I have a suspicious file/doc":**
`exiftool` + `capa-offline` + `floss` + `yara`; for Office/PDF use `oledump`/`pdfid`/`pdf-parser`.

**"I have a full disk image":**
`mmls` → `fls`/`tsk_recover` to recover files → `bulk_extractor` for PII/IOCs → mount artifacts and run the Windows tools above.

---

*Everything is offline and self-contained. `dfir` reprints this menu inside the container. Reports go to `/data`.*
