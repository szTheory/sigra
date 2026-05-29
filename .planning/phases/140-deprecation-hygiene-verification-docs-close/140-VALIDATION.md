---
phase: 140
slug: deprecation-hygiene-verification-docs-close
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-29
---

# Phase 140 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> This is a milestone-close phase: validation is dominated by the established
> six-gate proof bundle (Phase 136 pattern) plus source/doc grep assertions.
> No new product code or test files are added — see Wave 0 Requirements.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (built into Elixir) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/audit/` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | ~60–120 seconds (full suite); proof bundle adds dep-off + example + docs lanes |

Local prereq: live Postgres at `localhost:5432` (`postgres`/`postgres`). See CLAUDE.md.

---

## Sampling Rate

- **After every task commit:** Run the relevant source/doc grep assertion (DEPR string checks, DOC section-heading checks).
- **After every plan wave:** Run `{full suite command}` for code-touching waves; run the affected proof gate(s) for the verification wave.
- **Before `/gsd-verify-work`:** All 8 proof gates green and `140-VERIFICATION.md` filed.
- **Max feedback latency:** ~120 seconds (full suite).

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 140-DEPR-02 | deprecation | 1 | DEPR-02 | — / — | N/A (docstring-only; no behavior change) | source assert | `grep "0.4.0" lib/sigra/mfa/trust.ex` | ✅ | ⬜ pending |
| 140-DEPR-01 | deprecation | 1 | DEPR-01 | — / — | N/A (docstring-only; no behavior change) | source assert | `grep "0.5.0" lib/sigra/account.ex` | ✅ | ⬜ pending |
| 140-DOC-deploy | docs | 1 | DOC-01 | — / — | N/A (docs append) | doc assert | `grep "## Operator diagnostics" guides/recipes/deployment.md` | ✅ | ⬜ pending |
| 140-DOC-maint | docs | 1 | DOC-01 | — / — | N/A (docs append) | doc assert | `grep -c "OptionalDeps\|Recipe-contract\|Deprecation removal" MAINTAINING.md` (expect ≥3) | ✅ | ⬜ pending |
| 140-DOC-roadmap | docs | 1 | DOC-01 | — / — | N/A (stale-state reconciliation) | doc assert | `grep -n "\[x\].*Phase 137" .planning/ROADMAP.md` | ✅ | ⬜ pending |
| 140-PROOF-render | proof | 2 | DEPR-01, DEPR-02 | — / — | Timeline notes published, not just in source | doc render | `mix docs --warnings-as-errors && grep -r "Scheduled for removal in 0.4.0" doc/ && grep -r "Scheduled for removal in 0.5.0" doc/` | ✅ | ⬜ pending |
| 140-PROOF-bundle | proof | 2 | PROOF-01 | — / — | Whole-milestone claims green | proof bundle | 8 gates (see Manual-Only + Validation Architecture in 140-RESEARCH.md) | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements.* No new test files, fixtures, or framework install needed — the proof bundle re-runs existing suite gates; DEPR edits are source-only docstring appends; DOC-01 edits are documentation appends. All `File Exists` references above already exist in the tree.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `mix sigra.doctor` exit-code gate against the example app | PROOF-01 (Gate 6) | Runs against `test/example/` config, not the library's own test env; exit code recorded verbatim | `cd test/example && mix sigra.doctor`; record exit code (expected `0` — no misconfigured features) verbatim in 140-VERIFICATION.md regardless of value |
| Dep-off lane (Threadline absent) | PROOF-01 (Gate 3) | Multi-step unlock/clean/compile/test/restore; mutates `mix.lock` and must be restored after | Run the Gate 3 command sequence from 140-RESEARCH.md (mirrors ci.yml:171-219), expect 6 excluded / 0 failures, then restore `mix.lock` |
| `mix credo --strict` advisory count | PROOF-01 (advisory) | Non-CI-enforced advisory per D-08; recorded not gated | `mix credo --strict` (record count verbatim) + `mix credo --only sigra` (custom checks must exit 0) |

All other phase behaviors have automated grep/exit-code verification.

---

## Validation Sign-Off

- [ ] All tasks have automated verify (grep/exit-code) or are listed under Manual-Only with explicit instructions
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (none — all targets pre-exist)
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter (set during planning sign-off)

**Approval:** pending
