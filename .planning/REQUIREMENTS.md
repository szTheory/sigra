# Requirements: Sigra — v1.43 STABILIZE

**Defined:** 2026-07-02
**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.
**Milestone goal:** Prove the foundation is green and trustworthy, unblock adopters on the latest Phoenix, and clear accumulated real-bug / robustness / review debt — no new features, no UI redesign — so the next milestone can be a clean-base admin/operator UI cleanup & feedback pass.

## v1 Requirements

Requirements for this milestone. Each maps to exactly one roadmap phase.

### Health & Signal (HEALTH)

- [ ] **HEALTH-01**: The full library test suite runs green against live Postgres, with the exact command and result recorded as a trustworthy release signal.
- [ ] **HEALTH-02**: The example app test suite runs green against live Postgres.
- [ ] **HEALTH-03**: A clean local `mix test` run has zero spurious non-product failures — the `Chimeway.Repo` missing-database startup noise and the `Sigra.UpgradeIntegrationTest` env-DB failures are fixed or correctly gated so that "green" actually means green.
- [ ] **HEALTH-04**: Every required CI check passes green end-to-end on the milestone branch.

### Latest-Phoenix Compatibility (COMPAT) — SEED-004

- [ ] **COMPAT-01**: A host generated with the current `phx.new` (≥ 1.8.8) plus `mix sigra.install` compiles clean under `--warnings-as-errors` — no `undefined attribute "type" for …CoreComponents.button/1`, and no other 1.8.8 output drift breaks the generated compile.
- [ ] **COMPAT-02**: The install golden fixture and `golden_diff_test` are reconciled with `phx.new` ≥ 1.8.8 output (the `config/config.exs` `root_tag_attribute` byte-diff absorbed correctly), so the golden lane passes without the 1.8.7 archive.
- [ ] **COMPAT-03**: The `phx_new 1.8.7` pin is removed from CI workflows and the CLAUDE.md dev-prereq note, with the generated-host acceptance smoke green against current `phx.new`.

### Debt & Robustness Clear (DEBT)

- [ ] **DEBT-01**: Oban enqueue paths degrade safely when Oban is compiled but unsupervised or its table is absent (no `42P01` / crash; enqueue is guarded), proven by a regression test.
- [ ] **DEBT-02**: The deferred phase-209 code-review items are resolved — `panel-schema-check.sh` is wired into CI or explicitly retired, and the remaining info nits are closed.
- [ ] **DEBT-03**: The deferred phase-200 code-review items are resolved, or explicitly re-triaged with recorded rationale if genuinely not worth fixing.
- [ ] **DEBT-04**: The stray Hex `1.20.0` version-ranking wart is resolved so Sigra's version ordering/resolution is correct.
- [ ] **DEBT-05**: The demo `app.css` orphaned-comment corruption is cleaned up so no CSS rule is silently dropped, guarded against regression.

### Terminal Ratification (RATIFY)

- [ ] **RATIFY-01**: The milestone closes with the full suite + CI green, every deferred-items-ledger entry pulled into this milestone reconciled (marked resolved), and no new blocking debt introduced.

## v2 Requirements

Acknowledged but deferred — not in this roadmap.

### Config / Installer Features (feature milestone)

- **FEAT-01**: Runtime auth-prefix override (`2026-06-20-runtime-auth-prefix-override`).
- **FEAT-02**: `mix sigra.migrate` schema helper (`2026-06-20-mix-sigra-migrate-schema-helper`).
- **FEAT-03**: White-label auth/email theming (`2026-06-22-white-label-auth-email-theming`).

### UI Cleanup (next / UI milestone)

- **UI-01**: Demo-DX polish nits (`2026-06-19-uat-demo-dx-polish-nits`).
- **UI-02**: Tasklane rebrand residuals (`2026-06-22-vaultr-authed-rebrand-residuals`).
- **UI-03**: Admin/operator UI cleanup & feedback pass (the milestone this one clears the runway for).

## Out of Scope

Explicitly excluded from v1.43 to keep it a true stabilization lane.

| Feature | Reason |
|---------|--------|
| Admin/operator UI redesign | Reserved for the *next* milestone; this lane exists to make that one start from a clean base. |
| CI-perf / Playwright per-shard DB (SEED-005) | CI is already fast after v1.40 (−43%); no correctness value. |
| SEED-001 GA human-UAT matrix | Large; gated on an actual v1.0 GA public-announcement trigger. |
| SEED-002 audit-log atomicity (`log_safe` → `Ecto.Multi`) | Larger change; needs its own thesis + audit-aware test pattern. |
| SEED-003 auth copy / locale i18n | Feature; only surfaces with an admin-copy or multi-language milestone. |
| SEED-007 secret_key_base compile-env decoupling | Only surfaces if host-run `--dev` port fragility resurfaces; not blocking. |
| New auth capabilities / strategic bets | Post-1.0 posture: need explicit adopter/security/product thesis. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| HEALTH-01 | Phase 215 | Pending |
| HEALTH-02 | Phase 215 | Pending |
| HEALTH-03 | Phase 214 | Pending |
| HEALTH-04 | Phase 215 | Pending |
| COMPAT-01 | Phase 213 | Pending |
| COMPAT-02 | Phase 213 | Pending |
| COMPAT-03 | Phase 213 | Pending |
| DEBT-01 | Phase 214 | Pending |
| DEBT-02 | Phase 214 | Pending |
| DEBT-03 | Phase 214 | Pending |
| DEBT-04 | Phase 214 | Pending |
| DEBT-05 | Phase 214 | Pending |
| RATIFY-01 | Phase 215 | Pending |

**Coverage:**
- v1 requirements: 13 total
- Mapped to phases: 13 (fully mapped)
- Unmapped: 0 ✓

---
*Requirements defined: 2026-07-02*
*Last updated: 2026-07-02 — traceability table populated after roadmap creation (v1.43 STABILIZE, Phases 213-215)*
