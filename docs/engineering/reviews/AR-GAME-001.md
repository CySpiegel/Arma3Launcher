# GAME-001 independent recovery review

Reviewer: /root/launch_contract_review, Astra High; read-only. Candidate
1a4a77ce9acf0d15c834a0004a3e076918509903, source manifest
f0a56daaa9ddd2104f995537cd4fe887fa114f2647615b5c0f83362c83638f74.

Findings: (1) LaunchPlanner conforms to ARCH-001r2 by emitting bare-space
mod paths, but native argv preservation does not establish interpretation by
the eON Windows-style parser. This is a failed contract assumption. (2) Existing
planner tests assert that assumption and the app-model harness discards the plan.
(3) Original A4 remains incomplete without actual loaded-content evidence.

The installed wrapper exposes GetCommandLineA/W and CommandLineToArgvW strings;
the support log confirms C:\Users path mapping. Both selected directories contain
PBOs. The official Mac guide documents embedded quotes around spaced values.
This supports a narrowly scoped quoting correction, not proof of runtime cause.
No evidence supports moving mods or replacing discovery/NSWorkspace/UI.

Required candidate checks: exact argument bytes for empty/single/multiple lists,
original paths/order, Unicode, trailing slashes, deduplication, mixed DLC/Workshop,
unsafe path rejection and an injected model boundary capturing the selected
Standard bundle and complete plan. Independent gate/review and local commit
precede real verification. Positive loaded-mod information for ACE and CBA is
required; argv, handoff, pictures or file existence cannot close GAME-001.
Native and optional DLC remain separate coverage.

No code was written by this reviewer. Full findings and command receipts are in
the collaboration transcript. Root persisted this report before adjudication.
