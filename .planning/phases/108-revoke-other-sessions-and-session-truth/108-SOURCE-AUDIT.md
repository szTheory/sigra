# Phase 108 Source Audit

**Phase:** `108-revoke-other-sessions-and-session-truth`  
**Audited:** 2026-05-07  
**Authority order:** `108-CONTEXT.md` -> `108-RESEARCH.md` -> `108-PATTERNS.md` -> milestone files

## Scope Result

Phase 108 stays bounded to `SESS-02` plus only the minimum `SESS-04` / `SESS-05` truth work required to make the preserve-current revoke flow honest.

`SESS-03` is intentionally deferred by locked decision `D-108-14` and does not appear in any plan.

## Coverage Matrix

| Source Type | Item | Coverage |
|---|---|---|
| GOAL | Productize a truthful "revoke every other session" control plane without redesigning storage | `108-01` defines the library revoke-other contract; `108-02` wires the generated user surface; `108-03` aligns admin truth and docs |
| REQ | `SESS-02` preserve-current revoke with truthful outcomes | `108-01`, `108-02` |
| REQ | `SESS-04` current-session and already-owned session-state truth | `108-02`, `108-03` |
| REQ | `SESS-05` thin-host, library-owned session UX | `108-01`, `108-02`, `108-03` |
| REQ | `SESS-03` security activity feed | Deferred by `D-108-14`; excluded from this phase |
| RESEARCH | Use a new library-owned preserve-current wrapper over existing `:except_token` behavior | `108-01` |
| RESEARCH | Keep generated wrappers thin and preserve template parity | `108-02` |
| RESEARCH | Keep admin/user truth aligned and avoid invented timeout precision | `108-03` |
| CONTEXT | `D-108-01` center `SESS-02` first | `108-01`, `108-02` |
| CONTEXT | `D-108-02` thin-host, library-owned control plane | `108-01`, `108-02`, `108-03` |
| CONTEXT | `D-108-03` explicit preserve-current primitive | `108-01` |
| CONTEXT | `D-108-04` preserve current-session continuity | `108-01`, `108-02` |
| CONTEXT | `D-108-05` side effects match revoked set | `108-01` |
| CONTEXT | `D-108-06` no UI-computed revoke set | `108-01`, `108-02` |
| CONTEXT | `D-108-07` explicit current-session identification | `108-02`, `108-03` |
| CONTEXT | `D-108-08` show only Sigra-owned truth | `108-02`, `108-03` |
| CONTEXT | `D-108-09` no fake timeout/security precision | `108-02`, `108-03` |
| CONTEXT | `D-108-10` user/admin truth aligned | `108-02`, `108-03` |
| CONTEXT | `D-108-11` explicit preserve-current audit semantic | `108-01` |
| CONTEXT | `D-108-12` preserve-current is a security invariant | `108-01`, `108-02` |
| CONTEXT | `D-108-13` keep sensitive mutation in controller/library patterns | `108-01`, `108-02` |
| CONTEXT | `D-108-14` defer security-activity history | All plans exclude activity-feed work |
| CONTEXT | `D-108-15` preserve generator parity | `108-02` |

## Deferred / Excluded

These items are intentionally absent from the plan set:

- `SESS-03` recent security activity, suspicious-login history, or session lifecycle feed
- New session storage models, alternate adapters, or token formats
- Admin-only bulk revoke action beyond existing truthful session-state alignment
- Countdown-style timeout UI, device trust scoring, geo enrichment, or fraud semantics

## Wave Structure

| Wave | Plans | Why |
|---|---|---|
| 1 | `108-01` | Library contract and explicit audit semantics must exist before any generated-host surface can call them. |
| 2 | `108-02` | User/session template parity depends on the new library primitive and its failure semantics. |
| 3 | `108-03` | Admin truth and docs/tests closeout depend on the user/library contract being settled and must not fork semantics. |

## Outcome Check

- Every locked decision from `108-CONTEXT.md` is mapped to at least one plan.
- No plan includes recent-activity feed work.
- Admin scope remains truthful current-session/session-state alignment only.
- Preserve-current revoke is treated as an explicit semantic, not collapsed into generic `session.revoke_all`.
