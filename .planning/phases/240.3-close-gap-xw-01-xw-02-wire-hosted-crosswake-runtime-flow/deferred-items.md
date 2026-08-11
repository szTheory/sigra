# Deferred Items

- `test/example/lib/example_web/live/settings_live.ex:133` has a pre-existing verified-route warning for `/dev/mailbox`; it causes `mix precommit` to fail under `--warnings-as-errors` and is outside the continuation-storage task scope.
