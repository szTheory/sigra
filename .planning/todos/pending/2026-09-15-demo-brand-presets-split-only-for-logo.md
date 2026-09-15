---
created: 2026-09-15T00:00:00.000Z
status: pending
title: Demo brand presets are split into light/dark pairs only because one profile could not carry two logos
area: demo
severity: cosmetic
files:

  - test/example/lib/example/demo/branding.ex

source: 2026-09-15 — found while implementing dark_logo_url
related:

  - .planning/todos/pending/2026-09-15-branding-profile-has-no-dark-logo-url.md

audit_acknowledged:
  milestone: v1.47
  at: 2026-09-15
---

## What

`test/example/lib/example/demo/branding.ex` maintains `@rail_accent_light` and
`@rail_accent_dark` as two complete `Profile` structs, each pinned with `theme: :light`
or `theme: :dark`, differing in `logo_url` (`rail-accent-mark.svg` vs
`rail-accent-mark-dark.svg`) plus their colour tokens.

That split exists because a single profile could not express two logos. It is the same
gap an early adopter reported from outside — Sigra had already been working around it
internally, in its own demo, which is about as direct a confirmation as a report gets.

Now that `dark_logo_url` exists, the pair can collapse into one `theme: :system` profile
carrying both logos and both colour sets.

## Solution

Collapse the paired presets into single profiles using `dark_logo_url` and the `dark_*`
colour tokens. Deliberately **not** done alongside the `dark_logo_url` change itself:
the demo presets drive Playwright baselines and the persona switcher, so collapsing them
changes rendered output and would have mixed a demo-surface refactor into a library fix.

Worth doing, because the demo is also the worked example a reader copies from — leaving
it on the old workaround teaches the workaround. Check the admin-checkpoints and
design-gallery baselines when it lands.
