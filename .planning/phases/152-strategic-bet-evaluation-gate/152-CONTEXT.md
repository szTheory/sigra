# Phase 152: Strategic Bet Evaluation Gate - Context

**Gathered:** 2026-06-01 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

A formal evaluation document is created to assess if accumulated adopter demand warrants beginning work on `SCIM`, `sigra_lockspire`, or `Threadline` correlation. The evaluation explicitly defines the threshold of adopter demand required to override the maintenance-first default and violate the Diminishing Returns Wall. Any approved strategic bet includes deeper research scoping (e.g., `ex_scim` vs custom implementations for directory sync) to prepare for future implementation phases.
</domain>

<decisions>
## Implementation Decisions

### Overriding the Diminishing Returns Wall
- **D-01:** The formal threshold for overriding the Diminishing Returns Wall requires an enterprise adopter contract explicitly blocked by the lack of the feature (e.g., JIT provisioning proving insufficient).

### `sigra_lockspire` Glue Deferral
- **D-02:** The `sigra_lockspire` glue package remains formally deferred and blocked until both libraries are fully stable and a real companion-app trigger fires.

### Threadline Correlation
- **D-03:** Threadline correlation (trace-correlation ID propagation) cannot proceed until a stable upstream injection seam exists in Threadline.

### Claude's Discretion
- **SCIM / Directory Sync Implementation:** The strategic evaluation will scope adopting the `ex_scim` dependency against building a custom minimal implementation, rather than building a generic integration immediately.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- .planning/PROJECT.md
- .planning/MILESTONE-ARC.md
- .planning/research/SUMMARY.md
- .planning/decisions/001-defer-sigra-lockspire-glue-package.md
- .planning/milestones/v1.30-REQUIREMENTS.md
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ex_scim` (v0.2.0) is available on Hex.pm for protocol parsing and validation.
- Custom SCIM v2.0 sync requires `GET`, `POST`, and `PATCH` on `/Users` with complex conflict resolution and idempotency logic.

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