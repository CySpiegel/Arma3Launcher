# Handoff

The local test-drive candidate is the commit containing this handoff on
`issue/m0/001-foundation`. Resolve the exact SHA with `git log -1`; its receipt is
`.build/evidence/M0-001-A6-independent/commit.txt`. Source manifest:
`aef839af7f9d6c1fd31c0299bc496b0350cd4169d9d26fee2567e77b4d7053cf`.
Independent QA and full gate pass:68tests/10suites, strict formatting, Xcode Debug
warnings-as-errors build. No baseline exceptions. Review: engineering/reviews/QA-001-A6.md.
The board owns exact task state. No source writer is active.

## Working behavior and remaining acceptance

- Native Mac launcher locates the installed game and original Workshop directories,
  presents optional/platform DLC separately, saves presets and generates native argv.
- One artwork descriptor, reader and view serves Workshop and DLC. Actual local
  diagnostics decode4Workshop logos and15Steam-cache DLC images. MissingCSLA has
  no cached picture and correctly keeps a fallback. No addon copies or Steam writes.
- Advanced panel remains visible; Light→System appearance mismatch is corrected.
- Row-wide double-click waiting is removed. Identical successful settings saves
  are deduplicated; failed saves retry. Perceived click latency still needs the
  user's feedback; tool roundtrip timings are not input-latency measurements.
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
Current immutable packet:engineering/tasks/M0-001-R3.md. A6 is assisted attempt2;
all incident counters are preserved, with one assisted repair remaining before
mandatory redesigned-cycle review if the same incident fails again. A temporary
Sol capacity error resumed the same model and attempt successfully.

Next:reopen the committed build, finish native appearance/selection smoke, then
hand it to the user for the requested test drive. Record their feedback in the
board and TODO. Never infer visual approval or successful game loading from silence.
