# Phase 58: OAuth ceremony + audit smoke — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in **`58-CONTEXT.md`**.

**Date:** 2026-04-23  
**Phase:** 58 — OAuth ceremony + audit smoke  
**Areas discussed:** Ceremony path breadth; Audit outcomes vs substitute; Test deliverable shape; CI merge gate explicitness  
**Mode:** `[--all]` + parallel maintainer research (subagents) + principal synthesis against **`lib/sigra/oauth.ex`** / **`lib/sigra/audit.ex`**

---

## Ceremony path breadth

| Option | Description | Selected |
|--------|-------------|----------|
| A — Registration-only | `Callback.process_callback` → `oauth.register_via_oauth` as sole OA-01 ceremony | ✓ (primary) |
| B — + link / second domain path | Extra paths for distinct audit writers | ○ (optional if regression) |
| C — Full matrix | register + link + unlink merge-blocking | ✗ (deferred — CI + fixture cost) |

**User's choice:** All areas discussed; maintainer directive = **one-shot cohesive recommendations**.  
**Notes:** Subagents + code review: **authorize_url** is a **second** high-signal ceremony with **distinct** audit action **`oauth.authorize`** — included as **D-58-02** recommended in same phase.

---

## Audit outcomes vs documented substitute

| Option | Description | Selected |
|--------|-------------|----------|
| Row assertions only | Assert DB audit wherever schema set | ✓ |
| + Test-asserted substitute | Telemetry / structured events only where no row | ✓ (narrow) |
| Comment-only substitute | No assertion | ✗ (explicit anti-pattern) |

**Notes:** **`log_safe`** with **`audit_schema`** persists rows — **authorize** is **not** telemetry-only; substitute narrative applies only to true non-row sites per **EX-45-\*** / inventory.

---

## Test deliverable shape

| Option | Description | Selected |
|--------|-------------|----------|
| Extend atomicity module only | Single `OAuthAuditAtomicityTest` | ✗ |
| Dedicated ceremony module | `Sigra.OAuthCeremonyAuditTest` + move happy-path registration | ✓ |

**Notes:** Aligns with Plug/Phoenix-style **split by concern**; improves **OA-02** grep and doc naming.

---

## CI merge gate explicitness

| Option | Description | Selected |
|--------|-------------|----------|
| Status quo | `library_tests` → `mix test` | ✓ (behavioral gate) |
| Duplicate `mix test` path step | Second run of `test/sigra/oauth/` | ✗ |
| Optional contract test | Planning-style guard on `ci.yml` | ○ (Claude’s discretion **D-58-11**) |

---

## Claude's Discretion

- Contract test **wording / YAML anchoring** for **D-58-11** if implemented.  
- Shared test support extraction vs inline DDL duplication.

## Deferred Ideas

- Merge-blocking **full** link/unlink OAuth matrix; **live-provider** CI — see **58-CONTEXT.md** `<deferred>`.
