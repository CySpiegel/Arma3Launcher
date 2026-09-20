# Shared engineering workflow

Use the full graph for substantive or coordinated engineering work. Conversation, project
discovery, direct lookups, tiny edits, and routine setup corrections stay with the primary and
need no board card, worker dispatch, or full team lifecycle. Scale checks and review to the
change; reuse applicable reviewed architecture and preserve existing authorization safeguards.
If the project's purpose is unclear, discuss it with the user before adding workflow machinery.

## Installed mode

Mode: `coordinator-managed`

The main lead is the sole board writer and dispatcher. Workers request assignments and return results to the lead. The file board does not provide durable atomic multi-session claims, lease fencing, crash recovery, or exactly-once effects. Use one active coordination session. A runtime controller is a separate product task. Setup itself grants no product-construction authority. On 2026-09-19 the user separately authorized building this product ("ok lets make it, use the graph team") and creating the GitHub repository. Dispatch remains limited by architecture/gate readiness; the initial stack/gate bootstrap is included in that build authorization.

## Sources of truth

- Execution in coordinator-managed mode: `docs/engineering/board.json`
- Execution in controller-backed mode: the audited controller store; `board.json` is its identified revisioned projection
- Policy: this file
- Source and approved documents: Git at exact revisions
- Resume state: `docs/HANDOFF.md`, pointing to the board
- Deferred or user-only decisions: `docs/TODO.md`, linking to decision/task IDs
- Evidence: immutable artifacts referenced by the board

Do not duplicate live task state in HANDOFF or TODO.

## Teams and authority

- Operator: product intent, spending, releases, and required UI acceptance.
- Main lead: decompose authorized scope, serialize board writes and dispatch, assign review, and integrate evidence.
- Architecture: versioned contracts, dependencies, risks, and technical proposals.
- Development: scoped candidates and prescribed tests; cannot weaken acceptance or approve its own candidate.
- QA: independent scenarios, assertion/candidate review, findings, and assigned verdicts.
- Product/UX: journeys and usability/accessibility criteria before Ready; review the delivered experience.
- Security, platform, documentation, and marketing: create only when relevant to the increment.

Role labels and prompts are not security boundaries. Record the actual filesystem, process, credential, and network enforcement that exists.

## Lifecycle and revisions

### Mandatory architecture gate before coding

Architecture documents requirements, boundaries, contracts/data, dependencies, failure behavior,
relevant risks, applicable UI journeys, and test/delivery strategy before any software is written.
An independent reviewer who did not author the design reviews the exact revision for gaps, issues
and contradictory assumptions. Use a separate read-only Astra High attempt for consequential
architecture. Record findings and evidence using `templates/architecture-review-template.md`
and the board's `architecture_reviews` records.

Resolve blocking findings through design revision and independent re-review. The lead adopts
the passing revision within existing product authorization. The architecture author cannot
self-approve. Unresolved blocking findings cannot be waived merely to start coding.

Every coding task binds to the adopted design revision/hash and independent passing review ID
covering its scope before Ready, claim, dispatch or first write. This includes scaffolding,
test code, migrations, coding prototypes and controller/bootstrap tasks. An executable-gate
bootstrap exception does not bypass architecture review. Missing or stale approval blocks coding.
Discussion, design documents, non-code wireframes and read-only investigation may proceed.

Reuse a current approval for tasks already covered by its scope and assumptions. If the design
changes or implementation reveals an architectural gap, stop affected coding, invalidate its
binding, and obtain independent review/adoption of the revised design before resuming. Post-code
QA and integration validation remain separate requirements.

Stages: `Draft → Ready → Building → Verifying → Integrating → Integrated`. Work then moves to `AwaitingUserAcceptance → Done` when adopted policy requires human acceptance, or directly to `Done` when it does not. `NeedsDecision`, `Canceled`, and `Superseded` are explicit outcomes; canceled and superseded work is never Done.

Claim, submission, verification, integration, and completion are separate transitions. Acceptance changes require a new immutable revision, dependency impact analysis, and affected evidence invalidation. Dependencies form a DAG and use `approved-contract` or `integrated-source` edges. Feedback creates a bounded repair attempt or a new revision, not a cycle.

After restart, reconcile the prior claim, process, workspace, and uncertain effects against reality before dispatch. Paused, canceling, or canceled coordination state denies new claims.

## Git branches and merge requests

