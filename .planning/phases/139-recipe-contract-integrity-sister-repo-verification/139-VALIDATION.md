---
phase: 139
slug: recipe-contract-integrity-sister-repo-verification
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-29
---

# Phase 139 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.18+) |
| **Config file** | `test/test_helper.exs` (existing) |
| **Quick run command** | `mix test test/sigra/recipes/companion_lib_contract_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~2 seconds (fixture only; pure filesystem, `async: true`, no DB) |

Recipe-fix verification (RCV-01/RCV-02) additionally uses `mix docs --warnings-as-errors`.

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/recipes/companion_lib_contract_test.exs`
- **After every plan wave:** Run `mix test` (full suite, requires live Postgres per CLAUDE.md)
- **After recipe edits (RCV-01/RCV-02):** Run `mix docs --warnings-as-errors` — must exit 0
- **Before `/gsd-verify-work`:** Full suite must be green AND `mix docs --warnings-as-errors` clean
- **Max feedback latency:** ~2 seconds for the fixture; full suite as usual

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 139-01-01 | 01 | 1 | RCT-01 | — | N/A (docs-contract) | unit | `mix test test/sigra/recipes/companion_lib_contract_test.exs` | ❌ W0 | ⬜ pending |
| 139-01-02 | 01 | 1 | RCT-01 | — | Fixture fails when a marker is removed (drift caught) | unit (negative) | manual remove-marker → assert red → revert | ❌ W0 | ⬜ pending |
| 139-01-03 | 01 | 1 | RCT-01 | — | Fixture fails when glob is empty (D-05) | unit | `mix test test/sigra/recipes/companion_lib_contract_test.exs` | ❌ W0 | ⬜ pending |
| 139-02-01 | 02 | 1 | RCV-01 | — | `lockspire.md` example returns `{:ok, account}`/`{:error, :not_found}` | docs/source | `mix docs --warnings-as-errors` + RCT-01 fixture | ✅ | ⬜ pending |
| 139-02-02 | 02 | 1 | RCV-02 | — | `rulestead.md` declares `@behaviour Rulestead.Admin.Policy` + `@impl can?/4` | docs/source | `mix docs --warnings-as-errors` + RCT-01 fixture | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*Note: RCV-01/RCV-02 are documentation-correctness fixes verified against cited sister-repo source (Lockspire v1.2.0 `def616d`; Rulestead v0.1.3 `0a18360`) — the verification is the cited reference + clean docs build, not a new runtime test. The RCT-01 fixture re-asserts structural integrity over the edited recipes.*

---

## Wave 0 Requirements

- [ ] `test/sigra/recipes/companion_lib_contract_test.exs` — new pure-ExUnit fixture for RCT-01 (does not exist yet; created in Wave 1, no separate framework install needed)

*ExUnit infrastructure already exists. The only "missing" file is the fixture itself, which is the Wave 1 deliverable. No `conftest`-equivalent or framework install required.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Drift is caught at merge time (Success Criteria #2) | RCT-01 | Negative test proves the fixture's value but should not ship as a permanent failing test | Temporarily remove one required marker from one recipe, run the fixture, confirm it fails with a message naming the recipe + missing marker, then revert. Document the observed failure in the task evidence. |

*All other phase behaviors have automated verification via the fixture and `mix docs --warnings-as-errors`.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (fixture file)
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s for fixture
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
