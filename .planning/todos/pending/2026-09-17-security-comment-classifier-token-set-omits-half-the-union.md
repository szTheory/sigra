---
created: 2026-09-17T00:00:00.000Z
status: pending
title: "237 security-comment classifier's tolerated-token set omits IN-NN, ORG-UX-NN, GATE-NN and friends, so bookkeeping sweeps trip it"
area: planning-tooling
files:
  - .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-security-comment-diff-check.sh

source: "Phase 239 plan 04 (single batched re-bless), SC-5b — the gate went RED on a citation-only removal whose security rationale was fully preserved"
audit_acknowledged:
  milestone: v1.48
  at: 2026-09-17
---

## What

`237-security-comment-diff-check.sh` flags a removed line when it matches the rationale class
(`security|CSRF|enumeration|timing|scope|impersonation`) **and** carries no bookkeeping token.
Its tolerated-token set is:

```
\b(D-[0-9]{2}|SC-[0-9]+|Phase [0-9]{1,3})\b|\.planning/
```

Phase 239's frozen union regex — the repository's actual definition of a bookkeeping token —
is considerably wider. It additionally covers `IN-[0-9]{2}`, `ORG-UX-[0-9]{2}`, `GATE-0[0-9]`,
`UI-SPEC`, `DX-[0-9]{2}`, `T-[0-9]+-[0-9]+`, `\bB[0-9]\b`, `Plan [0-9]{2}`, and the
`[0-9]{3}-[A-Z0-9-]+\.md` document form.

## How it surfaced

Phase 239's sweep removed the citation `(10.1 IN-03)` from this line in
`priv/templates/sigra.install/core/auth.ex` and its two mirrors (`test/example`, the golden
fixture):

```
-  # token clause so security signals are preserved (10.1 IN-03). Tokens
+  # token clause so security signals are preserved. Tokens
```

`IN-03` is a bookkeeping token under the union regex but not under the classifier's set, so the
line read as "security rationale deleted with nothing to justify it" and the gate went RED.

The rationale is in fact fully intact. The surrounding comment still reads:

> Test-only helper — bypasses the HMAC signature rewind, audit log row, and telemetry events
> that the signed-token clause above emits via `Sigra.Auth.reset_password/4`. Do NOT call this
> from controllers; production flows must use the signed token clause so security signals are
> preserved.

Only the citation left. Positive control: the same classifier over the same phase diff with the
`auth.ex`/`accounts.ex` mirrors excluded examines 409 removed lines and exits 0, so the check
was live and this one line family was its sole trip.

## Why it matters

This is a false RED on a security gate, which is the most expensive kind. It trains readers to
wave the gate through, and the next sweep that touches an `ORG-UX-` or `GATE-0` citation next to
the word "scope" will trip it the same way. `scope` in particular is a very common word in this
codebase (`current_scope`, `:org_scoped`, scope structs), so the rationale-class matcher is
already wide.

## Not fixed here

D-16 pins this script as unmodifiable, and Standing Constraint 4 says found-while-cleaning
becomes a todo. Both point the same direction: do not edit it inside phase 239.

## Suggested shape

Phase 241's `p18` slot is named as the durable bookkeeping ratchet. Give that ratchet a single
shared token definition and have both this classifier and any future one read it, instead of
each phase artifact carrying its own hand-copied subset. If the script is re-derived rather than
edited, the D-16 pin is honoured and the drift class disappears rather than being patched once.
