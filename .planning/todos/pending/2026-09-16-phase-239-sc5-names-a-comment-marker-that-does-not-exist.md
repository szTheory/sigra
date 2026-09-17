---
created: 2026-09-16T00:00:00.000Z
status: pending
title: Phase 239's SC-5 names the literal `# SECURITY:` comment marker, which occurs zero times in this repository
area: planning
severity: major
source: phase 237 plan 06 boundary check
files:
  - .planning/ROADMAP.md
---

## Problem

Phase 239's ROADMAP entry (`### Phase 239: priv/templates/ Sweep + One Batched Re-bless`),
success criterion 5, reads:

> Load-bearing infrastructure is provably untouched: `git diff origin/main -- .github/` shows
> no `name:` change (a renamed required context never reports and PRs hang forever), and no
> `# SECURITY:`-class comment sentence is deleted.

This phase (237) hit the identical defect at its own SC-5 and fixed it in-plan via decision
D-04 (`237-CONTEXT.md`): the literal marker `# SECURITY:` occurs **zero** times anywhere in
this repository. Re-measured at this phase's final HEAD, with a positive control proving the
search machinery works:

```bash
$ rg -n "# SECURITY:" lib/ priv/templates/
# (no output)
$ rg -c 'defmodule' lib/sigra/audit.ex
1
```

A guard — or an in-plan check — written against the literal `# SECURITY:` marker can **never
fire**. It is precisely the "green gate that verifies nothing" pattern this v1.48
CLEAN-BASELINE milestone exists to remove, and Phase 239's SC-5 inherits it verbatim from the
same stale ROADMAP wording this phase's own SC-5 predated.

## Replacement rationale class this phase adopted

D-04 (`237-CONTEXT.md`) redefines the subject as a regex class over `#`-comment lines,
because that class actually has matches and can actually go red:

```
security|CSRF|enumeration|timing|scope|impersonation
```

Measured in `lib/` at this phase's HEAD: **52** matching comment lines
(`rg -n -i '^\s*#.*\b(security|CSRF|enumeration|timing|scope|impersonation)\b' lib/`).

This phase's committed check
(`.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-security-comment-diff-check.sh`)
is the working precedent: it greps removed diff lines for that regex class, tolerates lines
that also carry a bookkeeping token (the reviewed-rewrite case), and was demonstrated RED
against a committed synthetic fixture
(`.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/fixtures/237-security-sentence-deleted.diff`)
before being trusted GREEN against the real phase diff.

## Solution

Before Phase 239 is planned, correct its SC-5 wording to use the regex class (or point at
Phase 241's durable `p18`-adjacent successor, if one exists by then) instead of the dead
`# SECURITY:` literal. Phase 239's own diff will also need to be checked against
`priv/templates/` specifically — the same class, scoped to the templates directory Phase 239
sweeps rather than `lib/`, since `priv/templates/` may carry its own security-rationale
comments in generated-host code.

This todo records the observation and the fix's shape; it does not correct Phase 239's
ROADMAP entry itself — that correction belongs to whoever plans Phase 239, per this phase's
own phase-boundary fence against fixing anything these two todos describe.
