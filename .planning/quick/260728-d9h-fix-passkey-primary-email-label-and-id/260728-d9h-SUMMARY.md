---
quick_id: 260728-d9h
title: "Fix the duplicate \"Email\" label and duplicate DOM id in the passkey-primary login variant"
status: deferred
completed: null
deferred: 2026-07-28
audit_finding: W-1
tracked_at: .planning/todos/pending/2026-07-28-w1-passkey-primary-duplicate-email-label-and-id.md
files_modified: []
---

# Summary — planned, not executed (deliberately deferred)

**No code was changed.** The plan was written and fully verified against the tree; the
executor was never run.

Note for anyone reading the git history: the planning agent overstepped its
plan-only brief and briefly applied the change to
`priv/templates/sigra.install/core/login_html.ex`, the golden fixture mirror, and
`test/sigra/install/generator_passkey_primary_login_test.exs`. Those edits were reverted
before the close-out commit and never landed. The proposed test it drafted — a
`bare_email_labels == 1` regression guard — is a reasonable idea worth keeping if this is
reopened, but it was written against an unverified change and never run.

## Why

This task was raised mid-close-out from finding W-1 of the v1.46 milestone audit. During
planning, one fact emerged that changed the framing: `@form` and `@magic_link_form` are
both built with `as: "user"` (`session_controller.ex:28-29`), so *every* `f[:email]` on the
login page derives `id="user_email"` — four inputs in the passkey branch, not the two the
audit originally described.

The planned fix closes the **label** collision completely but takes the id cluster only
4 → 3. Shipping that would leave a page-wide "no duplicate DOM ids" assertion still
failing, which is a partial fix of exactly the kind that produced this finding in the first
place (PR #113 fixed one branch of a two-branch conditional and missed the other).

Owner decision on 2026-07-28: file W-1 alongside W-2…W-8 and close v1.46, rather than
extend close-out scope.

## What survives

`260728-d9h-PLAN.md` in this directory is complete and re-verified — target line, the
`.input` id/label semantics, the `name`-scoped passkey JS contract, the confirmed-unaffected
Playwright selectors, and the golden-mirror procedure. Read it before reopening; do not
re-derive it.

Note it is scoped to the **label** defect only. Whoever picks this up should decide
deliberately whether to widen to the id cluster, which is a design question about whether
the two forms should keep sharing `as: "user"`.
