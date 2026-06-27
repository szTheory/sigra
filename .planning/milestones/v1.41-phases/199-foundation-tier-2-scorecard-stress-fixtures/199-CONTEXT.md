# Phase 199: Foundation — Tier-2 Scorecard & Stress Fixtures - Context

**Gathered:** 2026-06-25 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Make Tier-2 "Award-grade" **objectively earnable and forward-only guarded**, and stress-test
the demo seed data — without elevating any actual page yet.

In scope:
- Define measurable Tier-2 proxies in the fractal scorecard + quality ledger (LEDGER-01).
- Confirm/extend the monotonic guard so the Tier-2 ratchet is enforced merge-blocking vs `origin/main` (LEDGER-02).
- Add a deterministic ≥25-audit-event persona so MG-5/MG-6 pagination + desktop↔mobile content-equivalence is testable, closing the tracked `admin-design-mg5-6-content-equivalence-data-dependent` todo (FIXT-01).
- Add list-scale + "ugly" stress fixtures (long names/emails/UUIDs, multi-session/org breadth, varied audit outcomes) under the `MIX_ENV=test` raise guard with idempotent upserts (FIXT-02).

Out of scope (later phases): any award-grade rework of `user_show_live`, `users_index_live`,
or the audit surfaces (Phases 200-202); consistency propagation (203); terminal ratification /
allowlist reset / adversarial review (204). This phase builds the measuring instruments and the
stress data; it does not move any cell to Tier 2.
</domain>

<decisions>
## Implementation Decisions

### Tier-2 Proxy Encoding (LEDGER-01)
- **D-01:** Encode the Tier-2 proxies as a **new dedicated "Tier-2 Add-on" block in `guides/reference/admin-fractal-scorecard.md`**, mirroring the existing per-level add-on structure (pass-criteria bullets cross-referencing concrete specs). Do **not** introduce a parallel machine-parseable proxy file or per-proxy sub-tier columns in the ledger table.
- **D-02:** Map each named proxy to an **existing automated gate where one already exists**, and mark the rest **documented-as-manual**:
  - overlay-open axe-clean → `admin-modal-interaction.spec.ts` ("axe-while-open")
  - focus-trap/restore APG gates → the existing "7 APG gates"
  - desktop↔mobile content-equivalence → `admin-design.spec.ts` MG-5/6 + the un-skipped equivalence test (FIXT-01)
  - glossary-clean microcopy → `glossary_test.exs`
  - motion-token conformance / no `transition: all` → documented-as-manual (no current gate)
  - density/whitespace rhythm → documented-as-manual
  - target-size minimum → documented-as-manual
- **D-03:** A maintainer asserts a cell reached Tier 2 by changing its `Tier` column to `2` in `admin-quality-ledger.md` **and** expanding that row's `Evidence` column to cite the specific spec/test proving each applicable proxy. The ledger table shape (column-4 = single `[012]` integer, no decorators) is preserved so the monotonic guard's positional `awk -F'|'` parse keeps working.

### Monotonic Guard Tier-2 Behavior (LEDGER-02)
- **D-04:** **No parser/logic change** to `scripts/ci/quality-ledger-monotonic.sh` — it already reads column-4 as a numeric integer and fails on any decrease (`head_tier -lt base_tier`), so a `2` cell is automatically protected against dropping to `1`/`0`. Tier 2 is "free" numerically.
- **D-05:** Add a **`2→1` regression self-test** (synthetic ledger fixture that asserts the guard exits non-zero on a Tier-2 decrease) so the Tier-2 case is positively exercised, not just assumed.
- **D-06:** **Reconcile the ledger's terminal-ratification prose** (`admin-quality-ledger.md` ~lines 81-84, "Tier 2 NOT declared here / objective proxies ratcheted separately") so it no longer contradicts the new Tier-2 contract. The doc must be internally consistent — no stale "Tier 2 not declared" language once proxies exist.
- **D-07:** Confirm the guard stays wired merge-blocking in CI with `--base origin/main` (`ci.yml:109-110`); no rewiring expected.

