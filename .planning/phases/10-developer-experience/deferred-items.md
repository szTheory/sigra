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
- 2026-04-10 (10-04): Pre-existing `mix docs --warnings-as-errors` failures unrelated to 10-04 — @doc references in `lib/sigra/oauth/strategies/{github,google,facebook,apple}.ex` point at hidden `Assent.Strategy.*.authorize_url/1` and `callback/2` functions; `lib/sigra/session.ex` and `lib/sigra/audit/changeset.ex` reference hidden `Sigra.Audit.__log_internal__/3` and undefined `Sigra.Audit.log_safe/3`; `lib/sigra/rate_limiters/hammer.ex` references undefined `Sigra.RateLimiter.check_rate/3`. Confirmed pre-existing via `git stash` + `mix docs --warnings-as-errors` on baseline (same warnings present before guides scaffold). Non-strict `mix docs` exits 0 and all 15 guides render correctly under Introduction/Flows/Recipes groups. Out of scope for the docs scaffolding plan; schedule a doc-cleanup task in a follow-up plan.
