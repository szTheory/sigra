# Deferred Items

- The Phase 242 final Crosswake security matrix was run after the rendered-entry changes. Its `Example.Accounts.CrosswakeContinuationsTest` cleanup-count case failed because the shared local `example_test` database retained terminal continuation rows (`expected 2`, `got 4`). This is the pre-existing test-isolation debt documented in `.planning/v1.48-MILESTONE-AUDIT.md`; no protocol or production code was changed in this phase.
