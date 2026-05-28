---
phase: 136-verification-proof-bundle-narrative-honesty-corrigendum
plan: "02"
subsystem: planning-narrative
tags: [corrigendum, narrative-honesty, mailglass, changelog]
dependency_graph:
  requires: []
  provides: [DOC-01-corrigendum]
  affects: [.planning/MILESTONES.md, .planning/PROJECT.md, CHANGELOG.md]
tech_stack:
  added: []
  patterns: [corrigendum-in-place, keep-a-changelog]
key_files:
  created: []
  modified:
    - .planning/MILESTONES.md
    - .planning/PROJECT.md
    - CHANGELOG.md
decisions:
  - "Preserved original v1.25 bullets rather than deleting them — historical record of what was planned/claimed, corrected in place by a clearly-labeled corrigendum block."
  - "Added corrigendum coverage for all three overclaiming lines (shim/flag, catalog, adapter-compile) in a single block rather than annotating each bullet individually — clearer to read."
  - "Removed only the duplicate ## [Unreleased] header line; folded its bullet content into the surrounding context without adding any new header, so the file has exactly one [Unreleased] section."
  - "Placed the D-08 Mailglass note under a ### Documentation subsection in [Unreleased] to match Keep-a-Changelog convention used elsewhere in the file."
metrics:
  duration: "~8 minutes"
  completed: "2026-05-28"
  tasks_completed: 2
  files_modified: 3
---

# Phase 136 Plan 02: Narrative Honesty Corrigendum Summary

**One-liner:** Corrected v1.25 EMAIL-RAILS Mailglass overclaims across MILESTONES.md, PROJECT.md, and CHANGELOG.md; removed stray duplicate [Unreleased] header.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 136-02-01 | Corrigendum in MILESTONES.md + PROJECT.md (D-06, D-07) | ccf75e1 | .planning/MILESTONES.md, .planning/PROJECT.md |
| 136-02-02 | CHANGELOG [Unreleased] host-owned-wiring note + remove duplicate header (D-08, D-09) | 403601d | CHANGELOG.md |

## What Was Corrected

### D-06 — MILESTONES.md v1.25 entry

The v1.25 EMAIL-RAILS entry contained three overclaiming bullets:
- Line 79: "Introduced an optional `Sigra.Mailers.Adapters.Mailglass` shim and `--with-mailglass` installer path"
- Line 80: "Shipped generated-host override rails and the Mailglass preview catalog for all 18 auth email surfaces"
- Line 84: "Mailglass adapter compilation is now optional-dependency-safe"

A `**Corrigendum (v1.29 DOC-01, 2026-05-28):**` block was appended after the key-accomplishments bullets, before the `---` separator. It states plainly that the library-resident `Sigra.Mailers.Adapters.Mailglass` module and `--with-mailglass` flag did NOT land on the release branch, that no Mailglass preview catalog shipped in the library, and that the supported posture is recipe-only host-owned wiring via `Sigra.Mailer`. The original bullets were preserved for historical record.

### D-07 — PROJECT.md v1.25 bullet

The "Previously shipped: v1.25 EMAIL-RAILS" section opened with:
- "optional Mailglass adapter plus `--with-mailglass` installer path"
- "generated-host override seam and Mailglass preview catalog for auth emails"

The first bullet (unqualified overclaim) was removed and replaced with an accurate description of what did ship (generated-host override seam for auth emails). The second bullet was revised to remove the Mailglass preview catalog claim. A matching `**Corrigendum (v1.29 DOC-01, 2026-05-28):**` note was appended so PROJECT.md and MILESTONES.md tell the same story.

### D-08 — CHANGELOG.md [Unreleased] host-owned-wiring note

A `### Documentation` subsection bullet was added under the correctly-placed `## [Unreleased]` header (at line 33 in the original, immediately above `## [0.2.5]`). The bullet names the v1.29 Mailglass integration posture as recipe-only host-owned wiring via `Sigra.Mailer`, states no library-resident adapter and no `--with-mailglass` flag, and references `guides/recipes/companion-libs/mailglass.md`.

### D-09 — CHANGELOG.md duplicate [Unreleased] header removed

The stray duplicate `## [Unreleased]` header that appeared at line 222 (below a block of historical commit-style entries) was removed. The bullet content that sat under it — `.formatter.exs` chore, Human GA pointer, AUD-04 inventory entries, AUD-05 block — was preserved by folding it directly under the preceding context. The file now has exactly one `## [Unreleased]` header.

## Verification Results

All automated checks from the plan passed:

1. `grep -i "did not land\|not part of the supported surface" .planning/MILESTONES.md` — MATCH
2. `grep -q "Sigra.Mailers.Adapters.Mailglass" .planning/MILESTONES.md` — MATCH
3. `grep -q -- "--with-mailglass" .planning/MILESTONES.md` — MATCH
4. `grep -qi "Sigra.Mailer" .planning/MILESTONES.md` — MATCH
5. `grep -qi "Mailglass" .planning/PROJECT.md` — MATCH
6. `grep -q -- "--with-mailglass" .planning/PROJECT.md` — MATCH
7. `grep -qi "Sigra.Mailer\|recipe-only\|host-owned\|did not land\|not part of the supported surface" .planning/PROJECT.md` — MATCH
8. No banned phrases in MILESTONES.md or PROJECT.md — PASS
9. `grep -c "^## \[Unreleased\]" CHANGELOG.md` == 1 — PASS
10. `grep -qi "Sigra.Mailer" CHANGELOG.md` — MATCH
11. `grep -q "companion-libs/mailglass" CHANGELOG.md` — MATCH
12. `grep -q -- "--with-mailglass" CHANGELOG.md` — MATCH
13. No banned phrases in CHANGELOG.md — PASS
14. `grep -q "formatter.exs" CHANGELOG.md` — MATCH
15. `grep -q "Human GA" CHANGELOG.md` — MATCH

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — this is a documentation-only plan; no data wiring required.

## Threat Flags

No new network endpoints, auth paths, file access patterns, or schema changes introduced — documentation edits only.

## Self-Check: PASSED

- `.planning/MILESTONES.md` exists and contains corrigendum: confirmed
- `.planning/PROJECT.md` exists and contains corrigendum: confirmed
- `CHANGELOG.md` has exactly one `## [Unreleased]` header: confirmed
- Commits ccf75e1 and 403601d both exist in git log: confirmed
