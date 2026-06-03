---
phase: 149-launch-evidence-and-announcement-pack
reviewed: 2026-06-01T15:27:26Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - docs/launch/v1.0/announcement.md
  - docs/launch/v1.0/alternatives.md
  - docs/launch/v1.0/evidence.md
  - README.md
  - CHANGELOG.md
  - mix.exs
  - docs/NEXT-STEPS-MANUAL.md
  - doc/llms.txt
  - llms.txt
  - scripts/ci/launch-pack-contract.sh
  - test/sigra/planning/phase_149_launch_evidence_and_announcement_pack_test.exs
findings:
  critical: 0
  warning: 2
  info: 0
  total: 2
status: issues_found
---
# Phase 149: Code Review Report

**Reviewed:** 2026-06-01T15:27:26Z
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

Reviewed all scoped Phase 149 docs, routing surfaces, contract script, and phase tests. Launch-pack contract script and scoped ExUnit tests pass, but two warning-level quality defects remain in test/contract robustness.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: Brittle negative-version assertions can fail for unrelated legitimate content

**Classification:** WARNING  
**File:** `test/sigra/planning/phase_149_launch_evidence_and_announcement_pack_test.exs:33` and `:82`  
**Issue:** The test hard-refutes `"v1.32"` in `announcement.md` and `CHANGELOG.md`. This is not a semantic contract for Phase 149 and can fail when historical references, migration examples, or cross-links include `v1.32` for valid reasons. This creates false negatives unrelated to launch-pack correctness.
**Fix:**
```elixir
# Replace brittle negative string checks with positive contract checks, e.g.
assert announcement =~ "Hex 1.0.0"
assert changelog =~ "Hex 1.0.0 launch pack"
# (remove refute =~ "v1.32")
```

### WR-02: Launch-pack contract does not enforce alternatives-route linkage on public routing surfaces

**Classification:** WARNING  
**File:** `scripts/ci/launch-pack-contract.sh:90-93`  
**Issue:** The script enforces `announcement.md` and `evidence.md` links in `README.md`, `CHANGELOG.md`, and `docs/NEXT-STEPS-MANUAL.md`, but does not enforce `alternatives.md` there. This allows docs routing drift where the alternatives page can silently disappear from public guidance while tests still pass.
**Fix:**
```bash
for file in "${README}" "${CHANGELOG}" "${NEXT_STEPS}"; do
  require_text "${file}" "docs/launch/v1.0/announcement.md"
  require_text "${file}" "docs/launch/v1.0/alternatives.md"
  require_text "${file}" "docs/launch/v1.0/evidence.md"
done
```

---

_Reviewed: 2026-06-01T15:27:26Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: standard_
