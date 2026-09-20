# Read-only installation investigation

Date: 2026-09-19. Investigator: `/root/mac_installation`, requested native
`sol_worker`, `gpt-5.6-sol`, effort `medium`, `fork_turns: none`.
This is the persisted worker report, not independent product acceptance.
Detailed direct-tool receipts remain in that agent's session transcript; no
standalone raw log artifact was produced. No files, Steam/game state or Git were
changed and no app/game was launched by the investigation.

Input README SHA256: `7a50b41478b912e900c40a2d2d43adc02c0532667fbcbeabcaa6d0a7e1ff8214`.
Input design brief SHA256: `b610a6cb07cf6266d8cd841dd236dbee16f337c026aff8b2205af61aca900866`.
Both input hashes matched. User-specific absolute home paths are omitted here.

## Actual installed files

Default Steam game directory contains two bundles:

| Bundle | Executable architecture | Identifier |
| --- | --- | --- |
| ArmA3.app | x86_64 | com.vpltd.Arma3 |
| ArmA3 AS Native.app | arm64 | com.vpltd.Arma3 |

Both plists report 1.84.0/build 20241031.1 and minimum macOS 11. This is bundle
metadata, not proof of the actual game content version. Host: arm64/macOS 27.0.
Bundle IDs collide, so launch modes must be selected by exact bundle URLs.

`libraryfolders.vdf` contains the default library but its `apps` map omits 107410.
Nevertheless `appmanifest_107410.acf` exists with StateFlags 4, UpdateResult 0,
matching download/stage byte pairs, and an actual game folder. Do not rely on
the library apps map for existence.

`appworkshop_107410.acf` reports NeedsUpdate/NeedsDownload 0. Four items appear in
both Installed and Details with matching manifests. The observed logical file
byte totals match the installed manifest sizes; this is not an integrity check.

| Workshop ID | Preferred display name | Top-level addon packages | Bytes observed |
| --- | --- | --- | --- |
| 450814997 | Community Base Addons v3.19.0 | 32 | 4,997,533 |
| 463939057 | Advanced Combat Environment 3.21.2 | 188 | 239,844,420 |
| 620260972 | Arma 3: ALiVE | 65 | 487,228,224 |
| 751965892 | Advanced Combat Radio Environment 2 | 44 | 668,208,314 |

All four have top-level addons folders with PBOs; none supplies a positive
mission-only specimen. ACRE lacks a meta.cpp name but has a literal mod.cpp name.
ACE/ALiVE have nested optional packs; do not automatically select those. Names
may use CRLF, absent fields or expressions; parse data only.

Optional DLC package-bearing folders: Contact (22), GM (64), vn (180), WS (30),
SPE (381), RF (15), EF (43). Appmanifest InstalledDepots includes corresponding
DLC app IDs; some DLC mod.cpp files also confirm names/appIds. These demonstrate
installation, not durable purchase/entitlement. CSLA was not installed.

## Command evidence and limitations

Worker reports relevant `plutil`, `file`, `codesign`, `rg`, `sed`, bounded file
enumeration/byte totals and timestamp checks exited 0. An exploratory broad
listing was truncated and excluded from conclusions. A read of a nonexistent
Arma support directory was tool-rejected before process start; a bounded parent
check subsequently exited 0 and found no relevant directory. No detailed logs
were synthesized after the fact.

Critical untested behavior: game-level C:-mapped paths and spaces through native
argv; game loading the selected addon/optional DLC; LaunchServices collision and
already-running behavior. Purchase entitlement and mission classification remain
unproven by local file evidence.

## Official references

- [Bohemia Mac guide](https://community.bistudio.com/wiki/Arma_3%3A_Play_on_Mac):
  retrieved through indexed official content after direct HTTP 403. It documents
  Mac modes, mod-path arguments and optional DLC loading.
- [Apple NSWorkspace arguments](https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration/arguments):
  arguments apply to a new app instance and are ignored for a sandboxed caller.
- [Apple OpenConfiguration](https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration):
  explicit bundle URL and running-app substitution behavior need deliberate
  configuration and a preflight policy.