### Stress-Fixture Shape & Persona Identity (FIXT-01, FIXT-02)
- **D-08:** The **≥25-event persona is the existing `admin` persona** (already the "rich audit trail" persona, near the threshold, and the one MG-5/6 navigates to as first-listed user). Top up its `@audit_actions` batch in `seeds.ex` to a **hard ≥25 self-tied** (`effective_user_id`) count. Do not create a brand-new persona for this — a new one risks not being first-listed and leaving pagination unexercised.
- **D-09:** Add list-scale "ugly" users as a **separate bulk cohort kept OUT of `Personas.all()`** (e.g. 30-60 generated `loadtest-NN@demo.tasklane.test` users with deliberately long display names, near-max-length emails, raw UUID-looking identifiers). Keeping them out of the persona catalog protects `/demo/credentials`, the `print_credentials` loop, the `feature_map` single-source-of-truth contract, and the `demo_users == length(Personas.all())` assertion in `seeds_test.exs`.
- **D-10:** Insert the bulk cohort + topped-up events via **idempotent upserts** following the existing count-threshold pattern (`seeds.ex` ~634-651) with `on_conflict: :nothing` / transaction-wrapped inserts, under the existing **`MIX_ENV=test` raise guard** and dev/test environment gating. Re-running seeds must not duplicate.
- **D-11:** **"Varied severities" maps to the existing audit `outcome` vocabulary** (`success` / `failure` / `error` per `audit/changeset.ex:28`) plus action-prefix variety — **there is no `severity` column**. Add multi-session and multi-org breadth using existing schema fields; do not invent new columns.

### Snapshot / Recapture Blast Radius
- **D-12:** Treat seed changes as **NOT snapshot-neutral** — added events + list-scale users shift rendered row counts and pagination controls on `/admin/users`, `/admin/audit`, the user-detail audit feed, and the MG-5/MG-6 gallery boards.
- **D-13:** **Un-skip the MG-5/6 content-equivalence test** (`admin-design.spec.ts:328`) and resolve the tracked `admin-design-mg5-6-content-equivalence-data-dependent` todo as part of FIXT-01.
- **D-14:** Recapture **only the affected non-canary slugs** through the **recapture gate** (`snapshot-recapture-gate.sh`), not the canary guard. The `impersonation-banner` canary must stay byte-stable. Use the correct per-lane canary/allowlist (no cross-lane mixups, per `ci.yml:1666-1667`).
- **D-15:** **Leave both allowlists reset to empty at end-of-phase** (mirroring the Phase 192 proof method). Phase 199 does not defer allowlist cleanup to Phase 204 — it stays green on its own.

### Claude's Discretion
- Exact bulk-cohort size (target ~30-60 users — pick a number that exercises list-scale pagination on `/admin/users` without bloating CI snapshot time).
- Exact long-string fixture values (specific near-max email lengths, UUID-shaped identifiers, multi-word display names) — choose representative "ugly" data that pressure-tests overflow.
- Whether the guard self-test (D-05) lives as a shell test, a CI step, or an Elixir test — pick the lowest-friction location consistent with existing CI test patterns.
- Precise wording of the scorecard Tier-2 add-on block and ledger prose reconciliation.

### Folded Todos
- **`2026-06-17-admin-design-mg5-6-content-equivalence-data-dependent`** — folded into FIXT-01/D-13. The ≥25-event `admin` persona makes pagination render so the content-equivalence test can be un-skipped and the todo closed (`resolves_phase: 199`).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `guides/reference/admin-fractal-scorecard.md` — grading rubric; Tier-2 add-on block goes here (lines 42-122 show the add-on structure to mirror)
- `guides/reference/admin-quality-ledger.md` — machine-parseable tier record (lines 14-30 parsing rules; ~81-89 terminal-ratification prose to reconcile)
- `scripts/ci/quality-ledger-monotonic.sh` — monotonic guard (lines 22-53 — already numeric; no Tier-2 logic gap)
- `.github/workflows/ci.yml` — guard wiring (lines 109-110, `--base origin/main`); recapture-gate lanes (~1377-1673, canary/allowlist semantics ~1666-1667)
- `test/example/lib/example/demo/seeds.ex` — demo seed module (`@audit_actions` ~479-498; count-threshold idempotency guard ~634-651)
- `test/example/lib/example/demo/personas.ex` — persona catalog; bulk users must stay OUT of `all/0` (feature_map SSoT ~line 188)
- `test/example/test/example/demo/seeds_test.exs` — seed assertions scoped to named personas (lines 107, 126); `seeds_script_test.exs` — MIX_ENV=test raise guard contract
- `test/example/priv/playwright/tests/admin-design.spec.ts` — MG-1..MG-11 gallery; skip to remove at line 328; first-listed-user navigation lines 371-378
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — seeds once per project (~line 40); list-scale data flows into these captures
- `.planning/todos/pending/2026-06-17-admin-design-mg5-6-content-equivalence-data-dependent.md` — the todo FIXT-01 closes (`resolves_phase: 199`)
- Thresholds: `lib/sigra/admin/audit/query_params.ex:22` (`@default_limit 25`); `lib/sigra/admin/users/query.ex:65` (`default_limit: 25`)
- Audit outcome vocab: `lib/sigra/audit/changeset.ex:28` (`~w(success failure error)` — no severity column)
- Process/governance: `guides/reference/admin-ui-principles.md`, `guides/reference/admin-design-contract.md` (sg-* design system; same-job → same-component; light/dark/system)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- The fractal scorecard's **per-level add-on pattern** (`admin-fractal-scorecard.md:42-122`) is the exact template for the new Tier-2 proxy block — pass-criteria bullets that cross-reference concrete specs.
- The ledger's existing **Evidence column convention** (cite the spec/test that proves a cell) extends directly to Tier-2 proxy evidence.
- The seed module already implements an **idempotent count-threshold upsert pattern** for non-uniquely-indexed rows (`seeds.ex` ~634-651) — reuse it for both the topped-up audit events and the bulk user cohort.
- The monotonic guard is **already Tier-agnostic numeric** — Tier 2 is enforced "for free" once cells carry it.

