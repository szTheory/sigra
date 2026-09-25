<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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

### Deferred Ideas (OUT OF SCOPE)
- Implementing Dependabot `groups:` — separate durable-policy work, not part of draining current PRs.
- Fixing any todo, unrelated dependency regression, new Credo finding, or unrelated CI failure — retain or defer it for its owning phase/milestone.
- Merging Playwright PR #213 — Phase 244 owns its isolated visual-drift measurement and merge/defer decision.
- Deleting branches or PR head/base refs — Phase 245 owns branch pruning after dependent PRs are closed.
- Any registry or release mutation not already explicitly in scope — requires its own authorization or phase boundary.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| QUEUE-01 | Dependabot PRs are merged in tiers on a proven-green gate, checking lockfiles against PR titles. | Live PR inventory and repository CI/gate seams are identified; plans must collect merge SHA, exact lock values, and Actions job evidence. |
| QUEUE-03 | Close eight stale phase/recapture PRs with an individual reason before branch pruning. | Context identifies reason/comment and retained-ref evidence requirements; live PR list is mutable and must be re-read at execution. |
| QUEUE-04 | Disposition every execution-start pending todo exactly once, changing only todo files in the triage commit. | Current inventory count is 66 markdown files; a sorted inventory snapshot and per-file structured disposition validator provide reproducible coverage. |
</phase_requirements>

## Summary

Phase 243 is an operational queue-drain rather than a code feature. The important implementation pattern is a series of bounded, evidence-producing transactions: inspect live state, mutate only the explicitly named PR/todo records, then re-read public state and preserve a machine-readable receipt. **HIGH confidence:** phase contract and scope come from the roadmap and CONTEXT; the pending directory currently contains 66 markdown files. **MEDIUM confidence:** GitHub state can change before execution, so named PR numbers, titles, refs, and required checks are an execution-time assertion rather than a plan-time constant.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Dependabot merges and merge sequencing | GitHub PR / maintainer operations | CI / Actions, local lockfiles | The merge decision occurs on GitHub; package lockfiles and Actions jobs prove the resulting state. |
| Stale PR closure and reason audit | GitHub PR / maintainer operations | Git refs | Comments and closed state are public GitHub records; branch objects must remain resolvable. |
| Pending todo triage | Repository planning records | Git history | Dispositions are repository files; one commit is constrained to `.planning/todos/`. |

## Standard Stack

- `gh` CLI is the repository's existing interface for PR and Actions inspection. [VERIFIED: phase context and `gh pr list --repo szTheory/sigra --state open --json ...` run during this research]
- `git`, `mix.lock`, and `test/example/priv/playwright/package-lock.json` establish merged source state and exact locked package versions. [CITED: `.planning/phases/243-*/243-CONTEXT.md`, canonical refs]
- GitHub Actions API/job-level result inspection is required; aggregate PR status is not enough. [CITED: `.planning/METHODOLOGY.md`, Automation-First Verification; phase context D-07]
- Machine-readable JSON is recommended for inventory and PR evidence because exact coverage and one-to-one dispositions need deterministic checks. [ASSUMED: format recommendation; no existing phase evidence format is mandated]

## Architecture Patterns

1. **Freeze before mutation.** Capture the sorted `pending/*.md` path inventory once at execution start and hash or persist it. Every disposition row must map to exactly one frozen path; do not discover scope by repeatedly globbing as items move.
2. **Sequence causal changes.** Tier A is one batch. Tier B is individual merges with a completed green `ci-gate` on `main` between each. After every merge, compare PR title to the post-merge lockfile value; do not infer a version from a branch name.
3. **Use read-after-write evidence.** For PR merges/closures, retain PR URL/number, head/base refs, merge/close state, SHA where applicable, comments, workflow run URL/SHA, and the exact required job conclusion. On a failure, stop and preserve diagnostic evidence before any corrective action.
4. **Separate disposition from implementation.** Todo triage changes only planning records and does not patch the issue described by a todo. Existing required FUT records should be corrected/reused where identity and diagnosis match.

## Don't Hand-Roll

- Do not build a new GitHub API client; use `gh` for read/write operations and retain machine-readable JSON output.
- Do not build a generic todo taxonomy or rolling backlog processor; implement only the phase's fixed execution-start snapshot and the three allowed dispositions.
- Do not treat Dependabot branch labels as version authority. Read the merged lockfile entry and compare it to the PR title.

## Common Pitfalls

