# Phase 9: Audit Logging - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-09
**Phase:** 09-audit-logging
**Areas discussed:** Capture mechanism, Storage and schema, Query API surface, Custom events hook

---

## Gray Area Selection

User selected all 4 proposed areas for discussion.

| Area | Selected |
|------|----------|
| Capture mechanism | ✓ |
| Storage and schema | ✓ |
| Query API surface | ✓ |
| Custom events hook | ✓ |

---

## Capture Mechanism

User asked for research-backed recommendation before committing. Two parallel research agents spawned:
1. Elixir audit patterns (libraries, telemetry ecosystem, auth-lib precedent, Ecto patterns)
2. Scalability / DX / DevOps-SRE / software architecture

**Options considered (after research):**

| Option | Atomicity | Silent failure risk | Precedent |
|--------|-----------|---------------------|-----------|
| Ecto.Multi direct write | Guaranteed | None | Rodauth, PaperTrail, Better Auth, Elixir Forum consensus |
| Telemetry handler → DB write | None | HIGH — handler auto-detaches on crash, no recovery | Nobody uses this for security audit |
| Telemetry handler → Oban job | Eventual | Low | Observability only |
| PostgreSQL triggers (Carbonite) | DB-level guaranteed | None | Loses application context (IP, UA); PG-only |

**Critical finding:** Per telemetry v1.4.1 docs and Elixir Forum thread 56069, telemetry handlers that raise/exit/throw are automatically detached with no recovery until app restart. A single DB pool exhaustion or connection timeout silently kills all future audit capture. **Disqualifying flaw** for security audit.

**User's choice:** Direct Ecto.Multi writes (recommended). Telemetry continues for observability layer only.

**Notes:** Matches Rodauth (architectural gold standard cited in PROJECT.md). Aligns with "own your code" philosophy — audit is a first-class concern inside Auth functions, not an out-of-band observer.

---

## Storage and Schema

Schema design presented as a single concrete recommendation with three sub-questions (naming, retention, PII handling). No alternatives offered at the schema-structure level because the fields were derived directly from AUDIT-02 requirement + research.

### Sub-question 1: Table name

| Option | Selected |
|--------|----------|
| audit_events (matches Phase 1 D-27 reservation) | ✓ |
| audit_logs (industry term) | |

**User's choice:** `audit_events` (recommended). Preserves Phase 1 reservation and Sigra's "events, not logs" telemetry naming convention.

### Sub-question 2: Retention default

| Option | Selected |
|--------|----------|
| Keep forever (nil default) | ✓ |
| 365-day default | |
| 90-day default | |

**User's choice:** Keep forever. Forces explicit developer decision, no silent data loss, safest for compliance (SOC 2 / GDPR).

### Sub-question 3: PII handling on user deletion

| Option | Description | Selected |
|--------|-------------|----------|
| Keep audit rows as-is, natural pseudonymization | actor_id is UUID, no email/PII in audit row | ✓ |
| Null out actor_id on deletion | Loses actor linkage | |
| Cascade delete audit rows | Destroys security forensics for deleted users | |

**User's choice:** Keep rows. Phase 8 anonymize/delete leaves the audit trail pointing to a removed/anonymized user — security forensics preserved, "right to erasure" satisfied because personal data is gone.

**Notes:** No partitioning / RLS / PG-only features baked in — multi-adapter support required per CLAUDE.md constraints.

---

## Query API Surface

| Option | Description | Selected |
|--------|-------------|----------|
| Ship all 5 functions (log, query, list, stream, count) | Full composable + paginated + export-ready | ✓ |
| Minimal: log + list only | Simplest, pushes work to consumers | |
| Full set + on_log behaviour callback | Extra extension point beyond telemetry | |

**User's choice:** All 5 functions. Each has a distinct job; covers AUDIT-03 (query by user/date/type), AUDIT-04 (custom log), SIEM export (stream), and admin listing (list).

**Key design points recorded:**
- Cursor pagination (Base64-encoded `inserted_at_usec|id`), not offset
- `query/1` returns an `Ecto.Query.t()` for composability
- `action_prefix` filter for namespace-based tiered queries
- `count/2` separated from `list/2` to make O(n) cost explicit
- Internal Sigra modules use private `__log_internal__/3` that bypasses namespace guardrails

---

## Custom Events Hook (AUDIT-04)

| Option | Description | Selected |
|--------|-------------|----------|
| Reserved prefixes + size cap + format validation | Full guardrails | ✓ |
| Size cap + format validation only | No reserved prefixes (trust developers) | |
| Everything + hash-chained immutability | Tamper-evident chain (regulated industry) | |

**User's choice:** Full guardrails (recommended).

**Specifics:**
- Reserved prefixes: `auth.` `session.` `mfa.` `oauth.` `api.` `account.` `sigra.`
- Configurable reserved list — host apps can extend (e.g., `admin.`)
- Action format regex: `^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$`
- Metadata size cap: 8KB default, configurable
- Same `Sigra.Audit.log/3` entry point as internal events (one surface)
- `log_multi/3` wrapper for transactional custom events
- Telemetry passthrough: `[:sigra, :audit, :log]` fires on every audit write

Hash-chained tamper-evident audit rejected as premature for v1 — deferred as extension point for future regulated-industry milestone.

---

## Claude's Discretion

Areas deferred to planner/executor:
- Exact internal module split (`Sigra.Audit`, `Sigra.Audit.AuditEvent`, `Sigra.Audit.Cursor`, `Sigra.Audit.Changeset`, `Sigra.Workers.AuditCleanup`)
- Cursor encoding format details (Base64 vs Base64URL vs signed)
- Error tuple shapes for validation failures
- Whether `count/2` uses PG estimated counts for large tables
- Generator template structure and migration file format
- Full telemetry metadata shape for `[:sigra, :audit, :log]` beyond the listed fields

## Deferred Ideas

- Admin LiveView for browsing audit log (likely Phase 10 or separate milestone)
- Hash-chained tamper-evident audit rows (regulated industry feature, post-v1)
- SIEM export format helpers (to_csv, to_jsonl)
- Aggregation/reporting functions (count_by_action, failed_logins_per_hour)
- Full-text search on metadata
- PostgreSQL native table partitioning integration (document as scaling guide only)
- Per-tenant audit isolation (tenant_id column — orgs deferred to v2)
- Batch log API (log_many/1 — encourages fire-and-forget)
- Event versioning (host-app concern)
- Failure-capture on `token_verify` successes (too noisy by default)
