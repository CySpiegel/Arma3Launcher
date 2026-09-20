# Automatic team code-review checkpoints

The active lead automatically schedules these reviews within authorized work; the
user does not need to request each one. The coordinator records the session and
its evidence. This policy is not an installed unattended controller/native hook.
Preserve actual capability limits and do not claim reviews ran from a task status.

## Trigger and bounded review team

Run an independent review of each issue's submitted code candidate before its
issue-to-milestone MR can merge. Review the complete issue diff against its exact
base, adopted architecture/pattern register, CODING-STANDARDS.md and acceptance.
After a material repair, source/target movement or conflict resolution, re-review
the affected delta and interactions; widen to the full candidate if impact is
uncertain. Deduplicate unchanged candidates by task/contract/source/target/check
identities. Cheap focused fix-and-test loops need not launch a whole review team
on every edit, but a changed accepted candidate must not reuse stale sign-off.

Before milestone promotion, conduct a combined independent integration review
against the current default branch, including cross-issue design conformance and
milestone exit criteria. Review scope and combined gate evidence must match the
actual merge-result tree. Review is separate from merge authority and issue/milestone
acceptance. Keep required committed-build UI acceptance after automated checks.

Use one independent routine code/QA reviewer by default, with a separate architecture
specialist for consequential pattern/boundary changes or structural findings.
Security/privacy and Product/UX reviewers participate when the affected scope needs
them. At most two disjoint reviewers concurrently and one integration lane; do not
launch a large team for trivial repairs. The lead assembles the necessary lenses,
not one model per checklist item. Follow the runtime's model routes. The specific
candidate/design author cannot be its sole independent approver.

## What reviewers enforce

- Correctness and meaningful tests against the issue's acceptance; inspect assertions,
  failure paths and behavior, not just passing counts or implementer claims.
- Adopted patterns, module/public-API boundaries and dependency direction; reasons
  for justified exceptions and missing architecture decisions.
- One clear responsibility per function when practical, readable control flow,
  explicit effects, intentional errors/resource handling and manageable complexity.
- Cohesive reusable helper modules with clear contracts/tests; duplication versus
  premature abstraction, hidden coupling and miscellaneous utility dumping grounds.
- The 800-line soft and 1400-line hard file policy, complete counting scope and any
  applicable genuine human exception. Splitting must improve design, not hide size.
- Relevant security, data isolation, concurrency, compatibility and UI/accessibility
  obligations, with targeted specialist review where those boundaries warrant it.

## Findings, repair and evidence

Retain a session record with issue/milestone/MR, exact contract/design/source/target
and combined tree identities, reviewers and actual requested models, checks/raw
receipts, findings with severity/criterion/path, all dispositions and a scope-bound
pass/fail/incomplete verdict. QA decisions belong to independent review; raw tool
execution is evidence only. Direct command execution never supplies an independent acceptance verdict.

The lead sends fixable findings to the current coder through the bounded
RETRY-ESCALATION policy when that profile is installed. Reuse the originating
incident/counters; reopening a finding is not a new free retry budget. Retest every
repair, run the full actual gate before integration, and independently recheck the
changed candidate. Preserve confirmed/refuted/duplicate dispositions; do not drop
findings or weaken acceptance. Pattern/architecture problems stop affected coding
for review/redesign. A hard-size exception requires the user's explicit decision
with the lead's recommendations under CODING-STANDARDS.md.

Missing reviewer capacity, missing real gate or unresolved findings produces an
incomplete/blocked session, not a synthetic pass. Tasks stay review/blocked or
awaiting-user as applicable. Record actual automation/CI coverage separately from
lead-enforced checks; no silent unattended integration is authorized by this policy.
