---
created: 2026-09-15
source: v1.47 CI-EFFICIENCY milestone audit (re-audit at close)
severity: medium
requirements: [GATE-05]
audit_acknowledged: v1.47
---

# GATE-05 ownership ledger: Playwright-scoped, missing 230/234, contradicts the skip manifest

`235-TERMINAL-RATIFICATION.json` `ownership.rows` = 93 rows = 31 constructs x 3 events.
GATE-05 promises "which specs run on PR vs main vs nightly before and after this
milestone". Three shortfalls:

1. **No Phase 230 or 234 rows.** `jq '.ownership.rows[].phase' | sort | uniq -c` yields
   12x`231`, 69x`232`, 12x`233`. Phase 230 made the milestone's two headline demotions
   (`admin_eval_render` off PR, `design_gallery_snapshots` off PR) plus the tier-C
   docs-only demotion in four ruleset-required lanes — none attributed to 230.

2. **Playwright-scoped only.** `ownership.source_inventory.path` is
   `234-PLAYWRIGHT-INVENTORY.json`, so `after.direct_owner` spans just 7 jobs. Absent
   entirely: `example_unit_smoke`, `install_smoke`, `example_http_smoke`,
   `install_golden_contract`, `fast_checks`, `install_matrix`, `upgrade_smoke`,
   `passkeys_manual_fallback_smoke`, `passkeys_opt_out_smoke`, `nightly_probe`,
   `admin_checkpoint_recapture`.

3. **Contradicts the skip manifest on the same demotion.** Ledger row
   `family=design_gallery_snapshots` gives `after.direct_owner = admin_design_recapture`
   on push/schedule. But `ci.yml:1298` puts the non-PR `--grep '@snapshot'` assertions in
   `example_playwright_shard`, and `.github/ci-skip-manifest.tsv` tier-B records exactly
   that. Two "authoritative" inventories name different receivers for one construct, and
   `admin_design_recapture` is a recapture utility that opens a PR for human review — not
   an assertion lane.

Reconcile the ledger receiver with the manifest, and widen the source inventory beyond
Playwright before citing GATE-05 as full lane-universe ownership.
