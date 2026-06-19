---
phase: 191-microcopy-ia-sweep
verified: 2026-06-18T00:10:00Z
status: passed
score: 9/9
behavior_unverified: 0
overrides_applied: 0
requirements_verified:
  - COPY-01
  - COPY-02
  - COPY-03
---

# Phase 191: Microcopy & IA Sweep — Verification Report

**Phase Goal:** A system-wide voice pass aligns all admin microcopy with the brand book and GOV.UK plain-language standards, producing a committed one-term-per-concept glossary with no synonym drift and consistent error/empty/success/warning tone across every admin surface.
**Verified:** 2026-06-18T00:10:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Canonical-term glossary exists at `guides/reference/admin-glossary.md` with the required table, voice rubric (incl. E-6 enumeration-boundary branch), and exemplars | VERIFIED | File exists (12086 bytes). Section `## Canonical Terms` has 18-row pipe-delimited table (Canonical/Banned synonyms/Context rule/Enforcement columns). `## Voice Rubric` has 5 subsections including E-6 branch explicitly. `## Exemplars` has 5 codebase examples. |
| 2 | ExUnit drift guard at `test/sigra/admin/glossary_test.exs` parses all 8 in-scope source files and passes GREEN with 0 violations after Wave 2 edits | VERIFIED | `mix test test/sigra/admin/glossary_test.exs` → 1 test, 0 failures (run confirmed, 0.4s). |
| 3 | The auth-replica carve-out (sigra-auth--preview block in branding_live.ex) uses DOM-marker anchoring and keeps `<h1>Log in</h1>` exempt while `<h2>Sign-in preview</h2>` admin heading is scanned | VERIFIED | `branding_live.ex:585` opens carve-out on `class="sigra-auth sigra-auth--preview"`. Line 583 reads `<h2 class="sg-section-heading">Sign-in preview</h2>` (admin chrome, fixed). Line 601 `<h1>Log in</h1>` is inside carve-out. Confirmed: glossary test reports 0 violations on current source. |
| 4 | The drift guard scans exactly the 8 in-scope files (7 admin LiveViews + components.ex); generated auth forms under `priv/templates/sigra.install/` are never scanned | VERIFIED | `glossary_test.exs:21-30` defines `@in_scope_files` as exactly the 7 LiveViews + components.ex. No `priv/templates` path present. |
| 5 | COPY-03: `chip_label("deleted", nil)` returns `"Deletion scheduled"` — consistent with the status pill | VERIFIED | `users_index_live.ex:557` — `defp chip_label("deleted", nil), do: "Deletion scheduled"`. |
| 6 | All 5 affected LiveViews contain canonical terms; banned synonyms eliminated (org/teammates/logins/Login preview/login/accounts-as-person-noun) | VERIFIED | `organization_live.ex` — "Search organization members, open member detail", "Investigate organization events", "invite members". `index_live.ex` — "review risky users", "Review users". `user_show_live.ex:502` — "revoke active sessions". `branding_live.ex:583` — "Sign-in preview". Glossary guard GREEN confirms 0 violations. |
| 7 | WR-04 + WR-02 inspect leaks in `branding_live.ex` error_message/1 are gone — both clauses return generic operator copy | VERIFIED | `branding_live.ex:725-731` — `error_message(%{__struct__: _})` rescue returns `"Could not save auth branding. Check the values and try again."`. `error_message(_reason)` returns same generic message. No `inspect/1` present anywhere in the file (grep confirms). |
| 8 | `admin-quality-ledger.md` has the branding-live L3 row; monotonic guard passes GREEN | VERIFIED | `grep -c "branding-live" admin-quality-ledger.md` → 1 match at line 67 (L3, Tier 1). `bash scripts/ci/quality-ledger-monotonic.sh` → "PASS (35 cells checked vs HEAD)". |
| 9 | Snapshot-allowlist is empty; 15 PNGs recaptured (5 slugs x 3 projects); impersonation-banner canary PNGs unchanged | VERIFIED | `test/example/priv/playwright/snapshot-allowlist` contains comments only (0 non-comment lines). `git diff 0a449435..HEAD --name-only | grep .png` → exactly 15 PNGs (5 slugs, all non-canary). `snapshot-canary-guard.sh` → "PASS (0 changed slug(s), all within allowlist)". |

