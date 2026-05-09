---
date: "2026-05-08 12:30"
promoted: false
---

Comment-hygiene audit results from the 2026-05-08 cleanup pass:

**Phase-ref comments by surface:**
- `priv/templates/` — 17 occurrences (cleaned today as quick-win A2; user-visible noise that ships into every host's generated code).
- `lib/` inline — 9 `# NN-NN` style comments encoding decision context (e.g. `# 15-02 Category 3:` describes auth-state class).
- `lib/` moduledocs and inline — 60+ `# Phase NN` style references.

**Verdict:**
- Template noise is high-leverage to clean (every adopter sees it). Cleaned today.
- Library noise is internal-only and many comments encode real decision context. Deferred to SEED-009 for a focused paraphrasing pass — the rule is paraphrase, not strip.

**Find the surface:**

```bash
grep -rn -E '^[[:space:]]*#[[:space:]]+(Phase [0-9]+|[0-9]+-[0-9]+|P[0-9]+|v[0-9]+\.[0-9]+)' lib/
```

Cross-links: A2 (template cleanup, completed today), SEED-009 (lib paraphrase, deferred).
