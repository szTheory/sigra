# Phase 50: Nyquist validation & CI gate hygiene - Context

**Gathered:** 2026-04-21  
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the **v1.4 milestone process** slice owned by ROADMAP phase **50**: bring **Nyquist / validation posture for phases 41–44** in line with honest evidence (not merge theater), and make **CI + docs** explicit for **long-budget / subprocess-heavy** work called out in **`.planning/v1.4-MILESTONE-AUDIT.md`** (e.g. `golden_diff_test.exs`, installer golden host under `test/fixtures/install_golden/`). No net-new product auth features — process, contracts, and gates only.

**Source of scope:** `.planning/ROADMAP.md` phase **50**; `.planning/REQUIREMENTS.md` milestone process row; `.planning/v1.4-MILESTONE-AUDIT.md` Nyquist table + `tech_debt` notes.

</domain>

<decisions>
## Implementation Decisions

### D-50-01 — Nyquist outcome for phases **41–44** (hybrid + single policy table)

- **Adopt a hybrid**, not a uniform forced `nyquist_compliant: true` nor unchecked permanent `false`.
- **Where per-task rows bind to stable, CI-reproducible commands** (scoped `mix test` paths, merge gates already cited in `41–44` verification work): run **`/gsd-validate-phase`** (or equivalent manual execution of the same checklist) until **`nyquist_compliant: true`** is **honest** for that phase’s claimed scope.
- **Where rows are expensive, redundant with dated merge-gate receipts (phases 47–48), or “human / matrix” scaffolding (phase 42)**: keep **`nyquist_compliant: false`** only if paired with a **short, grep-able waiver row** (phase **36**-style discipline): **owner**, **date**, **pointer** to superseding artifact (`NN-VERIFICATION.md`, CI job name, SHA band), and **trigger to reopen** (e.g. templates changed → re-run nested golden contract).
- **Publish one policy table** (in phase **50** planning artifact or `MAINTAINING.md` micro-section): for each of **41–44**, state **Full Nyquist** vs **Waiver + superseding evidence** — so contributors have **one** place to read the model (principle of least surprise).

### D-50-02 — Expensive in-repo tests (`golden_diff`, `phx.new`, etc.) without breaking local/CI parity

- **Do not introduce default `ExUnit.configure(exclude: …)`** for suites that today run under plain **`mix test`**, unless the project **explicitly** amends `test/test_helper.exs` and `CLAUDE.md` in the same effort — today’s invariant is: **default local `mix test` matches what the primary library CI step runs** (no silent skipped blind spot).
- Prefer **engineering hygiene** first: **`@tag timeout:`** (or module-level) on subprocess-heavy tests, **deterministic env**, **pinned `phx_new` / archive steps** already in CI, and **reducing redundant shell-outs** where possible.
- Add **CI layering without hiding tests from default `mix test`**: e.g. **scheduled** workflow on `main` for **ecosystem drift** (Hex/Phoenix bumps), **stricter timeouts / retry policy** only where it does not mask real failures, and **clear MAINTAINING.md** expected wall-clock for maintainers.
- **Path-filtered *additional* checks** are allowed for **nested** workloads (see D-50-03) — they add signal, they do not remove tests from the default root suite.

### D-50-03 — Installer golden nested host (`test/fixtures/install_golden/`)

- Add a **flat Mix alias** **`mix ci.install_golden`** (same pattern as **`mix ci.audit_45`**: top-level string key in `aliases/0`) that is the **single cited command** for: deps + compile + DB lifecycle + **`mix test`** inside the fixture tree, with **Postgres env vars** documented verbatim next to the alias (copy/paste contract).
- **CI:** dedicated job using **`.tool-versions` / strict BEAM** + Postgres + **`mix archive.install phx_new`** as needed, with **cache keys scoped to the fixture tree** (do not reuse root `deps`/`_build` cache keys for the nested app — footgun).
- **Triggers:** on **PRs**, reuse the **same path filter family** as `installer_milestone_audit` (`priv/templates/sigra.install/`, `lib/sigra/install/`); **always** run on **push to `main`**; optional **`schedule`** weekly for drift. This matches “release gate runs in CI” **without** pretending root **`mix test`** loads excluded fixture paths.

### D-50-04 — What “validation artifacts updated” means (atomic doc unit)

Treat these as **one logical documentation change** when closing batch **41–44** / phase **50**:

