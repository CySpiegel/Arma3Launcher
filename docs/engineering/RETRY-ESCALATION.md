# Codex coding repair, specialist escalation and redesign

The active lead automatically applies this bounded recovery policy within an
already-authorized issue. No new permission is needed for ordinary in-scope retries
or advisory escalation. This is coordinator policy, not an installed unattended
controller. Preserve the selected primary model and effort. Commands execute through
the responsible agent's direct tools with raw stdout/stderr, exit/error status and
full-output artifacts when response limits require a marked excerpt. There is no
LLM runner or routing agent; the lead routes work and interprets evidence.

## Cheap repair loops and assigned roles

| Stage | Implementation | Advisory judgment | Initial + repairs | Code attempts/cycle |
| --- | --- | --- | --- | --- |
| Sol repair | sol_worker / gpt-5.6-sol / medium | Lead triage | 1 + 3 | 4 |
| Astra-assisted repair | sol_worker / gpt-5.6-sol / medium | Read-only astra / gpt-6-astra / high | 1 + 2 | 3 |

A failed test does not automatically escalate. Give ordinary fixable failures to
the current Sol worker with the raw output, affected criterion, candidate SHA and
remaining count. Apply a bounded fix and retest. Minor syntax, type, lint and logic
issues can remain cheap. Each implementation attempt includes its verification;
running several prescribed checks is not several code attempts.

Escalate from the initial Sol allowance when exhausted, the worker explicitly cannot
solve it, or at least two consecutive attempts repeat the same normalized failure
without meaningful change or a new evidence-backed hypothesis. Do not promote merely
because one check failed. Preserve successful fixes and verified state. Stop/release
the old writer, checkpoint the issue branch and hand off the contract, adopted design,
diff, raw logs, attempted hypotheses and counters. Never add an overlapping writer.

The Astra High specialist diagnoses from evidence and returns precise scoped repair
advice; Sol Medium applies it and runs checks directly. Astra does not edit source.
Allow one initial bounded diagnosis and at most one follow-up for new unresolved
judgment per assisted cycle. Do not spend an advisory call on every minor repair.
The three assisted implementation attempts belong to the same originating incident;
model/worker replacement, a new task revision or restart never resets the counts.
Independent routine QA is a separate Sol attempt, with Astra High for consequential
adjudication. Keep authorship distinct from independent approval.

This profile uses the user's two assigned model families. It does not invent a Sol
High/Max implementer, a third coding model or a command-runner agent to mimic another
runtime's tier count. Limits are seven implementation attempts per coding cycle,
at most one independently approved redesign round and one further coding cycle:
fourteen implementation attempts per originating incident. Budget/time/capability
and scope guards can stop earlier; those ceilings are not a spending reservation.

## Tests and infrastructure failures

Retest every repair with relevant focused checks, then run the complete real gate
and independent review on the combined issue/milestone candidate before acceptance.
A focused pass never replaces the full gate or required committed-build UI acceptance.
Never weaken assertions, skip required checks, change acceptance to fit code or
rerun flaky failures unchanged until a passing sample appears. Review test semantics,
not only counts. Raw receipts and missing/truncated reports remain explicit.

The lead distinguishes code/reasoning failures from environment outages, credentials,
permissions, unsupported models/efforts and unavailable agent capacity. Retry an
infrastructure action at most twice only when safe/idempotent and authorized; first
reconcile uncertain effects. Keep infrastructure counters separate. A rejected
no-effect dispatch is not a failed code attempt and never justifies a more expensive
model, bypass or redesign. A crash after writes counts once effects are reconciled;
a resumed action attaches to its existing attempt rather than repeating mutations.

## Exhausted assisted repairs: Astra Max review and redesign

Stop affected coding and invalidate its eligibility. Checkpoint the exact candidate,
raw failure evidence and resume point on the issue branch. Dispatch a fresh independent
Astra Max architecture/root-cause reviewer who did not author the relevant design or
failed repair advice. Then task a separate Astra Max design advisor with the review
to propose a revised architecture/specification or implementation/validation plan.
Keep both specialists read-only; the lead or a scoped Sol Medium documentation worker
persists their design output without substituting implementation judgment for it.

The exact advisory route uses gpt-6-astra with reasoning_effort max, fork_turns none,
and a role that actually permits that effort. The native astra role is fixed at High;
never claim it ran Max. Prefer the skill's read-only graph_astra_max agent profile
when the runtime can select it, or a supported default-role direct override with an
explicit read-only packet and verified effective permissions. Block if unavailable;
do not silently lower effort, switch models or change the primary's settings.

Review distinguishes an architectural defect from an implementation/validation-plan
problem. Redesign only the supported scope; no invented product change, spending or
broad rewrite. During design, no product code, tests, migrations or executable gate
scripts are written. Allow one revised draft and one correction (two design writes)
in the single redesign round. Independently review the exact persisted revision;
the design advisor and its document implementer cannot approve their own design.
Record all findings, exact hashes and scope-bound adoption before code can resume.
Unresolved review failures stop at NeedsDecision; no budget or status can create a pass.

After a passing redesign/plan revision is adopted, one further coding cycle can
start with Sol, using a new contract but the same originating incident. Preserve
both per-cycle and cumulative counts. If it exhausts too, stop with the evidence
and options; do not mint another issue/revision/incident to evade the bound. Human
hard-size exceptions and out-of-scope product decisions remain explicit decisions.
User stop cancels owned work and never automatically restarts on resume.

## Journal and acceptance

Before dispatch and after result, record incident/root issue, contract revision,
cycle/stage, per-stage/cumulative code/design/advice/infra counts, failure category
and fingerprint, hypothesis, raw receipts, branch/worktree/base/candidate/target,
pending action identity and effects, retry/escalation reason, requested/observed
model and effort, remaining allowance/budget, architecture invalidation and the
review/adoption binding. Only the lead writes these records. Reconcile GitLab and
Git on resume; unchanged pending actions are not duplicated.

Model escalation is separate from Git promotion. Issue MRs still target their own
milestone; independent review, current combined gate and applicable human acceptance
remain required before merge. Lead-driven policy is not runtime-enforced automation.