- GitHub open PR state can drift between planning and execution. Re-query every named PR immediately before acting and stop if identity/base/title differs materially.
- A green aggregate check can hide a missing job. Verify `ci-gate` on the exact `main` SHA; additionally verify `library_tests_dep_off` for Threadline #226.
- Retrying or reverting a failed merge without causal evidence can destroy attribution. Capture pre-merge baseline and failing job; revert only when the bump caused the failure.
- Closing the eight stale PRs without a specific public comment fails the intent even if the status is closed. Never delete branches here.
- The research notes and current STATE.md contain older todo totals (36/41); the phase context's 66 current markdown files supersedes those historical counts. Recount and snapshot at execution start.
- New Credo findings and discovered failures are filed as todos; they are not fixes in this phase.

## Project Constraints (from AGENTS.md)

- For admin UI work, follow `guides/reference/admin-ui-principles.md` and `guides/reference/admin-design-contract.md` (not applicable to this operations-only phase).
- Preserve `sg-*` cascade-layer/BEM, Rail Accent assets, and Light/Dark/System modes if UI scope appears (UI work is out of scope).
- Keep Playwright/admin tests deterministic: role selectors, stable hooks, LiveView readiness, no sleeps (no UI tests are in scope).
- Automation-first verification: deterministic tests/browser automation/CI polling and committed machine-readable evidence replace manual verification where available; retry transient failures once; diagnose deterministic failures; never waive or misstate missing evidence; do not expand phase scope.
- GitHub CI polling: at most one watcher per workflow run; `gh run watch <run-id> --repo szTheory/sigra --compact --interval 60 --exit-status`; inspect `gh api rate_limit` before long watches; if REST core budget is <=250, stop polling until reset; 403/429 is a hard stop until reset/retry time.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `gh` | PR inventory, merge/close, Actions evidence | Yes | available in session | None for public GitHub evidence |
| `git` | lockfile/ref validation and scoped commit | Yes | available in session | None |
| Mix/Elixir | `mix.lock`, Threadline override evaluation, relevant CI diagnosis | Repository toolchain | verify on execution host | Hosted Actions evidence for CI; do not claim local probe if unavailable |
| Node/npm | Playwright package-lock verification for named bumps | Repository toolchain | verify on execution host | Hosted Actions evidence |

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Phase-specific shell/Node checks plus GitHub Actions job results |
| Config file | `.github/workflows/ci.yml` and repository scripts under `scripts/ci/` |
| Quick run command | `git diff --check` plus scoped JSON/inventory validators authored by the plan |
| Full suite command | No product code changes are planned; use the repository's CI evidence for dependency merges and the exact required Actions jobs |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| QUEUE-01 | Merged versions agree with PR titles and required gates are green per sequence | External integration/evidence | `gh pr view ... --json ...` + `gh run view ... --json ...` and lockfile parsing | No phase validator yet; plan should add a read-only evidence validator |
| QUEUE-03 | Each named stale PR closed with public reason and refs retained | External integration/evidence | `gh pr list --state closed ...` plus per-PR comment/ref checks | No phase validator yet |
| QUEUE-04 | Frozen pending inventory has exactly one disposition per todo; triage commit touches only todo tree | Deterministic script/git diff | `git diff --name-only <base>..<triage-commit>` and inventory JSON validation | No phase validator yet |

### Sampling Rate
- Per mutation: capture before/after structured evidence and validate the exact changed object.
- Per dependency gate: observe once per unique Actions run using one watcher, then fetch structured summary once.
- Phase gate: validate all phase evidence against roadmap criteria and confirm final evidence commit scope.

### Wave 0 Gaps
- Add a phase-scoped validator for sorted inventory and disposition uniqueness, todo-only changed paths, PR closure evidence, and dependency/title/lockfile rows; keep it outside product CI unless independently justified.

## Sources

### Primary (HIGH confidence)
- `.planning/ROADMAP.md` Phase 243 — fixed tiers, success criteria, dependencies and phase boundary.
- `.planning/REQUIREMENTS.md` — QUEUE-01, QUEUE-03, QUEUE-04 requirement text.
- `.planning/phases/243-*/243-CONTEXT.md` — decisions D-01 through D-10 and live surfaces.
- `.planning/METHODOLOGY.md` — automation-first verification and evidence discipline.
- `gh pr list` live output — open Dependabot PR identities observed 2026-09-24; execution must refresh.

### Secondary (MEDIUM confidence)
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` — repository-specific CI and dependency maintenance lenses; advisory material, not authority over the locked phase contract.

## Metadata

**Confidence breakdown:** Scope HIGH (locked context and roadmap); implementation patterns HIGH (existing GitHub/Actions and git interfaces); live PR inventory MEDIUM (mutable external state); exact future dispositions LOW until execution evidence is gathered.

**Research date:** 2026-09-24
**Valid until:** Recheck live GitHub and todo inventory at execution start.
