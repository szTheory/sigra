---
created: 2026-07-28T00:00:00.000Z
status: pending
title: export_auth_data/2 impersonation deny path is unreachable in a generated host
area: security
severity: low
audit_finding: W-5
audit_source: .planning/v1.46-MILESTONE-AUDIT.md
requirements: [SEC-01]
files:
  - priv/templates/sigra.install/core/auth.ex
  - test/sigra/install/generated_impersonation_parity_test.exs
source: 2026-07-28 v1.46 milestone audit (cross-phase integration check)
---

## What

SEC-01 requires generated hosts to deny data export during impersonation. The guard exists
— `core/auth.ex:1101-1107` calls `forbid_sensitive_operation/3` with
`"account.data_export"` — but it is **unreachable**:

1. **No caller.** No generated template, controller, or example module calls
   `export_auth_data/`. The function is generated but never wired to a route or UI.
2. **Opt-in even if called.** The guard only fires when the caller passes `scope:` —
   `extract_scope/1` at `:1159-1161` returns no scope otherwise, and the guard no-ops.

`generated_impersonation_parity_test.exs:18` asserts only that the string
`"account.data_export"` appears in the template, which is why this passed.

The other nine SEC-01 operations are genuinely wired: `forbid_sensitive_operation/3` guards
10 sites (`core/auth.ex:226,694,709,756,808,816,1031,1055,1075,1103`) and scope propagation
was verified at each consumer — `settings_live.ex:241,286,313`,
`mfa_settings_live.ex:734,782,838`, `session_controller.ex:278` and `:393-401`. API tokens
keep a separate typed contract (`auth_api_token.ex:58-69` → `api_token_controller.ex:62,83,100`).
Example parity confirmed at 10 guard sites on both sides. **This finding is about the tenth
operation only.**

## Why it is low severity

Nothing is *insecure* — there is no exposed data-export path to abuse, precisely because
there is no caller. The defect is that SEC-01's data-export clause is satisfied on paper
rather than in behaviour, so if an adopter later wires up export they inherit a guard that
silently does nothing unless they remember to pass `scope:`.

## Recommended fix

Pick one, deliberately:

- **Wire it.** Generate a data-export route/UI so the guard is on a live path, and add a
  deny-during-impersonation assertion to the parity test. This is the option that makes
  SEC-01 true as written.
- **Or scope it out.** If data export is not meant to ship in the generated host yet,
  remove the clause from SEC-01's wording so the requirement stops claiming coverage it
  does not have, and leave the guard in place for adopters who add their own export.

Separately, and regardless of which is chosen: consider making the scope argument
non-optional for guarded operations, so a caller cannot accidentally bypass the guard by
omitting `scope:`. That is the general-case fix and it protects the other nine too.

## Related

- W-6 in the same audit — same family: generated artifact outside its verification net.
- [[reference_installer_context_impersonation_guard_gap]] if that todo still stands.
