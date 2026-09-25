---
created: 2026-09-16T00:00:00.000Z
status: pending
title: The organizations installer template ships a dead `.planning/` reference into every adopter's repo
area: installer
severity: major
source: phase 237 code review (WR-01)
files:
  - priv/templates/sigra.install/organizations/organizations.ex
  - test/example/lib/example/organizations.ex
---

## Problem

Phase 237 swept dead `.planning/` references out of `lib/` — `grep -rn '\.planning/' lib/` is
now empty. The sweep did not cover `priv/templates/`, and the one surviving reference is in the
worst possible place:

```
priv/templates/sigra.install/organizations/organizations.ex:59
  # configured @sigra_org_config. See .planning/phases/16-org-liveviews-switcher/
  #   16-CONTEXT.md D-10 / D-11 / D-16
```

Mirrored at `test/example/lib/example/organizations.ex:87`.

That template is copied verbatim into every host application created by
`mix sigra.install --organizations`. Adopters therefore receive a source comment pointing at a
path that does not exist in their repository and never will — this maintainer-only bookkeeping
pointer is precisely the defect class Phase 237 set out to eliminate, left in the one location
where it escapes the maintainer audience and reaches strangers.

Verified independently at phase 237's final HEAD, with a positive control proving the search ran:

```bash
$ grep -n "\.planning/" priv/templates/sigra.install/organizations/organizations.ex
59:  # configured @sigra_org_config. See .planning/phases/16-org-liveviews-switcher/
$ printf 'See .planning/x\n' | grep -c "\.planning/"
1
```

## Why it was not fixed in phase 237

Out of that phase's declared scope (`lib/` docs surface, per D-01). Filed rather than
guess-fixed.

## Suggested fix

Apply the same inline-the-substance treatment Phase 237 applied to `lib/sigra/testing.ex`:
keep the substantive claim the D-10/D-11/D-16 decisions establish as prose in the comment, drop
the unreachable pointer. Update the `test/example/` mirror in the same change so the example
does not drift from the template (see the installer-template-drift note).

## Relationship to the p18 ratchet

`.planning/ROADMAP.md:192` already specifies that Phase 241's `p18` prohibition guard hard-fails
a fixture containing a `.planning/` path **and** a `priv/templates/` bookkeeping token — so this
occurrence is in the guard's declared scope. This todo exists because the defect ships to
adopters now, ahead of that guard landing; closing it early also keeps `p18` from going red on
its first run.
