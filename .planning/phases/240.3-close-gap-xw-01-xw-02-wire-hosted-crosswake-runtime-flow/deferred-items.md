# Deferred Items

- `cd test/example && mix precommit` currently fails before this plan's browser proof because `ExampleWeb.SettingsLive` references `/dev/mailbox`, which is absent when `dev_routes` is disabled under the alias's warnings-as-errors compilation. The touched Playwright config, browser spec, and proof runner do not affect that route or LiveView. Logged during 240.3-04 Task 1 on 2026-08-11.
