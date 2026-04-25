# Phase 82 — Technical research

**Question:** What must the planner know to implement **AUD-19** (JWT refresh **persistence** + **`api.jwt_refresh*`** audit co-fate)?

**Sources:** `82-CONTEXT.md`, Phase **81** closure, `lib/sigra/jwt.ex`, `lib/sigra/jwt/refresh_token.ex`, `lib/sigra/api_token.ex`, `.planning/AUDIT-ATOMICITY-DEFAULTS.md`.

---

## Current behavior (pre–82)

- **`Sigra.JWT.refresh/3`** calls **`RefreshToken.rotate/3`**, which performs **`repo.update!`** (supersede) then **`do_create`** (insert) **outside** any shared transaction with audit. Joken signing runs after **`{:ok, ...}`** from rotate.
- **`RefreshToken.rotate/3`** reuse branch: **`revoke_family`** (multiple **`update!`**) then **`Telemetry.event([:sigra, :jwt, :refresh_reuse_detected], ...)`** then **`{:error, :reuse_detected}`** — telemetry fires even though DB writes already committed.
- **`Sigra.APIToken.commit_api_token_jwt_audit/3`** always wraps **`Audit.log_multi_safe`** in **`config.repo.transaction(multi)`** — composing it inside another **`JWT.refresh`** transaction would nest transactions (savepoint semantics on Postgres), violating **D-82-01** / **D-AUD-01**.

---

## Target architecture

1. **Single outer `Repo.transaction/1`** in **`Sigra.JWT.refresh/3`** when **`Keyword.get(opts, :audit_schema)`** (via merged audit opts from config) is set — mirror how **`commit_api_token_jwt_audit`** sources **`opts`** (see **`api_token_audit_opts/1`** and **`Sigra.Config`** audit fields). When audit is off, preserve today’s non-transactional persistence behavior (no artificial txn solely for audit).
2. **`APIToken`**: expose **`append_api_token_jwt_audit(multi, config, action, opts)`** (name bikeshed OK) that returns **`multi |> Audit.log_multi_safe(action, opts)`** when **`:audit_schema`** present, else **`multi`** unchanged. Refactor **`commit_api_token_jwt_audit/3`** to **`Multi.new() |> append_api_token_jwt_audit(...) |> repo.transaction`** so standalone **`audit_jwt_refresh/2`** / **`audit_jwt_refresh_reuse/2`** keep Phase **81** semantics (**`:ok`** + telemetry on audit-only failure per **D-AUD-06**).
3. **`RefreshToken`**: remain audit-agnostic; add **`Multi`/`changeset`-based** helpers (private or **`@doc false`**) used only from **`JWT.refresh`** — e.g. supersede step + insert step as named **`Multi`** operations, and reuse path as **`Multi.update_all`** / per-row updates + single audit step in the **same** outer transaction. **No** **`Sigra.Audit`** imports in **`RefreshToken`**.
4. **Public contract (D-82-02):** when co-fate path used and any step fails (including audit), return **`{:error, :jwt_refresh_aborted}`**; document exception to **D-AUD-06**. Preserve **`{:error, :invalid_token}`**, **`{:error, :token_expired}`** for pre-txn validation. **`{:error, :reuse_detected}`** only after reuse bundle commits.
5. **Reuse telemetry (D-82-03):** emit **`[:sigra, :jwt, :refresh_reuse_detected]`** only from the success path **after** transaction commits (e.g. inside **`case repo.transaction(...)`** success branch), not before.

---

## Ecto / repo API

- Library targets **Elixir ~> 1.18**; use **`Repo.transaction/1`** + **`Ecto.Multi`** as the stable pattern (same as Phase **79**/**80**/**81**). **`Repo.transact/2`** is optional discretion only if already used consistently for this codepath — **not** required for acceptance.

---

## Testing posture

- New file **`test/sigra/jwt_refresh_audit_cofate_test.exs`**, **`async: false`**, Postgres-only patterns from **`api_token_audit_atomic_test.exs`**: **`sigra_config/1`**, CHECK constraint fault injection, telemetry handlers with unique IDs, SQL counts for **`user_tokens`** and **`audit_events`**.
- Prove: (1) happy rotate + exactly one **`api.jwt_refresh`** row and persisted rotation; (2) audit off → persistence without audit rows; (3) audit fault → no partial **`user_tokens`** state; (4) reuse + **`api.jwt_refresh_reuse`** + rollback on audit failure; (5) telemetry ordering on reuse.

---

## Planning truth (AUD-19-04)

- **44** / **45** / **09-VERIFICATION** rows **048–049**: mechanism text must describe **one transactional boundary** covering **`user_tokens`** refresh effects **and** **`api.jwt_refresh*`** when **`:audit_schema`** set; dated footnote **81** = audit-only txn; **82** = **AUD-08** persistence co-fate closure per **D-82-05**.
- **`CHANGELOG` [Unreleased]**: one bullet — operator-facing co-fate behavior.
- **`09-03-SUMMARY.md`**: short pointer to **`82-VERIFICATION.md`**.

---

## Validation Architecture

| Dimension | How phase 82 validates |
|-----------|-------------------------|
| 1. Correctness | **`mix test test/sigra/jwt_refresh_audit_cofate_test.exs`** — happy path row counts + token state |
| 2. Atomicity | Fault injection: failed audit insert rolls back **`user_tokens`** updates from same txn |
| 3. Regression | Existing **`api_token_audit_atomic_test.exs`** still passes (audit-only API unchanged) |
| 4. Audit-off | Config without **`:audit_schema`** — no **`audit_events`** rows; refresh still succeeds |
| 5. Contract | **`grep`** for **`@spec`** / **`@doc`** mentioning **`:jwt_refresh_aborted`** on **`JWT.refresh`** / **`Auth.refresh_jwt`** |
| 6. Docs | Inventory + **09** + **CHANGELOG** grep-verifiable strings per plan **03** |
| 7. Security | Co-fate prevents “rotated refresh without audit row” (repudiation / compliance gap) |
| 8. Nyquist | **`82-VALIDATION.md`** maps each plan task to **`mix test`** commands |

---

## RESEARCH COMPLETE

Planner may proceed. Open questions left to executor discretion per **82-CONTEXT.md** §Claude's discretion (`Multi` step names, exact helper arity).
