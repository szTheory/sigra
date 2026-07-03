# Admin Eval Schema

Contract documentation for the Sigra admin evaluation harness ledgers.
This document governs `admin-award-ledger.json`, `admin-render-sha.json`,
`settled-findings.tsv`, and their consumers in `scripts/ci/`.

---

## finding_id Key Contract

The `finding_id` is a deterministic, content-addressed key computed as:

```
finding_id = sha256(surface + "\0" + class + "\0" + anchor)
```

**Byte-level specification:**
- `surface` — the ledger cell key string (e.g. `users-index-live`)
- `"\0"` — a single NUL byte (0x00) separator between fields
- `class` — the probe class string (e.g. `off-token-spacing`, `target-size`, `focus-ring`)
- `"\0"` — a single NUL byte separator
- `anchor` — a structural CSS selector or `data-*` hook that identifies the specific DOM element
  the finding refers to (e.g. `[data-testid="admin-users-desktop-results"] .sg-applied-chip`)
- The SHA-256 digest is **lowercase hex** (64 characters)

**Implementation (Node.js):**
```javascript
import { createHash } from 'node:crypto';

function findingId(surface, probeClass, anchor) {
  return createHash('sha256')
    .update(surface + '\0' + probeClass + '\0' + anchor)
    .digest('hex');
}
```

### Cross-Phase Contract: Phase 217 AUTOFIX-01 — UNRESOLVED SEAM

**IMPORTANT:** This `finding_id = sha256(surface + "\0" + class + "\0" + anchor)` key is the
**deterministic substrate key that Phase 217 AUTOFIX-01's fix-queue key MUST match**.

Phase 217's requirement text uses the phrasing `hash of surface + lens + question + anchor`.
The 216 substrate uses `class` (probes have a class), while Phase 217's language says
`lens + question`. This is an **unresolved cross-phase contract seam** — it is intentionally
NOT silently resolved here per D-22 (plan both together).

**Recommended reconciliation path for 217 planning:**
- Map 217's `lens+question` into the same `class` slot when constructing `finding_id`
  (e.g. `class = lens + ":" + question` as a namespaced string), OR
- Use an identical key formula in 217's fix-queue schema so the SHA is byte-identical

**This seam must be jointly resolved before Phase 217 implements its fix-queue.**
Do not finalize 217's TSV/queue schema without confirming key compatibility with this formula.

---

## Ledger Files and Their Authoritative Role

| File | Authoritative For | Read By |
|------|------------------|---------|
| `guides/reference/admin-award-ledger.json` | Award vector (4-axis scores, band, render verification) | `scripts/ci/award-guard.mjs` (Plan 05) |
| `guides/reference/admin-render-sha.json` | `render_sha256` per (surface×cell) + `open_findings` counts | `scripts/ci/stale-render-guard.sh`, `scripts/ci/quality-findings-monotonic.sh` |
| `guides/reference/settled-findings.tsv` | Suppression set (waived/resolved findings) | `scripts/ci/settled-findings-lint.sh` (Plan 04), Phase 217 AUTOFIX-01 fix-queue |

Each guard reads ONE authoritative source. Do not duplicate open-finding counts between files.

---

## Award Band Semantics (A0..A3)

The award sub-score is an ordinal band **above Tier-2** (Tier-2 = entry gate to A0).
The ladder is monotone end-to-end: `Tier 0 → 1 → 2 → A0 → A1 → A2 → A3`.

Bands are **additive** — a surface cannot hold A2 without satisfying all A1 criteria:

| Band | Name | Criteria |
|------|------|----------|
| A0 | Nominated | Tier-2 + every applicable probe has a *rendered* evidence key |
| A1 | Shortlisted | A0 + the 3 manual proxies (motion/whitespace-rhythm/target-size) converted to rendered probes |
| A2 | Commended | A1 + adversarial states (zero/loading/error) rendered & axe-clean, content-equivalence proven |
| A3 | Award-grade | A2 + persona-JTBD panel `clean` + cross-viewport/theme render parity |

**Pilots cap at A2** — A3 requires the persona-JTBD panel to be re-run at current HEAD (D-25).
That panel is a Phase 209 artifact; re-running it is out of scope for Phase 216.

### band = min(axes) Rule

The `band` field is **derived** from the 4-axis vector, never hand-typed:

```
band = min(token_fidelity, rhythm, a11y_polish, states)  [using ordinal A0=0, A1=1, A2=2, A3=3]
```

The band equals the weakest axis. A surface cannot "buy" a higher band by maxing one cheap axis.
This mirrors the persona rubric's existing worst-verdict floor rule.

**The award guard (`scripts/ci/award-guard.mjs`) recomputes `min(axes)` and fails CI if
`band != min(axes)`** — the JSON value is a cache/convenience field only.

