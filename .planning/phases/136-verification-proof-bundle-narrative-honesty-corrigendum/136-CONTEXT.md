# Phase 136: Verification Proof Bundle + Narrative-Honesty Corrigendum - Context

**Gathered:** 2026-05-28 (assumptions mode, `minimal_decisive` calibration)
**Status:** Ready for planning

<domain>
## Phase Boundary

The milestone-close phase of v1.29 SUITE-INTEGRATION (phases 131-136; 131-135 complete).
Two requirements, **no new `lib/` code**:

- **PROOF-01** — Land the milestone-close proof bundle: forwarder unit + integration
  tests pass; dep-off CI lane (Threadline absent) proves `mix compile && mix test`
  green; `mix test test/sigra/audit/` clean; `mix test` inside `test/example/` clean;
  `mix docs --warnings-as-errors` exits 0; `mix credo --strict` clean; `131-VERIFICATION.md`
  through `135-VERIFICATION.md` all filed; v1.29 milestone artifacts ready to archive in
  the same shape as v1.28. No waivers, no `@tag :skip` additions on v1.29 work.
- **DOC-01** — v1.25 EMAIL-RAILS Mailglass-narrative corrigendum: the library-resident
  `Sigra.Mailers.Adapters.Mailglass` module and `--with-mailglass` installer flag from
  Phase 111/114 did NOT land on the release branch and are NOT supported. Correct
  `MILESTONES.md`, `PROJECT.md`, and note the v1.29 host-owned-wiring posture in
  `CHANGELOG.md` [Unreleased].

**Hard scope anchors (FIXED — not re-litigated):**

- This phase RECORDS proof of an already-green bundle; it does NOT add CI lanes.
- The actual milestone archive (move ROADMAP/REQUIREMENTS into `milestones/`, write the
  audit, relocate phase dirs) is a SEPARATE post-phase step — see D-05.
- DOC-01 is strictly the v1.25 Mailglass narrative. The v1.29 Threadline "forwarder"
  (sometimes loosely called "adapter" elsewhere) is NOT in scope.
- No re-landing of the orphaned Phase 111/114 Mailglass adapter — recipe-only stays the
  supported posture (locked in STATE.md).
</domain>

<decisions>
## Implementation Decisions

### VERIFICATION.md Backfill (PROOF-01)

- **D-01:** **Rename** `.planning/phases/132-threadline-recipe-mailglass-cross-link-recipe/VERIFICATION.md`
  → `132-VERIFICATION.md`. The content already exists (a passing 3/3 report); only the
  filename lacks the dash-prefix PROOF-01 requires. Use `git mv` to preserve history.
- **D-02:** **Create** `133-VERIFICATION.md` from scratch — phase 133 has no verification
  file. Match the canonical shape of `134-VERIFICATION.md` / `135-VERIFICATION.md`
  (frontmatter: `phase:`, `verified:`, `status: passed`, `score: N/N must-haves verified`,
  `overrides_applied: 0`). Cite real evidence from `133-01-SUMMARY.md` (NX-01,
  `guides/introduction/suite-integration.md`, mix.exs extras registration, README
  Topic-map pointer).
- **D-03:** Phase 136 also files its own `136-VERIFICATION.md` recording the full proof
  bundle (mirrors v1.28's `130-VERIFICATION.md`).

### Proof-Bundle Execution Model (PROOF-01)

- **D-04:** **Record-only.** Phase 136 RUNS each proof command on the release-branch HEAD
  and records green results in `136-VERIFICATION.md`; it adds NO new CI lanes. The dep-off
  lane (`library_tests_dep_off`, Phase 131-06), the three `test/example/` lanes, and the
  `mix docs --warnings-as-errors` gate (inside `library_tests`) all already exist in
  `.github/workflows/ci.yml`. **Exception:** `mix credo --strict` is NOT a CI lane (credo
  is a dev/test-only dep at `mix.exs:120`) — it is run and recorded **locally**. Do not add
  a credo CI job (scope creep); do not assume it runs in CI (gate never proven).
- **D-04a:** If any gate fails (most plausibly an unresolved cross-reference in
  `mix docs --warnings-as-errors` — the v1.28 near-miss class), RECORD it as a blocker per
  the v1.28 `130-01-PLAN.md` blocker-classification pattern and fix the xref in a tracked
  follow-up. Do NOT add `@tag :skip` or waivers to make the bundle pass.

### Milestone Archive Boundary (PROOF-01) — the escalation-worthy call

- **D-05:** Phase 136 does **NOT** perform the milestone archive. It produces the proof
  bundle + DOC-01 corrigendum + verification backfill and reconciles traceability
  **in-place** (Phase 136 rows in `ROADMAP.md` / `REQUIREMENTS.md`). The archive — moving
  `ROADMAP.md`→`milestones/v1.29-ROADMAP.md`, `REQUIREMENTS.md`→`v1.29-REQUIREMENTS.md`,
  writing `v1.29-MILESTONE-AUDIT.md`, creating `v1.29-phases/`, and updating
  `MILESTONES.md`/`PROJECT.md`/`STATE.md` — is the downstream `/gsd-complete-milestone`
  + `/gsd-audit-milestone` step that runs AFTER phase execution. PROOF-01's "archived at
  close" describes the milestone-close OUTCOME, not a Phase 136 task.
  - Precedent: v1.28's PROOF phase (130) closed PROOF-01 in-place; a SEPARATE
    `chore: archive v1.28` commit (`6ab1519`) did all 50 file moves. `130-01-PLAN.md:208`
    explicitly said "Do not update `.planning/milestones/v1.28-MILESTONE-AUDIT.md`".
  - Confirmed with Jon during discussion (2026-05-28).

### Corrigendum (DOC-01)

- **D-06:** Append a one-line corrigendum to the v1.25 EMAIL-RAILS entry in
  `.planning/MILESTONES.md` (lines ~79-84) stating the library-resident
  `Sigra.Mailers.Adapters.Mailglass` module + `--with-mailglass` flag from Phase 111/114
  did NOT land on the release branch and are not part of the supported surface. The
  corrigendum's scope covers all three overclaiming lines (79 shim/flag, 80, 84 adapter
  compile claim), not just line 79.
