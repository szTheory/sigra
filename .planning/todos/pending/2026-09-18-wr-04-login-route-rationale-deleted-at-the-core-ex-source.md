---
created: 2026-09-18T00:00:00.000Z
status: pending
title: "WR-04: the login-route rationale was collapsed to a single fact, leaving a project constraint unguarded by prose"
area: installer
files:
  - lib/sigra/install/features/core.ex
  - test/example/lib/example_web/router.ex
  - test/fixtures/install_golden/tree/

source: "Phase 239 code review (239-REVIEW.md, WR-04) — surfaced in the example mirror, but the authoritative wording is the installer source, which sits outside the reviewed aa1372cb..HEAD range."
audit_acknowledged:
  milestone: v1.48
  at: 2026-09-18
---

## What

The sweep collapsed a four-line router comment to a single fact. Removed:

```elixir
    # Phase 10.1.1 B9: login page is a plain controller + HEEx render,
    # NOT a LiveView. Keeping it outside the live_session ensures
    # `Phoenix.Component.form/1` renders a plain `<form action=... method="post">`
    # with no phx-submit interception.
```

Replaced by:

```elixir
    # Login page is a plain controller, not a LiveView.
```

Only `Phase 10.1.1 B9:` was bookkeeping. The three surviving lines were the **reason the route must
stay where it is**, and they went with it.

The review's suggested restoration — bookkeeping still removed, rationale back:

```elixir
    # Login page is a plain controller + HEEx render, NOT a LiveView. Keeping it
    # outside the live_session ensures `Phoenix.Component.form/1` renders a plain
    # `<form action=... method="post">` with no phx-submit interception.
    get "/log_in", SessionController, :new
```

## Why the rationale is load-bearing

`get "/log_in"` currently sits three lines above a `live_session :redirect_if_user_is_authenticated`
block. A maintainer who moves the route into that adjacent block silently reintroduces `phx-submit`
interception on the login form — the exact defect `login_html.ex`'s own moduledoc, edited in this
same range, still documents, and a constraint `CLAUDE.md` states at project level: *"Login/logout via
HTTP POST (not LiveView events)."*

What remains describes the **current state**. It no longer tells the reader what breaks if the state
changes, so the comment and its neighbouring moduledoc now disagree about how much the reader needs
to know. The routing behaviour itself is unchanged and correct — only its documented rationale is
missing.

## Not fixed in Phase 239 — deliberately

The review surfaced this at `test/example/lib/example_web/router.ex:103`, but the **authoritative
wording lives at `lib/sigra/install/features/core.ex:503`**, which is outside the reviewed
`aa1372cb..HEAD` range and was already collapsed before it. Plan 239-07 mirrored that collapse into
the example *correctly*, per the mirror rule — the example is not the defect, it is the reflection.

Fixing it therefore requires editing the installer source, re-mirroring the example, and re-blessing
the golden fixture: a **fourth** edit batch, which this closure is not chartered to open (and which
would carry its own D-29 batch justification). Phase 239 **deliberately did not fix** WR-04.

## Fix location, in order — do not re-derive this

1. `lib/sigra/install/features/core.ex:503` — the router heredoc. This is the source of truth.
2. `test/example/lib/example_web/router.ex` — re-mirror the counterpart.
3. `test/fixtures/install_golden/tree/` — one batched `MIX_ENV=test mix sigra.fixture.rebless_golden`,
   comment-only diff, alone in its commit, per SC-3's unchanged per-commit properties.