Install and follow `docs/engineering/GIT-WORKFLOW.md` from the skill's
`references/git-workflow.md`. Work on issue branches created from their milestone
branch; issue MRs return only to that milestone, and accepted milestone MRs promote
to the default. Bind branch/base/MR/source/target/result identities in task and
acceptance records. Direct work or pushes to integration branches are prohibited.
Keep verified server protections distinct from manual review/routing guards.

## Evidence and integration

Evidence binds task/acceptance revision, exact base and candidate or integrated tree, dependencies, gate, environment, command, exit status, logs, and reports. A report cannot override a nonzero exit status; missing required checks remain incomplete.

The candidate author cannot be its sole QA approver. One integration owner builds the combined candidate on current head and runs the full configured gate. Changed trees require review of the affected delta. Focused repair checks never replace the final gate.

Independent writers cannot own overlapping files. Assign exclusive ownership for migrations, lockfiles, generated clients, ports, databases, and mutable build outputs. Use parallel work only with actual enforced workspace/process/resource separation; otherwise serialize it.

Commit, push, deploy, and user acceptance are separate authorities. UI signoff occurs on the committed, gate-green build after automated checks and review, and records the exact build.

## Routing

Preserve the selected primary model and effort. Use `sol_worker`, gpt-5.6-sol,
medium for scoped writes/tests/docs/routine independent QA. Use read-only `astra`,
gpt-6-astra, high for consequential design/diagnosis/adjudication. Pin model and
effort with fork_turns none; no child agents. Commands run directly, with raw receipts,
and no LLM command relay. Astra advice is applied by Sol, not the advisor.

Final recovery requires independent Astra Max review/redesign through a supported
read-only graph_astra_max profile or explicit default-role model/effort override;
never mislabel the High-fixed native role. Verify capability, preserve scope and
separate authors from approvers. See RETRY-ESCALATION.md and the Codex adapter.

## Scheduling, repair, and budget

Default limits: two child workers, one integration lane and built-but-unintegrated WIP of two. Coding recovery permits Sol initial + three repairs, then Astra High advice with Sol initial + two repairs; exhausted assisted repair triggers independent Astra Max review/redesign. At most seven implementation attempts/cycle, one redesigned cycle and fourteen implementation attempts/incident. Preserve counts across revisions/replacements/resumes. Non-coding review retains its declared bound.

Prioritize QA, repair, and integration before new development. Within a class, use priority then age; after three bypasses, service the oldest feasible eligible class. Avoid idle model polling.

Budget: record authorized, reserved, measured, estimated, and unknown usage separately. Unknown is not zero. Do not claim token or price enforcement the adapter lacks. Reserve verification capacity; exhaustion blocks dispatch and never implies acceptance.

## Gate

Gate: `bash scripts/gate.sh`

Working directory: repository root

Execution status: bootstrap script exists; consult board evidence for current
candidate status. Worker-reported success is not independent acceptance.

Script: `scripts/gate.sh`. Initial worker receipts were preserved under
`.build/evidence/M0-001-A1/`; implementation and validation concerns are being
independently reviewed. The coordinator must run the final gate after repairs.

A separately authorized bootstrap task may create the minimal stack and executable gate under explicit acceptance criteria. Workflow setup alone does not authorize it, and the bootstrap task cannot pass acceptance until that real gate succeeds. For docs-only setup with an existing gate, record `recorded-not-run` unless repository policy requires execution or setup changed executable validation.

## Controller capability audit

Controller status: not present. Atomic claims/fencing, immutable revisions/stale rejection, dependency invalidation, evidence binding, budget enforcement, cancellation/recovery, effect reconciliation, isolation, and adapter model/effort support are unverified. The integration owner is coordinator-serialized. Audit and record these capabilities before changing to controller-backed mode.

## Skills and hook integration

During setup, populate the installed skills map and hook capability ledger from the setup skill's
`references/skills-and-hooks.md`. Preserve this as repository-local guidance so future sessions
do not depend on the personal skill path. Map resume/watchdog to reconciliation, independent
architecture review before coding, relevant design skills before UI implementation, gate/land
to verification and integration, dev-stack/smoke to browser acceptance, and end to handoff.

For each logical hook, record supported runtime event or script path, actual executor, enabled
state, bounded timeout, deduplication rule and verification evidence. Default status is
`not-installed`; do not imply that this template installs hooks. Missing native hooks use
explicit coordinator checks and do not establish unattended enforcement. Skills and hooks
cannot bypass architecture review, manufacture passing evidence, or resume canceled work.

## Stop and recovery

A user stop halts dispatch and session-owned work. Do not restart without explicit authorization. Reconcile prior claims, processes, workspaces, uncertain termination, and effects against actual state before retry or replacement dispatch. No commit, push, deployment, service launch, remote creation, global setting, or product-code change follows from this workflow alone.

