---
created: 2026-06-04T00:00:00.000Z
status: completed
completed_at: 2026-06-05
completion_evidence: Kept role="status" for the post-connect alarm and documented the opt-in rationale at both overview call sites.
title: decide role="status" semantics on the connected?-gated Overview alarm notice
area: lib/sigra/admin/live
files:
  - lib/sigra/admin/live/index_live.ex
  - lib/sigra/admin/live/organization_live.ex
  - test/example/test/example_web/admin_shell_test.exs
source: 157-REVIEW.md (WR-05)
---

## Finding (Phase 157 code review, WR-05)

The needs-review alarm `<.notice>` carries `role="status"`. The design contract
warns `role="status"` "is for post-load updates (MDN) and risks duplicate
announcements on LiveView re-render," reserving it for "genuinely post-load
dynamic notices." The reviewer flagged this as a contradiction.

**Deferred (not fixed) because the call is genuinely debatable:** with the
`connected?(socket)` gate, the notice is absent on the disconnected/loading frame
(`:if={not @loading}`) and appears only when the socket connects — i.e. it IS a
post-load appearance from the user's perspective, which is arguably the correct
use of `role="status"`. The reviewer's duplicate-announcement concern applies if
the alarm subtree re-renders while present (e.g. counts change), which is rare.

## Risk

If the reviewer is right: screen readers may re-announce the alarm on unrelated
LiveView re-renders. If the reviewer is wrong: removing `role="status"` drops a
legitimate post-connect announcement of the headline alarm. Either way the test
currently pins `role="status"`, so the decision and the test must move together.

## How to apply

Make a deliberate a11y decision (ideally with a screen-reader check):
- **Keep** `role="status"` if the post-connect appearance is the intended single
  announcement and re-render churn is confirmed harmless; document the rationale
  inline so it reads as intentional, OR
- **Drop** it per the contract for load-present notices and rely on visual/textual
  tone, OR
- Render an empty live region on the loading frame and populate it on connect (the
  only pattern guaranteed to announce exactly once).

Update the `admin_shell_test.exs` assertion in lockstep with whichever is chosen.