- **D-07:** Apply the same correction to the "Previously shipped: v1.25 EMAIL-RAILS" bullet
  in `.planning/PROJECT.md` (lines ~103-104, "optional Mailglass adapter plus
  `--with-mailglass` installer path").
- **D-08:** Add a `CHANGELOG.md` `[Unreleased]` note (the correctly-placed header at
  line 33) clarifying the v1.29 Mailglass integration posture as host-owned wiring via the
  `Sigra.Mailer` behaviour, with a referent to `guides/recipes/companion-libs/mailglass.md`.
- **D-09:** **Remove the stray duplicate `## [Unreleased]` at `CHANGELOG.md:222`** as a
  same-file honesty cleanup (the phase is already editing `[Unreleased]`; two Unreleased
  sections is a latent docs defect). Confirmed in scope with Jon.

### Claude's Discretion

- Exact prose of each corrigendum line and the CHANGELOG note (truthful, no marketing
  voice — banned phrases per REQUIREMENTS.md Out-of-Scope still apply).
- Internal structure / evidence-section ordering of the backfilled `132/133-VERIFICATION.md`
  and the new `136-VERIFICATION.md`, as long as they match the established frontmatter shape.
- Whether `136-VERIFICATION.md` records command outputs inline or references CI run links.
- Whether the proof-bundle commands run as one plan or split (planner's call).

### Folded Todos

None — `gsd-sdk query todo.match-phase 136` returned no matches.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before planning or implementing.**

### Verification backfill targets + shape analogs

- `/Users/jon/projects/sigra/.planning/phases/132-threadline-recipe-mailglass-cross-link-recipe/VERIFICATION.md` — the unprefixed passing report to `git mv` → `132-VERIFICATION.md` (D-01).
- `/Users/jon/projects/sigra/.planning/phases/133-suite-narrative-ecosystem-diagram/133-01-SUMMARY.md` — evidence source for the `133-VERIFICATION.md` backfill (D-02): NX-01, suite-integration.md, mix.exs extras, README Topic-map.
- `/Users/jon/projects/sigra/.planning/phases/134-recipe-only-companion-libraries/134-VERIFICATION.md` AND `/Users/jon/projects/sigra/.planning/phases/135-reference-example-threadline-forwarder-demo-in-test-example/135-VERIFICATION.md` — canonical VERIFICATION.md frontmatter + section shape to match for both backfills and 136's own report.
- `/Users/jon/projects/sigra/.planning/milestones/v1.28-phases/130-verification-and-release-readiness/130-VERIFICATION.md` AND `130-01-PLAN.md` AND `130-01-SUMMARY.md` — the v1.28 PROOF-phase precedent: record-only execution, blocker-classification pattern (D-04a), and the explicit "do not touch the milestone-audit / do not archive" boundary (D-05).

### Proof-bundle command surfaces

- `/Users/jon/projects/sigra/.github/workflows/ci.yml` — `library_tests_dep_off` lane (lines ~170-219, `deps.clean threadline` → `mix compile --warnings-as-errors` → `mix test --exclude requires_threadline`); `mix docs --warnings-as-errors` inside `library_tests` (~line 168); `example_unit_smoke` / `example_http_smoke` / `example_playwright_smoke` (~lines 221, 538, 602). Confirms record-only (D-04); confirms NO credo lane exists.
- `/Users/jon/projects/sigra/mix.exs` — credo dev/test dep (line ~120, no CI job → run locally, D-04); `docs:` config: `extras:` (lines ~199 suite-integration, ~220-225 companion-libs), `groups_for_extras` (~228 Introduction, ~231 Companion Libraries) — registration completeness for the docs gate (assumption #5).
- `/Users/jon/projects/sigra/test/sigra/audit/` — the forwarder unit + integration test tree PROOF-01 names explicitly.

### Corrigendum targets (DOC-01)

- `/Users/jon/projects/sigra/.planning/MILESTONES.md` (lines ~73-84) — v1.25 EMAIL-RAILS entry; overclaims at lines 79 (shim + `--with-mailglass`), 80, 84 (D-06).
- `/Users/jon/projects/sigra/.planning/PROJECT.md` (lines ~103-104) — "Previously shipped: v1.25 EMAIL-RAILS" bullet, same Mailglass claim (D-07).
- `/Users/jon/projects/sigra/CHANGELOG.md` — `[Unreleased]` at line 33 (add the note, D-08); stray duplicate `## [Unreleased]` at line 222 (remove, D-09).
- `/Users/jon/projects/sigra/guides/recipes/companion-libs/mailglass.md` — the RC-02 recipe documenting the host-owned `Sigra.Mailer` posture; the CHANGELOG note's referent.

### Planning artifacts

- `/Users/jon/projects/sigra/.planning/REQUIREMENTS.md` — PROOF-01 (line 48) + DOC-01 (line 49) + Out-of-Scope (banned marketing phrases, recipe-only Mailglass).
- `/Users/jon/projects/sigra/.planning/ROADMAP.md` — Phase 136 Goal + Success Criteria #1-#3.
- `/Users/jon/projects/sigra/.planning/STATE.md` — v1.29 status (5/6 complete), locked Mailglass-recipe-only decision, deferred items.
- `/Users/jon/projects/sigra/.planning/METHODOLOGY.md` — Decisive Defaulting + Escalation Threshold lenses applied here (D-05 was the escalation item).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **Verification-report template:** `134/135-VERIFICATION.md` give the exact frontmatter +
  section shape to copy for the 132 rename-normalize, the 133 backfill, and 136's own report.
- **v1.28 PROOF-phase precedent:** `130-01-PLAN.md` / `130-01-SUMMARY.md` / `130-VERIFICATION.md`
  are a near-perfect template — same record-only proof bundle, same archive-is-separate boundary.
- **Existing CI proof surfaces:** the dep-off lane, three `test/example/` lanes, and the
  docs-warnings-as-errors gate already exist in `ci.yml` — Phase 136 invokes/records them,
  doesn't build them.

### Established Patterns

- **`NNN-VERIFICATION.md` dash-prefix convention** — every filed verification report uses it;
  132's unprefixed file is the lone deviation (D-01).
- **Archive is a `chore:` commit, separate from phase `docs(NNN)` commits** — v1.28's `6ab1519`
  proves the archive runs after phase execution via `/gsd-complete-milestone` (D-05).
- **No-waiver proof discipline** — v1.29 work carries no `@tag :skip`; blockers get recorded
  and tracked, not skipped (D-04a).

### Integration Points

- `.planning/phases/132-.../VERIFICATION.md` → `132-VERIFICATION.md` (rename).
- `.planning/phases/133-.../133-VERIFICATION.md` (new file).
- `.planning/phases/136-.../136-VERIFICATION.md` (new file — this phase's own report).
- `.planning/MILESTONES.md`, `.planning/PROJECT.md`, `CHANGELOG.md` (DOC-01 edits).
- `ci.yml` lanes + local `mix credo --strict` (commands to run/record — no edits).
</code_context>

<specifics>
## Specific Ideas

- **Credo is the easy-to-miss gate:** because it has no CI lane, the executor MUST run
  `mix credo --strict` locally and paste the clean result into `136-VERIFICATION.md`.
  Forgetting it leaves a named PROOF-01 gate unproven.
- **Corrigendum coherence:** correct all three Mailglass-overclaim surfaces together
  (MILESTONES.md, PROJECT.md, CHANGELOG.md) — a partial fix leaves the narrative
  internally contradictory.
- **Archive is the NEXT command, not this phase:** `136-VERIFICATION.md` should note the
  archive as the post-phase `/gsd-complete-milestone` step, never record it as done.
</specifics>

<deferred>
## Deferred Ideas

- **`Sigra.OptionalDeps` SOT consolidation** — deferred out of v1.29 (REQUIREMENTS.md Future).
- **`mix sigra.doctor` adopter diagnostic** — deferred out of v1.29.
- **Mailglass library-resident adapter recovery** — separate post-v1.29 quick task decides
  recover-vs-delete of the orphaned wip branches; current call is drop. DOC-01 only corrects
  the narrative, it does not reopen the recovery decision.
- **Threadline correlation-ID propagation** — v1.30 candidate.
- **Recipe-contract test fixtures** (walk `guides/recipes/companion-libs/*.md` for required
  headings/pins/banner) — differentiator, deferred.

### Reviewed Todos (not folded)

None — `todo.match-phase 136` returned no matches.
</deferred>