## Recovery, standards and review checkpoints

Follow `docs/engineering/RETRY-ESCALATION.md`, `CODING-STANDARDS.md` and
`CODE-REVIEW.md`. The lead schedules independent reviews of issue candidates,
material repairs/integration changes and milestone promotion. Architecture chooses
justified patterns/conventions, single-responsibility functions where practical and
cohesive reusable helpers with clear contracts/tests. Above 800 physical handwritten
code lines triggers maintainability review; above 1400 blocks acceptance/merge until
refactored or explicitly approved by the user after lead options/recommendation.
Preserve bounded retry counters and independent review/adoption after Max redesign.
These lead-driven checks are not an installed unattended controller or executable gate.

When an external tracker such as GitLab already owns task definitions, milestones,
dependencies and shared lifecycle, preserve that authority: board JSON is the
lead-owned dispatch/recovery journal and linked snapshots, not a competing backlog.
File-board authority applies only when no external tracker owns those fields.

## Project bindings and enforcement ledger

- This is a native Swift/SwiftUI macOS app; native UI verification replaces the
  browser-only dev-stack/smoke path. Do not start a web server for this product.
- Authoritative tasking: this repository's file board; GitHub is the source host,
  not yet a separate authoritative task tracker.
- Local repo initialization/ancestry and in-scope candidate commits are part of
  the authorized new-project construction. Push, PR merge, release, signing with
  a paid identity, and deployment require their own authorization.
- One writable checkout and one writer at a time. Read-only investigation and
  independent reviews may overlap with non-conflicting coordinator work.
  Prompts are not filesystem isolation. The host sandbox restricts writes; Git
  metadata actions may need tool-level approval. No global settings are changed.
- A native app without App Sandbox is proposed because Apple's documented
  NSWorkspace argument forwarding ignores arguments for sandboxed callers. This
  is product configuration, not a change to the agent's sandbox. Review it in
  the architecture. Distribution/signing decisions remain separate.
- Usage accounting: no user token/dollar cap supplied; tool does not expose
  reliable token/cost totals. Usage is unknown, never zero. Bound dispatch by
  packet time/tool limits and repair counters; retain one reviewer slot.

| Stage | Installed skill/capability | Application here |
| --- | --- | --- |
| Setup | graph-team-setup | This maintained workflow and board |
| Reconciliation | resume conventions; watchdog | Read board, Git, HANDOFF; inspect actual claims |
| Architecture | Lead plus independent Astra High | Hash-bound review before coding |
| UX | design-taste app | docs/specs/design-brief.md; native light/dark checkpoint |
| Implementation | Sol Medium | One exclusive writer; direct command tools |
| Review | independent Sol; Astra for consequential findings | Exact candidate and assertions |
| Verification | gate | Canonical native gate once bootstrapped; no baseline exceptions |
| Candidate commit | land | Independent gate/review; preserve separate remote authority |
| Native UI | macOS UI automation/manual verification | Committed candidate in both appearances; user verdict required |
| Handoff/stop | end/resume conventions | Cancel owned work and persist exact state |

| Logical hook | Runtime/executor | Status | Bounds/deduplication and evidence |
| --- | --- | --- | --- |
| Coding eligibility | Lead checks board/design/branch | manual | Before each claim; task revision + design hash |
| Worker result | Collaboration event delivered to lead | manual | Once per attempt; record raw result before review |
| Candidate change | Lead invalidates dependent review | manual | Candidate hash + affected scope |
| Gate completion | Lead consumes direct-tool receipt | manual | Command + tree + exit status; never parallel mutable gates |
| Pre-commit/integration | Lead branch/review/gate checks | manual | Exact head and candidate; no server hook |
| UI candidate committed | Lead native-app QA | manual | Build hash + appearance; user acceptance remains open |
| Reconciliation | Lead-driven watchdog | manual | Check workers at 10–15 min, nudge silence >15 min |
| User stop | Lead plus collaboration/process cancellation tools | manual | Stop new dispatch immediately; retain uncertain effects |
| Session end | Lead handoff write | manual | Board revision and latest actual state |

No persistent monitor/loop, native hooks, unattended controller, isolated worker
credentials, remote protections or exactly-once delivery are verified. The
optional repo-local Astra Max role is not installed: this adapter supports a
default-role explicit override but effective read-only enforcement/Max execution
is unverified. Normal Sol/Astra High routes remain available. Native astra is
fixed at High; never claim it ran Max.
