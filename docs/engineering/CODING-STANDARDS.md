# Architecture-selected patterns and maintainable coding standards

These standards apply to every handwritten source file, test and executable script.
Architecture must define the concrete project/language rules and observable checks
before coding is dispatched. A pattern list or a formatter pass is not architecture
adoption; the standards and chosen patterns must be independently reviewed with
the design at its exact revision. Do not infer permission to implement from this file.

## Choose patterns from the actual problem

Record a compact pattern/convention register in the architecture: the problem and
quality goal, chosen pattern or simpler design, alternatives rejected and why,
applicable modules/boundaries, invariants/dependency direction, tradeoffs and the
review or automated check that demonstrates conformance. Use established patterns
where they solve a concrete need; do not prescribe a framework or elaborate layering
for every project. Reviewers enforce the adopted register rather than personal
style preferences. An architectural departure triggers review and a revised binding,
not an undocumented coding decision. Keep the register current as requirements change.

Define language-specific naming, formatting/linting, module boundaries/public APIs,
error handling, async/cancellation, resource lifecycle, nullability/types, dependency
management, logging/privacy and test conventions where applicable. Name the actual
tools/configuration and explain which checks are automated, manual or pending.
Existing code and stronger applicable standards are reconciled, not silently reset.
No tool or numeric complexity threshold is invented merely to fill a template.

## Functions, modules and reusable helpers

A function should have one clear responsibility and do it well whenever practical.
Use precise names, explicit inputs/outputs and small cohesive units. Separate
transformation/business logic from I/O when that makes behavior easier to reason
about and test. Keep side effects visible; handle errors intentionally and preserve
cancellation/resource cleanup. Avoid unrelated validation, persistence, rendering
and transport work bundled into one method. Orchestration functions may coordinate
several calls for one named outcome; algorithms and transaction boundaries may
justify a larger cohesive function. Document such decisions in review rather than
forcing arbitrary fragmentation or a universal function-length cap.

Reusable helper functions and libraries are welcome. Group them by a coherent
purpose or domain, with clear contracts, ownership, supported inputs/error behavior
and focused tests. Extract stable repeated behavior or a useful independent concept;
prefer composition and existing suitable utilities over duplicate implementations.
Keep helpers close to their consumers until a shared boundary is justified. Export
only the intended API and keep implementation details private. Preserve layering,
dependency direction and platform constraints when sharing code.

Avoid a miscellaneous Utils/Common dumping ground, hidden global state, implicit
I/O, circular dependencies, flag-heavy multi-purpose helpers and abstractions that
obscure simple code. Similar-looking code with different domain semantics need not
share one abstraction. Do not duplicate or fragment behavior solely to satisfy a
line count, nor minify code, remove useful comments or add indirection to evade limits.
Review readability, cohesion, complexity and testability as well as size.

## File size: 800 soft, 1400 hard

Count physical lines including comments and blank lines in every in-scope
handwritten code file. Count a final unterminated line; empty files count zero.
Use the architecture-approved source roots/file types so production code, tests,
helper libraries and handwritten scripts are included. Explicitly list and justify
exclusions such as generated outputs, vendored code and dependency lockfiles; a
filename or newly added generated marker is not enough to self-exempt a file.
Documentation and state/evidence JSON are not handwritten program code, but their
size still affects maintainability and context costs. Review changes to counting
scope/exclusions independently so authors cannot exempt their failing files.

- Up to and including 800 lines: normal review still applies.
- 801–1400 lines: soft-limit finding. The author and reviewer assess responsibilities,
  cohesion, complexity and a possible extraction/split. Record the chosen action or
  a specific rationale for retaining the size; a soft warning is not an automatic
  human-approval request.
- Above 1400 lines: hard-limit blocker. Stop ordinary expansion and block acceptance
  and merge unless there is a valid named human exception. Independent structural
  review and the lead assess decomposition or architecture redesign. Remediation
  that reduces the violation may proceed within its scope; existing oversized files
  are not silently grandfathered or grounds to halt unrelated compliant tasks.

The lead should react when growth is forecast to cross the hard limit, not only
after writing it. If a candidate already crosses it, retain the candidate and raw
line-count evidence for review without treating it as accepted. Each issue review
checks changed files; the integration gate inventories all in-scope files so a
pre-existing violation remains visible. Large files can justify redesign, but size
alone is not proof that the entire architecture is wrong.

## Required human decision for a hard-limit exception

Prefer a concrete refactoring or redesign that brings the file below the limit.
If retaining an oversized file is warranted, the lead prepares a review packet:
exact path and candidate hash/line count; its responsibilities; why splitting is
costly or unsafe; feasible decomposition/redesign options and tradeoffs; independent
review findings; the lead's recommendation; and a proposed bounded exception.
Keep the relevant source/tests and current verification evidence reviewable before
asking the user. If tests/gate are unavailable or blocked, disclose that in the packet.

Only the user can explicitly approve exceeding 1400. Ask for a human review at
that real boundary; silence, timeout, Auto mode, lead/agent approval or a green test
run never grants the exception. Show why the review is needed and the lead's
recommendation. The user may approve the bounded exception or choose refactoring.
An approval records the named file and issue/design scope, allowed purpose and
maximum line count, evidence/candidate identity, human decision and timestamp,
expiry/revisit milestone and any follow-up refactor. No blanket project exemption.
The author or a model cannot create or extend an approved exception.

Verify the exception on each affected review: scope, purpose, ceiling and expiry
must still match. A materially changed purpose, new file, exceeded ceiling or expired
exception requires a new user decision; edits within the already approved bounds
retain that authority and undergo ordinary review. An exception never waives
architecture, correctness, independent QA, full gate or UI acceptance requirements.
Until approved, set the issue awaiting-user with the hard-limit blocker and keep
unrelated authorized tasks moving. Preserve refused/expired decisions as history.
