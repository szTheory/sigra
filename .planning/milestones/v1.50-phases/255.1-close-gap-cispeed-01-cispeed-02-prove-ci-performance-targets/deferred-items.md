# Phase 255.1 deferred items

Out-of-scope findings logged during Plan 06 execution. Not fixed here.

## From the seed continuation 02 follow-up (2026-10-29)

1. **Settlement's read budget undercounts downloads.** `named_operations['settlement']['run_job_artifact_log_cache_reconciliation_reads']` is a flat 20. Settlement after a real seeder run reads one listing, the run, jobs, artifacts, 5 job logs and 5 artifacts (each with a redirect hop), 5 new entries and up to 5 restored-from entries (about 44 attempts). This matters only if another install/seed leg runs. Re-derive it before proposing one.
2. **The normal install/continuation leg does not read restored-from entries.** On a real prefix-fallback writer it now stops fail-closed (`shared_cache_inventory_restored_entry_unread`), and settlement completes the verification. Adding those 5 reads to the normal leg would change its window derivation. Re-derive before any new seeding leg.
3. **A settlement verification failure blocks restoring the release workflows.** Seed continuation 02 (`dispatch_run_unresolved`) and attempt 08 both ended in manual restores. Restoring once the writer run is terminal, even if output verification fails, would be safer. This is a design change for any future pause leg.
  status: acknowledged
