# Phase 245: Branch Prune — Local and Remote - Context

**Gathered:** 2026-09-27 (assumptions mode)
**Status:** Ready for planning, gated on Phase 244 completion before branch deletion

<domain>
## Phase Boundary

Prune stale local and remote branches after their dependents are resolved. Preserve the
documented safety refs on `origin`, protect every open PR head and base, and prove every
object SHA in a committed pre-prune ref snapshot remains resolvable after pruning. Do not
run `git gc`, `git reflog expire`, or any `--prune=now` variant. Phase 244 must complete
before any branch deletion; its separate blocker remains outside this phase.

</domain>

<decisions>
## Implementation Decisions

### Prune Readiness
- **D-01:** Phase 245 may be planned while Phase 244 is unfinished, but no branch deletion may occur until Phase 244 is complete and its ref-dependent work is resolved. The Phase 242 contract blocker and draft PR #283 remain Phase 244 work; do not fix or absorb them here.

### Object Recoverability
- **D-02:** Commit a pre-prune `git for-each-ref` snapshot, then prove after pruning that every recorded SHA remains resolvable with `git cat-file -e`, checking against that committed snapshot. Do not run `git gc`, `git reflog expire`, or any `--prune=now` variant as part of Phase 245. Keep the existing historical audit unresolved; Phase 245 does not claim to prove command absence for earlier milestone windows. Leave stashes untouched, consistent with Phase 237 D-09.

### Open PR Exclusions
- **D-03:** Derive the exclusion set from the live `gh pr list --json headRefName,baseRefName` result, protecting both head and base refs. Recheck open PR state and base-ref integrity after pruning. Keep `gsd/238-generated-auth-runtime-proof-evidence` while PR #219 still uses it as its head; prior inventory is not a substitute for the live execution-time check.

### Safety Refs on Origin
- **D-04:** Preserve these named refs on `origin`: `ci/phase-235-16-source-complete`, `safety/local-main-before-release-cleanup-*`, and `archive/local-main-pre-235-recovery`. Preserve each existing ref's type and object identity. Publish a required local-only ref when its name is absent remotely; if the remote already has that name at a different object, stop and reconcile rather than force-update it. Preserve `archive/local-main-pre-235-recovery` as its existing tag.

### Local Prune Concurrency
- **D-05 (user decision, 2026-09-28):** Keep local apply fail-closed until a verifiable shared repository-wide maintenance coordinator exists and every branch/worktree mutator honors it during the deletion window. Git cannot atomically combine expected-OID ref deletion with worktree registration, and the repository currently has no shared coordinator. Do not re-enable local deletion based only on a preflight or a private helper lock. Plan 245-09 is halted, and REPO-04 remains blocked; after a shared coordinator exists, plan its integration with `$gsd-plan-phase 245 --gaps`. The current census of zero eligible local heads does not satisfy the unchanged-eligible-delete criterion.

### Evidence Feasibility
- **D-06 (process guardrail, 2026-09-29):** Before creating or executing another gap-closure plan, run a read-only preflight for every pinned baseline, cited blob, full-window history source, and independent trust registry the plan requires. Save a machine-readable ready/blocked result first. If a historical source or trust root did not cover the past window, preserve `unknown` and stop; do not add more audit implementation to try to reconstruct it. Any replacement baseline or changed historical acceptance criterion requires explicit approval because it changes the evidence contract.

### Rebaseline From Available Sources
- **D-07 (user decision, 2026-09-29):** The available authoritative sources are this local Git checkout and GitHub. The pinned historical baseline is unavailable from both, so do not search additional backup services or claim the commit was deleted. Replan current-state PR/ref protection around a fresh, immutable pre-mutation snapshot captured from the local checkout, GitHub's complete live open-PR inventory, and exact live origin refs. Compare current identities at the mutation boundary and afterward; do not require the unavailable historical 11-row base-OID equality. Preserve the prior PR mismatch audit and 30-row cleanup-history audit as explicitly unresolved historical records. This rebaseline does not waive D-05's shared-coordinator gate or any current PR, safety-ref, object-retention, and exact-OID checks.

### the agent's Discretion
- Choose the snapshot and machine-readable evidence formats, plus the exact prune command sequence, provided the roadmap criteria remain directly reproducible and every remote mutation is preceded by a verified allowlist and current PR exclusion set.

### Reviewed Todos
- Keep `.planning/todos/pending/2026-09-26-phase-244-mix-ci-blocked-by-phase-242-hex-contract.md` separate. It blocks Phase 244 resumption, but resolving it is not part of branch pruning.

