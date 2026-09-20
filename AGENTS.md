# Arma3Launcher working instructions

## Start here

Read [README.md](README.md) for confirmed product scope, the proposed first
increment, and current project state. This project is a native macOS GUI for
configuring the Mac release of Arma 3, including launch methods, purchased DLC,
and downloaded Steam Workshop mods. Read the
[design brief](docs/specs/design-brief.md) before GUI design work; later design
specifications must cite it.

Read [WORKFLOW.md](docs/engineering/WORKFLOW.md) before substantive work and
[GIT-WORKFLOW.md](docs/engineering/GIT-WORKFLOW.md) before branch or integration
operations. The lead alone writes [board.json](docs/engineering/board.json).
This is coordinator-managed; no unattended controller or atomic file claims
exist. Conversation, lookups and tiny edits need no graph lifecycle.

## Authority and construction prerequisites

- On 2026-09-19 the user authorized building the product using the graph team
  and asked the lead to create the GitHub repo. This includes the local project,
  stack/gate bootstrap, tests, native app verification, and local candidate
  commits. GitHub repo creation and local Git initialization are complete.
- Push, remote integration, release/deploy, paid signing, unrelated services,
  global settings, and permission weakening are not authorized by construction.
- Every coding increment, including scaffold, tests, and bootstrap, must refer
  to an adopted architecture revision and an independent passing gap/issue
  review covering its scope before dispatch. Documentation setup is not that
  review or an architecture approval.
- Gate: `bash scripts/gate.sh` from repository root. The bootstrap script exists;
  the board records its exact candidate evidence and independent verification
  status. It must pass independently before candidate acceptance. Never report
  worker claims or absent validation as an independent green gate.
- Preserve existing user edits. Do not move, delete, or rewrite installed game,
  Workshop, or Steam files as part of setup.
- A stop request immediately stops session-owned agents and background work;
  do not restart them without the user's go-ahead.

## Automatic routing

- Preserve the user-selected primary model and effort. Handle conversation,
  discovery, targeted searches, tiny edits, and routine setup locally.
- Delegate substantive bounded routine implementation or investigation to
  `agent_type: sol_worker`, `model: gpt-5.6-sol`,
  `reasoning_effort: medium`, `fork_turns: none`.
- Use read-only `agent_type: astra`, `model: gpt-6-astra`,
  `reasoning_effort: high`, `fork_turns: none` for consequential architecture or
  difficult adjudication; reason locally when the primary is already Astra.
- Pin both model and effort in each dispatch. Provide a self-contained brief
  with objective, exclusions, input revision, dependencies, owned paths,
  deliverables, acceptance checks, authority, bounded time/tool and repair
  allowances, and explicit `no child agents`. Workers are not alone in the
  workspace and must preserve other contributors' edits.
- Use direct tools for commands and retain actual exit statuses. Report a
  missing requested model or capability; do not silently substitute.
- Default to one worker and at most two for independent work. Keep one
  integration lane. This is a shared workspace, not enforced agent isolation;
  serialize mutations unless isolation is actually established. Do not assign
  overlapping writers.
- For long delegated work, check progress every 10–15 minutes and investigate a
  worker silent beyond 15 minutes. The primary integrates results and remains
  the user's single contact.

## Verification and handoff

Scale checks to the change. Gate status and the canonical command live in the
board and workflow. Bootstrap must establish a real gate; do not claim a pass
from a proposed command. Run it independently before a candidate commit; retain
exact revision evidence. Follow the maintained
[coding standards](docs/engineering/CODING-STANDARDS.md),
[independent reviews](docs/engineering/CODE-REVIEW.md), and
[bounded recovery](docs/engineering/RETRY-ESCALATION.md).

Handwritten source, tests and scripts: 800 physical lines is a soft review
threshold; above 1400 blocks acceptance without a named bounded human exception.
No code author supplies its own sole QA approval. One mutation lane at a time.

For UI implementation, a committed, gate-verified wave must precede asking the
user to inspect the UI. User visual sign-off is a completion criterion. Report
any missing commit authorization rather than silently bypassing that safeguard.
