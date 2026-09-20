# Handoff

The latest local test-drive code is the commit containing this A7 update on
`issue/m0/001-foundation`; exact receipt:
`.build/evidence/M0-001-A7-author/commit.txt`. Source manifest:
`f0a56daaa9ddd2104f995537cd4fe887fa114f2647615b5c0f83362c83638f74`.
Independent code review and full gate pass: 68 tests in 10 suites, strict
formatting and Xcode Debug warnings-as-errors build. See QA-001-A7. Xcode's
optional AppIntents metadata extraction warning is recorded in that report.
The board owns task state. No source writer is active. The user confirmed the
prior 1.5-second selection delay is fixed. A7 makes the visible artwork background
follow the picture aspect ratio in the shared row/detail component.

## Working behavior and remaining acceptance

- Native Mac launcher locates the installed game and original Workshop directories,
  presents optional/platform DLC separately, saves presets and generates native argv.
- One artwork descriptor, reader and view serves Workshop and DLC. Actual local
  diagnostics decode4Workshop logos and15Steam-cache DLC images. MissingCSLA has
  no cached picture and correctly keeps a fallback. No addon copies or Steam writes.
- Advanced panel remains visible; Light→System appearance mismatch is corrected.
- Row-wide double-click waiting is removed. Identical successful settings saves
  are deduplicated; failed saves retry. The user confirmed the click delay is
  fixed. A7 also matches artwork boxes to picture proportions in the shared view.
- Automatic mod dependency selection/ordering is not implemented. Selected order
  is preserved. Actual in-game content loading and both game modes are unverified.
- User visual/test-drive acceptance remains open. Do not mark the project done
  merely because the app builds or the user has opened an earlier preview.

## App and verification

App: `.build/DerivedData/Build/Products/Debug/Arma3Launcher.app`.
Canonical gate: `bash scripts/gate.sh` from repository root. Direct execution
requires normal Xcode package-cache access; approved escalation succeeded, while
an earlier sandbox-only Xcode invocation exited74. No accepted failing baseline.
Author artifacts are preserved under `.build/evidence/M0-001-A6-author/`; the
root independent log is `.build/evidence/A6-independent-gate.log`.

Native UI uses CUA and full app-path selection. Do not select Dock (a prior call
stalled over2hours) or repeat coordinate drag/click calls returning noWindowsAvailable.
Accessibility-index interactions and direct app reopening work. Native captures
are in the tool transcript; no generated image substitutes for a running app.
Preserve the user's current configuration during further checks. Latest observed
launch configuration:0content selections,0presets,AppleSilicon,SkipIntro/NoSplash on,
Windowed off, empty advanced args,System appearance. No game was launched by us.

## Authority and workflow

User authorized building with the graph team, creating the private GitHub repo,
local candidate commits, actual app launch, shared DLC/Workshop artwork and the
click-latency correction. All addons must remain in Steam's original folders.
Private repo:https://github.com/CySpiegel/Arma3Launcher. No source has been pushed;
remote publication, merge and release require their own authorization.
Milestone `milestone/m0`, default `main`, seed
`a3ef844f4c9035e590c6d1f2dddb270ac9a50cf7`. Candidate is not a remote integration.

Adopted:ARCH-001r2/AR-001-R2, ARCH-002r1/AR-002-R1, ARCH-003r2/AR-003-R2.
Current immutable packet:engineering/tasks/M0-001-R3.md. A7 preserves the incident
counters and is the last assisted attempt; any further failed repair of this same
incident requires the documented independent redesign review. A temporary
Sol capacity error resumed the same model and attempt successfully.

Next:reopen the committed build, finish native appearance/selection smoke, then
hand it to the user for the requested test drive. Record their feedback in the
board and TODO. Never infer visual approval or successful game loading from silence.
