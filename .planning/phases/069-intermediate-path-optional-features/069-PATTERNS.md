# Phase 69 — Pattern map

## Template analog

- **`.planning/phases/068-deploy-and-mail-confidence/068-01-PLAN.md`** — ExDoc-only phase: YAML frontmatter, `<threat_model>`, `<tasks>` with `<read_first>`, concrete `<action>`, grep-style `<acceptance_criteria>`, trailing `mix docs --warnings-as-errors` verify.

## Doc tone and structure

- **`guides/recipes/deployment.md`** (phase 68) — checklist hub; **do not** fork prod tables into intro tutorials.
- **`guides/introduction/getting-started.md`** — end matter **`## What's next`** bullet list; **`## Before you ship to production`** deployment anchors.

## Code truth

- **`lib/mix/tasks/sigra.install.ex`** — `@switches`, `@default_opts`, `@moduledoc` **Options** must list every switch (including `organizations`).

## ExDoc wiring

- **`mix.exs` `docs/0`** — `extras:` paths are repo-relative strings; `groups_for_extras:` Keyword order controls sidebar grouping.

## PATTERN MAPPING COMPLETE
