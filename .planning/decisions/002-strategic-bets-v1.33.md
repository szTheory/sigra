# Strategic Bets Evaluation (v1.33)

**Status:** Proposed / Evaluated
**Date:** 2026-06-01 (assumed)

## Purpose
To transition Sigra to long-term stewardship by establishing strict criteria for greenfield enterprise feature requests. This formal evaluation document assesses whether accumulated adopter demand warrants beginning work on `SCIM`, `sigra_lockspire`, or `Threadline` correlation, enforcing the Diminishing Returns Wall.

## Threshold for Action (Diminishing Returns Wall)
To override the maintenance-first default and violate the Diminishing Returns Wall, a strict threshold must be met. The formal threshold for overriding requires an **enterprise adopter contract explicitly blocked by the lack of the feature** (such as JIT provisioning proving insufficient). Without this concrete business blocker, feature work will remain deferred to prioritize stability and maintenance.

## Bet: SCIM / Directory Sync
**Status:** Pending concrete enterprise block.

**Evaluation:** 
Implementation is deferred until a concrete enterprise contract requires it. When implemented, the scope must be explicitly restricted to adopting the `ex_scim` dependency rather than building a custom minimal implementation (which would require complex conflict resolution and idempotency logic for `GET`, `POST`, and `PATCH` on `/Users`). By using `ex_scim`, we can leverage existing protocol parsing and validation available on Hex.pm.

## Bet: sigra_lockspire Glue
**Status:** Deferred

**Evaluation:**
Per D-02 (and ADR 001), the `sigra_lockspire` glue package remains formally deferred and blocked until both libraries (Sigra and Lockspire) are fully stable and a real companion-app trigger fires. Hosts must hand-wire integration until this threshold is met.

## Bet: Threadline Correlation
**Status:** Deferred

**Evaluation:**
Per D-03, Threadline correlation (trace-correlation ID propagation in `lib/sigra/audit/forwarders/threadline.ex`) cannot proceed. This feature is blocked until a stable upstream injection seam exists in Threadline.
