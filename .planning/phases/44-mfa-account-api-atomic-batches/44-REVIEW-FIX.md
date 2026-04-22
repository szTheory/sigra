---
status: complete
phase: 44
iteration: 2
fix_scope: all
findings_in_scope: 4
fixed: 2
documented_no_change: 2
completed_at: "2026-04-20"
---

# Phase 44 — Code review fix report

## Iteration notes

- **Iteration 1** (`fix_scope: critical_warning`): **WR-01** — `@spec` on `Sigra.APIToken.revoke/2` extended with `{:error, Ecto.Changeset.t()}` (`lib/sigra/api_token.ex`).
- **Iteration 2** (`fix_scope: all`, this document): **IN-03** — added `key-files` YAML frontmatter to **`44-04-SUMMARY.md`** and **`44-05-SUMMARY.md`** so GSD code-review scoping can extract paths like plans 44-01..03.

## Summary (`--all` pass)

| Finding | Severity | Action |
|---------|----------|--------|
| WR-01 | warning | Fixed in iteration 1 (typespec) |
| IN-01 | info | **No code change** — intentional symmetry with `create/3` (`Repo.transaction` + no-op `log_multi_safe` when audit disabled); negligible overhead |
| IN-02 | info | **No code change** — matches `APIToken`/`Account` defensive `raise` style; atomicity tests use `Ecto.ConstraintError` |
| IN-03 | info | **Fixed** — YAML `key-files` on 44-04 and 44-05 summaries |

## Files touched (iteration 2)

- `.planning/phases/44-mfa-account-api-atomic-batches/44-04-SUMMARY.md`
- `.planning/phases/44-mfa-account-api-atomic-batches/44-05-SUMMARY.md`
- `.planning/phases/44-mfa-account-api-atomic-batches/44-REVIEW-FIX.md` (this file)

## Follow-up

- **`/gsd-code-review 44`** — optional refresh of `44-REVIEW.md` after summary structure change.
