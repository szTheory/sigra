---
phase: 144-readme-evaluator-lane-docs-proof
reviewed: 2026-05-30T15:38:46Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - docs/ga-evidence.md
  - guides/introduction/demo-showcase.md
  - mix.exs
  - test/example/README.md
findings:
  critical: 1
  warning: 3
  info: 1
  total: 5
status: issues_found
---

# Phase 144: Code Review Report

**Reviewed:** 2026-05-30T15:38:46Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

This phase adds a `demo-showcase.md` guide, rewrites `test/example/README.md` into a polished Vaultr showcase document, registers `demo-showcase.md` in `mix.exs` extras + assets config, and appends a planning-internal link to `docs/ga-evidence.md`. The changes are largely correct and well-structured, but contain one broken-link defect that ships into published docs, two factual inaccuracies across the new documentation, and a stale/misleading comment in `mix.exs`.

---

## Critical Issues

### CR-01: Broken relative path in `ga-evidence.md` — link resolves to non-existent `docs/.planning/` on GitHub

**File:** `docs/ga-evidence.md:19`
**Issue:** The newly added link uses the path `.planning/phases/144-readme-evaluator-lane-docs-proof/144-VERIFICATION.md`. Because `ga-evidence.md` lives under `docs/`, the relative path `.planning/…` resolves to `docs/.planning/…` — a directory that does not exist. On GitHub (and in any Markdown renderer that resolves relative paths from the file's own directory), this link is a 404. The correct path from `docs/` to the repo-root `.planning/` directory is `../.planning/…`.

**Fix:**
```markdown
- [v1.31 DEMO-SHOWCASE proof bundle (planning-internal)](../.planning/phases/144-readme-evaluator-lane-docs-proof/144-VERIFICATION.md)
```

Note: the `skip_undefined_reference_warnings_on` entry in `mix.exs` suppresses ExDoc's undefined-reference warnings for `ga-evidence.md` — this does not suppress broken-href rendering. The rendered ExDoc HTML will still emit an `<a href=".planning/…">` that resolves to a dead URL. The suppression is necessary but does not mask the broken path.

---

## Warnings

### WR-01: `docs/ga-evidence.md` links to non-existent git tag `v0.2.0`

**File:** `docs/ga-evidence.md:11-13`
**Issue:** Three "tag snapshot" links hard-code `v0.2.0` as the git ref:
```
https://github.com/sztheory/sigra/blob/v0.2.0/docs/uat-ci-coverage.md
https://github.com/sztheory/sigra/blob/v0.2.0/.planning/v1.4-GA-UAT.md
https://github.com/sztheory/sigra/blob/v0.2.0/.planning/milestones/v1.4-REQUIREMENTS.md
```
The tag `v0.2.0` does not exist in the repository; the earliest existing tag is `v0.2.1`. All three URLs return a 404 on GitHub. These links were not changed in this phase's diff, but they are in a file modified by this phase, making them in scope. The files referenced do exist under `v0.2.1`.

**Fix:** Replace `v0.2.0` with `v0.2.1` in all three URLs:
```markdown
- [UAT ↔ CI coverage — OA-01 / OA-02 machine baseline (tag snapshot)](https://github.com/sztheory/sigra/blob/v0.2.1/docs/uat-ci-coverage.md)
- [v1.4 GA / UAT matrix (tag snapshot)](https://github.com/sztheory/sigra/blob/v0.2.1/.planning/v1.4-GA-UAT.md)
- [v1.4 requirements closure (tag snapshot)](https://github.com/sztheory/sigra/blob/v0.2.1/.planning/milestones/v1.4-REQUIREMENTS.md)
```

---

### WR-02: `demo-showcase.md` falsely lists Node.js as a prerequisite

**File:** `guides/introduction/demo-showcase.md:12`
**Issue:** The guide tells readers to "See `test/example/README.md` for prerequisites (Elixir, PostgreSQL, and **Node.js** versions)." The `test/example/README.md` does not list Node.js as a prerequisite. Inspection of the example app confirms that `mix setup` runs only `deps.get` and `ecto.setup` — there is no `assets.deploy`, `npm install`, or Node.js build step. The `watchers: []` config in `test/example/config/dev.exs` confirms no JavaScript bundler is invoked. A developer who stops to install Node.js before running the demo is misdirected.

**Fix:** Remove the Node.js reference:
```markdown
Then visit [http://localhost:4000](http://localhost:4000). See `test/example/README.md` for prerequisites (Elixir and PostgreSQL versions).
```

---

### WR-03: Stale/misleading comment in `mix.exs` for the `ga-evidence.md` suppression

**File:** `mix.exs:179-181`
**Issue:** The comment justifying the `skip_undefined_reference_warnings_on` entry for `ga-evidence.md` reads: _"links to a planning-internal VERIFICATION.md that does not exist until Plan 03 (Wave 2) completes."_ As of this phase, all three plan summaries (`144-01-SUMMARY.md`, `144-02-SUMMARY.md`, `144-03-SUMMARY.md`) are present, meaning Wave 2 is complete and the file exists. The comment is now factually incorrect. The real reason suppression is needed is permanent: ExDoc cannot resolve a relative `.planning/` path from `docs/ga-evidence.md` because `.planning/` is not an ExDoc extra, so the suppression remains necessary but the stated rationale is wrong and will mislead future maintainers.

**Fix:** Update the comment to reflect the actual (permanent) reason:
```elixir
# ga-evidence.md links to a planning-internal path (.planning/…) that ExDoc
# cannot resolve — .planning/ is not in extras, so the undefined-reference
# warning is suppressed permanently for this file.
"docs/ga-evidence.md"
```

---

## Info

### IN-01: `demo-showcase.md` does not include a credentials table — readers must run the server to see passwords

**File:** `guides/introduction/demo-showcase.md:16-18`
**Issue:** The guide shows a screenshot of the credentials page and says "visit `/demo/credentials` for a live cheat-sheet listing all six persona emails and passwords." This means a reader evaluating the guide without running the demo cannot see the actual credential values. The `test/example/README.md` (in the same changeset) includes a full credentials table. The guide could include the same table for offline readability, especially since the passwords are explicitly labeled public-by-design demo credentials. This is a DX omission, not a correctness issue.

**Fix (optional):** Add the credentials table from `test/example/README.md` directly into `demo-showcase.md`, below the screenshot, matching the README format.

---

_Reviewed: 2026-05-30T15:38:46Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
