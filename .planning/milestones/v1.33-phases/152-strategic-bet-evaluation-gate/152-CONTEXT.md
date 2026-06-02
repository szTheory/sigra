# Phase 152: strategic-bet-evaluation-gate - Context

**Gathered:** 2026-06-01 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

A formal document assesses demand for SCIM, sigra_lockspire, and Threadline. Approved strategic bets (if any) are queued for deep research; rejected bets are formally deferred.
</domain>

<decisions>
## Implementation Decisions

### Strategic Evaluation Threshold (Diminishing Returns Wall)
- **D-01:** Greenfield enterprise features (like SCIM or new auth primitives) will remain blocked unless an explicit enterprise adopter contract requires them.

### SCIM Implementation Strategy
- **D-02:** When SCIM is eventually unblocked by an enterprise contract, it will use the `ex_scim` dependency rather than a custom minimal implementation.

### Lockspire Integration Posture
- **D-03:** Lockspire integration will remain a host-owned responsibility (manual stub generation) rather than a published glue package (`sigra_lockspire`).

### Threadline Tracing Correlation
- **D-04:** Threadline trace-correlation ID propagation is deferred until Threadline provides a stable upstream injection seam (noting that external research shows Threadline v0.5.0+ has unblocked this seam).

### Claude's Discretion
None

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

.planning/ROADMAP.md
.planning/decisions/001-defer-sigra-lockspire-glue-package.md
.planning/decisions/002-strategic-bets-v1.33.md
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ex_scim` (v0.2.0) is available on Hex.pm for protocol parsing and validation.

### Established Patterns
- "Maintenance-first" posture blocks unbounded enterprise feature creep.
- Deferral until concrete demand exists (e.g., Lockspire glue package).

### Integration Points
- Threadline forwarder exists in `lib/sigra/audit/forwarders/threadline.ex`.
</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches
</specifics>

<deferred>
## Deferred Ideas

None — analysis stayed within phase scope
</deferred>