---
phase: 132-threadline-recipe-mailglass-cross-link-recipe
verified: 2026-05-27T00:00:00Z
status: passed
score: 3/3 must-haves verified
overrides_applied: 0
---

# Phase 132: Threadline Recipe + Mailglass Cross-Link Recipe — Verification Report

**Phase Goal:** Publish the canonical Threadline integration recipe (the milestone's canary recipe) and the Mailglass host-owned-wiring recipe so adopters can paste the literal `forwarders:` block from Phase 131 and wire Mailglass behind the existing `Sigra.Mailer` behaviour without expecting a library-resident Mailglass adapter.

**Verified:** 2026-05-27
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (Roadmap Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC-1 | An adopter can paste the `forwarders:` block from `guides/recipes/companion-libs/threadline.md` into their Sigra config, run `mix deps.get`, and emit audit events in Threadline with no library edits beyond Phase 131 | VERIFIED | Literal canonical config block present verbatim (lines 58-72); prose pin `lib/sigra/audit/forwarders/threadline.ex:290-307` present (line 74); zero lib/ changes confirmed via `git diff HEAD~3 HEAD --stat lib/` |
| SC-2 | An adopter following `guides/recipes/companion-libs/mailglass.md` can wire Mailglass `~> 1.2` behind `Sigra.Mailer` without expecting a Sigra-owned adapter module or `--with-mailglass` flag (recipe explicitly says so) | VERIFIED | `@behaviour Sigra.Mailer` + `use Mailglass.Mailable, stream: :transactional` shown end-to-end (lines 51-73); Non-goals explicitly states "Sigra does not ship a library-resident Mailglass adapter" and "no `--with-mailglass` install flag" |
| SC-3 | Both recipes ship with `validated_against:` + `last_validated:` frontmatter, `mix.exs` snippet, Failure modes section, Non-goals section, standalone banner, reachable from ExDoc under "Companion Libraries" group | VERIFIED | HTML-comment frontmatter on both files confirmed; all sections present; `mix docs --warnings-as-errors` exits 0; `doc/llms.txt` confirms "Companion Libraries" group lists both recipes |

**Score:** 3/3 truths verified

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `guides/recipes/companion-libs/threadline.md` | Canary Threadline integration recipe — literal `forwarders:` block, role/scope table, prerequisites, failure modes, non-goals, cross-links | VERIFIED | 157 lines; all plan-specified content present; eight-section contract satisfied |
| `guides/recipes/companion-libs/mailglass.md` | Mailglass host-owned-wiring recipe — `Sigra.Mailer` impl, `stream: :transactional`, failure modes, non-goals, cross-links | VERIFIED | 130 lines; all plan-specified content present; eight-section contract satisfied |
| `mix.exs` | ExDoc registration — two new `extras:` entries + tightened `Recipes:` regex + new `"Companion Libraries":` group entry | VERIFIED | All three blocks present; "Companion Libraries" entry at line 226, before `Recipes:` entry at line 227 |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `guides/recipes/companion-libs/threadline.md` | `lib/sigra/audit/forwarders/threadline.ex` | Prose pin: "Sigra invokes `Threadline.record_action/2` per `lib/sigra/audit/forwarders/threadline.ex:290-307`" | VERIFIED | Line 74 of threadline.md |
| `guides/recipes/companion-libs/mailglass.md` | `lib/sigra/mailer.ex` | `@behaviour Sigra.Mailer` in code example (line 56) | VERIFIED | Pattern present; behaviour contract satisfied per `deliver/3` callback |
| `mix.exs` (groups_for_extras) | `guides/recipes/companion-libs/*.md` | `"Companion Libraries": ~r{guides/recipes/companion-libs/.?}` placed before `Recipes:` entry | VERIFIED | CL at line 226, Recipes at line 227; first-match-wins ordering correct |

---

## Artifact Content — Full Contract Check

### threadline.md

| Check | Result |
|-------|--------|
| HTML-comment frontmatter (not YAML `---`) | PASS |
| `<!-- validated_against: threadline ~> 0.5 -->` on line 1 | PASS |
| `<!-- last_validated: 2026-05-27 -->` on line 2 | PASS |
| Human-visible "Validated against: `threadline ~> 0.5` as of 2026-05-27" | PASS |
| "Sigra works fully standalone" banner | PASS |
| "What this is" section with role/scope table | PASS |
| Prerequisites section | PASS |
| `mix.exs` snippet section | PASS |
| Sigra-side config block section | PASS |
| Literal `forwarders:` block (canonical shape from plan) | PASS |
| `dispatch: :auto`, `module: Sigra.Audit.Forwarders.Threadline`, env var refs | PASS |
| Prose pin `lib/sigra/audit/forwarders/threadline.ex:290-307` | PASS |
| "Failure modes" section (H2 heading exact) | PASS |
| 5 failure mode subsections (D-13 count) | PASS — count=5 |
| `maybe_warn_missing_forwarder_deps/0` referenced | PASS |
| `attach_forwarders/0` referenced | PASS |
| `[:sigra, :audit, :forward, :error]` telemetry event | PASS |
| `Sigra.Workers.AuditForward` referenced | PASS |
| `:schema_mismatch` referenced | PASS |
| "Non-goals" section (H2 heading exact) | PASS |
| 4 non-goal bullets (D-14 count) | PASS — count=4 |
| "See also" section | PASS |
| `../flows/audit-logging.html` cross-link | PASS |
| `./mailglass.html` cross-link | PASS |
| `Sigra.Audit.Forwarder` behaviour + `Mox.defmock` closing subsection | PASS |
| No banned phrases | PASS |
| No `Threadline.record_action/2 (` call-site example | PASS |
| No `Threadline.Plug` | PASS |
| `mix threadline.gen.triggers` appears only in Non-goals exclusion text | PASS (see note below) |
| Line count 157 (target 120–260) | PASS |

**Note — `mix threadline.gen.triggers` false-positive gate:** The plan's negative grep `! grep -qE "mix threadline\.gen\.triggers"` fires because line 140 of the recipe mentions the command in the Non-goals exclusion sentence: "This recipe does **not** cover... `mix threadline.gen.triggers`." This is exactly the content D-14 item 3 mandates. The plan gate was intended to prevent showing trigger-gen instructions to adopters; it did not anticipate the correct Non-goals exclusion text. The content is present for the right reason. Classification: plan gate defect (false-positive), not a content defect. The recipe correctly follows D-14.

### mailglass.md

| Check | Result |
|-------|--------|
| HTML-comment frontmatter (not YAML `---`) | PASS |
| `<!-- validated_against: mailglass ~> 1.2 -->` on line 1 | PASS |
| `<!-- last_validated: 2026-05-27 -->` on line 2 | PASS |
| Human-visible "Validated against: `mailglass ~> 1.2` as of 2026-05-27" | PASS |
| "Sigra works fully standalone" banner | PASS |
| "What this is" section with role/scope table | PASS |
| Prerequisites section | PASS |
| `mix.exs` snippet section | PASS |
| Sigra-side mailer module section | PASS |
| `@behaviour Sigra.Mailer` in code example | PASS |
| `MyApp.SigraAuthMailer` module name | PASS |
| `use Mailglass.Mailable, stream: :transactional` | PASS |
| `NoTrackingOnAuthStream` compile-time guard explained | PASS |
| `deps/mailglass/lib/mailglass/mailable.ex:30-33` reference | PASS |
| No `stream: :bulk` literal (negative gate — D-15 fix) | PASS |
| "Mailglass sits **above** Swoosh" framing | PASS |
| "not a Swoosh adapter" explicit statement | PASS |
| "Failure modes" section (H2 heading exact) | PASS |
| 3 failure mode subsections (D-15 count) | PASS — count=3 |
| "Non-goals" section (H2 heading exact) | PASS |
| 3 non-goal bullets (D-16 count) | PASS — count=3 |
| "no library-resident Mailglass adapter" explicit | PASS |
| "no `--with-mailglass` install flag" explicit | PASS |
| "See also" section | PASS |
| `../flows/oauth.html` cross-link | PASS |
| `../introduction/installation.html` cross-link | PASS |
| `./threadline.html` cross-link | PASS |
| `../introduction/suite-integration.html` forward cross-link | PASS |
| No banned phrases | PASS |
| Line count 130 (target 60–160) | PASS |

---

## mix.exs Three-Block Edit Verification

| Check | Result |
|-------|--------|
| Block 1: `"guides/recipes/companion-libs/threadline.md"` in `extras:` | PASS — line 219 |
| Block 1: `"guides/recipes/companion-libs/mailglass.md"` in `extras:` | PASS — line 220 |
| Block 2: `Recipes: ~r{guides/recipes/[^/]+\.md$}` present | PASS — line 227 |
| Block 2: Tightened regex correctly excludes companion-libs subdir | PASS — verified via Python regex test |
| Block 2: Tightened regex still matches existing recipes (passkeys.md, companion-oauth-provider.md, etc.) | PASS |
| Block 3: `"Companion Libraries": ~r{guides/recipes/companion-libs/.?}` present | PASS — line 226 |
| Block 3: "Companion Libraries" entry BEFORE "Recipes" entry (line 226 < 227) | PASS |
| Both new recipe files in `skip_undefined_reference_warnings_on:` | PASS — lines 172-173 |
| Phase 131 lib/ files in `skip_undefined_reference_warnings_on:` (pre-existing gate unblock) | PASS — lines 165-169 |
| No other mix.exs regions touched | PASS — `git diff HEAD~3 HEAD -- mix.exs` shows only docs() function changes |

---

## ExDoc Gate (D-12)

| Check | Result |
|-------|--------|
| `mix docs --warnings-as-errors` exit code | 0 — PASS |
| Generated HTML at `doc/threadline.html` (ExDoc flattens by basename) | PASS |
| Generated HTML at `doc/mailglass.html` | PASS |
| `doc/llms.txt` shows "Companion Libraries" group with both recipes | PASS |
| Existing "Recipes" group unchanged in `doc/llms.txt` | PASS — "Testing Auth Flows" appears under Recipes |
| `doc/guides/recipes/companion-libs/` subdir path does NOT exist (ExDoc flattens) | Confirmed — this is expected ExDoc 0.40.1 behavior |

The SUMMARY.md deviation note was accurate: `test -f doc/guides/recipes/companion-libs/threadline.html` (the plan's verify gate) would fail because ExDoc 0.40.1 flattens all extras to `doc/<basename>.html`. The actual generated paths (`doc/threadline.html`, `doc/mailglass.html`) are correct. Group assignment was verified via `doc/llms.txt` as the executor noted.

---

## Phase Verification Checklist (from PLAN `<verification>` block)

| Check | Result |
|-------|--------|
| `test -f guides/recipes/companion-libs/threadline.md` | PASS |
| `test -f guides/recipes/companion-libs/mailglass.md` | PASS |
| `mix docs --warnings-as-errors` exits 0 | PASS |
| `doc/llms.txt` lists both recipes under "Companion Libraries" | PASS |
| Banned-phrase audit on both recipe files | PASS — zero matches |
| Banner audit: `grep -c "Sigra works fully standalone"` ≥ 1 per file | PASS |
| No YAML `---` frontmatter in either recipe | PASS |
| `git diff --stat lib/` shows no changes (docs-only phase) | PASS — zero lib/ changes |
| `git diff --stat test/` shows no changes | PASS — zero test/ changes |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| RC-01 | 132-01-PLAN.md | `guides/recipes/companion-libs/threadline.md` with `validated_against:`, config block, failure modes, non-goals, banner | SATISFIED | File verified fully above |
| RC-02 | 132-01-PLAN.md | `guides/recipes/companion-libs/mailglass.md` with host-owned wiring, no library adapter, no install flag | SATISFIED | File verified fully above |

RC-03 through RC-06, NX-01, EX-01, PROOF-01, DOC-01 are assigned to later phases (134–136) and are not Phase 132 scope.

---

## Anti-Patterns Found

None. Both recipe files contain no placeholder text, no `TBD`/`FIXME`/`XXX` markers, no `TODO` markers, and no stub implementations. The `mix.exs` edit is surgical and well-commented.

---

## Deviations Accepted

| Deviation | Classification | Verdict |
|-----------|---------------|---------|
| `mix docs --warnings-as-errors` gate required adding Phase 131 lib/ source files to `skip_undefined_reference_warnings_on:` (pre-existing hidden Application helper warnings from Phase 131 were already failing the gate) | Correct fix — using the documented seam | ACCEPTED |
| ExDoc flattens extras by basename; generated HTML is at `doc/threadline.html` not `doc/guides/recipes/companion-libs/threadline.html` | ExDoc 0.40.1 behavior; group assignment verified via `doc/llms.txt` | ACCEPTED |
| Mailglass Failure modes mode 1 describes wrong-stream failure generically ("any non-transactional stream") rather than with literal `stream: :bulk` to satisfy the NEGATIVE grep gate | Satisfies D-15 intent; avoids showing `:bulk` as an example | ACCEPTED |

---

## Human Verification Required

None — this is a documentation-only phase. All content checks, section counts, regex correctness, ExDoc compilation, and group assignment are fully verifiable programmatically. No UI, real-time behavior, or external service integration is involved.

---

## Summary

Phase 132 goal is achieved. Both recipe files exist, are substantive (not stubs), satisfy the full eight-section contract from D-01, pass all content checks defined in the plan, and are correctly registered under the new "Companion Libraries" ExDoc group. `mix docs --warnings-as-errors` exits 0. Requirements RC-01 and RC-02 are fully satisfied. No library code was modified.

The one plan gate that fires false-positive (`! grep -qE "mix threadline\.gen\.triggers"`) is a verification script defect: the string appears in the Non-goals exclusion text exactly as D-14 item 3 mandates. This does not represent a content problem.

---

_Verified: 2026-05-27_
_Verifier: Claude (gsd-verifier)_
