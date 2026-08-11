# Deferred Items

- `cd test/example && mix precommit` currently fails before this plan's browser proof because `ExampleWeb.SettingsLive` references `/dev/mailbox`, which is absent when `dev_routes` is disabled under the alias's warnings-as-errors compilation. The touched Playwright config, browser spec, and proof runner do not affect that route or LiveView. Logged during 240.3-04 Task 1 on 2026-08-11.
- `cd test/example && mix precommit` again fails for the same pre-existing `ExampleWeb.SettingsLive` `/dev/mailbox` verified-route warning while completing the Phase 240.3 Plan 05 source contract. The recipe, receipt runner, and root planning test do not touch that LiveView; the focused contract passes with the configured PostgreSQL environment. Logged during 240.3-05 Task 1 on 2026-08-11.
