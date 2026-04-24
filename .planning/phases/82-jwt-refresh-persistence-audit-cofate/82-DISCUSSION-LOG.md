# Phase 82: JWT refresh persistence + audit co-fate — Discussion log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in **`82-CONTEXT.md`**.

**Date:** 2026-04-24  
**Phase:** 82 — JWT refresh persistence + audit co-fate  
**Mode:** User requested **all** gray areas + parallel subagent research + one-shot cohesive recommendations (auto-synthesized into context).

**Areas covered:** (1) transaction owner + API shape, (2) caller-visible contract on audit failure, (3) reuse path symmetry, (4) test layout, (5) planning truth for **048–049**.

---

## Area 1 — Transaction owner + API shape

| Option | Description | Selected |
|--------|-------------|----------|
| A — `Sigra.JWT.refresh` owns one `Repo.transaction` + `Multi` | Stable public API; orchestrator at use-case boundary | ✓ |
| B — `RefreshToken.rotate` with audit callbacks | Callback ordering smell | |
| C — `Sigra.Auth.refresh_jwt` owns txn | Duplicates “official” API vs `JWT.refresh` | |
| D — `Sigra.APIToken` owns rotation + audit | Domain blur, reject | |
| E — Internal private coordinator | ✓ combined with A if `jwt.ex` splits | ✓ (optional split) |

**User's choice:** **All** → research synthesis: **A + optional E**, **`RefreshToken`** Multi-friendly without audit, **`APIToken`** contributes audit steps without nested txn, **`Auth.refresh_jwt`** stays delegate.

**Notes:** Subagent compared Rails/Django/Spring implicit txn/callback footguns vs explicit **`Multi`**.

---

## Area 2 — Caller-visible contract when audit fails (co-fate)

| Option | Description | Selected |
|--------|-------------|----------|
| Rollback + `{:error, _}` from refresh | Matches Ecto + **AUD-19** | ✓ |
| `:ok` + telemetry only | Wrong for token-returning co-fate | |
| Raw `Multi` error tuples | Poor DX | |

**User's choice:** **All** → research synthesis: **`{:error, :jwt_refresh_aborted}`** (or planner-aligned name) + **`@doc`** contrast with **D-AUD-06** / Phase **81** audit-only helpers; telemetry complementary.

---

## Area 3 — Reuse path (`:reuse_detected`) symmetry

| Option | Description | Selected |
|--------|-------------|----------|
| Single txn: family revoke + `api.jwt_refresh_reuse` | Postgres ACID + **AUD-19-02** | ✓ |
| Split txn | Orphan state risk | |

**User's choice:** **All** → research synthesis: one **`Multi`**; telemetry **after** commit; **`update_all`** discretionary for lock time.

---

## Area 4 — Test strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Extend only `api_token_audit_atomic_test.exs` | Hurts CI clarity for different contract | |
| New dedicated co-fate test module | JWT persistence + audit proofs | ✓ |
| Both | Split: audit-only stays in A; co-fate in new file | ✓ |

**User's choice:** **All** → research synthesis: **new file** primary; keep Phase **81** tests in existing file.

---

## Area 5 — Planning truth (**048–049**)

| Option | Description | Selected |
|--------|-------------|----------|
| Surgical cells + dated footnote | Nyquist integrity, low surprise | ✓ |
| Full matrix rewrite | Avoid | |

**User's choice:** **All** → research synthesis: surgical + **2026-04-24** supersession note Phase **81** → **82**; **`82-VERIFICATION.md`** + **`CHANGELOG`** as closure spine.

---

## Claude's discretion

- Exact error atom string and internal normalization helper.
- **`update_all`** vs per-row updates in **`revoke_family`** when safe without migration.

## Deferred ideas

Captured in **`82-CONTEXT.md`** `<deferred>` (grace window, `family_id` column, phase **83**).
