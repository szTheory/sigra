# Phase 109 Source Audit

**Phase:** `109-security-activity-and-session-history-truth`  
**Audited:** 2026-05-08  
**Authority order:** `109-CONTEXT.md` -> `109-RESEARCH.md` -> `109-PATTERNS.md` -> milestone files

## Scope Result

Phase 109 stays centered on `SESS-03` per `D-109-01`: a recent security-activity surface derived from Sigra-owned persisted truth, with only the minimum `SESS-04` / `SESS-05` follow-through needed to keep generated and admin surfaces aligned.

Phase 108 preserve-current revoke semantics are treated as already decided. Phase 109 may surface those lifecycle events truthfully, but it does not reopen the preserve-current mutation contract itself.

Timeout-expiry history is intentionally excluded from this first activity surface because current timeout cleanup does not persist a corresponding audit event. Present-state timeout/session posture remains the `SESS-04` boundary; history is not promised here.

## Coverage Matrix

| Source Type | Item | Coverage |
|---|---|---|
| GOAL | Productize recent account/session security activity from persisted Sigra truth without introducing a second read model | `109-01` defines the library-owned activity seam and missing audit truth; `109-02` wires the generated user surface and template parity; `109-03` aligns admin truth and docs |
| REQ | `SESS-03` recent security activity including sign-ins, suspicious-login outcomes, and meaningful session lifecycle events | `109-01`, `109-02`, `109-03` |
| REQ | `SESS-04` generated user/admin session surfaces stay aligned with already-owned session/security state | `109-02`, `109-03` |
| REQ | `SESS-05` thin-host, library-owned session/security UX | `109-01`, `109-02`, `109-03` |
| RESEARCH | Add a library-owned `Sigra.SecurityActivity` seam instead of querying raw audit rows from LiveView | `109-01` |
| RESEARCH | Close missing persisted truth for voluntary logout and MFA completion before UI inference | `109-01` |
| RESEARCH | Reuse admin audit query/presenter ordering and normalization instead of a parallel user-only read model | `109-01`, `109-03` |
| RESEARCH | Add the first activity surface to the existing `/users/sessions` experience and refresh it after relevant actions | `109-02` |
| RESEARCH | Keep timeout history out unless persisted audit truth is also added | All plans exclude timeout-history claims |
| CONTEXT | `D-109-01` center `SESS-03`; do not reopen Phase 108 beyond activity semantics | `109-01`, `109-02`, `109-03` |
| CONTEXT | `D-109-02` thin-host, library-owned activity surface | `109-01`, `109-02`, `109-03` |
| CONTEXT | `D-109-03` activity must come from Sigra-owned persisted truth | `109-01`, `109-02` |
| CONTEXT | `D-109-04` normalize activity through a presentation seam | `109-01`, `109-03` |
| CONTEXT | `D-109-05` keep sign-in, suspicious-login, revoke-other, revoke-all, single revoke, and logout semantics distinct | `109-01`, `109-02`, `109-03` |
| CONTEXT | `D-109-06` show only bounded metadata Sigra already owns | `109-01`, `109-02`, `109-03` |
| CONTEXT | `D-109-07` keep user/admin truth aligned | `109-01`, `109-02`, `109-03` |
| CONTEXT | `D-109-08` suspicious-login is visibility work, not a new detector | `109-01`, `109-02` |
| CONTEXT | `D-109-09` deterministic ordering/pagination | `109-01` |
| CONTEXT | `D-109-10` preserve generator parity | `109-02` |
| CONTEXT | `D-109-11` prefer extending existing audit/query infrastructure | `109-01`, `109-03` |
| CONTEXT | `D-109-12` keep the first activity surface focused on account/session security events | `109-01`, `109-02`, `109-03` |

## Deferred / Excluded

These items are intentionally absent from the plan set:

- Timeout-expiry history rows or UI copy implying timed-out session history
- New suspicious-login detection logic, risk scoring, or geolocation enrichment
- Organization-wide or admin-product activity feeds unrelated to the current user's account/session story
- Session-store redesign, alternate adapters, or a second session read model
- Replanning Phase 108 preserve-current mutation semantics beyond rendering those events truthfully

## Wave Structure

| Wave | Plans | Why |
|---|---|---|
| 1 | `109-01` | The persisted truth gaps and normalized activity-row contract must exist before any generated or admin surface can render the feed honestly. |
| 2 | `109-02` | The user-facing surface, logout host wiring, and generator parity depend on the library seam and explicit lifecycle semantics from `109-01`. |
| 3 | `109-03` | Admin preview/explorer alignment and docs should settle after the shared row semantics and generated-host surface are final. |

## Outcome Check

- Every locked decision from `109-CONTEXT.md` is mapped to at least one plan.
- Voluntary logout is planned as a distinct persisted semantic from generic revoke/delete semantics.
- Timeout history is excluded because there is no persisted audit truth supporting it today.
- Thin-host boundaries are preserved: library-owned query/presenter rules first, generated/admin rendering second.
