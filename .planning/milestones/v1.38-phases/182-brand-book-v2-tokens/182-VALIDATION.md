---
phase: 182
slug: brand-book-v2-tokens
status: active
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-12
---

# Phase 182 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None (brand asset phase) — scripted shell checks + axe harness |
| **Config file** | n/a |
| **Quick run command** | `find brandbook -maxdepth 1 -name '*.svg' \| xargs -n1 xmllint --noout && xmllint --noout brandbook/index.html` |
| **Full suite command** | Machine-verifiable check suite below |
| **Estimated runtime** | ~30 seconds (including axe harness ~10s) |

---

## Sampling Rate

- **After every task commit:** `find brandbook -maxdepth 1 -name '*.svg' | xargs -n1 xmllint --noout && xmllint --noout brandbook/index.html` (all parse clean)
- **After every plan wave:** Full check suite below
- **Before `/gsd:verify-work`:** All checks green + `node scripts/brand/axe-brandbook.mjs` exits 0
- **Max feedback latency:** 35 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 182-01-1 | 01 | 1 | BRAND2-10 | T-182-01 | tokens.json: version=1.0.1, meta.changed set; tokens.css: provenance header references v1.0.1 | jq+grep | `jq -r '.version' brandbook/tokens.json` (expected 1.0.1); `jq -r '.meta.changed' brandbook/tokens.json` (expected ISO date); `head -3 brandbook/tokens.css \| grep -c 'tokens.json'` (expected 1) | ✅ | ⬜ pending |
| 182-01-2 | 01 | 1 | BRAND2-10 | T-182-01 | README.md: no "Rail Accent" in Files table logo rows; two new rows added; Token Change Policy section present | grep | `grep -c 'Token Change Policy' brandbook/README.md` (expected 1); `grep -c 'logo-primary-subtitle' brandbook/README.md` (expected ≥1); `grep -c 'social-card-dark' brandbook/README.md` (expected ≥1) | ✅ | ⬜ pending |
| 182-01-3 | 01 | 1 | BRAND2-09 | T-182-01 | brand-book.md: Inter Display Black gone; Space Grotesk present; suite architecture section added | grep | `grep -c 'Space Grotesk' brandbook/brand-book.md` (expected ≥1); `grep -c 'Inter Display Black' brandbook/brand-book.md` (expected 0); `grep -c 'Suite Architecture\|suite architecture' brandbook/brand-book.md` (expected ≥1) | ✅ | ⬜ pending |
| 182-01-4 | 01 | 1 | BRAND2-09 | T-182-02 | Stale specimens: M17 14v14 path removed from both files; D4 geometry present; valid XML | grep+xmllint | `grep -c 'M17 14v14' brandbook/examples/landing-hero.svg` (expected 0); `grep -c 'M17 14v14' brandbook/examples/readme-header.svg` (expected 0); `xmllint --noout brandbook/examples/landing-hero.svg brandbook/examples/readme-header.svg` (exits 0) | ✅ | ⬜ pending |
| 182-02-1 | 02 | 2 | BRAND2-09 | T-182-04 | index.html v2: #scorecard id added; #suite section present; #logo expanded with all 8 D4 assets; no external deps; only tokens.css <link> | grep+xmllint | `grep -c 'id="scorecard"' brandbook/index.html` (1); `grep -c 'id="suite"' brandbook/index.html` (1); `grep -c 'logo-primary-subtitle' brandbook/index.html` (≥1); `grep -cE 'http[s]?://\|cdn\.\|@import' brandbook/index.html` (0); `grep -c '<link' brandbook/index.html` (1); `xmllint --noout brandbook/index.html` (exits 0) | ✅ | ⬜ pending |
| 182-02-2 | 02 | 2 | BRAND2-09 | T-182-03 T-182-05 | axe-brandbook.mjs: exits 0; uses createRequire; loads from test/example; no screenshot calls; axe gate: zero wcag2a/wcag2aa violations on brandbook/index.html | axe harness | `node scripts/brand/axe-brandbook.mjs` (exits 0); `grep -c 'createRequire' scripts/brand/axe-brandbook.mjs` (1); `grep -c 'screenshot' scripts/brand/axe-brandbook.mjs` (0) | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/brand/axe-brandbook.mjs` — axe harness script (Plan 02 Task 2: must exist before `node scripts/brand/axe-brandbook.mjs` can run). Created in Plan 02 as a Wave 2 task — the script IS the Wave 0 item for the final axe assertion.

All other files exist and are being edited in-place (tokens.json, tokens.css, README.md, brand-book.md, index.html, examples/*.svg). No other Wave 0 gaps.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| index.html v2 visual coherence — expanded #logo section layout legible at desktop and mobile widths | BRAND2-09 | Optical judgment: grid layout reflow, logo-strip proportions, no clipping of wide lockups | Open `brandbook/index.html` directly in a browser; resize viewport to mobile (~375px). Verify: all 8 logo specimens visible (no overflow clipping); typemark anatomy and clearspace text readable; #suite section table scrolls on narrow viewports. |
| axe-brandbook.mjs output on a fresh run (no cached violations) | BRAND2-09 | Confirms script runs to completion in CI-like conditions | Run `node scripts/brand/axe-brandbook.mjs` in a clean shell session (no prior browser instance open on port 7743); observe "axe: PASS" in stdout. |

---

## Full Phase Check Suite

Run after all plans complete:

```bash
# 1. axe: zero violations on index.html (primary gate)
node scripts/brand/axe-brandbook.mjs

