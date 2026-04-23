# Phase 59 — Technical research: UAT + GA narrative alignment (OA-02)

**Question answered:** What must planners and executors know so **OA-02** is satisfied without over-claiming machine proof?

## Summary

Phase **59** is **documentation + pointer hygiene** only: align **`docs/uat-ci-coverage.md`** (hub), **`.planning/v1.4-GA-UAT.md`** (GA-03 row), **`.planning/uat-evidence/v1.4/GA-03/waiver.md`**, optional **`.planning/uat-evidence/v1.4/INDEX.md`**, **`docs/ga-evidence.md`** (Hex router), and living narrative in **`.planning/PROJECT.md`** / **`.planning/MILESTONES.md`** with **Phase 58** facts. No test or production code changes (**58** owns **OA-01**).

### Machine proof facts (do not drift)

| Artifact | Module / job | What merge-blocking CI proves today |
|----------|--------------|-------------------------------------|
| `test/sigra/oauth/oauth_ceremony_audit_test.exs` | `Sigra.OAuthCeremonyAuditTest` | Persisted `audit_events` for **`oauth.register_via_oauth`** (registration) and **`oauth.authorize`** after successful **`Sigra.OAuth.authorize_url/3`**, Postgres + Sandbox, in-process mock, **no live IdP HTTP** (**OA-01**). |
| `test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs` | `Sigra.Planning.Phase58OauthOa01CiContractTest` | Structural honesty: **`library_tests`** → “Run library tests” → plain **`mix test`** path (**D-58-11**); **not** a substitute for integration assertions. |
| `test/sigra/oauth/oauth_test.exs` | `Sigra.OAuthTest` | Assent-shaped **authorize/callback contract** with mock strategy (historical **SEED-4** / **GA-03** substitute language). |

### Residual (must stay explicit in prose)

- Live Google consent UX, refresh/token edge cases, tenant policy — **not** CI-closed.
- Phrasing like “OAuth fully verified in CI” or implying a **single** shared `MockStrategy` drives both `OAuthTest` and `OAuthCeremonyAuditTest` unless code is refactored — **forbidden** per **59-CONTEXT D-59-02**.

### ID disambiguation (**D-59-05 / D-59-06**)

- **AUD-03** in **v1.2 admin** vs **v1.3 integration smoke** are different labels — use **`OA-01`**, **`v1.3 AUD-03 (OAuth deferred)`**, or cite **`.planning/milestones/v1.3-REQUIREMENTS.md`** when describing history.
- Replace vague “**AUD-03 / OAuth ceremony not claimed**” hooks in **living** files with **OA-01 / OA-02** vocabulary and explicit **v1.3** qualifiers where referring to archived deferral.

### Doc architecture pattern

- **Hub-and-spoke:** `docs/uat-ci-coverage.md` owns **depth** (grep-friendly subsection with literals **`OA-01`**, **`OA-02`**, **`library_tests`**, **`oauth_ceremony`**); matrix row + INDEX + `ga-evidence.md` carry **short pointers**, not duplicate authoritative CI tables (**D-38-08** alignment).

### SHA / waiver footgun (**D-59-04**)

- Matrix row, Notes, and `waiver.md` **compensating_controls** can triple-drift on SHA. Prefer **one** pin or soften to “modules listed in `docs/uat-ci-coverage.md` as of \<date\>” — executor picks least brittle option consistent with existing GA style.

---

## Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Over-claim vs tests | Every touched surface cites **module + path**; residual bullets explicit. |
| AUD-03 ambiguity | Forward-only vocabulary in **PROJECT.md**; time-versioned addendum in **MILESTONES.md** if needed. |
| Hex readers miss `.planning/` | **`docs/ga-evidence.md`** “Where to read next” uses **absolute GitHub URLs** matching existing `v0.2.0` tag style (**D-59-08**). |

---

## Validation Architecture

> Nyquist / plan-checker **Dimension 8** — how execution proves this phase without false confidence.

### Feedback channels

| Dimension | How sampled for Phase 59 |
|-----------|---------------------------|
| Doc truth vs code | `grep` for required literals (`OA-01`, `OA-02`, `Sigra.OAuthCeremonyAuditTest`, file paths, `library_tests`) in edited markdown. |
| Build health | `mix compile --warnings-as-errors` after edits (no code change expected; catches accidental syntax in fenced blocks if any). |
| Regression on OAuth tests | Optional smoke: `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/oauth/oauth_ceremony_audit_test.exs test/sigra/oauth/oauth_test.exs` — **should remain green**; phase does not modify these files. |

### Sampling policy

- **After Plan 01 (coverage doc):** Run grep acceptance set on `docs/uat-ci-coverage.md` only.
- **After Plan 02 (matrix + satellites):** Run grep on all touched paths + `mix compile --warnings-as-errors`.
- **Before handoff / verify-work:** Full grep matrix from **59-VALIDATION.md** sign-off table.

### Wave 0

- **Not applicable** — no new test files. Existing **`library_tests`** pipeline remains authoritative for **OA-01** code truth.

### Manual-only

- Human read of prose tone (“does this still sound like live Google is in CI?”) — **maintainer spot check**; automated gate is grep for forbidden phrases where listed in plans.

---

## RESEARCH COMPLETE

Phase 59 scope is bounded; **CONTEXT.md** decisions **D-59-01–D-59-08** are sufficient for planning. No external dependency research required.
