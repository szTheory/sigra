---
phase: 160
slug: regression-hardening-baseline-ratification
status: verified
threats_open: 0
asvs_level: 1
created: 2026-06-05
---

# Phase 160 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.
> Verdict: **SECURED** — 13/13 threats CLOSED (2 `mitigate` verified in code, 11 `accept` rationale confirmed). Register was authored at plan time; this is verification of declared dispositions, not a fresh scan.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| admin LiveView → Users query | Admin-only, behind `Sigra.Admin.Authorizer`. The D-07 `needs_review` filter must not broaden the visible user set beyond the authorized admin's scope. | User PII (locked/deleted account rows), org-scoped |
| installer templates → scaffolded host app | One-way diff/apply on `priv/templates/`; no user input. | Template source files |
| Playwright runner → example app | Ephemeral test fixtures (`registerUser`/`createOrganization`); no production data. | Throwaway test data |
| Planning doc writes → git repo | Documentation-only writes; no auth/session/user data. | Markdown + git commit metadata |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-160-01 | Information Disclosure | `lib/sigra/admin/users/query.ex` needs_review filter | mitigate | Scope-safe `where` (not `or_where`) at `query.ex:317-323`; reachable via `@allowed_params:24`, `@filter_fields:38`, Flop `filterable:59`, embedded schema `:83`; ExUnit `users_query_test.exs:332` (global union) + `:402-405` (org-scope guard) | closed |
| T-160-P3-01 | Tampering | `scripts/ci/snapshot-canary-guard.sh` | mitigate | `--require-all` three-property gate: only-declared-change (`:94-96`), all-declared-changed (`:102-109`), impersonation-banner canary byte-green hard-fail (`:91-93`) | closed |
| T-160-02 | Tampering | D-06 CSS dark override | accept | CSS `:root` token only; no input/auth/session surface | closed |
| T-160-03 | Information Disclosure | D-08 verify-only | accept | No code change; read-only confirmation | closed |
| T-160-SC | Tampering | npm/pip/cargo installs (Plan 01) | accept | Plan 01 `tech-stack.added: []` — no new installs | closed |
| T-160-P2-01 | Tampering | `priv/templates/sigra.install/` sync | accept | Mechanical diff/apply; 0 files changed; `admin-generated.spec.ts` (6 passed) is integrity gate | closed |
| T-160-P2-02 | Information Disclosure | throwaway Phoenix app | accept | Temp dir, ephemeral data, discarded after run | closed |
| T-160-P2-SC | Tampering | npm/pip/cargo installs (Plan 02) | accept | Plan 02 `tech-stack.added: []` — no new installs | closed |
| T-160-P3-02 | Information Disclosure | axe WCAG-AA dark run | accept | Runs against example test data; no PII | closed |
| T-160-P3-SC | Tampering | npm/pip/cargo installs (Plan 03) | accept | Plan 03 `tech-stack.added: []` — no new installs | closed |
| T-160-P4-01 | Tampering | REQUIREMENTS.md gate flip | accept | Doc checkbox; mechanical proof (Playwright compare + canary guard + ExUnit) precedes flip | closed |
| T-160-P4-02 | Repudiation | v1.34-MILESTONE-AUDIT.md | accept | Committed to git (`2abe5915`), ISO-timestamped; commit hash is audit trail | closed |
| T-160-P4-SC | Tampering | npm/pip/cargo installs (Plan 04) | accept | Plan 04 `tech-stack.added: []` — no new installs | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

### Mitigate-threat verification detail

**T-160-01 — needs_review OR-filter must not broaden the authorized set (the live security concern of this phase).**
Code review (`160-REVIEW.md`) found two defects in the first implementation, both remediated in commit `8231f840` and re-verified in current source:
- **CR-01:** `needs_review` was unregistered → the `apply_filter` clause was unreachable dead code, so `?needs_review=true` returned the full unfiltered set. Now registered across all four Flop layers (`query.ex:24,38,59,83`), so the clause is reachable.
- **WR-01:** the clause used `or_where`, which would OR the locked/deleted disjunction past the base authorization scope (cross-org leak). Now `where(query, [user: user], not is_nil(user.locked_at) or not is_nil(user.deleted_at))` — disjunction internal to a single AND-combined `where`, cannot escape `base_query/3` scope (`query.ex:203-226`, `:317-321`).
- **Tests:** `users_query_test.exs:332` (global union) and `:402-405` (org1 admin sees only carol/deleted-in-scope, NOT bob/locked-out-of-scope) — direct WR-01 regression guard.

**T-160-P3-01 — snapshot-canary-guard `--require-all` three-property gate.** All three present: only-declared-change (`:94-96`), all-declared-changed under `REQUIRE_ALL=1` (`:102-109`), canary `impersonation-banner` byte-green hard-fail (`:91-93`, canary default `:20`). Slug derivation strips `-admin-checkpoints-{chromium,mobile,dark}.png` (`:53-55`) so one allowlist entry covers all three projects.

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|

No residual accepted risks beyond the register above. All `accept`-disposition threats have factually-consistent rationale (confirmed against code/SUMMARY frontmatter) and introduce no new attack surface; none carry forward as resurfacing risk.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-06-05 | 13 | 13 | 0 | gsd-security-auditor (verify-mitigations mode) |

Register origin: `register_authored_at_plan_time: true` (all 4 PLAN files carried a `<threat_model>` block). No unregistered flags — `160-03-SUMMARY.md` is the only summary with a `## Threat Flags` section and it reads "None." Implementation files were not modified by this audit.

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-06-05