### Established Patterns
- Quality-ledger column-4 = single `[012]` integer with no decorators; the guard's positional `awk -F'|'` parse depends on this table shape — must not be broken.
- Demo personas are a closed catalog (`Personas.all/0`) that drives `/demo/credentials`, `print_credentials`, and `feature_map`; seed tests assert `demo_users == length(Personas.all())` — bulk fixtures must live outside the catalog.
- Audit default page size is **25** on both users and audit queries — the magic number that makes the ≥25-event persona the pagination trigger.
- Snapshot lanes use a **canary slug** (`impersonation-banner`) + per-slug allowlist; recapture goes through `snapshot-recapture-gate.sh`, canary stays byte-stable (Phase 192 / SEED-006 precedent).

### Integration Points
- New Tier-2 proxy definitions connect scorecard ↔ ledger ↔ monotonic guard ↔ specific Playwright/ExUnit gates.
- Seed fixtures connect to `/admin/users`, `/admin/audit`, user-detail audit feed, and the MG-5/MG-6 design gallery boards (row counts + pagination).
- CI wiring: monotonic guard (ci.yml:109-110) and recapture-gate lanes (ci.yml ~1377-1673) are both merge-blocking and must end the phase green.
</code_context>

<specifics>
## Specific Ideas

- The ≥25 trigger is not arbitrary: it matches the `@default_limit 25` page size, so the `admin` persona crossing 25 self-tied events is what makes MG-5/MG-6 pagination actually render.
- "Ugly" fixtures should pressure-test real failure modes: text overflow (long display names/emails), identifier rendering (UUID-shaped strings), and multi-session/multi-org breadth — not just volume.
- This phase is the "measuring instrument" phase: it must make Tier 2 *earnable and guarded* but must not itself ratchet any cell to Tier 2 (that's Phases 200-204 with proxy evidence).
</specifics>

<deferred>
## Deferred Ideas

- Actual elevation of `user_show_live` / `users_index_live` / audit surfaces to Tier 2 — Phases 200-202.
- Consistency propagation to Overviews / Branding workbench / gallery — Phase 203.
- Terminal allowlist reset + adversarial milestone review + Tier-2 cell locking — Phase 204 (note D-15 still keeps Phase 199's own allowlists empty).

### Reviewed Todos (not folded)
- `2026-06-18-token-reference-completeness-ci-guard` (optional admin-token-reference CI guard, 186 IN-03) — not folded; unrelated to Tier-2 proxies / fixtures, separate optional guard.
- `2026-06-17-page04-branding-explicit-scoring` (score Branding customizer PAGE-04 in L3 ledger) — not folded; that's a ledger *scoring* action better suited to the Branding propagation work (Phase 203), not the Tier-2 *instrument* phase.
- `2026-06-20-mix-sigra-migrate_schema-helper`, `2026-06-19-uat-demo-dx-polish-nits`, `2026-06-21-app-css-comment-corruption-cleanup`, `2026-06-24-oban-enqueue-unguarded...` — low relevance (installer/DX/CSS/Oban), out of phase scope.
</deferred>
