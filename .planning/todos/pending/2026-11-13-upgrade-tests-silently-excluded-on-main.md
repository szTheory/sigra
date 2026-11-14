---
created: 2026-11-13T00:00:00.000Z
status: pending
title: Upgrade tests are silently excluded on main because test_helper runs a non-existent `mix archive.list`
area: ci
severity: major
source: v1.50 branch triage (CI-machinery review); confirmed error on Elixir 1.19.5
files:
  - test/test_helper.exs
  - test/upgrade_test.exs
---

`test/test_helper.exs` decides whether the `phx_new` archive is installed by running `mix archive.list`, which is not a Mix task, so the check always fails and `test/upgrade_test.exs` (`:upgrade`, 600 s timeout) is excluded even though CI installs the archive.

Fix: detect the archive with a real check (e.g. `Mix.Tasks.Archive` path lookup or `mix archive` output), and under `SIGRA_CI_REQUIRED=1` fail loudly instead of excluding. Expect extra CI minutes and possibly latent failures. Land on its own PR; positive control: a run where the archive is deliberately absent must go red under `SIGRA_CI_REQUIRED=1`.
