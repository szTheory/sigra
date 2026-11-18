---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
reviewed: 2026-11-18T17:29:50Z
depth: standard
files_reviewed: 21
files_reviewed_list:
  - README.md
  - guides/flows/password-reset.md
  - test/example/lib/example_web/live/confirmation_live.ex
  - test/example/lib/example_web/live/reset_password_live.ex
  - test/example/lib/example_web/router.ex
  - test/example/test/example_web/enumeration_parity_test.exs
  - test/example/test/example_web/live/confirmation_live_test.exs
  - test/example/test/example_web/live/reset_password_live_test.exs
  - test/fixtures/brand/copy-inventory/generated.tsv
  - test/fixtures/brand/copy-inventory/host.tsv
  - test/fixtures/brand/copy-inventory/library.tsv
  - test/fixtures/brand/public-surfaces.json
  - test/sigra/brand/claims_docs_test.exs
  - test/sigra/brand/copy_contract_test.exs
  - test/sigra/brand/copy_inventory_test.exs
  - test/sigra/brand/frozen_surface_test.exs
  - test/sigra/brand/legacy_profiles_test.exs
  - test/sigra/brand/regen_guard_test.exs
  - test/support/brand/copy_inventory.ex
  - test/support/brand/copy_scan.ex
  - test/support/brand/regen_guard.ex
findings:
  critical: 0
  warning: 4
  info: 0
  total: 4
  necessity: 0
status: issues_found
---

# Phase 259: Code Review Report

**Reviewed:** 2026-11-18T17:29:50Z  
**Depth:** standard  
**Files Reviewed:** 21  
**Status:** issues_found

## Summary

I reviewed the 21 source and fixture files in the prior Phase 259 review scope against the current implementation and phase plans. The evaluation-scope resolver returned `degraded` (`no-reachable-task-commits`) with an overbroad cross-phase list, so this review is bounded to those prior Phase 259 paths. The previous reset-guide, README-claim, parity-dimension, and flow-guide-scope findings are fixed. The documented copy gate still has four coverage gaps: concatenated literals, visible attributes, two generated-template families, and common enumeration-claim wording. No implementation was changed and no tests were run for this review.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: Concatenated literals can split prohibited copy across scanner segments

**Severity:** WARNING  
**File:** `test/support/brand/copy_scan.ex:746-760`  
**Issue:** `code/3` extracts each quoted string independently and `literal/3` decides whether each fragment is copy on its own. Thus a copy expression such as `"Please log " <> "in to continue"` is scanned as two benign fragments and the prohibited phrase is never matched. The same applies when the concatenation spans source lines. Phase 259's copy contract is intended to catch wording changes in generated/admin copy; this common Elixir construction bypasses the check.
**Fix:** Coalesce adjacent `<>`-joined literal segments before applying the copy predicate and term matcher. Add planted controls for both same-line and wrapped concatenations.

### WR-02: Visible confirmation and submit labels are excluded from the copy scan

**Severity:** WARNING  
**File:** `test/support/brand/copy_scan.ex:86-87,1043-1068`  
**Issue:** The scanner inspects only six named attributes. HEEx values such as `data-confirm`, `phx-disable-with`, and `aria-description` are discarded before matching even though their text is shown to users or assistive technology. For example, the generated installer has a confirmation string containing “You will be logged out” in `priv/templates/sigra.install/core/session_live.ex`; it is outside the scanner's attribute list, so the banned `logout` wording is not checked. This leaves an existing visible instance and allows later regressions to pass.
**Fix:** Include user-visible attributes in the scanner's copy-attribute set (at minimum `data-confirm`, `phx-disable-with`, and `aria-description`), distinguish non-copy attributes such as class/style, and update the baseline and planted controls after review.

### WR-03: Generated OAuth templates carry prohibited vocabulary outside the copy gate

**Severity:** WARNING  
**File:** `test/support/brand/copy_scan.ex:83,225-227`; `test/support/brand/copy_inventory.ex:57`  
**Issue:** Both the generated-copy scanner and inventory are rooted only at `priv/templates/sigra.install`. The packaged `priv/templates/sigra.gen.oauth` generator is also shipped adopter output, but is not covered by either guard. It currently contains banned wording, including “Log in to link your … account” in `oauth_controller.ex` and “log in with” confirmation text in `oauth_settings_live.ex` and `oauth_settings.html.heex`. A copy change in these templates can therefore evade the contract and the inventory, despite the milestone applying the identity and vocabulary policy to generated output.
**Fix:** Extend the generated lane to cover `priv/templates/sigra.gen.oauth` (and explicitly decide whether `sigra.upgrade` contains user-facing copy), then review/regenerate its inventory and baseline. If the intended contract excludes these templates, track and state that exclusion as a deliberate policy boundary and add a separate check for their vocabulary.

### WR-04: Enumeration-claim sweep misses common promises

**Severity:** WARNING  
**File:** `test/sigra/brand/claims_docs_test.exs:161-182,733-750`  
**Issue:** The sweep title and failure text imply that all unqualified enumeration claims are rejected, but its three regex families miss ordinary phrasings. For example, “Sigra blocks enumeration of accounts,” “It prevents username enumeration,” “The flow is enumeration-proof,” and “The response does not reveal which emails are registered” do not match the current families. A future public-doc edit can introduce one of these claims and still pass the purported guard.
**Fix:** Add the demonstrated phrasings as planted controls and broaden the rule to recognize claim forms beyond the current exact verb/wording list. Keep narrowly justified neutral threat-description exceptions explicit and shrink-only.

---

_Reviewed: 2026-11-18T17:29:50Z_  
_Reviewer: Codex (gsd-code-reviewer)_  
_Depth: standard_
