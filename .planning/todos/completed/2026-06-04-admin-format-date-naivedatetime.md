---
created: 2026-06-04T00:00:00.000Z
status: completed
completed_at: 2026-06-05
completion_evidence: organization_live.ex and shared audit_row/1 now handle %NaiveDateTime{} explicitly.
title: format_date/1 silently renders non-DateTime host timestamps as "—"
area: lib/sigra/admin/live
files:
  - lib/sigra/admin/live/organization_live.ex
source: 157-REVIEW.md (WR-03)
---

## Finding (Phase 157 code review, WR-03)

`format_date(%DateTime{})` is the only formatting head; `format_date(_) -> "—"`.
`invitation.expires_at` comes from host-app data via
`Detail.shape_invitation_row/2` (typed `DateTime.t() | nil`). The example app
uses `:utc_datetime` (loads as `%DateTime{}`, so tests pass), but a host using
Ecto's equally-valid `:naive_datetime` loads `%NaiveDateTime{}` and would render
every non-expired invitation's expiry as "—" with no error and no test signal.

This is **pre-existing** lib-owned code (identical at base commit d0371b7e, line
184-185) reading host-controlled data, so it was out of scope for the Phase 157
remediation pass. Logged so the silent fallback masking a populated-but-wrong-
typed value is not forgotten.

## Risk

A host misconfiguration (wrong column type) degrades silently and invisibly — the
worst failure mode for a library reading downstream data.

## How to apply

Handle `NaiveDateTime` (and optionally `Date`) explicitly so a mis-typed host
column degrades visibly or correctly:

```elixir
defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d")
defp format_date(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d")
defp format_date(nil), do: "—"
defp format_date(other), do: raise ArgumentError, "unexpected expires_at: #{inspect(other)}"
```

At minimum support `NaiveDateTime`; the catch-all "—" should not absorb a
populated-but-wrong-typed value.
