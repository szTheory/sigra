# Phase 129: Generated Host Parity And Docs - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md - this log preserves the analysis.

**Date:** 2026-05-27
**Phase:** 129-generated-host-parity-and-docs
**Mode:** assumptions
**Areas analyzed:** Generated Lifecycle Parity, Generated Export Boundary, Install Golden As Generated-Host Contract, Documentation Truth Claims

## Assumptions Presented

### Generated Lifecycle Parity

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Generated context wrappers, the example app, and install golden should keep account deletion as thin calls into `Sigra.Auth.schedule_deletion/3`, `Sigra.Auth.cancel_deletion/3`, and `Sigra.Account.deletion_status/1`. | Confident | `priv/templates/sigra.install/core/auth.ex`; `test/example/lib/example/accounts.ex`; `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex`; `lib/sigra/account/deletion.ex` |

### Generated Export Boundary

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 129 should add or align only thin generated/example/golden host seams for `Sigra.DataExport.export_auth_data/3`, passing repo/user/configured schemas without recreating payload shape in host code. | Likely | `lib/sigra/data_export.ex`; `test/sigra/data_export_test.exs`; `priv/templates/sigra.install/core/auth.ex`; `test/example/lib/example/accounts.ex`; `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex` |

### Install Golden As Generated-Host Contract

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| The install golden fixture should be updated after template/example parity changes, not treated as an independent source of behavior. | Confident | `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex`; `priv/templates/sigra.install/core/auth.ex`; `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/settings_live.ex`; `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/reactivation_live.ex` |

### Documentation Truth Claims

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Docs should explicitly distinguish Sigra-owned auth/account data from host-owned domain data, document omission behavior for optional schemas, and soften deletion-copy claims that say "all associated data" or unconditional permanent removal. | Confident | `guides/flows/account-lifecycle.md`; `priv/templates/sigra.install/core/settings_live.ex`; `priv/templates/sigra.install/core/reactivation_live.ex`; `lib/sigra/data_export.ex`; `test/sigra/data_export_test.exs`; `guides/flows/audit-logging.md` |

## Corrections Made

No corrections - all assumptions confirmed.

## External Research

No external research was needed. Codebase and prior phase context provided enough evidence.
