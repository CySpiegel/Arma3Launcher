# Handoff

Active work: verify GAME-001 correction in the game. The user reproduced
it with their ACE preset on the prior build and then closed the game. No game is
currently expected running. Preserve ACE preset, Standard (Rosetta), selected ACE
and CBA, SkipIntro/NoSplash on, Windowed off, System appearance. Do not restore
earlier zero-selection/AppleSilicon state. The board owns exact task state.

## Current work and checkpoint

Committed checkpoint: 1a4a77ce9acf0d15c834a0004a3e076918509903 on
issue/m0/001-foundation. Source manifest
f0a56daaa9ddd2104f995537cd4fe887fa114f2647615b5c0f83362c83638f74.
A7 full gate and independent review passed: 68 tests / 10 suites, strict format
and Xcode Debug warnings-as-errors build. Native screenshots verify proportional
DLC and Workshop artwork backgrounds. Receipt:
.build/evidence/M0-001-A7-author/native-final.json. The user confirmed earlier
selection delay is fixed; artwork geometry user sign-off remains open.

A8 is implemented, frozen and independently verified under M0-001 revision4 and adopted ARCH-001r3 / AR-001-R3.
Independent recovery review AR-GAME-001 identified an unsupported engine parsing
assumption: one native argv value with spaces need not survive the eON Windows
command-line bridge. Candidate correction adds actual double quotes around the
whole -mod path list. Paths, saved order, preflight, transport and UI stay intact.
No source writer is active. Independent QA-001-A8 passes; root full gate exit0:
72tests/10suites, strict format and Xcode Debug warnings-as-errors. The new
local candidate is the commit containing this update; exact receipt will be
.build/evidence/M0-001-A8-author/commit.txt. Source manifest:
5f1c05e727a47bccb16de286ee6ffb36c2dd69012aa1cc24a2d6bfcf5f4ffb82.

All seven prior attempts remain recorded. A8 is cycle2 attempt1, cumulative8.
One scoped recovery design round has passed independent review (one draft, no
corrections). Current user routing selects Astra High and supersedes the older
local Max pin; actual High is recorded accurately. No pending architecture
ratification decisions. ARCH-002r1 and ARCH-003r2 remain adopted and unchanged.

## Verification and next step

Canonical gate: bash scripts/gate.sh from repository root. No accepted failing
baseline. Use approved escalation for normal Xcode package-cache access; sandbox
only Xcode previously exited74. Gate internally writes A6-worker output, so copy
raw logs/manifests into distinct A8 evidence folders. Xcode optional AppIntents
metadata extraction warning is recorded, not a Swift compiler warning.

Source, independent review and root gate are preserved. Commit locally before
asking user to inspect, then reopen
.build/DerivedData/Build/Products/Debug/Arma3Launcher.app through CUA.
Actual game loading requires positive in-game loaded-mod evidence for ACE+CBA;
process argv, preview, PBO existence, logos and NSWorkspace handoff cannot prove
it. Native mode and optional DLC require separate verification. Automatic
approval review rejected root's baseline Play click for lack of explicit launch
permission; no game was started by root and no bypass occurred. User subsequently
clicked Play themselves and confirmed failure, then closed it. Finish corrected
build before any further test-launch permission request.

CUA: use exact full app path and accessibility indices. Do not select Dock
(previous call stalled over2hours) or repeat coordinate actions failing with
noWindowsAvailable. Reopening launcher preserves user settings. Never terminate
the user's game. Native captures are in tool transcript; ignored receipts bind
commit and binary hash.

## Product scope and remaining acceptance

Read Steam/game/Workshop files in place. Never copy, move, stage, symlink or edit
addons or Steam files. Shared artwork loader/view displays4Workshop and15cached
DLC images; missingCSLA lacks cached picture and retains fallback. Advanced panel
and appearance corrections remain verified. Automatic dependency selection/load
ordering is not implemented; saved order is preserved. Broad game compatibility
and user test-drive acceptance remain open.

User authorized graph-team construction, private GitHub repo creation, local
candidate commits and app previews. Private repo:
https://github.com/CySpiegel/Arma3Launcher. No push, remote integration, release or
paid signing authorization. No source pushed; user has been told local-only work
lacks remote backup. Base/milestone seed a3ef844f4c9035e590c6d1f2dddb270ac9a50cf7,
milestone/m0, default main. Candidate commits are not milestone integration.
