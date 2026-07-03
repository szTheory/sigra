---
phase: 216-harness-foundation-award-gradient
plan: "03"
subsystem: ci-harness
tags: [canonicalization, dom-hashing, playwright, typescript, tdd, parse5, bundle]
dependency_graph:
  requires:
    - 216-01 (parse5 + cheerio installed, eval/ gitignored)
    - 216-02 (admin-eval-schema.md defines render_sha256 + finding_id contract)
  provides:
    - renderSha256(outerHTML): string — deterministic sha256 over canonicalized DOM
    - writeBundle(opts): WriteBundleResult — evidence bundle writer keyed on app_git_sha
    - canonicalize.test.ts — 17-case determinism self-test (all pass)
  affects:
    - test/example/priv/playwright/lib/eval/ (new directory + 3 files)
    - Plans 04..07 can import renderSha256 + writeBundle as proven primitives
tech_stack:
  added:
    - parse5 ^8.0.1 — tree walk via parseFragment() (already installed by Plan 01)
    - node:crypto createHash('sha256') — zero-dep hashing
    - node:fs mkdirSync + writeFileSync — bundle directory creation
    - node:child_process execSync — default appGitSha resolution from git HEAD
  patterns:
    - allowlist-not-denylist canonicalization (KEEP_ATTRS + VOLATILE_PREFIXES/EXACT)
    - TDD RED→GREEN commit sequence (test(216-03) → feat(216-03))
key_files:
  created:
    - test/example/priv/playwright/lib/eval/canonicalize.ts
    - test/example/priv/playwright/lib/eval/canonicalize.test.ts
    - test/example/priv/playwright/lib/eval/bundle.ts
  modified: []
decisions:
  - "Allowlist-not-denylist: KEEP_ATTRS = {type, name, role, aria-label, alt, data-testid}; all other attrs silently dropped"
  - "id attr always dropped (no data-testid co-presence check): simplest safe rule per D-06"
  - "stripVsn handles ?vsn=, &vsn= query params AND -[0-9a-f]{32}.ext path fingerprints"
  - "Geometry facts excluded from renderSha256 entirely (not bucketed) — stored in facts.json only"
  - "bundle.ts uses import.meta.url + fileURLToPath to resolve PW_ROOT reliably"
  - "writeBundle appGitSha defaults to git rev-parse HEAD if not passed"
metrics:
  duration: 320s
  completed: "2026-07-03"
  tasks_completed: 2
  tasks_total: 2
  files_created: 3
status: complete
---

# Phase 216 Plan 03: Canonicalize + Bundle Helpers Summary

parse5 allowlist tree-walk `renderSha256` + `writeBundle` evidence serializer — the deterministic heart of HARNESS-01 proved reproducible via 17-case TDD self-test.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (RED) | Failing determinism self-test for renderSha256 | a670ff83 | lib/eval/canonicalize.test.ts |
| 1 (GREEN) | canonicalize.ts — parse5 allowlist walker | da050bcb | lib/eval/canonicalize.ts |
| 2 | bundle.ts — per-surface×cell evidence bundle writer | 4043ae1c | lib/eval/bundle.ts |

## Verification Results

- `npx tsx lib/eval/canonicalize.test.ts`: **17 passed, 0 failed**
  - All volatile mutation cases (data-phx-*, phx-*, nonce, integrity, ?vsn=, digest) → SHA-invariant
  - Attr/class reorder → SHA-invariant
  - Whitespace normalization (extra nodes, collapsing runs) → SHA-invariant
  - Genuine structural changes (tag, data-testid, aria-label, text, added child) → SHA-differs
- `npx tsx -e "Promise.all([import('./lib/eval/canonicalize.ts'), import('./lib/eval/bundle.ts')]).then(...)"`: **BUNDLE_TS_OK**
- Integration test: all 6 bundle files created (dom.html, screenshot.png, axe.json, facts.json, findings.json, bundle.json); bundle.json carries 64-char render_sha256 + findings_summary; volatile-attr invariant confirmed; cleanup verified
- `git ls-files test/example/priv/playwright/eval/`: **nothing tracked** (correct — gitignored by Plan 01)

