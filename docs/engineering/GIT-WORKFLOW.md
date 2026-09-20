# Milestone and issue Git workflow

All tracked work, including design, documentation, QA repairs and workflow updates,
uses an issue branch. Conversation and read-only investigation do not require a
new branch. The default and milestone branches are integration targets only.

## Branch graph

| Purpose | Branch | Created from | Merge request target |
| --- | --- | --- | --- |
| Accepted repository baseline | Discovered default branch (usually `main`) | Existing history | None |
| Milestone integration | `milestone/<key>` | Recorded accepted default SHA | Default branch, only at milestone acceptance |
| Issue work | `issue/<key>/<iid>-<slug>` | Recorded current milestone SHA | Its own `milestone/<key>` only |

Use stable lowercase milestone keys such as `m0`; persist their mapping to tracker
milestone IDs rather than inferring identity from titles. Every milestone has one
integration branch. Provision it at a recorded accepted base when branch creation
is authorized; future branches may be provisioned early but must synchronize with
the accepted default before their work starts. Branch creation at an existing
commit is provisioning, not permission to write work directly on that branch.

Never commit work directly on the default or milestone branch. Never push directly
or force-push to either. No issue-to-default MR, wrong-milestone MR, or sibling
milestone merge/cherry-pick can bypass the graph. Every task result returns through
an issue-to-milestone MR, including fixes and review evidence. The lead is the sole
integration owner; workers receive only their assigned issue branch and workspace.
A branch name does not isolate files, build outputs, credentials or processes.
Use separate worktrees for simultaneous writers, and serialize overlapping files
and shared mutable resources. Never switch another active worker's checkout.

## Before writing or dispatching

1. Reconcile Git, live issue/milestone, source and target branches, existing MRs,
   open claims, permissions and dependency evidence. Fetch the target explicitly.
2. Record the tracker issue ID, milestone ID/key/branch, issue branch, exact base
   SHA and workspace in the immutable task packet. Create the issue branch from
   that milestone head before any write; confirm the recorded base is an ancestor
   of the issue branch. Do not branch from the default or a sibling issue.
3. Apply architecture, scope, independent-review, budget and gate guards as before.
   Branch creation or an MR does not authorize coding or resolve a blocked design.
4. Only the assigned issue branch can receive task commits and authorized pushes.
   Set its upstream to the matching remote issue branch, never the milestone.
   Use explicit push source/target refs. Open a draft MR early once a diff exists;
   bind its IID/URL, source, target, issue and milestone to the journal.

## Review and issue integration

The issue MR targets exactly its mapped milestone branch and references the issue
using `Refs #<iid>`. Verify the live issue's milestone, branch mapping, source SHA,
target SHA, dependencies, merge-result tree and current acceptance before merge.
A matching branch spelling alone is not evidence of the tracker relationship.
The candidate author cannot supply its sole independent approval. Agents sharing
one GitHub identity do not create separate native approvals.

Review and test the combined candidate against the current milestone head, using
the actual configured gate. Changed source, target, contract or conflict resolution
invalidates affected review/gate evidence; reconcile and repeat the affected review
and complete required gate. Resolve conflicts on the issue branch (merge the current
milestone into it); do not rewrite protected milestone history. Serialize merges.
Record MR URL, reviewed source/target SHAs, merged commit/tree and receipts, and
verify the remote milestone contains the accepted result before resolving an
`integrated-source` dependency.

Merge and issue acceptance are distinct. Close the issue only after every required
criterion, independent QA and applicable committed-build UI acceptance passes.
Use `Refs`, not automatic closing text, until then; non-default-target MRs may not
auto-close issues at all. Delete an issue branch only after integration and retained
acceptance/recovery evidence; never delete an active or unmerged worker branch.

## Milestone promotion and synchronization

Promote `milestone/<key>` to the default through a separate milestone MR only when
all required milestone issues and exit criteria are accepted. Record the accepted
issue set, scope-bound architecture reviews, combined milestone gate, independent
review and required UI acceptance. Recheck against the actual current default and
record the resulting default commit. A milestone is not complete merely because
its issue MRs merged. Promotion and deployment retain their own authority.

When the default advances, synchronize it into a milestone through an explicitly
identified default-to-milestone synchronization MR, reviewed for the integrated
result; it contains no new direct default-branch work. This is the sole reverse
integration edge, not an issue-delivery shortcut. Document dependent milestone
bases. Cross-milestone `integrated-source` consumers wait for the producer's accepted
default promotion, then synchronize; `approved-contract` work can proceed only
within its independently reviewed contract. Do not import unpromoted sibling code.
If an issue moves milestones, invalidate its branch/contract binding and reconcile
a new correctly based branch and MR before more work; never silently retarget it.

## Enforcement and authorization

Where authorized, protect the default and `milestone/*`: direct push **No one**,
force push disabled, merge restricted to the integration role. Require unresolved
MR discussions to be resolved when supported. Audit every matching project/group
rule, deploy-key exception and effective permission; permissive overlapping rules
can weaken protection. Read back settings and retain evidence. A successful API
response alone is insufficient. If a rule must be replaced, keep an equivalent
restrictive guard during replacement and remove it only after the final rule is
verified. Do not weaken a stronger existing restriction.

Separate verified server controls from manual policy. Protected branches restrict
pushes; they do not validate issue milestone membership, MR source/target ancestry,
independent AI review, architecture adoption or test completeness. Until a reviewed,
installed and exercised CI/controller gate enforces those checks, the coordinator
must check them before dispatch and merge, and unattended integration depending on
those checks is unavailable. Missing automation never means passing validation.
Do not enable a required pipeline with no executable gate/runner and claim it works.
Administrative ability to change protection is not authorization to bypass it.

Persist a `git_workflow` record with branch patterns/default, milestone mappings,
protection read-back and manual/automated guard statuses. Task packets bind branch
and base identity; attempts bind worktree, pushed source and MR identity; acceptance
binds reviewed source/target and merged result. On restart reconcile those against
GitHub before resuming. Preserve historical direct-main commits as history; do not
rewrite them or falsely attach retrospective MRs. Apply this rule to new work.

The user's existing scope authorizes only its necessary actions. Installing this
protocol does not independently grant future commit, push, merge, deployment or
spending authority. Report pending review or unavailable automation explicitly.

## Initial repository binding (2026-09-19)

GitHub: https://github.com/CySpiegel/Arma3Launcher (created private by the lead at
the user's request). Git is initialized locally. The sole empty ancestry seed
`a3ef844` was created before installing this protocol; it contains no product or
workflow files. Do not retroactively describe it as reviewed product integration.
Default: `main`; milestone M0: `milestone/m0`; initial work branch:
`issue/m0/001-foundation`, based on the empty milestone head.

The file board is currently authoritative for task definitions and execution.
No external issue tracker has been adopted; `001` is the local task key, not an
invented GitHub issue number. Remote PR number/URL and target SHAs remain null
until actual publication. Local construction, checks, review and candidate
commits may proceed on the recorded issue branch. Remote push and PR integration
remain blocked until separately authorized; do not equate local commits with
integration. Before publishing, provision the empty accepted baseline and
milestone refs as repository initialization, reconcile exact ancestry, and open
issue-to-milestone PRs. Branch provisioning is not product integration.

Server protections have not been installed or verified. GitHub access to a
private repository does not prove branch-protection entitlement. MR/PR direction,
architecture, review, acceptance and branch ancestry are manual coordinator
guards; no unattended enforcement is installed.
