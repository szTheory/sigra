---
phase: 141
slug: seed-data-layer
status: validated
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-30
---

# Phase 141 — Validation Strategy

> Per-phase validation contract. Reconstructed retroactively (State B) from the
> four plan SUMMARYs + VERIFICATION.md, then gap-filled with automated tests.

This phase ships **example-app demo seed data**, deliberately excluded from
`mix test` at runtime (the `Mix.env() == :test` raise-guard in `seeds.exs` and the
`@demo.sigra.dev`↔`@example.test` email-domain segregation are the point). Original
verification was one-off `mix run -e …` commands captured in the SUMMARYs — none ran
in CI. This audit added two ExUnit files so the requirements are now exercised by
`mix test`. The orchestrator module `Example.Demo.Seeds.run/0` has **no** env guard
(only the `seeds.exs` script does), so it is called directly inside the Ecto SQL
Sandbox and rolls back — never executing the guarded script.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) |
| **Config file** | `test/example/test/test_helper.exs` (`Ecto.Adapters.SQL.Sandbox`, `:manual`) |
| **Quick run command** | `cd test/example && mix test test/example/demo/personas_test.exs test/example/demo/seeds_test.exs` |
| **Full suite command** | `cd test/example && mix test` |
| **Estimated runtime** | ~0.5 seconds (the two new files); Postgres at localhost:5432 required |

---

## Sampling Rate

- **After every task commit:** Run the quick run command
- **After every plan wave:** Run the full suite command
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~1 second (the two demo files)

---

## Per-Task Verification Map

| Req | Plan | Wave | Behavior | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|-----|------|------|----------|------------|-----------------|-----------|-------------------|-------------|--------|
| SEED-01 | 03,04 | 2,3 | `Seeds.run/0` twice → identical counts, no error | T-141-11 / T-141-14 | Idempotent re-run can't corrupt or duplicate demo data | integration | `mix test test/example/demo/seeds_test.exs` | ✅ | ✅ green |
| SEED-02 | 02,03 | 1,2 | Six `@demo.sigra.dev` personas, distinct states, orgs/membership/invite shape | — | N/A | unit + integration | `mix test test/example/demo/personas_test.exs test/example/demo/seeds_test.exs` | ✅ | ✅ green |
| SEED-03 | 01,03 | 1,2 | Rough edges: dave locked (5/`locked_at`/nil hash), frank scheduled-deletion, carol github identity, admin+bob TOTP (deterministic secret), admin passkey | T-141-10 | Fabricated credentials are display-only, never authenticate | integration | `mix test test/example/demo/seeds_test.exs` | ✅ | ✅ green |
| SEED-04 | 03 | 2 | Audit log ≥15 rows, ≥6 distinct actions, admin-tied via `effective_user_id` | T-141-09 | Audit rows correctly attributable in admin UI | integration | `mix test test/example/demo/seeds_test.exs` | ✅ | ✅ green |
| SEED-05 | 02,04 | 1,3 | Email-domain segregation: every persona `@demo.sigra.dev`, none `@example.test` | T-141-07 | `mix test` stays deterministic (no demo contamination) | unit | `mix test test/example/demo/personas_test.exs` | ✅ | ✅ green |
| SEED-05 | 04 | 3 | `MIX_ENV=test mix run priv/repo/seeds.exs` raises before any DB write | T-141-12 | CI fixture DB cannot be contaminated by the dev seed path | manual-only | (see Manual-Only) | — | ⬜ manual |
| SEED-06 | 02,04 | 1,3 | Real Argon2id (`$argon2id$`), policy-passing passwords, deterministic 20-byte TOTP secret + verbatim demo-only label | T-141-04 / T-141-05 / T-141-06 | Demo posture matches production; no real secrets; demo secret labeled | unit + integration | `mix test test/example/demo/personas_test.exs test/example/demo/seeds_test.exs` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky · ⬜ manual*

---

## Wave 0 Requirements

Existing ExUnit + `Example.DataCase` (SQL Sandbox) infrastructure covers all
automatable phase requirements. Two test files were authored to fill the MISSING
gaps (no framework install needed):

- [x] `test/example/test/example/demo/personas_test.exs` — pure-data assertions for SEED-02, SEED-05 (domain), SEED-06 (`async: true`, no DB)
- [x] `test/example/test/example/demo/seeds_test.exs` — `Example.DataCase` sandbox assertions for SEED-01, SEED-02, SEED-03, SEED-04, SEED-06 (`async: false`)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `seeds.exs` raises in `MIX_ENV=test` before any DB access | SEED-05 (raise-guard half) | The guard lives in the `priv/repo/seeds.exs` **script**, not the orchestrator module. The test suite itself runs in `MIX_ENV=test`, so invoking the script from a test would raise by design and cannot assert "no rows written" cleanly. This is a process-level behavior. | `cd test/example && MIX_ENV=test mix run priv/repo/seeds.exs` → expect non-zero exit + the contamination message before any DB write; confirm zero `@demo.sigra.dev` rows in `example_test`. **Roadmapped:** Phase 143 SC#4 adds this as a CI seeds-smoke check. |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or are justified manual-only
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (2 test files added)
- [x] No watch-mode flags
- [x] Feedback latency < 2s
- [ ] `nyquist_compliant: true` — **not set:** one behavior (SEED-05 raise-guard) is justified manual-only, deferred to the Phase 143 CI seeds-smoke. All other requirements are fully automated.

**Approval:** approved 2026-05-30 (PARTIAL — 5.5/6 requirements automated, 1 justified manual-only)

---

## Validation Audit 2026-05-30

| Metric | Count |
|--------|-------|
| Gaps found | 6 (SEED-01..06, all MISSING) |
| Resolved (automated) | 5 fully + SEED-05 domain half |
| Escalated to manual-only | 1 (SEED-05 raise-guard, process-level) |
| Tests added | 2 files / 20 tests (8 unit + 12 integration), 0 failures |
| Implementation bugs found | 0 |

---

## Validation Audit 2026-05-30 (re-audit — coverage re-verification)

State-A re-audit of the existing strategy. No gap-fill needed — the prior
reconstruction's claims were re-verified by **re-running** the two committed test
files (`cd test/example && mix test test/example/demo/personas_test.exs
test/example/demo/seeds_test.exs`): **20 tests, 0 failures, exit 0** (Postgres at
localhost:5432). Per-Task Map statuses unchanged; all automatable requirements
remain green; the single SEED-05 raise-guard remains justified manual-only
(roadmapped to Phase 143 CI seeds-smoke). Frontmatter unchanged
(`nyquist_compliant: false` — PARTIAL).

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |
| Tests re-run | 20 (8 unit + 12 integration), 0 failures |
| MISSING / failing requirements | 0 |
| Manual-only (justified) | 1 (SEED-05 raise-guard) |
