# Phase 10 — Deferred Items

Out-of-scope issues discovered during plan execution. Do NOT fix in the
originating plan; schedule in a follow-up plan or the dedicated cleanup
phase.

## Pre-existing compile warnings (not caused by plan 10-02)

- `lib/sigra/testing.ex:488` — `Sigra.Testing.trust_browser/3` calls the
  deprecated `Sigra.MFA.Trust.cookie_opts/0`. Causes
  `mix compile --warnings-as-errors` to fail. Unrelated to plan 10-02
  (auth_fixtures template is not compiled by the library). Likely
  targeted by plan 10-03 (cookie_domain config) since that plan
  threads `%Sigra.Config{}` through cookie builders.
- 2026-04-09 (10-03): Pre-existing test failures unrelated to 10-03 — Sigra.Audit.CursorPortabilityTest paginate cursor, Mix.Tasks.Sigra.InstallTest template rendering (fixtures). Confirmed pre-existing via stash bisect. Out of scope for cookie_domain plan.
