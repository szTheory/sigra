# GA-01 — Pointer to Phase 41 / CI proof (no rotation re-run in Phase 42)

**GA-01** (backup-code rotation) was validated in **Phase 41**. Phase 42 **does not** re-execute rotation; use the paths below as durable proof pointers.

## Automated / CI proof

- **Rotation persistence + regression:** `test/example/test/example_web/smoke/backup_code_rotation_test.exs` (runs under **`example_unit_smoke`** in `.github/workflows/ci.yml`).
- **Merge-blocking unit smoke job:** **`example_unit_smoke`** — see workflow `jobs:` for the exact job id.
- **Optional UX shell (Playwright):** `test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts` — browser-level reachability only; not a substitute for the ExUnit rotation proof.

## Not listed here (GA-02 scope)

HTML mail structure tests (`EmailsSecurityHtmlTest`, `EmailsLifecycleHtmlTest`) are **GA-02** machine baseline — see **`./GA-02/README.md`** and `docs/uat-ci-coverage.md` SEED-1/2.
