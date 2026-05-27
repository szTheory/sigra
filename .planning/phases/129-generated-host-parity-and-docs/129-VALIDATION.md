---
phase: 129
slug: generated-host-parity-and-docs
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-27
---

# Phase 129 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Mix project aliases |
| **Config file** | `mix.exs`, `test/test_helper.exs`, `test/example/mix.exs` |
| **Quick run command** | `mix test test/sigra/templates/settings_live_test.exs test/sigra/install/golden_diff_test.exs --max-failures 1` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | Quick: ~20-60 seconds; full suite depends on local Postgres and full project test load |

---

## Sampling Rate

- **After every task commit:** Run the focused test file for the files touched, plus `mix format --check-formatted` for changed `.ex` and `.exs` files.
- **After every plan wave:** Run `mix test test/sigra/templates/settings_live_test.exs test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs test/sigra/data_export_test.exs test/sigra/account/deletion_test.exs test/sigra/workers/account_deletion_test.exs --max-failures 1`.
- **Before `$gsd-verify-work`:** Run `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test`.
- **Max feedback latency:** Prefer under 60 seconds for task-level checks; use the full suite only at wave and phase gates.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 129-01-01 | 01 | 1 | HOST-01 | T-129-01 | Generated/export wrapper delegates to `Sigra.DataExport.export_auth_data/3` and does not serialize payload fields in host code. | template/unit | `mix test test/sigra/templates/settings_live_test.exs --max-failures 1` | Existing test file, assertions need update | pending |
| 129-01-02 | 01 | 1 | HOST-01 | T-129-02 | Generated lifecycle copy avoids unconditional permanent-removal claims and stays strategy-neutral. | template/unit | `mix test test/sigra/templates/settings_live_test.exs --max-failures 1` | Existing test file, assertions need update | pending |
| 129-01-03 | 01 | 1 | HOST-01 | T-129-03 | Install golden output mirrors templates after rebless. | golden/integration | `MIX_ENV=test mix sigra.fixture.rebless_golden && mix test test/sigra/install/golden_diff_test.exs --max-failures 1` | Existing golden test | pending |
| 129-02-01 | 02 | 1 | DOC-01 | T-129-04 | Docs distinguish Sigra-owned auth/account data from host-owned domain data and describe explicit `omissions`. | docs/grep or guide test | `mix test test/sigra/guides_dx02_test.exs --max-failures 1` or focused docs grep checks added by plan | Existing guide test file | pending |
| 129-02-02 | 02 | 1 | DOC-01 | T-129-05 | Docs describe `:hard_delete`, `:soft_delete`, and `:anonymize` consequences without compliance overclaim. | docs/grep or guide test | `mix test test/sigra/guides_dx02_test.exs --max-failures 1` or focused docs grep checks added by plan | Existing guide files | pending |

---

## Wave 0 Requirements

- [ ] Add or update template assertions that `priv/templates/sigra.install/core/auth.ex` contains `export_auth_data` and `Sigra.DataExport.export_auth_data`.
- [ ] Add or update assertions preventing broad generated deletion copy such as `all associated data` and unconditional `permanently removed` in generated templates.
- [ ] Rebless install golden after template changes with `MIX_ENV=test mix sigra.fixture.rebless_golden`.
- [ ] Add docs verification for Sigra-owned versus host-owned data, optional-schema `omissions`, and deletion strategy consequences.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Final docs readability and discoverability | DOC-01 | Automated grep can prove required terms exist, but not whether docs are positioned clearly for operators. | Read `guides/flows/account-lifecycle.md`, `guides/flows/audit-logging.md`, and `guides/recipes/testing.md`; confirm the export/deletion boundary is visible without implying full legal compliance. |

---

## Threat References

| Ref | Threat | Mitigation Required In Plans |
|-----|--------|------------------------------|
| T-129-01 | Secret-bearing auth data exposure through generated export code. | Generated/example wrappers must call `Sigra.DataExport.export_auth_data/3` and avoid hand-rolled payload serialization. |
| T-129-02 | Misleading deletion copy creates user/operator trust failure. | Generated/example/golden copy must avoid broad permanent-removal claims unless scoped to configured strategy. |
| T-129-03 | Golden fixture drift masks installer behavior. | Golden output must be regenerated from templates and verified by `golden_diff_test.exs`. |
| T-129-04 | Host-domain export overclaim implies Sigra exports all application data. | Docs must state Sigra export covers Sigra-owned auth/account data and host apps own domain-data export/retention. |
| T-129-05 | Optional schema omissions are hidden from operators. | Docs/tests must describe explicit `omissions` for missing optional Sigra-owned schemas. |

---

## Validation Sign-Off

- [x] All planned tasks have automated verification targets or Wave 0 dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references identified by research.
- [x] No watch-mode flags.
- [x] Feedback latency target documented.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** approved 2026-05-27 for planning