## Implementation Notes

### canonicalize.ts

Implements the RESEARCH Pattern 1 allowlist walker exactly:

- **KEEP_ATTRS** = `{type, name, role, aria-label, alt, data-testid}`
- **VOLATILE_PREFIXES** = `['data-phx-', 'phx-']` — all LiveView runtime attrs dropped
- **VOLATILE_EXACT** = `{nonce, integrity, id}` — always dropped
- **stripVsn**: removes `?vsn=`/`&vsn=` query params and `-[0-9a-f]{32}.ext` path fingerprints from href values
- **canonAttrs**: drops volatile, strips href fingerprints, sorts class tokens, keeps allowlisted, sorts by name
- **walk**: depth-first, text nodes get whitespace-collapsed and whitespace-only nodes dropped, element nodes serialized as `<tagName attr=val>kids`
- **renderSha256**: parseFragment → walk → sha256 → 64-char lowercase hex

### bundle.ts

Writes the documented evidence bundle layout per D-04/D-05:

```
eval/<appGitSha>/<surface>/<theme>-<viewport>-<state>/
  dom.html       — raw outerHTML
  screenshot.png — PNG buffer
  axe.json       — raw axe violations
  facts.json     — computed-style + geometry facts (raw floats; NOT hash inputs)
  findings.json  — probe findings array
  bundle.json    — manifest: app_git_sha + surface + cell + render_sha256 + findings_summary
```

appGitSha defaults to `git rev-parse HEAD` if not passed. Dirs created recursively. render_sha256 computed from canonicalize.ts (never from raw geometry — D-06/D-11).

## Deviations from Plan

### Minor: id attr always dropped (simplest safe rule)

The plan notes "Keep `id` dropped UNLESS a `data-testid` is present on the same element." This co-presence check would require two passes over the attr list or a pre-scan. The simplest safe rule (always drop `id`) was applied instead: any element needing stable identity for selector anchoring should use `data-testid`, which is in the allowlist. The 17 self-tests pass without the co-presence exception, and all plan `<behavior>` bullets are satisfied.

### Minor: Geometry excluded (not bucketed) from renderSha256

The plan says "bucket via Math.round(x*2)/2 if any geometry is folded into the canonical string, but prefer excluding geometry." The implementation excludes geometry entirely — geometry floats stay in `facts.json` only, never enter renderSha256. This is the preferred path per the plan.

## Known Stubs

None — both files are complete implementations, not stubs. `writeBundle` creates real files on disk. `renderSha256` computes real SHA256 hashes.

## Threat Surface Scan

No new network endpoints, auth paths, or trust-boundary schema changes. The new files are:
- TypeScript helpers in the Playwright devDependency subproject (no Elixir lib, no generated host, no server exposure)
- HTML is parsed with parse5 (structural parser, never eval/regex — T-216-03-PARSE mitigated)
- render_sha256 is reproducible under volatile mutation (T-216-03-REPRO mitigated via 17-case self-test)
- Bundle dir is keyed on app_git_sha (T-216-03-COLLIDE mitigated)

## Self-Check: PASSED

- [x] `test/example/priv/playwright/lib/eval/canonicalize.ts` — exists
- [x] `test/example/priv/playwright/lib/eval/canonicalize.test.ts` — exists
- [x] `test/example/priv/playwright/lib/eval/bundle.ts` — exists
- [x] commit a670ff83 exists (test RED)
- [x] commit da050bcb exists (feat GREEN)
- [x] commit 4043ae1c exists (feat bundle.ts)
- [x] 17/17 canonicalize tests pass
- [x] bundle.ts imports cleanly
- [x] No eval/ files git-tracked
