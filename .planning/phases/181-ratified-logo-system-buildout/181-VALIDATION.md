---
phase: 181
slug: ratified-logo-system-buildout
status: active
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-12
---

# Phase 181 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None (brand asset phase) — structural/scripted checks + render harness |
| **Config file** | n/a |
| **Quick run command** | `find brandbook -maxdepth 1 -name '*.svg' \| xargs -n1 xmllint --noout` |
| **Full suite command** | Machine-verifiable check table below |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** `find brandbook -maxdepth 1 -name '*.svg' | xargs -n1 xmllint --noout` (all parse clean)
- **After every plan wave:** Full check table below
- **Before `/gsd:verify-work`:** All checks green
- **Max feedback latency:** 20 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 181-01-1 | 01 | 1 | BRAND2-08 | T-181-01 | No font binaries; correct dark fills | parse+grep | `xmllint --noout brandbook/logo-primary.svg brandbook/logo-primary-dark.svg brandbook/logo-primary-subtitle.svg; grep -c '#c2410c' brandbook/logo-primary-dark.svg` (expected 0); `grep -l 'Space Grotesk' brandbook/{logo-primary,logo-primary-dark,logo-primary-subtitle}.svg \| wc -l` (expected 3) | ❌ W0 | ⬜ pending |
| 181-01-2 | 01 | 1 | BRAND2-08 | T-181-01 | favicon kill test; monochrome single ink | parse+grep+render | `xmllint --noout brandbook/logo-mark.svg brandbook/logo-monochrome.svg brandbook/favicon.svg; grep -c 'prefers-color-scheme' brandbook/favicon.svg` (≥1); `grep -c '#c2410c' brandbook/logo-monochrome.svg` (0) | ❌ W0 | ⬜ pending |
| 181-02-1 | 02 | 2 | BRAND2-08 | T-181-04 | No CDN; dark card no ember-700 in mark | parse+grep+render | `xmllint --noout brandbook/social-card.svg brandbook/social-card-dark.svg; grep -c '#c2410c' brandbook/social-card-dark.svg` (only .strong class); `grep -c '@import\|http' brandbook/social-card.svg` (0) | ❌ W0 | ⬜ pending |
| 181-02-2 | 02 | 2 | BRAND2-08 | T-181-03 T-181-05 | Archive atomicity; no font binaries | ls+grep+git | `ls brandbook/logo-options/archive-v1/*.svg \| wc -l` (6); `grep -c 'Misuse' brandbook/README.md` (≥1); `git ls-files -- '*.ttf' '*.otf' '*.woff' '*.woff2' \| wc -l` (0) | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `brandbook/logo-primary.svg` — v2 D4 typemark (light)
- [ ] `brandbook/logo-primary-dark.svg` — v2 D4 typemark (dark)
- [ ] `brandbook/logo-primary-subtitle.svg` — v2 D4 typemark + subtitle (new file)
- [ ] `brandbook/logo-mark.svg` — v2 D4 abstract rail mark
- [ ] `brandbook/logo-monochrome.svg` — v2 D4 single-ink typemark
- [ ] `brandbook/favicon.svg` — v2 D4 favicon mark
- [ ] `brandbook/social-card.svg` — v2 D4 light OG card
- [ ] `brandbook/social-card-dark.svg` — v2 D4 dark OG card (new file)
- [ ] `brandbook/logo-options/archive-v1/` — directory with 6 v1 SVGs + README

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| favicon 16px kill test | BRAND2-08 | Optical judgment — two distinct elements (stem+foot vs ember block) must be visually separable | Executor reads `/tmp/sigra-plan01-task2-renders/*favicon*-16px*light*.png` — ink stem+foot group and ember block must read as two distinct visual elements; if merged, the render has failed the kill test |
| 54px topbar fit | BRAND2-08 | Optical judgment — wordmark must be legible at admin topbar height | Read `*logo-primary*-54px-topbar*.png` — "sigra" wordmark characters must be distinguishable; no clipping of the rail-tittle at top of frame |
| monochrome rail block legibility | BRAND2-08 | Optical judgment — solid-ink block above i stem must read as spatially distinct | Read `*monochrome*` renders at 54px — rail block (above i) must still read as a separate element from the i glyph even without color contrast; position-based separation is the key |
| social card thumbnail legibility | BRAND2-08 | Optical judgment at 50% scale | Read `*social-card*` renders at 600×315 — D4 mark, "Sigra" wordmark, tagline, and code block must all be readable; dark card must show correct amber accents |

---

## Full Phase Check Suite

Run after all plans complete:

```bash
# 1. All 8 production SVGs exist
ls brandbook/{logo-primary,logo-primary-dark,logo-primary-subtitle,logo-mark,logo-monochrome,favicon,social-card,social-card-dark}.svg

# 2. All brandbook SVGs parse as valid XML
find brandbook -maxdepth 1 -name '*.svg' | xargs -n1 xmllint --noout

# 3. Font provenance in all 6 typemark/mark files
grep -l 'Space Grotesk' brandbook/{logo-primary,logo-primary-dark,logo-primary-subtitle,logo-mark,logo-monochrome,favicon}.svg | wc -l
# Expected: 6

# 4. Dark variants have no ember-700 in fills
grep -c '#c2410c' brandbook/logo-primary-dark.svg
# Expected: 0

# 5. Monochrome is single ink
grep -c '#c2410c' brandbook/logo-monochrome.svg; grep -c '#fdba74' brandbook/logo-monochrome.svg
# Expected: 0, 0

# 6. Favicon and mark have prefers-color-scheme
grep -l 'prefers-color-scheme' brandbook/favicon.svg brandbook/logo-mark.svg | wc -l
# Expected: 2

# 7. v1 archive exists with correct file count
ls brandbook/logo-options/archive-v1/*.svg | wc -l
# Expected: 6

# 8. Archive has deprecation README
test -f brandbook/logo-options/archive-v1/README.md && grep -q 'Do not use' brandbook/logo-options/archive-v1/README.md && echo PASS

# 9. README usage rules present
grep -c 'Misuse\|clearspace\|Clearspace\|Minimum' brandbook/README.md
# Expected: ≥3 (covers Clearspace, Minimum, Misuse Examples headings)

# 10. No font binaries committed
git ls-files -- '*.ttf' '*.otf' '*.woff' '*.woff2' | wc -l
# Expected: 0

# 11. No SVG exceeds 250KB
find brandbook -maxdepth 1 -name '*.svg' -size +250k -print
# Expected: empty (no output)

# 12. index.html referenced SVGs all resolve to v2 content
for f in favicon.svg logo-primary-dark.svg logo-primary.svg logo-mark.svg; do
  test -f "brandbook/$f" && echo "OK: $f" || echo "MISSING: $f"
done
```

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (all 8 production SVGs + archive dir)
- [x] No watch-mode flags
- [x] Feedback latency < 20s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
