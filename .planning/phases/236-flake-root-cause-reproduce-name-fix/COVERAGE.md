# Phase 236 — API Coverage Declaration

No external API integration: the phase touches one shipped LiveView
(`lib/sigra/admin/live/audit_index_live.ex`), one CI prohibition guard, and one dead workflow env
key. Its only contact with an external service is *reading* the GitHub Actions run list through
`gh run list` / `gh run view` as an evidence-harvest step for SC-3 — an observation of CI history,
not a capability surface this repo integrates, exposes, or could meaningfully enumerate as a
coverage matrix. No client is written, no endpoint is called for product behavior, and no adopter
of Sigra gains or loses an API surface.

The deterministic detector fired on the SC-3 prose ("The affected job, dispatched repeatedly
against the fix, passes every repeat…"). Re-read against the phase scope, that sentence describes
evidence harvesting, not integration. Declaration stands.
