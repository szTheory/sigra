---
phase: 82
plan: "01"
status: complete
---

# Plan 82-01 — JWT refresh co-fate (library)

## Outcome

- **`Sigra.APIToken.append_api_token_jwt_audit_to_multi/3`** composes **`Audit.log_multi_safe`** into a caller **`Ecto.Multi`**; **`commit_api_token_jwt_audit/3`** refactored to use it.
- **`Sigra.JWT.RefreshToken`**: **`classify_refresh_token/3`**, **`rotate_with_reuse_meta/3`**, **`build_rotate_persist_multi/5`**, **`build_revoke_family_multi/4`**; reuse telemetry removed from refresh_token module (**`[:sigra, :jwt, :refresh_reuse_detected]`** emitted from **`Sigra.JWT`**).
- **`Sigra.JWT.refresh/3`**: when **`:audit_schema`** is set, single **`Repo.transaction/1`** for happy + reuse paths; **`{:error, :jwt_refresh_aborted}`** on co-fate failure; **`Sigra.Auth.refresh_jwt/2`** spec updated.

## Self-Check: PASSED

- `MIX_ENV=test mix compile --warnings-as-errors`
- `mix test test/sigra/jwt_test.exs test/sigra/jwt/refresh_token_test.exs`

## Deviations

None.