1. **Per-phase `NN-VALIDATION.md` (41–44)** — tables + **`nyquist_compliant`** + deferral text aligned with D-50-01; **no** `true` while notes still say “batch deferred to 50” for rows being closed in this pass.
2. **`50-VERIFICATION.md`** (create when executing) — **receipts**: dated SHA, literal merge-gate commands, PASS lines — **links** to updated `NN-VALIDATION.md` files; does **not** redefine `nyquist_compliant` (single boolean lives in VALIDATION frontmatter).
3. **Index docs** (`MAINTAINING.md`, `docs/uat-ci-coverage.md`, `ROADMAP.md`) — **at most** short status + **links** to phase **50** artifacts; **avoid** duplicating full command strings in three places (drift footgun). If an index already asserts batch status incorrectly, **micro-edit** in the same change set.

### Claude's Discretion

- Exact YAML wording in `50-VERIFICATION.md`, choice of weekly vs biweekly schedule, and whether `50-VALIDATION.md` is a batch rollup vs “pointer only” file — as long as D-50-01–D-50-04 invariants hold.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone scope & debt
- `.planning/ROADMAP.md` — Phase **50** goal + success criteria
- `.planning/REQUIREMENTS.md` — Milestone process row (phase **50**); traceability table
- `.planning/v1.4-MILESTONE-AUDIT.md` — Nyquist table (**41–44** `nyquist_compliant: false`), `tech_debt` bullets (golden_diff timeout class, installer long budget)

### Prior patterns & evidence
- `.planning/phases/36-retroactive-nyquist-validation/36-CONTEXT.md` — waiver / inventory pattern (VAL-01..03)
- `.planning/phases/41-backup-codes-ga-product-closure/41-CONTEXT.md` — GA-01 / install golden / example router alignment
- `.planning/phases/45-oauth-ops-c1-signoff/45-VERIFICATION.md` — scoped merge gate narrative (optional full root suite)
- `.planning/phases/49-phase-45-verification-aud08-c1/49-CONTEXT.md` — `mix ci.audit_45` as contractual alias precedent

### Runtime contracts
- `CLAUDE.md` — Postgres prerequisite for `mix test`
- `mix.exs` — `test_load_filters`, `test_ignore_filters`, `aliases` (`ci.audit_45`)
- `.github/workflows/ci.yml` — `library_tests`, `installer_milestone_audit`, Postgres service wiring

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`mix ci.audit_45`** — precedent for a **named scoped test bundle** cited by verification docs
- **`test_load_filters` / `test_ignore_filters` in `mix.exs`** — root `mix test` intentionally does **not** compile `test/fixtures/install_golden/**`; nested contract must be **explicit alias + job**
- **`installer_milestone_audit` job** in `.github/workflows/ci.yml` — path-filter pattern to reuse for D-50-03

### Established Patterns
- **No default ExUnit excludes** in `test/test_helper.exs` — primary `mix test` remains the honest default for library tests that participate in that step
- **Postgres env vars** mirrored in CI and `CLAUDE.md` — keep new aliases/jobs consistent (`PGUSER`, `PGPASSWORD`, `PGHOST`, `MIX_ENV=test`)

### Integration Points
- `mix.exs` `aliases/0` — add `"ci.install_golden"` next to `"ci.audit_45"`
- `.github/workflows/ci.yml` — new job or extend installer-related jobs; optional `schedule`
- `MAINTAINING.md` / `docs/uat-ci-coverage.md` — link-level updates per D-50-04

</code_context>

<specifics>
## Specific Ideas

- User selected **all** gray areas and requested **subagent research** + **one coherent recommendation set** (executed here as locked decisions **D-50-01..04**).
- Cohesion principle: **named Mix aliases + honest VALIDATION/VERIFICATION split + CI layering** — same architectural story as **`mix ci.audit_45`**, extended to nested installer golden and batch Nyquist closure.

</specifics>

<deferred>
## Deferred Ideas

- **Tag-based default exclusion** (`:slow` / `:install`) for tests currently in default `mix test` — **deferred** unless explicitly reconciled with `test/test_helper.exs` “no default tag exclusions” invariant in a future phase.
- **SOC2-style duplicated attestations** across many index docs — avoid; use links from D-50-04.

</deferred>

---

*Phase: 50-nyquist-ci-gate-hygiene*  
*Context gathered: 2026-04-21*
