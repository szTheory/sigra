# Phase 42 — Pattern map

Analogs for documentation and evidence layout (no new auth modules).

| Intended artifact | Analog in repo | What to copy |
|--------------------|----------------|--------------|
| v1.4 GA matrix | `.planning/v1.3-HUMAN-UAT.md` | Title + intro paragraph + pipe table; changelog pointer section |
| Evidence hub | `.planning/uat-evidence/v1.3.0/INDEX.md` | Link table to item folders; Hex + SHA callouts |
| Per-item evidence | `.planning/uat-evidence/v1.3.0/item-*/` | Mix of `steps.md`, `waiver.md`, `README.md` — short, not log dumps |
| CI vs human map | `docs/uat-ci-coverage.md` | SEED table + policy paragraph; extend with v1.4 GA row or header note |
| GA-01 proof pointer | Phase 41 plans + `test/example/test/example_web/smoke/backup_code_rotation_test.exs` | Single matrix row: Executed + link only |
| GA-02 machine baseline | `test/example/test/example/accounts/emails_*_html_test.exs` | Cite in `CI_substitute` column text |
| GA-04 doc target | `guides/introduction/getting-started.md` | Evidence `steps.md` references exact path |

**Code excerpt pattern (v1.3 matrix header):**

```markdown
| SEED_item | Status | Date | Owner | Environment | Evidence_link | Expiry | Notes |
```

v1.4 extends with `| CI_substitute | Surface |` per `42-CONTEXT.md` D-42-01.
