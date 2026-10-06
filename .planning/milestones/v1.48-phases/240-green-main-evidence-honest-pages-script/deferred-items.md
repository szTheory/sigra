## Deferred (out of scope for Plan 240-01)

- **`Sigra.Audit.Forwarders.ThreadlineTest` — 6 local failures in `MIX_ENV=test mix ci`.**
  Every failure is `** (UndefinedFunctionError) function Sigra.Audit.Forwarders.Threadline.attach/1
  is undefined (module Sigra.Audit.Forwarders.Threadline is not available)` at
  `test/sigra/audit/forwarders/threadline_test.exs:136`. Observed 2026-09-18 on `main` at
  `04e94a86..2ca65989`. **Provably unrelated to this plan**: `git diff --name-only 04e94a86..HEAD`
  lists exactly three files — `.github/workflows/ci.yml`,
  `scripts/ci/ensure-github-pages-legacy-branch.sh`,
  `scripts/ci/ensure-github-pages-legacy-branch.test.sh` — and no Elixir source, test, or config
  file changed, so a module-availability failure cannot originate here. Reproduces identically on
  two consecutive warm-build runs; the optional `:threadline` dep (`mix.exs:120`, `~> 0.5`, locked
  at 0.7.0) recompiles on every invocation, which points at a local optional-dep load-order
  artifact rather than a source defect. Needs its own investigation (does it reproduce in CI?).
