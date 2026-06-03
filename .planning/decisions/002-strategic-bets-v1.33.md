# Strategic Bet Evaluations: v1.33

## Threshold for Action

In accordance with the Diminishing Returns Wall framing (D-01), the project's posture remains **maintenance-first**. Greenfield enterprise features are strictly blocked from the core roadmap unless accompanied by an explicit enterprise adopter contract requiring them. We do not build open-ended complex capabilities on speculation.

## Bet: SCIM / Directory Sync

**Status:** Pending concrete enterprise block

Enterprise directory sync (SCIM) is a valuable feature for large-scale deployments but carries significant surface area. Until a concrete enterprise block necessitates it, this bet remains paused. When eventually unblocked, the implementation must use the `ex_scim` dependency for protocol parsing and validation rather than hand-rolling a custom minimal implementation (D-02).

## Bet: sigra_lockspire Glue

**Status:** Deferred

A dedicated glue package (`sigra_lockspire`) for integrating Sigra with the Lockspire authorization platform has been deferred (D-03). Lockspire integration will remain a host-owned responsibility via manual stub generation, allowing operators full control over their specific integration topologies without burdening the Sigra core with an explicit dependency.

## Bet: Threadline Correlation

**Status:** Deferred

Trace-correlation ID propagation across the Threadline forwarder is currently deferred (D-04). We will hold on this until Threadline provides a stable upstream injection seam. Note that Threadline v0.5.0+ may unblock this in the future, at which point the bet can be re-evaluated.