# Handoff

The user confirmed ACE and CBA both appear in-game after the quoted-path fix,
then requested "Build and publish on my github". Publication is complete:
[beta release](https://github.com/CySpiegel/Arma3Launcher/releases/tag/v0.1.0-beta.1) and [draft source PR](https://github.com/CySpiegel/Arma3Launcher/pull/1). The repository remains private.

## Published build

Tag v0.1.0-beta.1 points to5c4ada5260c48992349b7131b459cf6957e7970d.
Source manifest:5f1c05e727a47bccb16de286ee6ffb36c2dd69012aa1cc24a2d6bfcf5f4ffb82.
Source branch:issue/m0/001-foundation; PR target:milestone/m0; default:main.
Main and milestone remain at accepted empty seed
a3ef844f4c9035e590c6d1f2dddb270ac9a50cf7. The source PR is intentionally draft:
publication is authorized, but complete milestone acceptance is not inferred.

Universal Release zip includes arm64+x86_64, macOS14minimum, valid ad-hoc
signature; not notarized. Downloaded GitHub archive hash matches local build.
See [release receipt](releases/v0.1.0-beta.1.md) for exact hashes, build checks
and distribution limits. Source changes are one planner line plus regression
tests; original Steam paths and selection order are unchanged.

## Verification and remaining acceptance

Independent source QA-001-A8 passes. Root final canonical gate
`bash scripts/gate.sh` exits0:72tests/10suites, strict format and Xcode Debug
warnings-as-errors. Universal Release build/extraction/signature checks pass
independently. No source writer or background build remains active.

The reported selected-mod failure is user-confirmed fixed for ACE+CBA in
Standard(Rosetta) on5c4ada5. Native game mode and optional DLC combinations remain
untested. Automatic dependency selection/order is not implemented. Preserve
the user's ACE preset, selected ACE thenCBA, Standard mode, SkipIntro/NoSplash
on, Windowed off and System appearance. User last started the game; do not
terminate it. Earlier selection delay is confirmed fixed; artwork box shape was
verified by CUA screenshots, with broader UI/user acceptance still open.

## Workflow and evidence

A8 is cycle2 attempt1, cumulative8, same M0-001 incident. All seven previous
attempts remain; one scoped recovery design round passed. Adopted ARCH-001r3
and independent AR-001-R3 plus ARCH-002r1/ARCH-003r2. Current user routing
supersedes the older local Max pin: actual specialist execution was Astra High.
No pending architecture ratification decisions. The board owns execution state.

Canonical gate needs normal Xcode cache access; approved escalation works. Its
script writes A6-worker output, so retain per-candidate copied evidence.
Current source/archive/checks: .build/evidence/M0-001-A8-author/;
root gate:.build/evidence/publication-gate.log; release:.build/release/.
The user-approved Debug launcher remains at
.build/DerivedData/Build/Products/Debug/Arma3Launcher.app.

Native CUA: use full launcher path and AX indices. Avoid Dock (past2hour stall)
and coordinate actions failing noWindowsAvailable. Game-window inspection was
not approved and stalled245seconds; no workaround occurred. User provided
positive loaded-mod confirmation. No game was launched or quit by root.

Publication authorization covers this source and beta, not future waves.
Preserve private visibility. No paid signing, milestone merge, unrelated
services, global settings or permission weakening is authorized.