**Score:** 9/9 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `guides/reference/admin-glossary.md` | Canonical-term table + voice rubric + exemplars | VERIFIED | 12086 bytes. All 3 sections present. 18 canonical rows, 5 voice rubric subsections, 5 exemplars. Header note links to drift guard. |
| `test/sigra/admin/glossary_test.exs` | Source-parsing ExUnit drift guard | VERIFIED | 12079 bytes. Reads 8 files, DOM-marker carve-out, 16-pattern strip, 11 banned terms. GREEN with 0 violations on current source. |
| `lib/sigra/admin/live/index_live.ex` | Canonical terms: user (not account) | VERIFIED | "review risky users", "Review users", "Once users exist", "Users registered since Monday UTC". |
| `lib/sigra/admin/live/organization_live.ex` | Canonical terms: organization/member (not org/teammates) | VERIFIED | "Search organization members", "Investigate organization events", "invite members". |
| `lib/sigra/admin/live/users_index_live.ex` | Canonical terms: user/sign-in/sessions | VERIFIED | "Review the user before unlocking", "Once users exist", "Last activity: None recorded". chip_label("deleted") → "Deletion scheduled". |
| `lib/sigra/admin/live/user_show_live.ex` | Canonical terms: sessions (not logins); no inspect leaks | VERIFIED | "revoke active sessions and unlock below" at line 502. |
| `lib/sigra/admin/live/branding_live.ex` | "Sign-in preview" heading; no inspect(reason); carve-out preserved | VERIFIED | Line 583: "Sign-in preview". Line 601 inside carve-out: "Log in" (preserved). No inspect() in error_message clauses. |
| `test/sigra/admin/components_test.exs` | Golden updated: "revoke active sessions" | VERIFIED | `@notice_golden` at line 68 and inner_block at line 403 both read "revoke active sessions". |
| `guides/reference/admin-quality-ledger.md` | branding-live L3 row; monotonic increase-only | VERIFIED | Line 67: branding-live row, L3, Tier 1. Monotonic guard PASS (35 cells). |
| 15 admin-checkpoints PNG baselines | Recaptured for 5 changed slugs x 3 projects | VERIFIED | All 15 files present and changed in `git diff 0a449435..HEAD`. Canary PNGs (impersonation-banner) unchanged. |
| `test/example/priv/playwright/snapshot-allowlist` | Empty (comments only) after recapture | VERIFIED | File contains comments only; 0 non-comment lines. |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `glossary_test.exs` | `guides/reference/admin-glossary.md` | `banned_terms/0` conceptually derived from glossary table | WIRED | Test defines 11 banned_terms entries matching glossary rows; glossary header notes the test. |
| `glossary_test.exs` | `lib/sigra/admin/live/*_live.ex` + `components.ex` | `File.read!/1` on `@in_scope_files` list | WIRED | `@in_scope_files` at lines 21-30 lists all 8 source files; test reads and scans them. |
| `chip_label("deleted", nil)` | "Deletion scheduled" status pill | Same term used in `users_index_live.ex:141,429` | WIRED | `chip_label/2` clause at line 557; `label="Deletion scheduled"` at line 141; status pill at line 429. |
| `branding_live.ex error_message/1` | Generic operator copy | Pattern-matched clause + rescue branch | WIRED | Both `%{__struct__: _module}` rescue and `_reason` catch-all return the same generic message. |

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Glossary drift guard passes GREEN | `mix test test/sigra/admin/glossary_test.exs` | 1 test, 0 failures, 0.4s | PASS |
| Components golden passes GREEN | `mix test test/sigra/admin/components_test.exs` | 35 tests, 0 failures, 0.5s | PASS |
| Monotonic ledger guard passes | `bash scripts/ci/quality-ledger-monotonic.sh` | PASS (35 cells checked vs HEAD) | PASS |
| Canary guard passes | `bash scripts/ci/snapshot-canary-guard.sh` | PASS (0 changed slug(s), all within allowlist) | PASS |
| Snapshot-allowlist empty | `cat test/example/priv/playwright/snapshot-allowlist` | Comments only | PASS |
| 15 PNGs recaptured, 0 canary changed | `git diff 0a449435..HEAD --name-only | grep .png` | 15 lines, no impersonation-banner | PASS |

---

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| COPY-01 | System-wide voice pass aligns admin microcopy with brand book; errors state what failed + why + next action | SATISFIED | Voice rubric authored in `admin-glossary.md` (5 subsections, E-6 branch). 21 copy edits applied across 5 LiveViews. WR-04 + WR-02 inspect leaks removed. "Sign-in preview" heading, "Revoking a session signs the user out of that device immediately." etc. |
| COPY-02 | GOV.UK plain-language pass; committed one-term-per-concept glossary; no synonym drift | SATISFIED | `admin-glossary.md` committed with 18-row canonical table. `glossary_test.exs` GREEN (0 violations). All synonym drift resolved: org → organization, teammates → members, logins → sessions, Login preview → Sign-in preview. |
| COPY-03 | Empty-state, success, and warning copy consistent across admin surfaces; ledger raised | SATISFIED | `chip_label("deleted", nil)` → "Deletion scheduled" aligns chip with status pill. Ledger raised: branding-live L3 row added (6 → 7 rows), D9/D10 re-scored. Monotonic guard PASS. |

---

### Anti-Patterns Found

| File | Issue | Severity | Impact |
|------|-------|----------|--------|
| `test/sigra/admin/glossary_test.exs:173` | `action=` strip pattern also silences `action=` component attributes carrying visible copy — false-negative risk for future `action=` label edits | Warning | No current defect (all `action=` values are clean). Future label edits in `action=` position are unguarded. Tracked in `.planning/todos/pending/2026-06-17-phase-191-review-deferred.md`. |
| `test/sigra/admin/components_test.exs:68,437` | `@notice_link_golden` inner_block still contains "Review accounts" (banned synonym in glossary), but test files are excluded from drift guard scope — structural test, not copy hygiene | Info | No test failure; intentional. Comment clarification added (WR-01 remediation in REVIEW.md). |

No `TBD`, `FIXME`, or `XXX` markers found in phase-191-modified files.

---

### Known Out-of-Scope Items (not failures)

Per the verification brief, the following are pre-existing and NOT phase-191 regressions:

- `test/sigra/install/vault_promotion_test.exs:9` and `test/sigra/install/golden_diff_test.exs:53` — reproduce identically on clean `origin/main`; installer/template lane.
- `admin-design.spec.ts` MG-5/6 content-equivalence failure — data-dependent pagination threshold; phase 191 never modified `admin-design.spec.ts`. Tracked in `.planning/todos/pending/2026-06-17-admin-design-mg5-6-content-equivalence-data-dependent.md`.

---

## Gaps Summary

No gaps. All 9 observable truths verified against the live codebase. All guards GREEN.

---

_Verified: 2026-06-18T00:10:00Z_
_Verifier: Claude (gsd-verifier)_
