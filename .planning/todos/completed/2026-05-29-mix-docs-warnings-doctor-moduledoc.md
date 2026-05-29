---
created: 2026-05-29T00:00:00.000Z
status: resolved
resolved: 2026-05-29
resolved_by: Phase 140 (140-03 Gate-5 Rule-1 auto-fix, commit 6f60743)
title: mix docs --warnings-as-errors fails on Sigra.Doctor moduledoc references to hidden functions
area: docs
origin_phase: 138
files:
  - lib/sigra/doctor.ex
  - lib/sigra/application.ex
  - lib/sigra/audit/forwarders.ex
---

## Resolution (2026-05-29, Phase 140)

Resolved by Phase 140 plan 140-03's Gate-5 Rule-1 auto-fix (commit `6f60743`). The
broken `@moduledoc` autolinks to `@doc false` functions in `lib/sigra/doctor.ex`
and `lib/sigra/optional_deps.ex` were rewritten as plain prose (no behavior change).
`mix docs --warnings-as-errors` now exits 0 — independently confirmed as Gate 5 of
the Phase 140 proof bundle (140-VERIFICATION.md, status: passed).


## Problem

`mix docs --warnings-as-errors` exits non-zero. The HTML generation fails because the
`Sigra.Doctor` moduledoc (`lib/sigra/doctor.ex:29,51,57,59,63`) references functions that are
`@doc false` (hidden), so ExDoc cannot resolve the autolinks:

- `Sigra.Application.verify_vault!/1` (`application.ex:172,185` — hidden)
- `Sigra.Application.attach_forwarders/0` (`application.ex:123` — hidden)
- `Sigra.Audit.Forwarders.oban_running?/1` (`forwarders.ex:90` — hidden)

## Origin / scope note

NOT introduced by Phase 139. `git diff <139-base>..HEAD -- lib/sigra/doctor.ex` is empty;
the last change to `doctor.ex` was `6c936a9 fix(138)`. Phase 139 only edited Markdown recipes
(code inside fences, never compiled by ExDoc) and a pure ExUnit fixture, none of which can
produce these warnings. This is pre-existing Phase-138 docs debt surfaced by the Phase-139
code review.

It does, however, mean the Phase-139 recipe must-have "`mix docs --warnings-as-errors` exits 0"
is currently blocked by an unrelated module. Track and resolve independently of Phase 139.

## Fix options

- Replace the autolink-style backtick references in the `Sigra.Doctor` moduledoc with plain
  inline code (e.g. ``Sigra.Application.verify_vault!/1`` → `` `verify_vault!/1` `` without the
  module path, or wrap in a non-autolinking form), OR
- Un-hide (give a real `@doc`) the three referenced functions if they are meant to be part of
  the documented surface, OR
- Use `:nofmt`/explicit-text rather than module-qualified references that ExDoc tries to link.

Smallest correct fix is almost certainly the first: these are explanatory references in a
moduledoc, not API the doctor module exposes, so they should not be autolinks.
