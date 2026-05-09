---
id: SEED-009
status: deferred
planted: 2026-05-08
planted_during: post v1.24 comment-hygiene audit
trigger_when: Any general-cleanup window between milestones; or paired with a focused refactor of one of the named modules
scope: Small to Medium
---

# SEED-009: Library-code phase-comment paraphrasing pass

## Why This Matters

A broad grep across `lib/` and `priv/templates/` finds far more plan-ID references than the original audit estimated. Patterns include:

- `# 15-02 Category 3: no user resolved — nil scope + target_id: nil` (lib/)
- `# Phase 16 D-26: assigns @user_organizations to the socket` (lib/ and templates)
- `# Phase 92 / B2B-02 (CR-02 fix): host-owned role atom` (templates)
- `# D-01: personal-workspace flag (Phase 18)` (templates)
- `## Role storage (Phase 92 / B2B-02)` (moduledoc headings in templates)
- `(D-09)`, `(Plan 18-02)`, `(WR-2-05 fix)`, `(CR-03 fix)` parenthetical references throughout

Some of these encode **real decision context** (e.g., "Category 3" is a meaningful auth-state class — anonymous-vs-known-vs-resolved — that recurs across `auth.ex`, `oauth.ex`, and `account.ex`). Stripping naively would lose that.

But the **plan-ID prefix** (`# 15-02`, `# Phase 92 / B2B-02`) is pure noise to a reader who isn't paging through `.planning/phases/`. Same for `(D-09)` and `(Plan 18-02)` parentheticals — they look like they encode meaning but rarely do, and they rot as plans archive.

The fix is a careful paraphrase pass: keep the semantic content, drop the plan IDs, rewrite as natural prose where the original is opaque.

**What was already shipped today (2026-05-08):** the leading `# Phase NN:` prefix comments in `priv/templates/` were stripped (see NOTE `2026-05-08-comment-noise-audit.md`, quick-win A2 in the loose-notes synthesis plan). What remains is the deeper paraphrasing of `D-XX`, `(Phase NN)`, `Plan NN-NN`, `CR-XX fix`, `WR-XX fix`, etc. references across both `lib/` AND `priv/templates/`.

## When to Surface

Trigger this seed when:

- Any general-cleanup window opens between milestones
- A specific module under heavy edit is being refactored and a paraphrase pass can fold in
- Adopter feedback mentions confusing internal comments

It should *not* be done as part of EMAIL-RAILS or any feature milestone — it deserves its own focused session because each comment requires a 30-second judgment call.

## Scope Estimate

Small to Medium — broader than initial audit suggested. Surface includes:

- **lib/** — ~70 references across moduledocs and inline comments (`# Phase NN`, `# NN-NN`, `D-XX`)
- **priv/templates/** — additional `D-XX` references, `(Plan NN-NN)` parentheticals, `B2B-XX` / `CR-XX` / `WR-XX` markers in both moduledocs and inline comments. Templates ship into every adopter's repo, so cleanup leverage is highest here.

**Rules of paraphrasing:**

- **Pure plan ref, no semantic content** (e.g. `# Phase 92 / Plan 92-02`) → delete
- **Plan ref + semantic content** (e.g. `# Phase 91 B2B-01: org-level MFA enforcement`) → drop the prefix → `# Org-level MFA enforcement`
- **Opaque category code** (e.g. `# 15-02 Category 3:`) → expand inline → `# Category 3 (truly-anonymous unknown-email):` or rewrite without the category number entirely
- **Decision IDs in parentheticals** (e.g. `(D-26)`, `(Plan 18-02)`, `(WR-2-05 fix)`) → drop unless the surrounding sentence relies on them; if they encode a real distinction (e.g. an at-most-one invariant), name the invariant instead
- **Moduledoc section headers** (e.g. `## Role storage (Phase 92 / B2B-02)`) → drop the parenthetical

A focused 2–3 hour pass, not a multi-day one. Templates first (user-visible leverage), lib/ second.

## Breadcrumbs

Find the surface:

```bash
grep -rn -E '^[[:space:]]*#[[:space:]]+(Phase [0-9]+|[0-9]+-[0-9]+|P[0-9]+|v[0-9]+\.[0-9]+)' lib/
```

Representative files (highest density):
- [`lib/sigra/auth.ex`](/Users/jon/projects/sigra/lib/sigra/auth.ex)
- [`lib/sigra/oauth.ex`](/Users/jon/projects/sigra/lib/sigra/oauth.ex)
- [`lib/sigra/account.ex`](/Users/jon/projects/sigra/lib/sigra/account.ex)
- [`lib/sigra/install/features/core.ex`](/Users/jon/projects/sigra/lib/sigra/install/features/core.ex)

See companion NOTE: `.planning/notes/2026-05-08-comment-noise-audit.md` for the full quantification.

## Notes

- The companion *template* cleanup (priv/templates/) is shipped today as quick-win A2, since template comments are user-visible and the noise is more harmful there.
- Library comments are internal-only, so this can wait for a focused window.
- Don't over-correct — some comments deserve to *expand* with context once the plan ID is stripped (e.g., "Category 3" needs a parenthetical explanation if it's not obvious from surrounding code).
