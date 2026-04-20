---
status: complete
phase: 44
iteration: 1
fix_scope: critical_warning
findings_in_scope: 1
fixed: 1
skipped: 3
skipped_ids: [IN-01, IN-02, IN-03]
completed_at: "2026-04-20"
---

# Phase 44 — Code review fix report

## Summary

| Finding | Severity | Action |
|---------|----------|--------|
| **WR-01** | warning | **Fixed** — `@spec` for `Sigra.APIToken.revoke/2` now includes `{:error, Ecto.Changeset.t()}` |
| IN-01 | info | Skipped (out of scope; no code change requested) |
| IN-02 | info | Skipped (documented as acceptable) |
| IN-03 | info | Skipped (out of scope; use `/gsd-code-review-fix 44 --all` to add SUMMARY frontmatter) |

## Code change

- **`lib/sigra/api_token.ex`**: Align public typespec with the `Ecto.Multi` implementation so callers and Dialyzer see the same `{:error, changeset}` path as for `create/3`.

## Verification

```bash
mix compile --warnings-as-errors
```

(Run in repo root; optional strict CI gate.)

## Follow-up

- Re-run **`/gsd-code-review 44`** if you want a fresh REVIEW.md after this fix.
- Use **`/gsd-code-review-fix 44 --all`** to address IN-* items (e.g. SUMMARY YAML for 44-04/44-05).