# 2. No external dependencies in index.html (expected: 0)
grep -cE 'http[s]?://|cdn\.|@import|<script[[:space:]]+src' brandbook/index.html

# 3. Only one <link> tag and it's tokens.css (expected: 1, 1)
grep -c '<link' brandbook/index.html
grep -c 'tokens.css' brandbook/index.html

# 4. All brandbook HTML/SVG parse valid
xmllint --noout brandbook/index.html
find brandbook -maxdepth 1 -name '*.svg' | xargs -n1 xmllint --noout

# 5. Stale v1 mark paths removed from specimens (expected: 0, 0)
grep -c 'M17 14v14' brandbook/examples/landing-hero.svg
grep -c 'M17 14v14' brandbook/examples/readme-header.svg

# 6. tokens.json version bumped to 1.0.1 (expected: 1.0.1)
jq -r '.version' brandbook/tokens.json

# 7. tokens.json meta.changed is set (expected: ISO date, not null)
jq -r '.meta.changed' brandbook/tokens.json

# 8. tokens.css provenance header present (expected: 1)
head -3 brandbook/tokens.css | grep -c 'tokens.json'

# 9. README.md Token Change Policy section added (expected: 1)
grep -c 'Token Change Policy' brandbook/README.md

# 10. README Files table no longer has "Rail Accent" in logo file rows
# (check within the table rows only — archive paths may legitimately reference it)
grep -A 25 '| File' brandbook/README.md | grep -c 'Rail Accent'

# 11. brand-book.md: Space Grotesk present, Inter Display Black gone
grep -c 'Space Grotesk' brandbook/brand-book.md      # expected: ≥1
grep -c 'Inter Display Black' brandbook/brand-book.md # expected: 0

# 12. index.html v2 sections present
grep -c 'id="scorecard"' brandbook/index.html   # expected: 1
grep -c 'id="suite"' brandbook/index.html       # expected: 1

# 13. index.html references all 8 D4 assets
grep -c 'logo-primary-subtitle' brandbook/index.html  # expected: ≥1
grep -c 'social-card-dark' brandbook/index.html       # expected: ≥1

# 14. No font binaries committed (expected: 0)
git ls-files -- '*.ttf' '*.otf' '*.woff' '*.woff2' | wc -l

# 15. No SVG in brandbook root exceeds 250KB (expected: empty output)
find brandbook -maxdepth 1 -name '*.svg' -size +250k -print

# 16. axe script exists, uses createRequire, no screenshots
test -f scripts/brand/axe-brandbook.mjs && echo PASS
grep -c 'createRequire' scripts/brand/axe-brandbook.mjs   # expected: 1
grep -c 'screenshot' scripts/brand/axe-brandbook.mjs       # expected: 0
```

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (axe-brandbook.mjs is the only missing file; created in Plan 02 Task 2 before the axe assertion)
- [x] No watch-mode flags
- [x] Feedback latency < 35s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
