---
phase: 183
slug: propagation-parity-verification
status: active
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-13
---

# Phase 183 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (root suite + example suite) + scripted shell checks + Playwright baseline gate |
| **Config file** | `test/test_helper.exs` (root), `test/example/test/test_helper.exs` (example) |
| **Quick run command** | `mix test test/sigra/install/features/admin_test.exs` (root installer test); `(cd test/example && mix test test/example_web/admin_shell_test.exs)` (example test) |
| **Full suite command** | `mix test && (cd test/example && mix test)` |
| **Estimated runtime** | ~10–15 seconds (quick); ~5–8 min (full suite including example); ~8–12 min (full + Playwright gate) |

---

## Sampling Rate

- **After every task commit:** `xmllint --noout priv/templates/sigra.install/admin/sigra-logo-primary{,-dark}.svg test/example/priv/static/images/sigra-logo-primary{,-dark}.svg test/example/priv/static/images/rail-accent-mark{,-dark}.svg` (all parse clean) + `cmp priv/templates/sigra.install/admin/sigra-logo-primary.svg test/example/priv/static/images/sigra-logo-primary.svg` (byte-identical)
- **After Plan 01 (Wave 1):** `mix test && (cd test/example && mix test)` — both suites must be green before Plan 02 starts
- **After Plan 02 (Wave 2):** Full check suite below (parseability + binary check + allowlist empty + both suites + git clean)
- **Before `/gsd:verify-work`:** All checks green; `scripts/ci/snapshot-recapture-gate.sh` exits 0 already confirmed in Plan 02 Task 1
- **Max feedback latency:** 15 seconds (quick); 480 seconds (full suite + Playwright gate)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 183-01-1 | 01 | 1 | BRAND2-11 | T-183-01 | All 4 admin lockup SVGs: viewBox="20 220 2361 1000", Space Grotesk v2.0 in desc, path-only, no text/font-family; installer == example byte-identical | grep+cmp+xmllint | `for f in priv/templates/sigra.install/admin/sigra-logo-primary{,-dark}.svg test/example/priv/static/images/sigra-logo-primary{,-dark}.svg; do grep -q 'viewBox="20 220 2361 1000"' "$f" && grep -q 'Space Grotesk v2.0' "$f"; done && cmp priv/templates/sigra.install/admin/sigra-logo-primary.svg test/example/priv/static/images/sigra-logo-primary.svg && cmp priv/templates/sigra.install/admin/sigra-logo-primary-dark.svg test/example/priv/static/images/sigra-logo-primary-dark.svg && echo "OK: lockups verified"` | ✅ (files replaced) | ⬜ pending |
| 183-01-2 | 01 | 1 | BRAND2-11 | T-183-01 | Companion marks: D4 geometry, explicit fills (light: #151515/#c2410c; dark: #f4f1eb/#fdba74), no CSS media query | grep+xmllint | `grep -q 'fill="#151515"' test/example/priv/static/images/rail-accent-mark.svg && grep -q 'fill="#c2410c"' test/example/priv/static/images/rail-accent-mark.svg && grep -q 'fill="#f4f1eb"' test/example/priv/static/images/rail-accent-mark-dark.svg && grep -q 'fill="#fdba74"' test/example/priv/static/images/rail-accent-mark-dark.svg && grep -qv '@media' test/example/priv/static/images/rail-accent-mark.svg && echo "OK: companion marks"` | ✅ (files replaced) | ⬜ pending |
| 183-01-3 | 01 | 1 | BRAND2-11, BRAND2-12 | T-183-01 | Guard tests assert D4 viewBox+provenance; token parity greps all OK (verify-unchanged); mix test (root) exits 0; example mix test exits 0 | ExUnit + grep | `mix test test/sigra/install/features/admin_test.exs && (cd test/example && mix test test/example_web/admin_shell_test.exs) && echo "OK: tests green"` | ✅ | ⬜ pending |
| 183-02-1 | 02 | 2 | BRAND2-13 | T-183-04 | 21 non-canary baseline PNGs recaptured; 3 impersonation-banner PNGs unchanged; gate exits 0; allowlist empty | Playwright + snapshot-recapture-gate.sh | `scripts/ci/snapshot-recapture-gate.sh audit-explorer global-overview global-user-index org-overview org-scoped-admin user-audit user-detail && grep -v '^#' test/example/priv/playwright/snapshot-allowlist \| grep -v '^$' \| wc -l \| grep -q '^0$' && echo "OK: gate passed + allowlist empty"` | ✅ scripts exist | ⬜ pending |
| 183-02-2 | 02 | 2 | BRAND2-14 | T-183-03 | All SVGs parse; no stray binaries; both mix test suites green; git clean | xmllint + git + ExUnit | `xmllint --noout priv/templates/sigra.install/admin/sigra-logo-primary{,-dark}.svg test/example/priv/static/images/sigra-logo-primary{,-dark}.svg test/example/priv/static/images/rail-accent-mark{,-dark}.svg && mix test && (cd test/example && mix test) && echo "OK: hygiene sweep"` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No new test files needed.

- All relevant ExUnit tests already exist and are being updated in-place (test assertion string changes only)
- Playwright scripts and gate infrastructure exist in `scripts/ci/`
- No new framework installs required

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| D4 logo renders correctly in the 54px admin topbar at all 3 Playwright projects | BRAND2-13 | Visual judgment that the recaptured baselines actually show the D4 mark (not stale v1 staggered-bars mark or whitespace artifact) | After `--update-snapshots=all`, briefly open one recaptured PNG (e.g., `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-overview-admin-checkpoints-chromium.png`) and confirm the topbar logo shows the Space Grotesk "sigra" wordmark with ember rail block — not the old three-stroke staggered bars. |
| g-tail descender not clipped in the 54px topbar render | BRAND2-11 | Optical check: the D4 'g' has an extended tail descender unique to D4; a wrong viewBox could clip it | At 54px height the rendered lockup should show the 'g' descender extending visually below the other glyphs. If it appears clipped, the viewBox bottom may be too shallow — re-check that viewBox height 1000 puts the bottom at y=1220 (220+1000), which clears the g-tail at y=1200 by 20 units. |

---

## Full Phase Check Suite

Run after all plans complete:

```bash
# 1. All 4 admin lockup SVGs: D4 viewBox + provenance + path-only
for f in priv/templates/sigra.install/admin/sigra-logo-primary{,-dark}.svg \
          test/example/priv/static/images/sigra-logo-primary{,-dark}.svg; do
  grep -q 'viewBox="20 220 2361 1000"' "$f" && echo "OK viewBox: $f" || echo "FAIL: $f"
  grep -q 'Space Grotesk v2.0' "$f" && echo "OK provenance: $f" || echo "FAIL: $f"
  grep -q '<path' "$f" && echo "OK has-path: $f" || echo "FAIL no-path: $f"
  grep -q '<text' "$f" && echo "FAIL has-text: $f" || echo "OK no-text: $f"
  grep -q 'font-family' "$f" && echo "FAIL font-family: $f" || echo "OK no-font-family: $f"
done

# 2. Byte-identity: installer == example (both light and dark)
cmp priv/templates/sigra.install/admin/sigra-logo-primary.svg \
    test/example/priv/static/images/sigra-logo-primary.svg && echo "OK: light byte-identical"
cmp priv/templates/sigra.install/admin/sigra-logo-primary-dark.svg \
    test/example/priv/static/images/sigra-logo-primary-dark.svg && echo "OK: dark byte-identical"

# 3. Companion marks: correct fills, no CSS, correct viewBox
grep -q 'fill="#151515"' test/example/priv/static/images/rail-accent-mark.svg && echo "OK: light glyphs fill"
grep -q 'fill="#c2410c"' test/example/priv/static/images/rail-accent-mark.svg && echo "OK: light rail-block fill"
grep -q 'viewBox="-70 -60 1040 1040"' test/example/priv/static/images/rail-accent-mark.svg && echo "OK: light viewBox"
grep -q '@media\|prefers-color-scheme' test/example/priv/static/images/rail-accent-mark.svg && echo "FAIL: CSS in light mark" || echo "OK: no CSS in light"
grep -q 'fill="#f4f1eb"' test/example/priv/static/images/rail-accent-mark-dark.svg && echo "OK: dark glyphs fill"
grep -q 'fill="#fdba74"' test/example/priv/static/images/rail-accent-mark-dark.svg && echo "OK: dark rail-block fill"
grep -q '@media\|prefers-color-scheme' test/example/priv/static/images/rail-accent-mark-dark.svg && echo "FAIL: CSS in dark mark" || echo "OK: no CSS in dark"

# 4. Token parity — verify-unchanged (4 greps, palette held in Phase 181/182)
grep '"ember-700"' brandbook/tokens.json | grep -q '#c2410c' && echo "OK: brandbook ember-700=#c2410c" || echo "FAIL"
grep 'sg-color-brand:' test/example/priv/static/assets/css/app.css | grep -q '#c2410c' && echo "OK: sg-color-brand=#c2410c" || echo "FAIL"
grep 'sg-logo-rail-accent:' test/example/priv/static/assets/css/app.css | grep -q '#fdba74' && echo "OK: sg-logo-rail-accent=#fdba74" || echo "FAIL"
grep 'sigra-auth-light-accent' priv/templates/sigra.install/core/sigra_auth.css | grep -q '#c2410c' && echo "OK: auth accent=#c2410c" || echo "FAIL"

# 5. Guard test assertions are D4 (not v1)
grep -q 'viewBox="20 220 2361 1000"' test/example/test/example_web/admin_shell_test.exs && echo "OK: example test viewBox D4"
grep -q 'Space Grotesk v2.0' test/example/test/example_web/admin_shell_test.exs && echo "OK: example test provenance D4"
grep -q 'viewBox="20 12 188 54"' test/example/test/example_web/admin_shell_test.exs && echo "FAIL: v1 viewBox still in example test" || echo "OK: v1 viewBox removed"
grep -q 'viewBox="20 220 2361 1000"' test/sigra/install/features/admin_test.exs && echo "OK: installer test viewBox D4"
grep -q 'Space Grotesk v2.0' test/sigra/install/features/admin_test.exs && echo "OK: installer test provenance D4"
grep -q 'viewBox="20 12 188 54"' test/sigra/install/features/admin_test.exs && echo "FAIL: v1 viewBox still in installer test" || echo "OK: v1 viewBox removed"

# 6. SVG parseability (all 6 files)
xmllint --noout \
  priv/templates/sigra.install/admin/sigra-logo-primary{,-dark}.svg \
  test/example/priv/static/images/sigra-logo-primary{,-dark}.svg \
  test/example/priv/static/images/rail-accent-mark{,-dark}.svg
echo "Exit code: $?"  # expected: 0

# 7. Snapshot allowlist empty (steady state)
ACTIVE=$(grep -v '^#' test/example/priv/playwright/snapshot-allowlist | grep -v '^$' | wc -l)
[ "$ACTIVE" -eq 0 ] && echo "OK: allowlist empty" || echo "FAIL: allowlist has $ACTIVE active slugs"

# 8. Canary PNGs unchanged
git diff --name-only test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/ | grep 'impersonation-banner' | wc -l
# Expected: 0

# 9. Non-canary baseline PNGs changed
git diff --name-only test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/ | grep -v 'impersonation-banner' | wc -l
# Expected: 21

# 10. No stray binary files outside baseline dir
STRAY=$(git diff --name-only --diff-filter=A HEAD \
  -- ':!test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/*.png' \
  | xargs -I{} file {} 2>/dev/null | grep -i 'binary\|executable' | grep -v 'SVG\|text' | wc -l)
[ "$STRAY" -eq 0 ] && echo "OK: no stray binaries" || echo "FAIL: $STRAY stray binary files"

# 11. Both test suites green
mix test && echo "OK: root mix test"
(cd test/example && mix test) && echo "OK: example mix test"

# 12. Git status clean (non-PNG files)
DIRTY=$(git status --short | grep -v '\.png' | wc -l)
[ "$DIRTY" -eq 0 ] && echo "OK: git clean" || echo "FAIL: $DIRTY uncommitted non-PNG files"
```

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify commands — no MISSING references
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0: existing infrastructure covers all phase requirements (no new test files needed)
- [x] No watch-mode flags
- [x] Feedback latency: quick run ~15s, full suite ~8min — both within acceptable bounds
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
