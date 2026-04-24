---
phase: 69
plan: "01"
completed: "2026-04-23"
---

## Outcome

Shipped **ACF-02** / **ACF-03** HexDocs work: new **`guides/introduction/intermediate-production-path.md`** (numbered solo-production spine, v1.10 default bundle + scope links, MFA + password/session sidebar, anti-patterns), **`guides/reference/generator-options.md`** (canonical flag matrix from `@switches` / `@default_opts`, prose clusters, `mix help sigra.install` footer), **`Mix.Tasks.Sigra.Install` `@moduledoc`** organizations bullet, **`mix.exs`** ExDoc `extras` + **`Reference:`** group, and intro cross-links in **installation**, **first-hour**, and **getting-started**.

## Key files

- `guides/introduction/intermediate-production-path.md`
- `guides/reference/generator-options.md`
- `lib/mix/tasks/sigra.install.ex`
- `mix.exs`
- `guides/introduction/installation.md`
- `guides/introduction/first-hour.md`
- `guides/introduction/getting-started.md`

## Verification

- `MIX_ENV=dev mix docs --warnings-as-errors` — PASS
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix ci.install_golden` — PASS

## Self-Check: PASSED
