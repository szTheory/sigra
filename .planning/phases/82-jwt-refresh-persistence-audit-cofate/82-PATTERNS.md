# Phase 82 — Pattern map

Analogs for executor **`read_first`** lists.

| Planned touch | Role | Closest analog |
|---------------|------|----------------|
| `lib/sigra/jwt.ex` | Orchestrator owns txn | `lib/sigra/account.ex` bounded Multi + `Repo.transaction` (Phase **80** posture) |
| `lib/sigra/api_token.ex` | Compose audit into caller Multi | `commit_api_token_verify_failure_audit/2` + **`commit_api_token_jwt_audit/3`** (Phase **81**) |
| `lib/sigra/jwt/refresh_token.ex` | Domain writes as Multi steps | `lib/sigra/api_token.ex` revoke path (`Multi` + `repo.transaction`) |
| `test/sigra/jwt_refresh_audit_cofate_test.exs` | Postgres atomicity tests | `test/sigra/api_token_audit_atomic_test.exs` (CHECK injection, telemetry) |

**Excerpt contract:** `Audit.log_multi_safe/3` appends to **`Ecto.Multi`**; never call **`Repo.transaction`** inside a function meant to run inside **`JWT.refresh`**’s outer transaction.
