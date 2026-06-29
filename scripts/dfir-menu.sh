#!/usr/bin/env bash
# `dfir` — reprint the toolbox menu. Evidence is mounted at /data.
cat <<'MENU'
============================================================================
  DFIR-AIO  —  offline forensics toolbox      (evidence mounted at /data)
============================================================================
 EVENT LOGS    chainsaw  hayabusa  EvtxECmd
 EXECUTION     PECmd  AmcacheParser  AppCompatCacheParser  prefetch  appcompat
 FILESYSTEM    MFTECmd   mmls fls icat tsk_recover (Sleuth Kit)
 REGISTRY      regripper  RECmd  regipy-dump  registry-diff
               SBECmd RBCmd LECmd JLECmd SrumECmd SumECmd WxTCmd
               RecentFileCacheParser VSCMount bstrings
 MEMORY        vol            (Volatility 3 + Win/Mac/Linux symbols baked in)
 MALWARE/DOCS  capa-offline  floss  yara
               oledump  pdfid  pdf-parser  emldump  olevba  exiftool

 Baked-in offline data:
   Sigma rules      /opt/chainsaw/sigma          (chainsaw)
   Sigma mappings   /opt/chainsaw/repo/mappings/sigma-event-logs-all.yml
   Hayabusa rules   /opt/hayabusa/rules
   YARA rules       /opt/yara-rules/index.yar  /opt/yara-signature-base/index.yar
   capa rules       /opt/capa-rules
   RegRipper plugins/opt/regripper/plugins
   Vol3 symbols     /opt/volatility3/symbols

 Examples:
   chainsaw hunt /data -s /opt/chainsaw/sigma \
            --mapping /opt/chainsaw/repo/mappings/sigma-event-logs-all.yml --csv --output /data/_chainsaw
   hayabusa csv-timeline -d /data -o /data/_hayabusa.csv
   PECmd -d /data --csv /data --csvf _prefetch.csv
   vol -f /data/mem.raw windows.pslist
   capa-offline /data/sample.exe
   yara -r /opt/yara-signature-base/index.yar -s /data/sample.exe

 Type `dfir` to reprint this menu.
============================================================================
MENU
