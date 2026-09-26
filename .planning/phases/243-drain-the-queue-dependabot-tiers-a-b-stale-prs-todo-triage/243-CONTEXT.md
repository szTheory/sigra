# Phase 243: Drain the Queue — Dependabot Tiers A/B, Stale PRs, Todo Triage - Context

**Gathered:** 2026-09-24 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Drain the live Dependabot and stale-PR queues with truthful, reviewable outcomes. Merge the named Tier A bumps together and Tier B bumps one at a time, verifying each merged dependency's locked version against its PR title and observing the required green gate between Tier B merges. Close the eight named stale phase/recapture PRs with an individual stated reason while preserving their branches. Give each todo in the execution-start pending inventory exactly one keep, close, or defer disposition with a reason; do not fix todos during triage. Create or correct the required FUT records and file, but do not implement, Dependabot grouping policy. Phase 243 does not depend on a 1.5.1 release and does not delete branches.
</domain>

<decisions>
## Implementation Decisions

### Queue inventory and todo dispositions
- **D-01:** Triage the complete `.planning/todos/pending/` inventory frozen at execution start. The inventory currently contains 66 markdown todos; the 41-todo figure in project-level research is historical. Avoid a rolling-until-empty scope that can grow during triage.
- **D-02:** Give every inventoried todo exactly one disposition (keep, close, or defer) and a clear reason. Close only when the evidence supports completion. An earlier `resolves_phase` owner or a resolved-sounding status in the file is not completion evidence by itself.
- **D-03:** Respect the roadmap boundary that approximately 12 todos owned by earlier phases close as a side effect of those phases, not through Phase 243 fixes. They still receive an honest triage disposition; keep or defer them until the owning phase supplies close evidence.
- **D-04:** Reuse and correct existing todo files when they represent a required FUT identity; create only missing identities. At least FUT-01, FUT-03 (`example_unit_smoke`), and likely FUT-05's existing release-related record overlap existing todos. Verify each diagnosis before treating it as the required record; do not create duplicates solely to satisfy the “five plus two” wording.
- **D-05:** The triage commit may modify only `.planning/todos/`, and triage itself fixes zero todos. Capture the exact sorted execution-start inventory and its per-file disposition evidence so completeness is reproducible.

### Dependabot merge sequence and recovery
- **D-06:** Preserve the roadmap's fixed tiers and merge order: Tier A (`attest-build-provenance`, `@anthropic-ai/sdk`, `zod`, `otplib`) as one batch; Tier B (`oban`, `hammer`, `flop_phoenix`, `threadline`, `credo`, `@axe-core/playwright`) individually. Confirm each merged locked version from `mix.lock` or `package-lock.json` against the PR title; branch names are not evidence.
- **D-07:** After each Tier B merge, wait for `ci-gate` to be observed green on `main` before starting the next. For Threadline PR #226, require `library_tests_dep_off` green. Re-verify the `hackney ~> 4.7` override against Threadline 0.9.0 and either remove it or retain it with a recorded reason. Preserve #215's same-line `# vX.Y.Z` action pin comment. New Credo findings become todos, not fixes.
- **D-08:** If a merge is blocked or the gate turns red, pause the sequence and capture the PR, merge SHA, actual locked version, failing job, Actions run, and pre-merge baseline comparison. Revert only when evidence ties the failure to that dependency bump. If unrelated, record the failure and a concrete resume condition; do not repair unrelated behavior, waive a required check, or proceed to the next Tier B PR while the required gate is not green.

### Stale PR closure
- **D-09:** Inspect each of the eight stale PRs and post an individually accurate closing reason that states whether its work is superseded, obsolete, or deferred, with a successor or evidence link where available. Index the PR number, head/base refs, disposition, reason, and verification in phase evidence. A generic “stale” comment or phase-artifact-only explanation is insufficient when the public PR has no reason.
- **D-10:** Verify the closed state using `gh pr list --state closed` and inspect each PR's closing comment. Do not delete any branch; #211/#219 bases remain candidates for Phase 245 and must stay resolvable through this phase.

### the agent's Discretion
- The phase researcher/planner may select the exact machine-readable inventory/evidence format and command sequence, provided the above scope boundaries, causal evidence, and GitHub authorization constraints remain explicit and every required claim is verifiable.