</decisions>

<specifics>
## Specific Ideas

- Treat the committed snapshot and the post-prune object check as evidence, not merely an inventory or an assertion in prose.
- The stale-PR inventory from Phase 243 is historical context only. Query open PR heads and bases again immediately before pruning and verify their state afterward.
- The existing origin tip of `ci/phase-235-16-source-complete` and its divergent local tip must not be force-aligned; preserve each identity and prove the recorded SHAs remain available.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and project constraints
- `.planning/ROADMAP.md` §Phase 245 — success criteria, dependencies, and prohibited object cleanup.
- `.planning/REQUIREMENTS.md` §Clean git working state (REPO), REPO-04 — branch pruning and SHA-resolvability contract.
- `.planning/PROJECT.md` — v1.48 milestone boundary and explicit limits on history cleanup.
- `.planning/STATE.md` — standing verification constraints and current Phase 244 blocker.
- `.planning/METHODOLOGY.md` — automation-first evidence and decisive-default lenses.

### Git recovery and ref handling
- `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-CONTEXT.md` D-09 — prior stash disposition; keep stash handling out of this phase.
- `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-GIT-OBJECT-SNAPSHOT.md` — committed ref/object snapshot precedent.
- `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-RESEARCH.md` — worktree, stash, and object-recoverability hazards.
- `.planning/phases/238-tag-guard-then-tag-deletion/238-CONTEXT.md` D-12 through D-15 — allowlisted ref deletion, SHA capture, and the branch holding prior tag objects.
- `.planning/phases/238-tag-guard-then-tag-deletion/238-EVIDENCE.md` and `238-VERIFICATION.md` — actual tag deletion and object-resolvability evidence.
- `.planning/decisions/003-tag-delete-list.tsv` — recorded tag object and commit SHAs relevant to prior reachability.
- `.planning/decisions/003-hex-release-versioning-no-tag-derived-publish.md` — allowed non-release `archive/` tag namespace.
- `scripts/maintainers/delete-planning-tags.sh` — dry-run-default, literal allowlist, and separately verified local/remote mutation pattern.

### PR exclusions and readiness
- `.planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-CONTEXT.md` D-10 — stale PR branches were retained for Phase 245 review.
- `.planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-STALE-PR-EVIDENCE.json` — historical head/base identities, including PR #219.
- `.planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-03-SUMMARY.md` — PR #219 carryover.
- `.planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-CONTEXT.md` — Phase 244's locked scope and merge/defer decision.
- `.planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-03-SUMMARY.md` and `continue.md` — current blocked status and separate prerequisite todo.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `237-GIT-OBJECT-SNAPSHOT.md` — reuse its committed-snapshot evidence approach, while defining a Phase 245 schema that records the complete pre-prune ref set needed by the roadmap criterion.
- `scripts/maintainers/delete-planning-tags.sh` — reuse its dry-run-first, explicit-name allowlist, and local/remote separation safeguards where they fit branch pruning.
- `243-STALE-PR-EVIDENCE.json` — reuse the head/base inventory as historical context, but refresh it from GitHub at execution time.
- `git cat-file -e` — established in `237-RESEARCH.md` and `scripts/ci/stale-render-guard.sh` as a direct object-existence check.

### Established Patterns
- Live external state must be observed at execution time; committed inventories from Phases 237, 238, and 243 are precedents, not proof of current refs or PR state.
- Destructive Git work uses explicit refs and verified local/remote passes, not broad globs.
- The milestone forbids garbage collection and reflog expiry, and stash handling was explicitly left untouched in Phase 237 D-09.

### Integration Points
- Local branch refs and `origin` refs are the objects being pruned or preserved.
- GitHub open PR head and base refs define the dynamic exclusion set; re-query them before mutation and verify PR state after.
- Phase 244 completion is a prerequisite for pruning; the current Phase 242 contract todo remains separately scoped.

</code_context>

<deferred>
## Deferred Ideas

- Resolve `.planning/todos/pending/2026-09-26-phase-244-mix-ci-blocked-by-phase-242-hex-contract.md` within Phase 244's separately scoped recovery work before branch deletion can proceed.
- Any newly discovered cleanup work is recorded as a new todo rather than fixed during this phase.

</deferred>

---

*Phase: 245-branch-prune-local-and-remote*
*Context gathered: 2026-09-27*