### Open Finding Count Rule

```
Open = total findings (for surface×cell) − settled findings (matching surface + class + anchor)
```

Open counts are computed by the harness from `admin-render-sha.json` (one authoritative source).
They are **never hand-maintained** — hand-maintaining open counts introduces drift.

---

## Anchor Identity Rule

A finding's `anchor` field MUST be a **structural CSS selector or `data-*` hook**. It MUST NOT
be:
- Prose text (e.g. "the Save button label")
- A line number
- A human-readable description

**Rationale:** Structural selectors survive copy edits (the Betterer merge-conflict lesson).
Prose anchors silently become stale when text changes; the evidence-anchor check
(`scripts/ci/evidence-anchor-check.mjs`) validates each anchor against the captured
outerHTML — a prose "anchor" cannot be selected via cheerio `$()`.

**Good anchors:**
- `[data-testid="admin-users-desktop-results"] .sg-applied-chip`
- `.sg-btn--danger`
- `[data-sg-confirm-dialog]`

**Bad anchors:**
- `"Save" button`
- `users-index-live.ex:147`
- `The remove chip next to the filter`

---

## settled-findings.tsv Column Specification

The TSV has a leading `#`-comment header and is sorted by `finding_id` (lexicographic ascending).
Zero data rows is correct at phase start — no findings are settled yet.

| Column | Type | Description |
|--------|------|-------------|
| `finding_id` | hex string | `sha256(surface\0class\0anchor)` — lowercase hex, 64 chars |
| `surface` | string | Ledger cell key (e.g. `users-index-live`) |
| `class` | string | Probe class (e.g. `off-token-spacing`, `target-size`) |
| `anchor` | string | Structural CSS selector / `data-*` hook |
| `disposition` | enum | `waived` or `resolved` |
| `waived_by` | string | Identifier of person who waived (for `waived`); empty for `resolved` |
| `note` | string | Rationale for the disposition |

**Invariants enforced by `scripts/ci/settled-findings-lint.sh` (Plan 04):**
- File must be sorted by `finding_id` (column 1)
- No duplicate `finding_id` values
- All rows must have exactly 7 tab-separated columns
- A stale entry (anchor no longer present in any current bundle) is flagged as a non-blocking warning

**Regen helper** — humans must never hand-edit ordering; use the regen helper to add entries:
```
# Conceptual interface (actual script in Plan 04):
scripts/ci/settled-findings-add.sh --surface users-index-live \
  --class off-token-spacing \
  --anchor '[data-testid="admin-users-desktop-results"] .sg-applied-chip' \
  --disposition waived --waived-by jon --note "dense admin inline chip — D-08 precedent"
```

---

## admin-award-ledger.json Schema

```jsonc
{
  "schema_version": 1,         // integer; bump if shape changes
  "notes": "...",              // free-text pointer to this document
  "cells": {
    "<surface-key>": {
      "axes": {
        "token_fidelity": "A0",  // ordinal: A0 | A1 | A2 | A3
        "rhythm":         "A0",
        "a11y_polish":    "A0",
        "states":         "A0"
      },
      "band":             "A0",  // DERIVED = min(axes); recomputed and verified by award-guard
      "verified_at_sha":  null,  // app_git_sha of the render that earned this band; null = unverified
      "rendered":         false, // false = no render verification; true = verified against a render
      "evidence_ref":     []     // list of probe IDs / test IDs / conformance selectors resolving the claim
    }
  }
}
```

**Award guard FAIL conditions (each covered by the guard's self-test):**
1. An axis band rose but `verified_at_sha` did not change — climb without fresh render.
2. `band != min(axes)` — inconsistent derived value.
3. Any raised axis has `rendered: false` OR an `evidence_ref` that does not resolve.
4. Any axis band decreased vs merge-base — regression.
5. No-change run — PASS. Legitimate climb (fresh `verified_at_sha` + resolving evidence) — PASS.

---

## admin-render-sha.json Schema

```jsonc
{
  "schema_version": 1,
  "notes": "...",
  "cells": {
    "<surface-key>": {
      "<theme>-<viewport>-<state>": {
        "render_sha256": null,   // sha256 of canonicalized DOM; null = not yet captured
        "open_findings": 0       // open finding count for this cell (total - settled)
      }
    }
  }
}
```

Cell key format: `<theme>-<viewport>-<state>` where:
- `theme` ∈ `{light, dark}`
- `viewport` ∈ `{desktop, mobile}`
- `state` ∈ `{populated, zero, loading, error}`

Example: `"light-desktop-populated"`, `"dark-mobile-error"`

The render-sha and open-finding counts are consolidated in this single file (not split into
separate files) so `quality-findings-monotonic.sh` has ONE authoritative source to diff
against the merge-base — no sync-drift between two files.