### Folded Todos
- All todos pending at the execution-start inventory are in scope for disposition because QUEUE-04 says every pending todo. The inventory is 66 markdown files as of 2026-09-24; record exact paths at execution time rather than treating fuzzy todo-match results as the authoritative list. The approximately 12 earlier-phase-owned items remain pending until their owners produce closure evidence.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase contract and requirements
- `.planning/ROADMAP.md` §Phase 243 — fixed tiers, merge verification, stale PRs, todo dispositions, scope boundaries, and phase dependencies.
- `.planning/REQUIREMENTS.md` §Drain the queue (QUEUE-01, QUEUE-03, QUEUE-04) — acceptance criteria; §Deferred to a Future Milestone (FUT-01…FUT-05) — required future records.
- `.planning/PROJECT.md` §Current Milestone: v1.48 CLEAN-BASELINE — historical queue thesis and original estimate; use live pending inventory for execution scope.
- `.planning/METHODOLOGY.md` — automation-first verification, decisive defaulting, and escalation threshold.
- `.planning/phases/242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1/242-SAFETY-CLOSEOUT.md` — Phase 242 closeout boundaries; Phase 243 must not infer that release or registry actions occurred.

### Repository research and prior operational evidence
- `.planning/research/SUMMARY.md` — v1.48 research synthesis and prior queue-count discrepancy.
- `.planning/research/FEATURES.md` — why dependency queues need deliberate review and why grouping is a separate durable-policy change.
- `.planning/research/PITFALLS.md` — prior risks around bulk merges and silent PR closure.
- `.planning/INBOX-TRIAGE.md` — prior Dependabot review precedent; use for process lessons, not current PR state.
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` — repository-specific CI/CD, Dependabot, release, and maintainer-practice research.

### Live repository surfaces to verify during planning/execution
- `.github/dependabot.yml` — active dependency update ecosystems and schedules.
- `.planning/todos/pending/` — execution-start inventory and disposition targets; its current population is volatile.
- `mix.lock` and `test/example/priv/playwright/package-lock.json` — actual locked versions after dependency merges.
- `scripts/ci/wait-for-ci-gate.sh` and `.github/workflows/ci.yml` — existing green-gate observation seam and required CI topology.
- `test/sigra/planning/phase_234_action_pinning_contract_test.exs` — action pin annotation contract relevant to PR #215.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/ci/wait-for-ci-gate.sh` and the existing CI workflow provide the gate-waiting pattern; planning should establish that it observes the exact `main` commit after each Tier B merge and fails closed.
- `.planning/todos/pending/*.md` files already carry diagnostics and ownership/history. Inspect file contents and live evidence before updating disposition; preserve the original diagnosis when correcting stale status.
- `test/sigra/planning/phase_234_action_pinning_contract_test.exs` enforces same-line action version annotations, so PR #215 must retain its `# vX.Y.Z` comment.

### Established Patterns
- The project prefers live Actions API evidence over YAML inspection or claims, and requires evidence of the intended job rather than relying on an aggregate status alone (`.planning/METHODOLOGY.md`, Phase 243 success criteria).
- Phase queue work is sequenced to keep failures attributable: one batch for Tier A, one-at-a-time Tier B with a green-gate boundary, and Playwright PR #213 held for Phase 244.
- Planning todos are queue records, not permission to expand the current phase into their implementation.

### Integration Points
- Dependabot PRs update `mix.lock`, the example Playwright `package-lock.json`, or pinned workflow references; validate the resulting lock/config state after merge.
- GitHub PR state/comments and Actions job results are external evidence sources for closure and merge claims.
- Phase 245 consumes refs retained here, particularly bases of #211/#219; Phase 244 consumes the decision to leave #213 alone.
</code_context>

<specifics>
## Specific Ideas

- Optimize for maintainer trust: every close or merge should leave a human-readable reason, a verifiable state change, and enough evidence to resume safely after a blocker.
- Keep the dependency grouping proposal as a filed todo only; changing Dependabot policy is outside this queue-drain phase.
- User requested research-led recommendations that use relevant repository prompts and project goals. Apply only the lenses relevant to queue operations: maintainer/developer ergonomics, supply-chain security, release engineering, SRE/evidence quality, least surprise, and planning honesty. UI/visual-design lenses do not apply to this phase.
</specifics>

<deferred>
## Deferred Ideas

- Implementing Dependabot `groups:` — separate durable-policy work, not part of draining current PRs.
- Fixing any todo, unrelated dependency regression, new Credo finding, or unrelated CI failure — retain or defer it for its owning phase/milestone.
- Merging Playwright PR #213 — Phase 244 owns its isolated visual-drift measurement and merge/defer decision.
- Deleting branches or PR head/base refs — Phase 245 owns branch pruning after dependent PRs are closed.
- Any registry or release mutation not already explicitly in scope — requires its own authorization and phase boundary.

### Reviewed Todos (not folded)
- No matched pending todo is excluded from QUEUE-04 disposition scope. Todos owned by earlier phases are not fixed or closed here; their evidence-backed completion remains with those owners.
</deferred>

---

*Phase: 243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage*
*Context gathered: 2026-09-24*
