---
created: 2026-06-04T00:00:00.000Z
status: pending
title: Admin Overview cleanup — dead test refutes, hardcoded paths, duplicated config helper, role_tone
area: lib/sigra/admin/live
files:
  - lib/sigra/admin/live/index_live.ex
  - lib/sigra/admin/live/organization_live.ex
  - test/example/test/example_web/admin_shell_test.exs
source: 157-REVIEW.md (WR-04, IN-01, IN-02, IN-04)
---

## Findings (Phase 157 code review — lower-priority cluster)

Grouped non-blocking quality items. The two-state LAND-04 gate is already
covered by real assertions (`sg-skeleton` on GET / `sg-metric-link__value` on
live), so none of these are urgent.

### WR-04 — vacuous refute assertions
`refute html =~ "sg-posture-strip__risk"` and `refute html =~ "Scoped attention"`
assert strings never produced in any state — they read as regression guards but
can only catch the exact old class/literal reappearing. Either keep them as
explicit "removed-element" guards with a comment, or replace with assertions that
exercise the loading-vs-loaded contract (e.g. alarm notice absent on the
disconnected frame, present on connected) for genuine coverage.

### IN-01 — hardcoded deep-link paths (global Overview)
`index_live.ex` hardcodes `/admin/users`, `/admin/audit`,
`/admin/users?locked=true` as string literals while the org view derives them via
`users_path/1` / `audit_path/1`. Breaks if the host mounts the admin router at a
non-default prefix. Centralize the admin base path.

### IN-02 — runtime_config!/0 duplicated verbatim
The two `runtime_config!/0` implementations are identical except for the
error-message prefix. Extract to a shared `Sigra.Admin` helper taking a label.

### IN-04 — role_tone/1 maps :owner and :admin to the same tone
Both return `"info"`; only the text label distinguishes the two roles. Likely
intentional, but `role_label/1` does distinguish them. Either give owner a
distinct tone or add a one-line comment that the shared tone is deliberate.

## How to apply

Address opportunistically during the admin-UI-coherence milestone (these align
with "same job → same component"). Not blocking Phase 157.
