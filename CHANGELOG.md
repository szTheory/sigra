# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Planning milestones vs Hex releases

This changelog uses **[Semantic Versioning](https://semver.org/spec/v2.0.0.html)** headings like **`[0.3.0]`** for **installable Hex releases**. Separately, maintainers track **planning milestones** labeled **v1.x** in **`.planning/`** and archived milestone docs — those labels describe shipped tranches of work, **not** a second installable version axis on Hex. When in doubt, treat this changelog's SemVer headings and live Hex package metadata as the installable version truth; treat planning milestones as project-management traceability.

## Unreleased

<!--
MAINTAINER WARNING — Release Please inserts each generated version section BELOW this
block, never into it. Anything written here must be folded by hand into the new version
section while the Release PR is still open. If it is not, these notes ship inside a
released package that still carries the "Unreleased" heading — and CHANGELOG.md is
packaged into the Hex tarball, so the mistake is permanent for that release.
-->

_Nothing yet._

## [1.4.0](https://github.com/szTheory/sigra/compare/v1.3.0...v1.4.0) (2026-07-28)

### Added

- Admin-enabled installs now generate a host-owned persisted platform-admin grant, explicit `mix sigra.admin.grant|revoke|list|check` lifecycle tasks, and an allow/deny policy test. Grants require an existing confirmed active account and mutation audit rows share the database transaction.
- Generated-host Playwright coverage now proves auth action hierarchy, Light/Dark/System behavior, reduced motion, 320px/200% text reflow, audit URL presets/applied state, and revoke-to-deny behavior.

### Changed

- Clean generated auth templates use the bounded semantic `sigra-auth-*` vocabulary and explicit action hierarchy across entry, recovery, settings, MFA, passkeys, sessions, and invitation states. Scoped utility/Daisy-shaped selectors remain as an older-template compatibility bridge.
- Both admin audit explorers use URL presets instead of duplicate checkbox/form keys and show a labeled active-filter region immediately after the form.
- Generated sensitive account operations propagate the current scope and return a typed denial during impersonation.

### Upgrade notes

- Existing generated files remain host-owned and are never overwritten automatically. See [Upgrading generated hosts for v1.46 adopter experience](guides/introduction/upgrading-to-v1.46.md) for the additive grant migration, one-line customized-policy delegation, UI comparison workflow, and rollback path.


### Features

* **221-01:** pass scope to Auth.rename_passkey in installer template ([0e34dcf](https://github.com/szTheory/sigra/commit/0e34dcf3814ebcf711b5805cb941dc480eda46ba))
* **221-03:** pin upgrade_smoke start version to 1.3.0 ([f507992](https://github.com/szTheory/sigra/commit/f507992ccd23f80e4ec57474c74f25733b434999))


### Bug Fixes

* **221-01:** complete SHIP-01 — add scope-aware rename_passkey/4 to generated context ([f94277c](https://github.com/szTheory/sigra/commit/f94277c0bce7b9c624463619ffb5256e196a2eea))
* **221-01:** dedupe delete-passkey confirmation body copy ([bae6b90](https://github.com/szTheory/sigra/commit/bae6b906a7d8ff101ce52c71a08f42fdaff126ff))
* **221-01:** gate impersonation helpers on passkeys? + fix stale foundation assertion ([a88cd66](https://github.com/szTheory/sigra/commit/a88cd66ef3c21e2bb5b71f344a7d6b399cddf8c5))
* **221-02:** reset last_was_prop on complete single-line declarations ([0cbb62b](https://github.com/szTheory/sigra/commit/0cbb62b7c20f722acd8e6019d33eb3f3349082a9))
* **221-02:** widen up.sh --help window to 2,26p for --print-env headroom ([c039f89](https://github.com/szTheory/sigra/commit/c039f8908e952954078f00132dc614f1e2b89d42))
* **auth-ui:** disambiguate duplicate "Email" label on generated login page ([#113](https://github.com/szTheory/sigra/issues/113)) ([743864c](https://github.com/szTheory/sigra/commit/743864c0b92da5d7a239014be08799b9d3af06de))

## [1.3.0](https://github.com/szTheory/sigra/compare/v1.2.0...v1.3.0) (2026-07-10)


### Features

* **216-01:** install parse5 ^8.0.1 + cheerio ^1.2.0 as playwright devDependencies ([25553f4](https://github.com/szTheory/sigra/commit/25553f4c201fb2056672b15f3e4eaeea731c700f))
* **216-02:** add award-ledger and render-sha JSON skeleton for two pilot surfaces ([a02435f](https://github.com/szTheory/sigra/commit/a02435f9ffb5ebeaf175e4585256fedb178e73e5))
* **216-02:** add settled-findings.tsv and admin-eval-schema.md with finding_id contract ([72bb8a5](https://github.com/szTheory/sigra/commit/72bb8a562149cb1a9b16f059b582260714231eb3))
* **216-03:** implement bundle.ts — per-surface×cell evidence bundle writer ([e38c4e3](https://github.com/szTheory/sigra/commit/e38c4e38a2f1bbe9cd7440eb09d3f44890594f39))
* **216-03:** implement canonicalize.ts — parse5 allowlist walker → render_sha256 ([5d8d20e](https://github.com/szTheory/sigra/commit/5d8d20ee8743394691024dfc362bb989259bf946))
* **216-04:** evidence-anchor-check.mjs guard + node self-test (D-09, cite-and-flip) ([8b6d4d0](https://github.com/szTheory/sigra/commit/8b6d4d0f02a834251fcc3162da85c464fdf73d30))
* **216-04:** quality-findings-monotonic.sh guard + hermetic self-test (D-21) ([84b31a8](https://github.com/szTheory/sigra/commit/84b31a868f9f85fcf2f4c649853c63272169009b))
* **216-04:** settled-findings-lint.sh guard + regen helper + hermetic self-test (D-22) ([9623514](https://github.com/szTheory/sigra/commit/9623514d37c68e10fd2dde3a176295bc91685d2a))
* **216-05:** add award-guard.mjs — verify-then-climb D-20 guard ([e48b2a6](https://github.com/szTheory/sigra/commit/e48b2a6c9468d00ae30deda31d424c61e1c884c1))
* **216-05:** add eval-probe-ids.mjs — single source of nine canonical probe ids ([fdf93fd](https://github.com/szTheory/sigra/commit/fdf93fdf56a696af7f6d212885198a693209de62))
* **216-06:** admin-eval.spec.ts + three playwright config projects (render matrix + bundles) ([2d1c246](https://github.com/szTheory/sigra/commit/2d1c246af84e9245274a311291c48b2afb95b4f4))
* **216-06:** probes.ts — nine in-browser visual probes (live --sg-* reads) ([43b2a80](https://github.com/szTheory/sigra/commit/43b2a80885a79b17982a3d1dedaa9f97bf44c1a8))
* **216-06:** stale-render-guard.sh + hermetic self-test (git plumbing, absence=FAIL) ([52be409](https://github.com/szTheory/sigra/commit/52be409bbcbf04bafe7f42790d0facd0d3778f3d))
* **216-07:** admin-eval-harness.sh — thin orchestrator (render→probe→guards) ([c195905](https://github.com/szTheory/sigra/commit/c195905c94d315d89537ee70be87eccfc42fd484))
* **216-07:** pilot verify-then-climb — users-index-live=A2, user-show-live=A1 ([19e9473](https://github.com/szTheory/sigra/commit/19e9473d484b4b12bc7ac6c54f530726201d441d))
* **216-07:** wire admin eval guards into fast_checks + add render job ([8124599](https://github.com/szTheory/sigra/commit/81245993f4da980e97bbea9d9c3bc23c1d2268ac))
* **216-08:** board-root scope all nine probe element-scan loops (Gap 1 fix) ([0db07c4](https://github.com/szTheory/sigra/commit/0db07c46b1e3e231df2975970674de92388eb39f))
* **216-08:** board-scope spec runAllProbes call + in-scope seeded-defect tests + D-22 enrichment ([111cf5f](https://github.com/szTheory/sigra/commit/111cf5f5a603c4df26f4439d11c86a55c40fb83b))
* **217-01:** author panel-schema.mjs findingId helper with 216 byte-identity test ([ad2970c](https://github.com/szTheory/sigra/commit/ad2970c6d8b374375c29c69f0ccc3352bba00308))
* **217-01:** extract isStructuralAnchor + GEOMETRY_ONLY_CLASSES into lib/anchor.mjs ([ef5cd4c](https://github.com/szTheory/sigra/commit/ef5cd4c17d995d44f2d23d4e16558066378f5de6))
* **217-01:** install @anthropic-ai/sdk + zod as Playwright devDeps ([38a42c2](https://github.com/szTheory/sigra/commit/38a42c2f20e572528c19bfdebd1af5ac9675972f))
* **217-02:** chain fix-queue-build.mjs into harness (Pitfall 3 ordering) ([1bef8e0](https://github.com/szTheory/sigra/commit/1bef8e07844431d6d5f6fa933b701ef952130ee6))
* **217-02:** GREEN — fix-queue-build.mjs sole open_findings writer + fix-queue.json ([0378f4e](https://github.com/szTheory/sigra/commit/0378f4e2602d808b29148f81e799a6ac050872d8))
* **217-02:** GREEN — fix-queue-lint.sh recomputes derived fields + open_findings check ([168a58a](https://github.com/szTheory/sigra/commit/168a58aa9921dcea457d0a3be4c2e5c91878a5ed))
* **217-03:** implement panel-forced-floor-check.mjs — 12-cell grid + NONE + anchor validation ([403ba2e](https://github.com/szTheory/sigra/commit/403ba2ed5c5ddaf40da61601054a96502788a8f2))
* **217-03:** panel-ci-isolation.test.sh — negative-assertion JUDGE-CI-01 proof (SC-5) ([ec5174f](https://github.com/szTheory/sigra/commit/ec5174ff1055a3d704579dbf11d76b8c890942f9))
* **217-04:** author admin-graphic-design-lens.md (3 perceptual questions, pillar-grounded) ([8198398](https://github.com/szTheory/sigra/commit/819839879326941478df133b83a2a68c84e4cd49))
* **217-05:** add admin-panel-verdicts.json cache + panel-verdicts-lint.sh anti-rot triad ([2880137](https://github.com/szTheory/sigra/commit/28801376d412beace45bf99b5afd5be466b02975))
* **217-05:** implement excerpt.mjs — anchor-preserving DOM canonicalization ([70076cc](https://github.com/szTheory/sigra/commit/70076ccd0a4b4baa2b572578014e7367f111e54f))
* **217-05:** implement judge.mjs — k=3 quorum panel judge with content-hash skip ([34c6085](https://github.com/szTheory/sigra/commit/34c60858f6c6d70d5ad68e6ebd8d7a095e26fcfb))
* **217-05:** implement lenses.mjs — 4 lens definitions + prompt assembly ([3685b35](https://github.com/szTheory/sigra/commit/3685b35acd929d31e21fcff361d2645d2c360a13))
* **217-06:** admin-autofix-loop.sh — apply/commit/re-render/revert with 4 rails ([5af0952](https://github.com/szTheory/sigra/commit/5af0952527319a7bcbe8d8b88788a5449602a112))
* **217-06:** board-autofix-seed fixture + admin-autofix-loop.test.sh (SC-4) ([413a58b](https://github.com/szTheory/sigra/commit/413a58bc9a3253b00d40ec105529c51582d7972e))
* **217-06:** fix-apply.mjs + copy-rules.json — deterministic copy + token swaps ([0e7e48f](https://github.com/szTheory/sigra/commit/0e7e48fdd7c622d62580f326e2f75e8bc2a152ac))
* **217-07:** admin-panel.sh — Hammer no-op degrade + pilot-surface default ([8a95d7f](https://github.com/szTheory/sigra/commit/8a95d7f8c7c6edb3c4fbf13013d006206b00a94a))
* **217-08:** align panel + render matrix on board-mg-5/9 surfaces (Option 2) ([5746e69](https://github.com/szTheory/sigra/commit/5746e695a42e17f13783b88e4e72647569144579))
* **217-08:** harden judge.mjs CLI ordering + add deterministic bundle-wiring self-test ([1b547a0](https://github.com/szTheory/sigra/commit/1b547a08478590ac226f9e83b0ae2b62b1b61621))
* **217-08:** seed appliable in-band SPACE finding + update runbook + fix lint cross-surface check ([f5d1524](https://github.com/szTheory/sigra/commit/f5d1524d7cba40ef8e7070c67a5da4f9bc5162ea))
* **218-01:** extend eval matrix to L1 boards + promote full matrix into both ledgers (D-02) ([d688539](https://github.com/szTheory/sigra/commit/d68853907dfb4f50c5e2df67e7962c99e3838b59))
* **218-02:** verify-hold L1/L2 fractal; add 24 board award cells at A0 floor ([3720ea5](https://github.com/szTheory/sigra/commit/3720ea5d4fccabd5340eb8a872645bebe3146c03))
* **218-03:** verify-hold 8 L3 award cells against proxy boards ([bdeb46d](https://github.com/szTheory/sigra/commit/bdeb46da6c316953be72d7709a6778d4ad94e598))
* **218-04:** fold UI-01 nits — flag warnings, --status re-probe, 120s host timeout, stale-stack reap ([59c934d](https://github.com/szTheory/sigra/commit/59c934d91368244c7001b88fa3780454f682f035))
* **218-05:** migrate mfa_settings_live.ex enrollment sub-flows to vt-* ([507e2a8](https://github.com/szTheory/sigra/commit/507e2a825db18305b48d10f39476648d5fbe2d2e))
* **218-05:** vt-modal + restyle org-members dialogs; remove dead mfa_challenge pair ([acc524b](https://github.com/szTheory/sigra/commit/acc524b1647811c25efb043d9ba7c4a6e7c91857))
* **218-08:** wire probeIdsDriftCheck() into admin-eval suite ([1a29cd8](https://github.com/szTheory/sigra/commit/1a29cd8161b4f90d97f8f8b0eab644947cbc8e24))
* **219-02:** add branch-scoped recapture dispatch (D-04) ([837e65d](https://github.com/szTheory/sigra/commit/837e65d06eb5f81492c3774559821c7bf3409375))
* **219-02:** close 3 recapture gaps + fix stale comments (D-03) ([176550d](https://github.com/szTheory/sigra/commit/176550d569399b1a851160e9551592921c65e682))
* **219-02:** enforce canary-never-allowlistable in snapshot-canary-guard.sh (D-06) ([f3b5e45](https://github.com/szTheory/sigra/commit/f3b5e45d4a3597c02a2f5d3843a57ab950dadec6))


### Bug Fixes

* **216-01:** ci.yml id:base emits merge-base SHA instead of tip (D-10) ([6c4983a](https://github.com/szTheory/sigra/commit/6c4983a02667ae762707d18f95e4c0a24ffb26e8))
* **216-08:** W1 — align evidence-anchor-check to real emitter shape + D-22 class strings ([625b3a2](https://github.com/szTheory/sigra/commit/625b3a26eb5e91cc2be93b7b77e3002f89e08f3c))
* **216-09:** wire audit-only suppression attrs and fix probeEmberReservedFor ([5ed2b8a](https://github.com/szTheory/sigra/commit/5ed2b8a8118cc745df8fcfa9640db95c312a1857))
* **217:** CR-01 canonicalize anchor in fix-queue-build to share finding_id keyspace ([9be2f52](https://github.com/szTheory/sigra/commit/9be2f52bbdc4ca0d166e98ac5e0f8c32db52d7c4))
* **217:** CR-01 refuse token swap when family unresolvable, never emit invalid var() ([f41b978](https://github.com/szTheory/sigra/commit/f41b978a062ede81118c7c29cb6cf5f896247f38))
* **217:** CR-02 align PANEL_SCHEMA schema_version enum to 217-05 ([c05f675](https://github.com/szTheory/sigra/commit/c05f6754ed6643cdd700a786d6a9a832f6ef4204))
* **217:** CR-02 pass output_config.format=PANEL_SCHEMA to constrain LLM output ([298ba4e](https://github.com/szTheory/sigra/commit/298ba4e1ff658f5f9531ab4777e1c4318b79d639))
* **217:** IN-01 judge CLI reads bundle DOM/facts and refuses paid calls on empty DOM ([0a6ee1d](https://github.com/szTheory/sigra/commit/0a6ee1d32a0863846d93cc45bd5bd7f637fb9e45))
* **217:** IN-02/IN-03 correct class-retention comments and guarantee vsn cleanup drops trailing separators ([b067d1a](https://github.com/szTheory/sigra/commit/b067d1ae4406fafd90d019351bcd1f2044a8f047))
* **217:** IN-04 pass finding_id/poison-set to inline node programs via argv, not interpolation ([4c94a68](https://github.com/szTheory/sigra/commit/4c94a6860fbf7ab33d04663cffafc81fe117c07e))
* **217:** IN-05 use in-band fixture so loop proves real apply-revert chain, require Revert commit ([c8f5cbb](https://github.com/szTheory/sigra/commit/c8f5cbb33cf5aba0aa15ae1851a9d8efc5c47050))
* **217:** WR-01 wire fix-queue + panel-verdicts lints into merge-blocking fast_checks ([26d4fd8](https://github.com/szTheory/sigra/commit/26d4fd8a062fd72ef7664bc8476de5883c69a46c))
* **217:** WR-02 run seven Phase-217 self-tests on merge-blocking fast_checks ([eec5ce8](https://github.com/szTheory/sigra/commit/eec5ce82fef5841e46d728ba59354bbbc64d0132))
* **217:** WR-03 delete dead/broken readFileSync const in fix-queue-lint ([9f758c2](https://github.com/szTheory/sigra/commit/9f758c243d421834ba6264e61e00a6d03a697cf5))
* **217:** WR-03 resolveTokenRef refuses 4-entry scale unless token_family=radius ([6d77b03](https://github.com/szTheory/sigra/commit/6d77b035dfc2e3c5c72c7e468ca3b62f93f29d2f))
* **217:** WR-04 fix-apply --queue mode refuses loudly instead of no-op 0 applied ([d91c672](https://github.com/szTheory/sigra/commit/d91c6724fc4a8bb366c4a960c102d165d64b5e7a))
* **217:** WR-05 handle git revert conflicts under set -e in autofix loop ([f0581d1](https://github.com/szTheory/sigra/commit/f0581d12d58b9e9741bdff301226d7f26b36555c))
* **217:** WR-05/06/07 dry-run restore fails loudly, scope git add, run rail 3 unconditionally ([bccffbe](https://github.com/szTheory/sigra/commit/bccffbe47d2acd8cda1724e03601b0728d053537))
* **217:** WR-06 correct false merge-base claim on --base HEAD guards ([ffef26e](https://github.com/szTheory/sigra/commit/ffef26ef8cb00a3b9c4ea1873b2ee473de35cf51))
* **218-01:** deflake first-nav goto in admin-eval.spec.ts (D-09) ([4b2a264](https://github.com/szTheory/sigra/commit/4b2a264dea134a56776367ae93df42a6c31e1e03))
* **218-01:** teach fix-queue-build.mjs to skip proxy-pinned L3 cells (Blocker-1 fix) ([7128b7d](https://github.com/szTheory/sigra/commit/7128b7d2ea3a16b5f1ed9883d0bb7e6c922bebe1))
* **218-07:** make fix-queue rep selection order-independent ([3c9561a](https://github.com/szTheory/sigra/commit/3c9561ae0d1bc8c06e9f672eec10583ef3622131))
* **218-08:** worker-unique eval emails + probes.ts nit fixes (WR-06, IN-01/02) ([25370bb](https://github.com/szTheory/sigra/commit/25370bbd8bc5e50560cdd45c23008c6683d68759))
* **218-09:** add error fallthrough to MFA confirm + fix WR-04 token ([4596f4d](https://github.com/szTheory/sigra/commit/4596f4debaed4a5765fc100fc72e65ed74af6941))
* **218-09:** guard org-members handle_event heads + flash lookup miss ([7fc0486](https://github.com/szTheory/sigra/commit/7fc04862a12b9501e06845eb5bd1b8d11e162d4d))
* **218-10:** union dev.local.proxy-host in reap_stale_uat_stacks (WR-05) ([b7be873](https://github.com/szTheory/sigra/commit/b7be87324a805854dd6add3ef0b5cbfb1702a15d))
* **219-01:** add :global attr + {[@rest](https://github.com/rest)} spread to example icon/1 (D-02) ([a148842](https://github.com/szTheory/sigra/commit/a1488427a099ea4b75bad7d2d60888f011ab935b))
* **219-02:** commit canary deletion before rebirth so guard sees pure 'added' (D-03.2) ([4346c89](https://github.com/szTheory/sigra/commit/4346c891f659b622a2ffe2dca9affc8535bf9c21))
* **220-01:** relocate cheerio require below no-bundles guard ([c0ca7fc](https://github.com/szTheory/sigra/commit/c0ca7fcd7a77b5b0ab8c82af2fa01ea13bd14a45))

## [1.2.0](https://github.com/szTheory/sigra/compare/v1.1.0...v1.2.0) (2026-07-10)


### Features

* **198-01:** add mix ci alias as DX-01 PR-gate local mirror ([6badb0e](https://github.com/szTheory/sigra/commit/6badb0e0f880e4e99f6dc4ebbe736301bf3acaa9))
* **199-03:** add 36-user ugly bulk cohort seeded before personas (FIXT-02, D-09, D-10, Finding 1) ([6ab94ae](https://github.com/szTheory/sigra/commit/6ab94ae571e7612c4ae144d6c271d082a473f0eb))
* **199-03:** mark multi-session/multi-org breadth as deliberate FIXT-02 cases (D-11) ([e7fced6](https://github.com/szTheory/sigra/commit/e7fced64a9aa416d4955e064b9ef03b478c3a24f))
* **199-03:** top up admin to &gt;=25 self-tied audit events for pagination (FIXT-01, D-08) ([0adb3fd](https://github.com/szTheory/sigra/commit/0adb3fdb63d5b061b18fbc5049081e6474154d41))
* **199-04:** un-skip MG-5/MG-6 content-equivalence test (FIXT-01, D-13) ([6e6d993](https://github.com/szTheory/sigra/commit/6e6d99360c392bccaf382754bc30360b8f09993d))
* **200-01:** add /admin/users/:id/sessions route to all three router files in lockstep ([44159e7](https://github.com/szTheory/sigra/commit/44159e7894a2ce39069f2c04f7ada40afd125f53))
* **200-01:** create UserSessionsLive with session table and APG confirm dialog ([e4c9764](https://github.com/szTheory/sigra/commit/e4c9764325ce9a8713749b611c58c8f5be5e883c))
* **200-01:** extend glossary drift guard to cover UserSessionsLive ([33b5a84](https://github.com/szTheory/sigra/commit/33b5a84a78c73723a9ceb362807ba06b30740377))
* **200-02:** convert Sessions/Orgs to bounded previews + remove session revoke flow (DETAIL-02) ([16a09e1](https://github.com/szTheory/sigra/commit/16a09e126ee217411da78f1a62894edce1f0067a))
* **200-02:** recompose identity header into one calm identity bar (DETAIL-01) ([2204dc4](https://github.com/szTheory/sigra/commit/2204dc49212c1a31f3b174881337553ccaf3d2f2))
* **200-02:** verify JTBD composition order and preserve host extra-section seam (DETAIL-02/D-07) ([4f4733e](https://github.com/szTheory/sigra/commit/4f4733e2617021c1b5d7332390fb447676e4e7de))
* **201-01:** consolidate filter panel, demote metric strip, resolve sg-chevron ([216b64c](https://github.com/szTheory/sigra/commit/216b64c0c30c08a786f9f456504b71150df99bca))
* **201-01:** DRY per-row presentation via shared field-slice components ([467c2cd](https://github.com/szTheory/sigra/commit/467c2cddb8e555323b2bc726ea629ef1b281943e))
* **201-01:** reduce status_pills/1 to decision-bearing signals ([0323fc2](https://github.com/szTheory/sigra/commit/0323fc2c9a4dc031964f06d0904979915f128f8e))
* **201-02:** emit non-empty extra_list_badges + extra_list_columns from example hook ([a44fd23](https://github.com/szTheory/sigra/commit/a44fd23de5668a9e6f73d13167fde99d3fc01bb6))
* **201-04:** sync mg-1/mg-2/mg-5 design gallery boards to elevated live markup ([44a3b77](https://github.com/szTheory/sigra/commit/44a3b77ac743138c0e8cc081963db9c7b4c3c157))
* **202-01:** add audit_table_row/1, audit_pagination_nav/1, audit_empty_state/1 to components.ex ([3fe5e58](https://github.com/szTheory/sigra/commit/3fe5e584b729c8a816e4a9728e90c36c9dac8c8c))
* **202-02:** collapse 3 forms into 1 with folded-in toggles + &lt;details&gt; disclosure ([e768f78](https://github.com/szTheory/sigra/commit/e768f7894652180b0686affe128a60d318fb15f3))
* **202-02:** rewire desktop table/pagination/empty-state to shared components; delete dup helpers ([c34c95a](https://github.com/szTheory/sigra/commit/c34c95a8bb6ed806714fe8f8ef2bce342727d404))
* **202-03:** add &lt;details&gt; advanced-disclosure to global audit filter form ([e664e7f](https://github.com/szTheory/sigra/commit/e664e7f1428a61b7d275c580c7bfbfa73ef385f8))
* **202-05:** ratchet audit-index-live and audit-user-live ledger cells to Tier 2 ([816a740](https://github.com/szTheory/sigra/commit/816a7408ad5e5655eb27c2e0c3bf8c3073c928c9))
* **203-01:** demote global Authentication coverage chip (D-03) ([e385117](https://github.com/szTheory/sigra/commit/e3851179f58f0426963841cfcbbb756cceebb1ba))
* **203-01:** drop org roster always-on Confirmed pill (D-02) ([d8d03a2](https://github.com/szTheory/sigra/commit/d8d03a2fde13002f5e543e4d1bb48da3c01de868))
* **203-03:** add branding #restore-defaults-overlay 7-APG + axe case (D-06) ([57b8cc1](https://github.com/szTheory/sigra/commit/57b8cc186baa15013b3c7dddf6febea8879aca2c))
* **203-05:** ratchet index-live, organization-live, branding-live to Tier 2 (D-08) + fold PAGE-04 todo (D-09) ([239f393](https://github.com/szTheory/sigra/commit/239f393ac4b206d5897cfd92f2e7edb89210bcbe))
* **205-02:** add zoe zero-state persona to Personas.all/0 and feature_map/0 (D-16, D-17) ([aed13f6](https://github.com/szTheory/sigra/commit/aed13f6306ea24c190f8188154d582ebb7dbef61))
* **205-02:** extend seeds.ex with ghost-org, i18n/RTL user, bulk_cohort_size/0, [@seconds](https://github.com/seconds)_per_day (D-16, D-18, D-19, IN-01, IN-02, IN-03) ([0138137](https://github.com/szTheory/sigra/commit/01381378f0e46cbeb6042694e7401337357ae10b))
* **205-03:** add 4 board-cfg-* page composite boards to design_gallery_live.ex (D-08, D-09) ([4ca6e53](https://github.com/szTheory/sigra/commit/4ca6e53743d04a53473455a9659b49607964ec86))
* **205-03:** register CONFIG_BOARDS in admin-design.spec.ts, add structural assertion (D-10, D-11) ([da980c7](https://github.com/szTheory/sigra/commit/da980c7a4294de9cc9e29a2b730ba4144a0aafe7))
* **206-01:** add admin-css-conformance.sh guard + fix lone hex violation ([1c4af42](https://github.com/szTheory/sigra/commit/1c4af42d00418d3b8be6c722a1da4a357d94bd9b))
* **206-04:** flip all 8 L1 component rows to tier 2 in quality ledger ([2b698b9](https://github.com/szTheory/sigra/commit/2b698b99aa70c0614aae42035bc2fc48252a153b))
* **207-01:** add narrow raw-px CHECK 3 to admin-css-conformance.sh (D-07) ([f7bb6c8](https://github.com/szTheory/sigra/commit/f7bb6c8a6156d3bd8853859fd3637075cbcf0fad))
* **207-01:** build admin-token-completeness.sh guard (D-06) ([a87f85f](https://github.com/szTheory/sigra/commit/a87f85f5fc968edcaf3ad5b13608dbbd032eac86))
* **207-04:** flip 6 ledger rows (token-layer L0 + 5 L1) to bare tier 2 ([bd77241](https://github.com/szTheory/sigra/commit/bd772413357110f11789eec2f9987e70ba331552))
* **209-01:** add admin_checkpoint_recapture CI job (D-09 checkpoint recapture mechanism) ([272e187](https://github.com/szTheory/sigra/commit/272e187c6176b44e31a3ae6df725d1e8f0b0b451))
* **209-02:** add panel schema-check helper + 4 list/overview surface docs ([4285c70](https://github.com/szTheory/sigra/commit/4285c702e00a7e6805b9306a87a71b900db81222))
* **209-02:** author 4 leaf/detail surface panel docs ([e52457f](https://github.com/szTheory/sigra/commit/e52457f7f0d1b98bb73c58bd33b564e7c40dade3))
* **209-02:** author v1.42-PERSONA-JTBD-PANEL roll-up index ([99e61a4](https://github.com/szTheory/sigra/commit/99e61a45c0e26fddc72b0d7e02b17873e266b7b7))
* **210-02:** flip 11 mg-* L2 ledger rows to bare tier 2 with rich evidence ([f5833b0](https://github.com/szTheory/sigra/commit/f5833b0b0fc03c9d5da4c3078d17ffb4c1886058))
* **212-02:** wire 3 persona-flow specs into admin_behavior CI step (FLOW-01) ([7a7da09](https://github.com/szTheory/sigra/commit/7a7da092068fc842f1d53e9ae922208a2d2dac6e))
* **212-03:** branch-scope generated_admin_playwright_smoke if to run on PR [#63](https://github.com/szTheory/sigra/issues/63) (GATE-02) ([efaf350](https://github.com/szTheory/sigra/commit/efaf350c91bc24f717b463aa43a2352f5b7b2232))
* **213-01:** rebless install golden fixture under phx.new 1.8.8 ([d5797e9](https://github.com/szTheory/sigra/commit/d5797e91bd00f90bd7f8885e7c5aa2d051c80fca))
* **213-02:** add rebless_golden --check CI drift-detector (D-06) + D-11 smoke version-asserts ([6cab0c5](https://github.com/szTheory/sigra/commit/6cab0c5a9e92648534bd08b71079a1acd0f6b9d3))
* **214-01:** add Sigra.OptionalDeps.oban_running?/0 SOT and fix all three call sites ([e1040b7](https://github.com/szTheory/sigra/commit/e1040b7add4607947f553ac8d2b00044983457bb))
* **214-02:** add user_id ownership guard to delete_session/3 (D-08) ([2ba35c1](https://github.com/szTheory/sigra/commit/2ba35c1535d69c31d70112ff476e31e53a72aba7))
* **214-03:** add app.css corruption guard and wire into ci.yml (D-17) ([bbb0b37](https://github.com/szTheory/sigra/commit/bbb0b37a0045b4235130ce7faf72a482d7d99b10))
* **example:** give the Vaultr demo app its own typographic mini-brand ([d242d1a](https://github.com/szTheory/sigra/commit/d242d1a8f2d5efeece3f2e973552ed72680fb371))
* **example:** kicker section spacing + click-to-copy on vt-code credential chips ([f20d398](https://github.com/szTheory/sigra/commit/f20d398599151aee930b4cb30764a86bddc682e4))
* **example:** lock the real login to Vaultr; brand-lab is a homepage preview only ([485d38f](https://github.com/szTheory/sigra/commit/485d38f745b8593bef953f62e85b674d0d6fcf9b))
* **example:** real Vaultr settings page + vt-* form/alert/menu primitives + product identity ([eab0479](https://github.com/szTheory/sigra/commit/eab0479f3d46e05d17ccfbf2077a886197eceec5))
* **example:** recolor the Night Ops brand-lab preset to indigo/violet ([0fac2fd](https://github.com/szTheory/sigra/commit/0fac2fd7b50efe76ca81a3d9594c67a682cd7791))
* **example:** Vaultr authenticated account-home hub at /app ([88004a9](https://github.com/szTheory/sigra/commit/88004a9e7ef3ac286d4b72ed812777e48aaf8e0a))
* **example:** wire check_account_active into :require_authenticated (loop-safe) ([619f1b1](https://github.com/szTheory/sigra/commit/619f1b1279d0fe03b9e84624d2a19bb87d20ca05))
* **install:** mirror loop-safe auth-plug guards into generated user_auth ([1ea0278](https://github.com/szTheory/sigra/commit/1ea02781e7160750f75661f63317c245565ba241))


### Bug Fixes

* **199-04:** target seeded &gt;=25-event admin in per-user audit pagination assertion (FIXT-01, D-15) ([bcbbfad](https://github.com/szTheory/sigra/commit/bcbbfad59f1ea065504004f41a60fdaec895ca32))
* **199:** assert &gt;25 admin audit events to match pagination boundary (WR-01) ([5be6445](https://github.com/szTheory/sigra/commit/5be6445b3b2e8b4c30cf7704c7704c9fcb442239))
* **199:** guard self-test fixture mutation actually applied (WR-04) ([6e3efdd](https://github.com/szTheory/sigra/commit/6e3efdd7fe8fef8f4bd5109fad888699f04a3dd5))
* **199:** revise plan 03 — add FIXT-02 breadth task + clean verify commands ([a620b22](https://github.com/szTheory/sigra/commit/a620b22a306a1b2213fd7c89492c42d056a21da2))
* **200:** WR-02 harden open_revoke_session token decode against malformed input ([146708e](https://github.com/szTheory/sigra/commit/146708e62402e1c0bd364c52ed2a16c6318960b6))
* **200:** WR-03 scope-restrict UserSessionsLive return_to to active-scope users index ([19a7d0f](https://github.com/szTheory/sigra/commit/19a7d0f6a56ab9704f440b70fbfe5bdb09d30589))
* **203:** extend glossary auth-replica carve-out to promoted preview_pair ([dcf1725](https://github.com/szTheory/sigra/commit/dcf17259d46283ee940e55f1c2a669a158a78d15))
* **203:** update IndexLive tests for demoted auth-coverage chip (D-03) ([52e6133](https://github.com/szTheory/sigra/commit/52e6133904c0d0832b9cfe5ba98e5aad9dd9db54))
* **204-02:** delete stale Phase192 known-failure contract test (D-08) ([c9e5cbb](https://github.com/szTheory/sigra/commit/c9e5cbbb24cdd88c2c4599341cc6c2e0f1b5dea3))
* **204-02:** reconcile Vaultr→Tasklane doc drift + update Phase148 contract (D-08) ([7202113](https://github.com/szTheory/sigra/commit/7202113b16d41d39696baea44a47ca30a20a2d51))
* **204-03:** raise .vt-status-pill contrast to ≥4.5:1 + recapture mobile baselines (D-03/D-04/D-05) ([c96749f](https://github.com/szTheory/sigra/commit/c96749fa5b4c877622eea8d0127c555bae90c276))
* **204:** remediate code-review findings (WR-01 dead-code regex, WR-02 unscoped refute, IN-01 stale comment) ([010cc42](https://github.com/szTheory/sigra/commit/010cc422174b8f9107d187633b54398fb4b9cc4c))
* **208.1-01:** add responsive desktop/mobile swap to board-cfg-audit ([1985994](https://github.com/szTheory/sigra/commit/198599422bc7f016b20de902e75ad9fa36e38ffe))
* **208.1-01:** correct board-mg-1 .sg-metric count assertion to 6 ([341e32a](https://github.com/szTheory/sigra/commit/341e32ae9af1471e4d7881ea530881510f6fb81f))
* **208.1-02:** reconcile stale sudo heading + audit disclosure selectors ([7854ab5](https://github.com/szTheory/sigra/commit/7854ab571b911a4c4c81de19ea0d9707f1ef7172))
* **208.1-02:** scope dual-DOM strict-mode assertions to visible variant ([ae1f947](https://github.com/szTheory/sigra/commit/ae1f94790fbf04c7413732b33143ca08d318d59e))
* **208.1-03:** reconcile demo-showcase spec selectors and copy drift ([9a32dfa](https://github.com/szTheory/sigra/commit/9a32dfad00a963a4e902e72d40aca7bc6c023411))
* **208.1-03:** reconcile non_admin spec selectors/copy to rendered UI ([b9642f5](https://github.com/szTheory/sigra/commit/b9642f52bef5bd18f9dd1341e5efc704b88572ff))
* **208.1-04:** reconcile library-side sudo heading assertions + golden fixture to 'Re-enter your password' ([cbe0b92](https://github.com/szTheory/sigra/commit/cbe0b92899822016fe1b878d1af02adce448bf4d))
* **208.1-04:** reconcile stale example unit smoke test assertions to current UI ([2ef6cfd](https://github.com/szTheory/sigra/commit/2ef6cfd6c6849cc20e9ede2026ac9247db44cd95))
* **208.1-04:** use viewport-only screenshot in captureAndVerify to avoid 32767px limit ([24ee68c](https://github.com/szTheory/sigra/commit/24ee68c8384a9b551075c9fe20cfdc10aec4c382))
* **209-03:** index_live — kill bare "All clear" + dedup Total-users ([f5d8fb8](https://github.com/szTheory/sigra/commit/f5d8fb847ec017f3b79409992255a271e324e5f3))
* **209-03:** organization_live — kill bare "All clear" + swap empty-states ([fd1ca31](https://github.com/szTheory/sigra/commit/fd1ca311c40d21b86d7cb34abb38d15ccf81fbca))
* **209-04:** branding_live — replace hardcoded scope_ribbon literal with context-appropriate scope_copy/1 helper ([44dc4ee](https://github.com/szTheory/sigra/commit/44dc4ee2c8d7d3f658101b1dd3fbf00d4d445f3f))
* **209-04:** user_sessions_live — entity-name H1 + security-preserving revoke copy (copy/IA only, no tier ratchet) ([869f199](https://github.com/szTheory/sigra/commit/869f1997861f331124d06ff3c796d59fe840d801))
* **209-04:** user_show_live — de-dup sessions count, raise Manage sessions, unify empty-states, sharpen kicker ([b28da2d](https://github.com/szTheory/sigra/commit/b28da2dcdd8046e2321460f79add6428b33bacfe))
* **209-05:** move audit_index scope_ribbon above header; waiver chips-post-form as Audit Explorer archetype ([7702539](https://github.com/szTheory/sigra/commit/7702539960636eaf5d50859a681554e7f6f284b1))
* **209:** harden Plan 03 empty-state gate (count-based, partial-fix-safe) ([a02efb7](https://github.com/szTheory/sigra/commit/a02efb7273fbb153a1db6c09bbe2ec432540f2e6))
* **209:** remove dead [@summary](https://github.com/summary)_posture assign in index_live (code-review IN-01) ([8f56f64](https://github.com/szTheory/sigra/commit/8f56f64eb84ffb8d72799d3c1ad7c7da66db12c5))
* **209:** revise plans per checker feedback (OQ resolution, dedup single-owner, positive-replacement + recapture-proof gates) ([6b7a938](https://github.com/szTheory/sigra/commit/6b7a9382505f5ce347fec5469e81fe54ad8e0fde))
* **209:** rework admin_checkpoint_recapture — drop circular canary self-gate (WR-01) ([eb066b4](https://github.com/szTheory/sigra/commit/eb066b496d28f6e8ad7a3eca869c20d6ec74a548))
* **211-04:** correct persona panel status PRE-FIX → POST-FIX (D-07) ([4d475b1](https://github.com/szTheory/sigra/commit/4d475b195e740972a89d9c068f80ba2eedb215d8))
* **212:** revise plans 01/04 — recapture-PR canary reconciliation + full-backlog merge vehicle ([dbae903](https://github.com/szTheory/sigra/commit/dbae9030c4349d21496cea3b4de9a6d84d783493))
* **214-03:** delete orphaned :root value fragments from app.css (D-15) ([76c6d11](https://github.com/szTheory/sigra/commit/76c6d116cefca56583adcf9cd5cea317edd18442))
* **214-05:** correct stray 1.20.0 version wart in contract.md (DEBT-04 D-13) ([59c37a9](https://github.com/szTheory/sigra/commit/59c37a9a4d70ca03a7274190a52d90e80c6f81df))
* **auth:** complete email-change confirmation fix (double-encode + session opts) ([c2ab16f](https://github.com/szTheory/sigra/commit/c2ab16f151c94fbf249e451981cb94710f70bb86))
* **auth:** email-change confirmation always failed (invalid/expired) ([1044180](https://github.com/szTheory/sigra/commit/1044180570663919d2115cc1d899a798a9a89f94))
* **auth:** run password-change + deletion on the real Sigra.Auth path ([9a157a9](https://github.com/szTheory/sigra/commit/9a157a9f4e93136ba86e7ec086ebeb7b6fe38a3b))
* **auth:** stale-sudo redirects to /users/sudo, not /users/log_in (WS4) ([6dae6d1](https://github.com/szTheory/sigra/commit/6dae6d1dfe989ca49586e210096a657fbc9b1fca))
* **auth:** thread session_store_opts in password-change + deletion (sibling of c2ab16f1) ([880fe5f](https://github.com/szTheory/sigra/commit/880fe5fe6406b9d6b2cc689ec72abec35b881b73))
* **ci:** route recapture-gate slugs per lane (single-lane recapture) ([cae8cbc](https://github.com/szTheory/sigra/commit/cae8cbc98616e5272fa361429d875f7c816d8568))
* **testing:** truncate deletion fixture timestamps to :utc_datetime precision ([08c947b](https://github.com/szTheory/sigra/commit/08c947b91747ad0ea52bdd0d31587427d2ab1a59))
* **uat:** make --dev host-run boot reliably (drop bogus flag, sync compile-env port) ([fddb160](https://github.com/szTheory/sigra/commit/fddb1604e1aec4dafeeca5bbeade690534b45a3a))
* **uat:** stable host-run port + tolerate compile-env drift on --dev (260621-in8) ([0487e74](https://github.com/szTheory/sigra/commit/0487e7476e921cdb355d683bb6576183dfe2e7ea))


### Reverts

* **206-03:** restore CI-native admin-design baselines ([43f5a3e](https://github.com/szTheory/sigra/commit/43f5a3e438497db1d5465a8927bf793f8ea00a10))

## [1.1.0](https://github.com/szTheory/sigra/compare/v1.0.0...v1.1.0) (2026-06-13)


### Features

* **154-02:** add sg-notice CSS block inside [@layer](https://github.com/layer) sg-components ([2c023ba](https://github.com/szTheory/sigra/commit/2c023baea2110ad50edd8c7c05ae8f2dfdc82a49))
* **155-01:** add stat, skeleton, and notice components (all 10 complete) ([969fbe8](https://github.com/szTheory/sigra/commit/969fbe808c1feb0192d7271c9e8906bd66f50592))
* **155-01:** define 8 live-analog admin components in Sigra.Admin.Components ([d13801d](https://github.com/szTheory/sigra/commit/d13801d85da9d206890ab6c9a614de8f39e069e7))
* **157-01:** redesign render/1 with front-door archetype and skeleton state ([0a7cdce](https://github.com/szTheory/sigra/commit/0a7cdcee084042dd25f181c8512882debd46a241))
* **157-01:** split mount/3 with connected? gate and loading assign ([29a72c4](https://github.com/szTheory/sigra/commit/29a72c4236c1a3c496be2574d208ff20c1ecf1e1))
* **157-02:** redesign org overview render/1 — front-door archetype + skeletons ([23b482e](https://github.com/szTheory/sigra/commit/23b482ed340c72c6d986e15cdb1d0725daf97f6a))
* **157-02:** split org overview mount/3 with connected? gate ([3dc1979](https://github.com/szTheory/sigra/commit/3dc19797ba1eee181da4c3a40cc04c7b3b130f4a))
* **157-04:** add global-overview and org-overview checkpoint blocks to admin-checkpoints.spec.ts ([e6296d5](https://github.com/szTheory/sigra/commit/e6296d5c839539f6cf4d42f7ed25c72e7a8d001a))
* **157-04:** record 6 initial PNG baselines for global-overview and org-overview ([e609b48](https://github.com/szTheory/sigra/commit/e609b48af1d74071c17705c0052bbfdbda6c5d40))
* **158-01:** add audit_row/1 as 11th component with audit_tone/1 and format_date/1 ([e56ccd7](https://github.com/szTheory/sigra/commit/e56ccd7ca5162daa3a8ac4c46ae33bce46d36eec))
* **158-02:** dual-layout wrappers + audit_row mobile cards + tone consolidation in AuditIndexLive ([73d296c](https://github.com/szTheory/sigra/commit/73d296cc5564235f4c7cccaf9dc4de2d46a1cdec))
* **158-03:** add dual-layout + audit_row mobile cards to AuditUserLive ([1d05c1e](https://github.com/szTheory/sigra/commit/1d05c1e498d36dcd3f6abef98a7c94a4ac92d8f2))
* **158-03:** wire shared chrome + quick-filter chips into AuditUserLive ([10fe1e4](https://github.com/szTheory/sigra/commit/10fe1e4ecf950f2987cca09bc530ee7322e50369))
* **158-04:** route user-detail Recent Audit through compact audit_row ([4f190da](https://github.com/szTheory/sigra/commit/4f190daff70f688edc4179e8eda0d43eacd27361))
* **158:** automated snapshot drift guard + recapture gate (zero-human baseline review) ([0d3c4d2](https://github.com/szTheory/sigra/commit/0d3c4d27a70594657d7084270912b7bcc1a6360d))
* **159-01:** add deletion_scheduled? to member_row type and shape_member_row/1 ([8fbeedc](https://github.com/szTheory/sigra/commit/8fbeedc002ea302aa9753369d2ca72de1abed54e))
* **159-01:** add roster deletion pill and expand format_date/1 in organization_live.ex ([75be3ba](https://github.com/szTheory/sigra/commit/75be3baeb5e3d0c4a49681f01d806d3bb94e8da9))
* **159-02:** add pat and grace personas to all/0 and feature_map/0 ([a5c4f9a](https://github.com/szTheory/sigra/commit/a5c4f9a47dcbaf3a8dd486f2d1dafcc822eb7d58))
* **159-03:** enrich seeds.ex with expired invite, grace Acme membership, pat passkey, FIXT-04 audit rows ([332d3c7](https://github.com/szTheory/sigra/commit/332d3c79bda9bec9456f5e12bea7d4a3cd0e9aed))
* **159-03:** update seeds_test.exs — expired_invitations key, grace/pat/expired-invite tests ([4261ad6](https://github.com/szTheory/sigra/commit/4261ad6100de62774dd96f6f701a7a289ec89634))
* **159-04:** add admin-coherence-sweep.spec.ts — behavior filmstrip + GATE-03 check (D-07) ([8223496](https://github.com/szTheory/sigra/commit/82234969f15ce696d966723cb41d6906e556bae9))
* **159-05:** fix scope_ribbon class + add OrganizationLive ribbon call ([8ed3ddc](https://github.com/szTheory/sigra/commit/8ed3ddce01627bbbe9f2dafd21d4c2dfbc97cf24))
* **159-05:** make GATE-03 motion check discriminating (WR-02) ([8169478](https://github.com/szTheory/sigra/commit/81694789b4334fe504f601f45aa71d5f90d5d211))
* **159-05:** run coherence sweep Playwright spec + fix spec locator issues ([31e05f8](https://github.com/szTheory/sigra/commit/31e05f89c8ab6490a4bedefadee8a4d84a153b87))
* **160-01:** D-06 dark brand-strong WCAG-AA fix + Sigra.Admin shared helper (IN-03) ([36bc1cf](https://github.com/szTheory/sigra/commit/36bc1cf749d0a14aa5f7617aa33a847c28c48501))
* **160-03:** re-record 7 dark checkpoint baselines for D-06 brand-strong fix ([e3cacd1](https://github.com/szTheory/sigra/commit/e3cacd1b7ad8ddcd486f4892970e22d8b091bfc2))
* **179-01:** critique-render.mjs + brandbook/README.md font provenance (BRAND2-04) ([beebd16](https://github.com/szTheory/sigra/commit/beebd16a7b2af5594153033e7598f3f1c2dcb43a))
* **179-01:** outline-wordmark.mjs — per-glyph SVG path generator (BRAND2-04) ([d267b99](https://github.com/szTheory/sigra/commit/d267b99c2f423fd61015fec897e03e2152419827))
* **179-02:** add B1/B2 refined lockups and C1 stacked wildcard ([3437b86](https://github.com/szTheory/sigra/commit/3437b867c2c9ef22520602f96a5a0223e5b3d4e8))
* **179-02:** add Direction A integrated typemark candidates A1-A4 ([a6be5ca](https://github.com/szTheory/sigra/commit/a6be5ca064ab43423366d8abb4b5e34eba65af15))
* **179-02:** add round-3 gallery index and rationale README ([16a6cdd](https://github.com/szTheory/sigra/commit/16a6cddd5bf3512f233dd818d1fc89843aa38b7a))
* **180-01:** add round-4 gallery index and README ([b6256e9](https://github.com/szTheory/sigra/commit/b6256e9e88ce77b587bf19e67a962b33d5823c04))
* **180-01:** add round-4 rail-i refinement candidates ([b9b5b64](https://github.com/szTheory/sigra/commit/b9b5b64c95ad7d0dd172675afb8484d291724355))
* **181-01:** write D4 Linked Rail mark, monochrome, and favicon SVGs ([8e52d20](https://github.com/szTheory/sigra/commit/8e52d20635cc1316fdbb68990c4dcba8fe681916))
* **181-01:** write D4 Linked Rail typemark SVGs (primary, dark, subtitle) ([ee29553](https://github.com/szTheory/sigra/commit/ee29553679aa81e16be1117403bfc37940ee15cc))
* **181-02:** archive v1 social-card and write D4 v2 social cards (light + dark) ([0445a98](https://github.com/szTheory/sigra/commit/0445a98e87071a666d0c7614fe90e0aafee20a7e))
* **182-01:** replace stale v1 mark geometry in landing-hero.svg + readme-header.svg ([d9175d7](https://github.com/szTheory/sigra/commit/d9175d78916936830c0d7beb6060f13baacc8f32))
* **182-02:** add scripts/brand/axe-brandbook.mjs — committed axe WCAG gate ([fadda96](https://github.com/szTheory/sigra/commit/fadda9643719dcdc22abd4477900090fcab9f959))
* **182-02:** expand index.html — scorecard id, expanded #logo, new #suite section ([a2a6684](https://github.com/szTheory/sigra/commit/a2a6684b5b227c1bf00ce0925af14a4fd27a7d3f))
* **183-01:** propagate D4 admin lockup SVGs to installer + example ([71953c4](https://github.com/szTheory/sigra/commit/71953c4806dd8a89f367b45780c6b15b6fa50440))
* **183-01:** replace companion marks with D4 abstract rail glyph geometry ([33313ee](https://github.com/szTheory/sigra/commit/33313ee11f17a9e25284492b72332bdaf0231beb))


### Bug Fixes

* **154:** correct app.css line citations shifted by sg-notice insertion (WR-01) ([3c0f033](https://github.com/szTheory/sigra/commit/3c0f033b74c075ba75a5ab7bce111ccf0ef6cba8))
* **155:** add attr :class merge to notice/1 (WR-01/WR-02) ([5ad22cd](https://github.com/szTheory/sigra/commit/5ad22cda5e29819350aeb08571a28dd658bbbcd1))
* **156:** remove nested &lt;p&gt; in user_show notice call (code-review WR-01) ([ad506c2](https://github.com/szTheory/sigra/commit/ad506c2cb024b2cdc1716318689b3f09f8d9e067))
* **157:** match org overview skeleton shapes to replaced content (WR-02) ([5806872](https://github.com/szTheory/sigra/commit/580687213c99f12f1cbd9a021b28ac25fb410b48))
* **158:** reflect active quick-filter chip state + dark-mode contrast ([b92777a](https://github.com/szTheory/sigra/commit/b92777a44156e053655f7f94d4e4eac7ee8fbcd4))
* **159-01:** replace &lt;p&gt; with &lt;div&gt; in notice/1 slot wrapper (org-notice-nested-p) ([81eeeb5](https://github.com/szTheory/sigra/commit/81eeeb570d5ac2a885d27bed38b4c29033df7310))
* **159-04:** scope sg-filter-chip transition to pointer:fine devices (D-06 GATE-03) ([1364d17](https://github.com/szTheory/sigra/commit/1364d173c42bb70867033153fb782ace6cf29890))
* **159-05:** WR-01 NaiveDateTime guard + WR-04 transaction result propagation ([65f7ce1](https://github.com/szTheory/sigra/commit/65f7ce15585eb8a38a174b08a0ba476d39d8e3e3))
* **160-01:** D-07 needs-review link + OR-filter fix, dedup needs_review/1 (IN-03) ([e0df0f3](https://github.com/szTheory/sigra/commit/e0df0f3c84dc21469c71d276900aa55b8366daa1))
* **160:** wire needs_review filter into Flop param contract + scope-safe where (CR-01, WR-01) ([8231f84](https://github.com/szTheory/sigra/commit/8231f84084314b074515b5d31e74fcc22843fd09))
* **179-02:** apply variable-font axis coords in glyph outlining ([ec2bd48](https://github.com/szTheory/sigra/commit/ec2bd48b5033faa3b58654047d5c163a290f2815))
* **179-02:** remove double Y-flip in outlined glyph path data ([5a02a27](https://github.com/szTheory/sigra/commit/5a02a27010fc4ddf3c125936e6b75c85d3d9507e))
* **ci:** pin phx_new to 1.8.7 to restore green install/golden jobs ([f5755a4](https://github.com/szTheory/sigra/commit/f5755a405e63231fe225c7bf74f4ea5433a0f7e2))
* **install:** repair auth-context test binding + core template count ([232b4e3](https://github.com/szTheory/sigra/commit/232b4e35c5d076c5ceb5487406c04c7ea57eae04))
* **upgrade:** guard organization migrations ([073f8fe](https://github.com/szTheory/sigra/commit/073f8fe8c8557a31da2ae2d938202c0b51f80097))

## [1.0.0](https://github.com/szTheory/sigra/compare/v0.3.0...v1.0.0) (2026-06-03)


### Features

* **135-01:** add forwarders config block and Threadline demo section in AGENTS.md ([e4add7c](https://github.com/szTheory/sigra/commit/e4add7cc61450fd9b266619f5a9c126e81ea3240))
* **135-01:** add integration test asserting Sigra→Threadline projection chain ([b39a9ba](https://github.com/szTheory/sigra/commit/b39a9ba9e35452d54acb1da0794b67b68f78f075))
* **135-01:** add Threadline dep + committed migrations (capture, semantics, governance) ([22790c4](https://github.com/szTheory/sigra/commit/22790c46134be41b409930175b840e042a59b591))
* **137-01:** add Sigra.OptionalDeps SOT module (OD-01) ([de3f3f8](https://github.com/szTheory/sigra/commit/de3f3f89369788f0d9b6ad5e8b175f93cc97db9e))
* **138-01:** implement Sigra.Doctor with injection seam, nine-feature matrix, and wiring checks ([4c69dcf](https://github.com/szTheory/sigra/commit/4c69dcfe5c8ed89dff6ba01925098604e890a424))
* **138-02:** implement Mix.Tasks.Sigra.Doctor thin shell with ANSI output and exit gate ([87b7c51](https://github.com/szTheory/sigra/commit/87b7c511e4169286e6bbe19dafc38922eb06ed5b))
* **139-01:** create companion-lib recipe contract fixture (RCT-01) ([c0a02c9](https://github.com/szTheory/sigra/commit/c0a02c9332659e829a623547680c1708d679dc6f))
* **141-01:** add create_user_identities migration ([cb89bc7](https://github.com/szTheory/sigra/commit/cb89bc704caa8e265e3a7da590953090e2f78cf1))
* **141-01:** add Example.Accounts.UserIdentity schema ([d8a38c6](https://github.com/szTheory/sigra/commit/d8a38c66a4086cf64e1515efa34b666b3c705252))
* **141-02:** create Example.Demo.Personas pure-data module (D-01, D-05) ([cff3116](https://github.com/szTheory/sigra/commit/cff31167b083450aeddc9bd199319d08766c54a5))
* **141-03:** implement Example.Demo.Seeds idempotent upsert orchestrator ([af8d1d3](https://github.com/szTheory/sigra/commit/af8d1d3c695e2094887da36ce6d6d43e9dab05f2))
* **141-04:** add D-03 raise-guard + wire Example.Demo.Seeds.run/0 in seeds.exs ([4359dd0](https://github.com/szTheory/sigra/commit/4359dd089137d5687602ef8c450fb7f23a1292a1))
* **142-01:** add Personas.feature_map/0 — D-02 single source for feature copy ([b14965d](https://github.com/szTheory/sigra/commit/b14965d3e8c6a1342cf7c5d933b33abf76253b52))
* **142-01:** create ExampleWeb.Demo.CredentialsLive + add /demo/credentials dev route ([6665257](https://github.com/szTheory/sigra/commit/6665257f36ec874a211d7e0e33c61bd3d541fc39))
* **142-02:** rebrand layouts.ex — Vaultr brand span + contextual nav (D-08, D-09, D-10) ([cf96964](https://github.com/szTheory/sigra/commit/cf969644a16b0f601def2770036f6b1b43f6de98))
* **142-02:** rebrand root.html.heex with Vaultr page title (D-08) ([d650804](https://github.com/szTheory/sigra/commit/d650804a60ee71730d0345370b446335e64868e4))
* **142-03:** add Seeds.print_credentials/0 — D-11 stdout block using Personas.feature_map/0 ([926e095](https://github.com/szTheory/sigra/commit/926e095ea54dc728e6030c8b9d827dd594780456))
* **143-02:** add demo-showcase spec with 4 committed PNG baselines ([5325aaf](https://github.com/szTheory/sigra/commit/5325aafb249e7e32b59771b40d5b08dc234a1e58))
* **143-02:** add demo-showcase-chromium project partition to playwright.config.ts ([3239dd1](https://github.com/szTheory/sigra/commit/3239dd120a06ca74367136d3b8c9622e786aeceb))
* **143-02:** add Run demo-showcase spec step to CI example_playwright_smoke job ([b65978f](https://github.com/szTheory/sigra/commit/b65978f793e263473de31ed82020da509eb9f594))
* **144-02:** copy screenshots to guides/assets/ and wire ExDoc config ([5d1b6a4](https://github.com/szTheory/sigra/commit/5d1b6a4cd2a932c657f7616028fb18dbfa6e2cf9))
* **144-02:** write demo-showcase.md guide and add ga-evidence.md pointer ([7838a1f](https://github.com/szTheory/sigra/commit/7838a1fc0cc147bf3e46a1be8bb4a55f6dac59ab))
* **146-01:** harden Hex publish truth and recovery gates ([74dadfb](https://github.com/szTheory/sigra/commit/74dadfbba9d69eb0d5cf2217d3e0ae88aa252c17))
* **146-02:** add canonical 1.0 release runbook ([d2da7f0](https://github.com/szTheory/sigra/commit/d2da7f0a0d256a7d1ef32a816c7b28373b201a60))
* **147-01:** add published-to-candidate upgrade smoke harness ([430131d](https://github.com/szTheory/sigra/commit/430131d328e173d3ca07e62a4166e5c533f1d64f))
* **149-01:** add alternatives comparison ([d7a942c](https://github.com/szTheory/sigra/commit/d7a942ca094fb544fef3c460af4e909eb10fcb1a))
* **149-01:** add launch announcement narrative ([583ea52](https://github.com/szTheory/sigra/commit/583ea52ff96ebca43a3a091ec48864b43c417099))
* **149-01:** add launch evidence bundle ([ed51883](https://github.com/szTheory/sigra/commit/ed51883e34c6ea960c83f62f90710a2bcac81cce))
* **149-02:** curate AI launch routing ([6451cd8](https://github.com/szTheory/sigra/commit/6451cd898ca278810007513a1fd9fa9f486ee466))
* **149-02:** route launch pack through public docs ([aa3c291](https://github.com/szTheory/sigra/commit/aa3c2919666635b1663e4879525263dc818da73c))
* **64-02:** ConfirmationCodeNotifier + dispatch_confirmation_code/5 ([c7f06d9](https://github.com/szTheory/sigra/commit/c7f06d9268061b2d3be84ae8801e71ed50544057))
* **64-02:** MagicLinkNotifier + dispatch_magic_link/4 ([583e80c](https://github.com/szTheory/sigra/commit/583e80caa12963e3dc77105073ad75b034024d2f))
* **64-02:** scaffold Sigra.Integrations.Chimeway + PendingDelivery ETS ([c2a34b7](https://github.com/szTheory/sigra/commit/c2a34b764255b1508522f33365252135da41d972))
* **admin-ui:** Cmd-K palette overlay CSS + hidden trigger in shell (Stage 7) ([87e9d37](https://github.com/szTheory/sigra/commit/87e9d375de25b61364515c9a1d45aabcfaef1eb1))
* **admin-ui:** inject admin hooks into committed example bundle (Stage 7) ([1452c5f](https://github.com/szTheory/sigra/commit/1452c5fdb75767760ad910cfa6530021459735db))
* **admin-ui:** investigator-shaped audit — outcome select, date range, filter chips, severity pill, teaching empty (Stage 5) ([92abb7c](https://github.com/szTheory/sigra/commit/92abb7ce8185729ca0dff90928bbdc3217085259))
* **admin-ui:** jobs-first needs-led landing launcher + posture strip + capability surface (Stage 2) ([2e5999e](https://github.com/szTheory/sigra/commit/2e5999ee0ce597de09fdf1e6ae117078d7ab4b42))
* **admin-ui:** plain-JS CmdK + CopyToClipboard hooks source + install template (Stage 7) ([ba364d7](https://github.com/szTheory/sigra/commit/ba364d710cc8bc0b81f462a380a09243bfddaf65))
* **admin-ui:** summary-first user detail — security facts strip + risk callout (Stage 4) ([1b2e56c](https://github.com/szTheory/sigra/commit/1b2e56cdacab37ac7675868c1177771ba480af81))
* **admin-ui:** tenant-marked scope chrome + sidebar nouns, fix shell test (Stage 1) ([2ec5dd6](https://github.com/szTheory/sigra/commit/2ec5dd6c7bbbf5d6e77407c25d488b5e8ee851c9))
* **admin-ui:** users-index craft — showing X-Y of Z, applied-filter chips, teaching empty states, truncate+tooltip, richer mobile card (Stage 3) ([628ec60](https://github.com/szTheory/sigra/commit/628ec60488070cb7a6f6debec736afc06daceccb))
* **admin:** Morgan org-admin persona + multi-session seed enrichment (Stage 6) ([425ae1c](https://github.com/szTheory/sigra/commit/425ae1cf7f5d266ee69cb7b617d39ab3dd40c69c))
* **admin:** org member roster + pending-invitations data layer + real org overview (Stage 6) ([c11a784](https://github.com/szTheory/sigra/commit/c11a78488d3d6479b665d9309a93f61c29b59482))


### Bug Fixes

* **134-01:** correct verified API errors in companion-lib recipes ([826e5a0](https://github.com/szTheory/sigra/commit/826e5a0e7a3dacaee59b44a3518c42cab28cf2b9))
* **134-01:** remove auto-linked Sigra.Organizations.add_member/4 from accrue.md ([8ba5893](https://github.com/szTheory/sigra/commit/8ba5893c1bdf5afcb778820e7dce45e0f9088fbc))
* **135-01:** make Threadline forwarder test isolation-safe ([d7e508e](https://github.com/szTheory/sigra/commit/d7e508ee00f0cf2e463363bcdc359495e33d8996))
* **138:** align Sigra.Doctor predicates to canonical config semantics (CR-01, WR-01..WR-06) ([6c936a9](https://github.com/szTheory/sigra/commit/6c936a9a8b32e02d841c200c5b4e73626f565d9f))
* **139:** correct rulestead.md policy example — guard `in` does not compile ([e2a7b7d](https://github.com/szTheory/sigra/commit/e2a7b7d1c4be21a5d16ee1ffabaa3b84518ff959))
* **140-03:** remove broken hidden-function backtick links from doctor.ex and optional_deps.ex moduledocs ([6f60743](https://github.com/szTheory/sigra/commit/6f60743b500ea9ecc95b5bfb66a25244c0474580))
* **141-03:** resolve code-review warnings in demo seeds ([db8961d](https://github.com/szTheory/sigra/commit/db8961d9a602f79a58324b4fe1f946e1229c16ed))
* **143-01:** add Run demo seeds step to CI example_playwright_smoke job ([98818f2](https://github.com/szTheory/sigra/commit/98818f2221962422276e12996243e85359547742))
* **143-01:** grant platform-admin to admin@demo.vaultr.test in SigraAdminPolicy ([4dfd9b8](https://github.com/szTheory/sigra/commit/4dfd9b8c63fd0d3356951e45ab5e9f9e91a9243f))
* **144.1-01:** correct Step 2 comment in demo-showcase.spec.ts — no TOTP challenge (TD-05) ([faf4787](https://github.com/szTheory/sigra/commit/faf4787066a59fdf256d127e7b37e17d22b740fd))
* **144.1-01:** replace stale v0.2.0 tag URLs with v0.2.1 in ga-evidence.md (WR-01 / TD-02) ([f0af6b4](https://github.com/szTheory/sigra/commit/f0af6b441219993eaeaa1f1425002f3dd0be4fd1))
* **144.2:** rename testInfo→_testInfo, fix ga-evidence link, drop ExDoc suppression ([46cbc18](https://github.com/szTheory/sigra/commit/46cbc18c6befd0f30c2186fcac19f490dac3812d))
* **144:** address code review findings CR-01/WR-02/WR-03 ([8943d56](https://github.com/szTheory/sigra/commit/8943d56d89ad55f5dd1b6ed43f91d82465128bb9))
* **145:** address release contract review warnings ([a367c2b](https://github.com/szTheory/sigra/commit/a367c2b3d1b2861cb68ba95c9abc1f54676996fa))
* **145:** align Mailglass deliver arity docs ([5e2b17d](https://github.com/szTheory/sigra/commit/5e2b17daf468c2061d013054b8fcc6913d8f8d43))
* **145:** align remaining Mailglass arity doc ([ba6c79a](https://github.com/szTheory/sigra/commit/ba6c79aaec7f948c21c3774b87b6944bbe042e7b))
* **145:** align unreleased changelog compare base ([df83626](https://github.com/szTheory/sigra/commit/df836264afbe8192cf1fbb5806eec20910ef4ecd))
* **145:** close companion recipe review warnings ([9dceb62](https://github.com/szTheory/sigra/commit/9dceb62e9e88f639e6bf922ab8178ec915468de9))
* **145:** link contract security details ([028e579](https://github.com/szTheory/sigra/commit/028e57965a2980dcf294a85f8420c6354fe96f8a))
* **146:** close release gate review findings ([5d7e318](https://github.com/szTheory/sigra/commit/5d7e318e907a5f9ccf4dd9a83b03a9f0ddd6cd9d))
* **147:** normalize upgrade posture references ([36017c2](https://github.com/szTheory/sigra/commit/36017c25a0c53842c5ee4c97858c8451638fdeb7))
* **147:** retarget upgrade smoke source series truth ([166e6d1](https://github.com/szTheory/sigra/commit/166e6d14a7b1e779c26e81acffe912885e2989a8))
* **147:** revise upgrade smoke planning posture ([c92ecb7](https://github.com/szTheory/sigra/commit/c92ecb712a5f31ee9df532ebbf3acdf80a90f8fe))
* **148:** align doctor exit contract with evaluator docs ([cdc736c](https://github.com/szTheory/sigra/commit/cdc736cd32e709556d96c93dba95c70ee406556d))
* **148:** close llms evaluator title verification gap ([7b2f914](https://github.com/szTheory/sigra/commit/7b2f914229cc93ba5324c9a0891b87da26eef83a))
* **148:** generate llms evaluator showcase title ([10eb29d](https://github.com/szTheory/sigra/commit/10eb29d47159a12f805c1c0e5b2a7d9edde2cf52))
* **149:** address launch review warnings ([df5a324](https://github.com/szTheory/sigra/commit/df5a324e2d0b9fa381db7ba1f258e09f1263ded3))
* **149:** align AI index launch links ([acd0e22](https://github.com/szTheory/sigra/commit/acd0e22b7a433a4a9153150ff06a1e358f82de51))
* **153-01:** make scratch repo teardown idempotent ([7f73b56](https://github.com/szTheory/sigra/commit/7f73b5697309a9c9851a8c8f688b96916c3d19a6))
* **admin-ui:** relabel Cmd-K trigger 'Jump to…' (avoid Search-button collision + UX clarity) + scope-chrome assertion tolerates tenant-marked chip (Stage 8) ([2581fa4](https://github.com/szTheory/sigra/commit/2581fa4ad80a94b3e5235f7dd496c0a033066e84))
* **ci:** compile deps before the dep-off lane removes threadline ([392ee7c](https://github.com/szTheory/sigra/commit/392ee7c3ea5d5cb1d35205af9d680336182eb1f6))
* **demo:** correct Carol org_member metadata to :acme (WR-02) ([bb5d667](https://github.com/szTheory/sigra/commit/bb5d6671ea0c65605788a2f42027af9a518097fc))
* **demo:** use on_conflict: :nothing in upsert_organization/2 (WR-03) ([a70c84b](https://github.com/szTheory/sigra/commit/a70c84b2784f355a64c4a7ae9140617674b85d29))
* **install:** backport org-scoped router opts + Layouts.app wrapper to templates ([6040a8f](https://github.com/szTheory/sigra/commit/6040a8f3f23d1356a131abf7036237085ec808cd))
* **install:** guard enterprise SSO in session_controller behind organizations? ([6e9b42b](https://github.com/szTheory/sigra/commit/6e9b42bf4725c05f0cdb45a7314cdf0a940aecc4))
* **install:** guard local_password_reset_denied? deny clause behind organizations? ([3badc58](https://github.com/szTheory/sigra/commit/3badc58db2d170e95a4938106a36c3add5481a1a))
* **test:** checkout_repo! runs DDL unboxed so admin tables persist on fresh DB ([128e731](https://github.com/szTheory/sigra/commit/128e731fe175c5bf9e631ed070dc3fbc31d4cec8))

## [0.3.0](https://github.com/szTheory/sigra/compare/v0.2.5...v0.3.0) (2026-05-25)

### Added

* **passkeys:** Added `Sigra.Passkeys.delete_with_posture/4` and `Sigra.Passkeys.DeleteResult` so hosts can distinguish ordinary passkey deletion from last-passkey recovery posture without re-querying state.

### Changed

* **passkeys:** Generated-host settings and controller flows now encode passkey credential IDs in forms and routes, decode them on the server side, and surface clearer last-passkey deletion guidance after the delete completes.
* **auth:** Confirmation-link issuance now stores the hash of the transported confirmation token string, so `confirm_user/3` can successfully look up valid emailed confirmation links after HMAC verification.
* **passkeys:** Generated confirmation and MFA recovery flows now redirect and message users more honestly when bootstrapping a first passkey or recovering from a canceled, timed-out, or unsupported browser ceremony.

### Fixed

* **generator:** `--no-passkeys` installs no longer leak passkey bootstrap helpers or warning-cleanliness regressions into generated apps.
* **ci:** Release-gate coverage and generator fixtures now align with the encoded passkey-id and delete-posture behavior shipped in the library and templates.

### Roadmap traceability

* Planning milestone **v1.26 PK-LIFECYCLE** (phases **115–121**) shipped on **2026-05-25**; see [`.planning/milestones/v1.26-ROADMAP.md`](https://github.com/szTheory/sigra/blob/main/.planning/milestones/v1.26-ROADMAP.md), [`.planning/milestones/v1.26-REQUIREMENTS.md`](https://github.com/szTheory/sigra/blob/main/.planning/milestones/v1.26-REQUIREMENTS.md), and [`.planning/milestones/v1.26-MILESTONE-AUDIT.md`](https://github.com/szTheory/sigra/blob/main/.planning/milestones/v1.26-MILESTONE-AUDIT.md).

## [Unreleased]

### Template Updates Required

When generator templates change, maintainers list the required upgrade command here. Adopters should run:

```bash
mix deps.update sigra
mix sigra.upgrade --yes
```

### Documentation

- **Architecture learning path:** Added complementary outside-in architecture and inside-out code walkthrough guides for adopters and maintainers, including the generated-host ownership boundary, durable session model, and current implementation seams.
- **Hex 1.0.0 launch pack:** Added `docs/launch/v1.0/announcement.md`, `docs/launch/v1.0/alternatives.md`, and `docs/launch/v1.0/evidence.md` as the canonical launch narrative, alternatives comparison, and compact evidence bundle for the public 1.0 release path.
- **Hex 1.0.0 release guidance:** GitHub Release, README, HexDocs, and AI-consumption routing should point to `docs/launch/v1.0/announcement.md` as the source for who should upgrade now, who should wait, and where proof lives.
- **Mailglass integration posture (v1.29 DOC-01):** Sigra ships no library-resident Mailglass adapter and no `--with-mailglass` installer flag. The supported integration posture is recipe-only host-owned wiring: the host implements `Sigra.Mailer` and delegates to a Mailglass-backed module. See `guides/recipes/companion-libs/mailglass.md` for the current supported configuration.
- **v1.0 adopter routing:** Existing pre-1.0 adopters should start with `guides/introduction/upgrading-to-v1.0.md` for the historical v1.0 cutover flow.
- **Migration lane (`phx.gen.auth`):** Existing `phx.gen.auth` teams should use `guides/introduction/migrating-from-phx-gen-auth.md` for boundary-first migration guidance.
- **Migration lane (Pow/Guardian/Ueberauth):** Existing Pow/Guardian/Ueberauth teams should use `guides/introduction/migrating-from-pow-guardian-ueberauth.md` for boundary-first migration guidance.

### Changed

- **BREAKING (installer):** Postgres installs now put Sigra-owned auth tables in the `auth` schema by default. Pass `--auth-prefix public` to intentionally generate the previous public-schema placement; MySQL and SQLite remain unprefixed.

## [0.2.5](https://github.com/szTheory/sigra/compare/v0.2.4...v0.2.5) (2026-04-25)

### Changed

* **mfa:** When `:audit_schema` is configured, `Sigra.MFA.confirm_enrollment/5` writes `mfa.enroll.failure` for invalid TOTP (pre-enrollment DB work) inside `Repo.transaction/1` via `Ecto.Multi` + `Sigra.Audit.log_multi_safe/3`, using the same `commit_ad_hoc_mfa_audit/5` shell as other MFA ad-hoc audits (**AUD-20-01** / **AUD-04-022**). The caller still receives `{:error, :invalid_code}` regardless of audit insert outcome; audit failures emit `[:sigra, :audit, :log_safe_error]`. Evidence: `test/sigra/mfa_audit_atomicity_test.exs`.
* **jwt:** When `:audit_schema` is configured, `Sigra.JWT.refresh/3` (and `Sigra.Auth.refresh_jwt/2`) runs refresh-token **`user_tokens`** persistence and `api.jwt_refresh` / `api.jwt_refresh_reuse` audit inserts in a single `Repo.transaction/1` via `Ecto.Multi` + `Sigra.Audit.log_multi_safe/3` (persistence + audit co-fate / **AUD-08** for the guided path). Any step failure in that transaction returns `{:error, :jwt_refresh_aborted}` instead of issuing new tokens without a matching audit row. Evidence: `test/sigra/jwt_refresh_audit_cofate_test.exs`.
* **jwt:** Refresh-token classify/revoke paths now base64url-decode the raw refresh token before hashing, so malformed or non-decodable inputs return `{:error, :invalid_token}` instead of hashing the encoded wrapper bytes.
* **audit:** When `:audit_schema` is configured, `Sigra.APIToken.audit_jwt_refresh/2` and `audit_jwt_refresh_reuse/2` write `api.jwt_refresh` / `api.jwt_refresh_reuse` inside `Repo.transaction/1` via audit-only `Ecto.Multi` + `Sigra.Audit.log_multi_safe/3` (audit-row atomicity only — standalone helpers; prefer `JWT.refresh/3` for co-fate so audit is not double-emitted).
* **audit:** When `:audit_schema` is configured, `Sigra.Account.clear_password_change_requirement/3` clears `must_change_password` and writes `account.password_change` (`metadata: %{forced: true}`) in one `Repo.transaction/1` via `Ecto.Multi` + `Sigra.Audit.log_multi_safe/3`. `Sigra.Account.audit_forced_password_change/2` is deprecated for that path — do not call both or you may duplicate audit rows.
* **audit:** When `:audit_schema` is configured, `Sigra.APIToken.verify/2` now writes `api.token_verify.failure` audit rows inside `Repo.transaction/1` via `Ecto.Multi` + `Sigra.Audit.log_multi_safe/3` (invalid, revoked, and expired branches). Success remains telemetry-only (**D-27**). Insert failures emit `[:sigra, :audit, :log_safe_error]` (`:invalid_changeset` or `:constraint_violation`) while the caller still receives `{:error, reason}`.

### Documentation

* **planning:** Milestone **v1.19** (phase **83**, **AUD-20**) — **AUD-04-022** + **EX-44-02** appendix, **09-VERIFICATION** C-1 row **022**, **09-03-SUMMARY**, **44-AUD-04-INVENTORY** for **`Sigra.MFA.confirm_enrollment/5`** invalid-code transactional audit. See [`.planning/phases/83-mfa-confirm-enrollment-022/83-VERIFICATION.md`](https://github.com/szTheory/sigra/blob/main/.planning/phases/83-mfa-confirm-enrollment-022/83-VERIFICATION.md).
* **planning:** Milestone **v1.19** (phase **82**, **AUD-19**) — **AUD-04-048** / **049** + **09-VERIFICATION** C-1 rows, **44**/**45** inventories, **09-03-SUMMARY** for **`Sigra.JWT.refresh/3`** persistence + audit co-fate; **AUD-08** closure for guided **`JWT.refresh`** path. See [`.planning/phases/82-jwt-refresh-persistence-audit-cofate/82-VERIFICATION.md`](https://github.com/szTheory/sigra/blob/main/.planning/phases/82-jwt-refresh-persistence-audit-cofate/82-VERIFICATION.md).
* **planning:** Milestone **v1.18** (phase **81**, **AUD-18**) — **AUD-04-048** / **049** + **09-VERIFICATION** C-1 rows, **44**/**45** inventories, **09-03-SUMMARY** note for transactional JWT refresh/reuse audit in **`lib/sigra/api_token.ex`**; **AUD-08** explicitly out of scope. See [`.planning/phases/81-jwt-refresh-audit-atomicity/81-VERIFICATION.md`](https://github.com/szTheory/sigra/blob/main/.planning/phases/81-jwt-refresh-audit-atomicity/81-VERIFICATION.md).
* **planning:** Milestone **v1.17** (phase **80**, **AUD-17**) — **AUD-04-043** / **EX-44-05** closure: **44-AUD-04-INVENTORY**, **09-VERIFICATION** C-1 row **043**, **09-03-SUMMARY** note; forced-clear audit atomicity in **`lib/sigra/account.ex`**. See [`.planning/REQUIREMENTS.md`](https://github.com/szTheory/sigra/blob/main/.planning/REQUIREMENTS.md).
* **planning:** Milestone **v1.16** (phase **79**, **AUD-16**) — **44-AUD-04-INVENTORY** + **09-VERIFICATION** C-1 rows **AUD-04-044..046** aligned to transactional **`verify/2`** in **`lib/sigra/api_token.ex`**; **09-03-SUMMARY** bounded-batch note; **EX-44-01** verify slice retired. See [`.planning/REQUIREMENTS.md`](https://github.com/szTheory/sigra/blob/main/.planning/REQUIREMENTS.md) and [`.planning/phases/79-api-token-verify-failure-audit/79-VERIFICATION.md`](https://github.com/szTheory/sigra/blob/main/.planning/phases/79-api-token-verify-failure-audit/79-VERIFICATION.md).
* **planning:** Milestone **v1.15** (phase **78**, **AUD-14**) — **44-AUD-04-INVENTORY** + **09-VERIFICATION** C-1 rows for **AUD-04-035..042** and **047** aligned to **`lib/sigra/account.ex`** / **`lib/sigra/api_token.ex`**; **09-03-SUMMARY** bounded-batch note. See [`.planning/phases/78-account-api-c1-planning-truth/78-VERIFICATION.md`](https://github.com/szTheory/sigra/blob/main/.planning/phases/78-account-api-c1-planning-truth/78-VERIFICATION.md).

### Added

* **tests:** `test/sigra/jwt_refresh_audit_cofate_test.exs` covers **`Sigra.JWT.refresh/3`** persistence + audit co-fate (happy path, audit-off, reuse + audit, **`CHECK`** fault injection on happy and reuse branches).
* **tests:** `test/sigra/api_token_audit_atomic_test.exs` covers **`api.jwt_refresh`** / **`api.jwt_refresh_reuse`** (happy path, audit-off, **`CHECK`** fault injection + **`log_safe_error`** telemetry).
* **tests:** `test/sigra/api_token_audit_atomic_test.exs` covers **`api.token_verify.failure`** for invalid / revoked / expired paths plus audit-table fault injection (constraint / telemetry parity).
* **tests:** `test/sigra/account_audit_atomicity_test.exs` exercises **`Sigra.Account.request_email_change/4`**, **`confirm_email_change/3`**, and **`cancel_email_change/3`** with Postgres `CHECK` fault injection so domain mutations roll back when the paired **`account.email_change_*`** audit insert is rejected — complements **AUD-04-035..037** C-1 evidence alongside **`change_password`**.
* **tests:** `test/sigra/account_audit_atomicity_test.exs` covers **`Sigra.Account.clear_password_change_requirement/3`** (happy path, audit-off branch, and **`account.password_change`** `CHECK` rollback) for **AUD-04-043** / **AUD-17**.

## [0.2.4](https://github.com/szTheory/sigra/compare/v0.2.3...v0.2.4) (2026-04-24)

### Changed

* **audit:** `Sigra.MFA.audit_backup_codes_regenerate/3` and `Sigra.MFA.audit_trust_browser/2` now emit audit rows via `Ecto.Multi` + `Sigra.Audit.log_multi_safe/3` inside `Repo.transaction/1` when `:audit_schema` is configured (bounded **SEED-002** closure for **AUD-04-033** / **AUD-04-034**; **`regenerate_backup_codes/4`** remains the authoritative rotation path).

### Fixed

* **audit:** `commit_ad_hoc_mfa_audit/5` rescues `Ecto.ConstraintError` (and related DB constraint failures) when the audit insert is rejected at the database layer without a matching changeset constraint, preserving `log_safe/3`-class behavior: emit `[:sigra, :audit, :log_safe_error]` with `reason: :constraint_violation` and return `:ok`.

### Documentation

* **planning:** **v1.11** adoption stabilization — triage notes (`.planning/v1.11-TRIAGE.md`), **`upgrading-to-v1.11.md`**, ExDoc extras, intro upgrade cross-links, and **`MAINTAINING.md`** milestone pause guidance (**STAB-01**..**STAB-04**).
* **planning:** **v1.12** trust bundle — [upgrading-to-v1.12.md](guides/introduction/upgrading-to-v1.12.md) (ExDoc extra), [docs/uat-ci-coverage.md](docs/uat-ci-coverage.md) (**v1.12 launch evidence** subsection), and [milestone UAT index](https://github.com/sztheory/sigra/blob/main/.planning/v1.12-UAT-EVIDENCE.md) on GitHub (**TRN-01**..**TRN-03** doc polish).

### Roadmap traceability

* Planning milestone **v1.14** (phase **77**, **AUD-13**) — operator-trust slice for MFA ad-hoc audit atomicity; see [`.planning/milestones/v1.14-ROADMAP.md`](https://github.com/szTheory/sigra/blob/main/.planning/milestones/v1.14-ROADMAP.md).

## [0.2.3](https://github.com/szTheory/sigra/compare/v0.2.2...v0.2.3) (2026-04-23)


### Bug Fixes

* **ci:** document RELEASE_PLEASE_TOKEN for downstream CI on release PRs ([#24](https://github.com/szTheory/sigra/issues/24)) ([324b036](https://github.com/szTheory/sigra/commit/324b03652a9da5c8c0332ddc4193a716acf5e175))

## [0.2.2](https://github.com/szTheory/sigra/compare/v0.2.1...v0.2.2) (2026-04-23)


### Bug Fixes

* **hex:** shorten Hex package description (300 char limit) ([#22](https://github.com/szTheory/sigra/issues/22)) ([3d8acfe](https://github.com/szTheory/sigra/commit/3d8acfed1d0cf7530454a8ef151f91e12ebbbe4c))

## [0.2.1](https://github.com/szTheory/sigra/compare/v0.2.0...v0.2.1) (2026-04-23)


### Features

* **053-01:** add Hex docs link and ExDoc publish reminder ([3362bf0](https://github.com/szTheory/sigra/commit/3362bf00ffdb7d3b0b3ee97398343ee3a025ae57))
* **053-01:** refresh Hex description for PUB-01 ([acd275e](https://github.com/szTheory/sigra/commit/acd275e8668d8159558efe87a80715de2f53ebea))
* **06-01:** add MFA deps, config, error types, and Credential struct ([52a25f4](https://github.com/szTheory/sigra/commit/52a25f481cca702865d1c59a48612725da2cc541))
* **06-01:** implement MFA orchestrator, BackupCodes, Trust, and Lockout modules ([e913806](https://github.com/szTheory/sigra/commit/e91380623f7e30fd0d10f866c30d0f6ca847b349))
* **06-02:** add MFA-aware authenticate flow and complete_mfa_verification ([db192a1](https://github.com/szTheory/sigra/commit/db192a12a75f5071cad1a75d9676b4ac211bbaff))
* **06-02:** add RequireMFA and RequireMFAEnrolled plugs with mfa_pending session type ([d3bb45b](https://github.com/szTheory/sigra/commit/d3bb45b204f5249e6e29c9b9071d28b1e5c4fb26))
* **06-03:** add MFA telemetry event catalog and integration ([826945c](https://github.com/szTheory/sigra/commit/826945c89965086cf727d6099f312b7670271040))
* **06-03:** add MFA testing helpers and TokenCleanup mfa_pending extension ([bf17b7c](https://github.com/szTheory/sigra/commit/bf17b7cc6d4565b9a5850bd820d26e58dd0577d9))
* **06-04:** add MFA email templates, Auth context delegation, and test fixtures ([8a93edb](https://github.com/szTheory/sigra/commit/8a93edb8efc898a3c6101bede287195a9a893f35))
* **06-04:** add MFA migration tables and generated Ecto schemas ([e66b8f4](https://github.com/szTheory/sigra/commit/e66b8f4f8910f9f77c0a46fbf20333e4624b994d))
* **06-05:** add MFA challenge page templates (controller + HTML + LiveView) ([8efd59d](https://github.com/szTheory/sigra/commit/8efd59d8702053f86538888d7099ffc64895630c))
* **06-05:** add MFA settings templates, require_mfa plug, and generator wiring ([89cc608](https://github.com/szTheory/sigra/commit/89cc608abd24ff95c48df73e94bc52d7353184ea))
* **07-01:** APIToken module and RequireScopes plug with full test coverage ([953adbe](https://github.com/szTheory/sigra/commit/953adbeccb6da292ce3563459a780d7e47b02d96))
* **07-01:** config extensions, StringList type, ScopeRegistry, error types, telemetry events ([e1e0e39](https://github.com/szTheory/sigra/commit/e1e0e39d2624a9aadd5d92f2023219bd29602a0e))
* **07-02:** add Joken dependency, ClaimsBuilder behaviour, and Signer module ([8c79f0c](https://github.com/szTheory/sigra/commit/8c79f0cdbd509216ae3b09a709e02ae68e25209d))
* **07-02:** add JWT module and RefreshToken with family-based reuse detection ([2d00c6e](https://github.com/szTheory/sigra/commit/2d00c6ec26c93415225f7316794d4cdb9c592486))
* **07-03:** add Auth delegation, TokenCleanup extension, Testing helpers, Email notification ([611e5f6](https://github.com/szTheory/sigra/commit/611e5f64c3656ce1230f3973c39400bdc2a8e1e8))
* **07-03:** rewrite FetchBearer with auto-detection and scope assignment ([425527a](https://github.com/szTheory/sigra/commit/425527ab56af1c6a631201d33e08801660f7af25))
* **07-04:** add API controllers, email template, injector, and install task ([86f9be4](https://github.com/szTheory/sigra/commit/86f9be436ce28faa624f1dd88c417785c8b2f3be))
* **07-04:** add API token migration and schema templates ([9b13525](https://github.com/szTheory/sigra/commit/9b13525e81639e54afa9e40c5e6678d671b4761f))
* **08-01:** add config extensions, email templates, and data export behaviour ([cd3ef15](https://github.com/szTheory/sigra/commit/cd3ef15aa504e82044ba3520d486779d8133df91))
* **08-01:** implement hooks engine with Ecto.Multi integration and tests ([b635995](https://github.com/szTheory/sigra/commit/b6359959ef0b62092d1ca2281159e24af8a1e24d))
* **08-02:** add Account orchestrator with unified delegation API ([44ea30a](https://github.com/szTheory/sigra/commit/44ea30a145fe27ead2399d2acaeca4770e5e0a80))
* **08-02:** implement Account Deletion module with 3 strategies ([cd31c37](https://github.com/szTheory/sigra/commit/cd31c3791fa1e9c6cd3ee5555ccd26d45a5d759b))
* **08-02:** implement EmailChange and PasswordChange modules ([601d35f](https://github.com/szTheory/sigra/commit/601d35f685f62fc84997359ee96976b78bc395b9))
* **08-03:** add telemetry events and Auth module lifecycle delegation ([34e6f2b](https://github.com/szTheory/sigra/commit/34e6f2bca6d1d940a0e170dc460f7cf2227cacbf))
* **08-03:** implement RequirePasswordChange plug and AccountDeletion Oban worker ([6c26dce](https://github.com/szTheory/sigra/commit/6c26dce53b1d6579db9d5d1c5cec29f3bfc467d0))
* **08-04:** add 7 account lifecycle email templates ([36363df](https://github.com/szTheory/sigra/commit/36363df8cbe1f32cf65dec2b89ef6dbd5f307b04))
* **08-04:** auth context lifecycle delegation and hooks stub module ([ada92fb](https://github.com/szTheory/sigra/commit/ada92fb0835d9485a032420a2e823f88aae90efe))
* **08-04:** migration template, user schema, and token TTL for account lifecycle ([21332d3](https://github.com/szTheory/sigra/commit/21332d317ead108dbc8509fd0437e8f82b9c5ef1))
* **08-05:** add generator injector for lifecycle routes, plugs, and tests ([ba5d3c5](https://github.com/szTheory/sigra/commit/ba5d3c5ffd52916a015b6db9902016eed2233e09))
* **08-05:** add settings LiveView, reactivation page, and lifecycle testing helpers ([61112c9](https://github.com/szTheory/sigra/commit/61112c9a6ea5b28791a3dd9500bbcf8433c8c900))
* **09-01:** add audit_events migration template ([02ae340](https://github.com/szTheory/sigra/commit/02ae34012c30d0aabc216edd8c5be2589c84a35a))
* **09-01:** add AuditEvent schema template and wire install task ([bd3f69f](https://github.com/szTheory/sigra/commit/bd3f69fca23b00dcff6a64fcbf835e6073ad1297))
* **09-02:** add Sigra.Audit changeset, cursor, query submodules ([01f75de](https://github.com/szTheory/sigra/commit/01f75deb86d1986c10c4c21f9097a8acf792abec))
* **09-02:** add Sigra.Audit public API ([ce6dc7c](https://github.com/szTheory/sigra/commit/ce6dc7cfc8f11d95d709cf26ac8497730ad1853a))
* **09-03:** integrate audit logging into auth + session + security subsystems ([0724d96](https://github.com/szTheory/sigra/commit/0724d96f2d4cc3250b4358c3f7ae598dd951fabb))
* **09-03:** integrate audit logging into mfa + oauth + api_token + account ([68e222c](https://github.com/szTheory/sigra/commit/68e222cf2eabdbf30d02eea78167a810dc7ac709))
* **09-04:** add Sigra.Workers.AuditCleanup Oban worker and startup warning ([a01a25c](https://github.com/szTheory/sigra/commit/a01a25c451ed5f8512cf9607ab0628e556cd3514))
* **10-01:** add audit test helpers and section headers to Sigra.Testing ([d891e2b](https://github.com/szTheory/sigra/commit/d891e2beb442d19d77522f9fdf0b3958465eba8b))
* **10-02:** add scenario fixtures to AuthFixtures template ([24ecd7c](https://github.com/szTheory/sigra/commit/24ecd7ce73c340641419d984f4506f02ad5bbe69))
* **10-03:** add :cookie_domain config + Sigra.MFA.Trust.cookie_opts/1 ([080fd4f](https://github.com/szTheory/sigra/commit/080fd4f277a833213904a36ac8501bcd571d9fea))
* **10-03:** runtime remember_me_options in UserAuth + MFA trust cookie + boot warning ([4aa7030](https://github.com/szTheory/sigra/commit/4aa703073f8c2d5de480eff8f4eab54a8412e1aa))
* **10-05:** add pure helpers + doctests to Config/Auth/Testing ([fa57f1e](https://github.com/szTheory/sigra/commit/fa57f1efa0c5cdc117f839a52a0eabe3362da773))
* **10-06:** scaffold test/example Phoenix app with Sigra installed ([2f1790e](https://github.com/szTheory/sigra/commit/2f1790e8f95a0c0e9330714a65cb812f8912c532))
* **10.1.1-03:** unify example app on Sigra canonical user_sessions store (B6, D-06/D-07) ([ddf7b94](https://github.com/szTheory/sigra/commit/ddf7b94ebed5063bb1d5cddaed0b85e01bbd57b8))
* **10.1.1-05:** flip installer default to binary_id (uuid) PKs (D-10) ([d1d2c40](https://github.com/szTheory/sigra/commit/d1d2c4047562f7e6a5049bfa79b80de57fe4644a))
* **10.1.1-06:** add --yes non-interactive flag to sigra.install ([2b15e81](https://github.com/szTheory/sigra/commit/2b15e81aef87fa7de3fcd0b5773ae2d0c3876cce))
* **10.1.1-06:** add install_smoke + example_http_smoke CI jobs ([ae37e78](https://github.com/szTheory/sigra/commit/ae37e787c1ab48fa0b4b652dab6af477b7db1157))
* **10.1.1-06:** add install-smoke.sh and http-smoke.sh CI drivers ([c082ab3](https://github.com/szTheory/sigra/commit/c082ab38301d3957e2ed15d056d051011e60f085))
* **10.1.1-07:** add data-testid hook to MFA TOTP secret ([7dd8e25](https://github.com/szTheory/sigra/commit/7dd8e25961b16bf25a1b2608646f39c29a77a4f7))
* **10.1.1-07:** scaffold Playwright golden-path browser smoke harness ([24e8c7c](https://github.com/szTheory/sigra/commit/24e8c7c9524ee89b20308b7820da6cc9d0fa113b))
* **41:** TOTP-gated backup code rotation and GA-01 regression ([e5f399e](https://github.com/szTheory/sigra/commit/e5f399e2d2600c61d5b956ea8fc49d7372e05efc))
* **43-02:** atomic auth.register.success audit via register_user_multi ([d2e6efb](https://github.com/szTheory/sigra/commit/d2e6efbe2f247d7ccb8403ff2415340ed4290a4c))
* **43-03:** atomic magic-link and password-reset request audits via Multi ([149ab89](https://github.com/szTheory/sigra/commit/149ab89c934f8ea8f26540cf338ab0a293d2ac8f))
* **43-04:** atomic auth.login.success audit with lockout Multi ([3bc7811](https://github.com/szTheory/sigra/commit/3bc7811aa444d4b6e9cfc0aa9826a03753521263))
* **49-01:** add mix ci.audit_45 alias for AUD-08 merge gate ([3adb5fe](https://github.com/szTheory/sigra/commit/3adb5fe122fc03136f210e89d818de893102999e))
* **50-01:** add mix ci.install_golden alias for install golden tests ([ba8ca30](https://github.com/szTheory/sigra/commit/ba8ca3065f590213a3adf587c3d7d303290e353e))
* **audit:** add audit_multi_step for multi-row Multi audits ([a642496](https://github.com/szTheory/sigra/commit/a642496d1990e77ed558e22b8257b97ac802ab07))
* **mfa:** atomic audit Multis for AUD-06 (MFA) ([3d5abf1](https://github.com/szTheory/sigra/commit/3d5abf112403cd71f2236c53538633ef0165e58c))
* **uat:** add Docker UAT environment + runbook for milestone v1.0 manual gates ([812eca0](https://github.com/szTheory/sigra/commit/812eca0734787484669cd3ce9fad18c39932741d))


### Bug Fixes

* **05:** enforce sudo mode on link_provider and unlink_provider (T-05-12) ([802b2da](https://github.com/szTheory/sigra/commit/802b2daf269812c069db6c989c4d89e2c38c7801))
* **05:** WR-04 remove dead code branch in detect_context_name ([77f61b5](https://github.com/szTheory/sigra/commit/77f61b5dee3b5da1cd347677eee91d3b8a413e14))
* **05:** WR-05 document encrypted_* field naming convention in get_tokens ([fa53680](https://github.com/szTheory/sigra/commit/fa5368071cfb8f834710eab00590e9eb59ed18bc))
* **06:** add Code.ensure_loaded! to function_exported? tests for isolation safety ([61826f8](https://github.com/szTheory/sigra/commit/61826f8b9702ace1d1658d107ac22efd5a644110))
* **06:** add settings_url binding to email template test for MFA emails ([86f9759](https://github.com/szTheory/sigra/commit/86f9759eb424b129ee8cd362c71bda90e90105b0))
* **06:** correct struct syntax for Ecto.Changeset.cast in MFA enrollment ([b968a86](https://github.com/szTheory/sigra/commit/b968a8672802cb2bb408f83fc0bbbbd04cb69def))
* **06:** CR-01 use Ecto cast to trigger cloak_ecto encryption for TOTP secrets ([3c74dc8](https://github.com/szTheory/sigra/commit/3c74dc83c52c523de572caa2da3ae2d216d33af8))
* **06:** CR-02 eliminate modulo bias in backup code and confirmation code generation ([66f1d3b](https://github.com/szTheory/sigra/commit/66f1d3b53e1758a29c256aa672de620be6e525d8))
* **06:** WR-01 wrap MFA enrollment and cleanup in Ecto.Multi transactions ([41b3899](https://github.com/szTheory/sigra/commit/41b3899434f479f3627cba9389a036e5e021e81a))
* **06:** WR-02 combine lockout increment and lock into single atomic query ([59f6d78](https://github.com/szTheory/sigra/commit/59f6d78440d2f96c64666f7a5cc34c9cf692647d))
* **06:** WR-03 align MFA pending state checks between controller, LiveView, and library plugs ([84fd485](https://github.com/szTheory/sigra/commit/84fd4856a006ae071551a9aae4ef9a95a7738e74))
* **06:** WR-04 add missing settings_url binding for mfa_disabled_email template ([a73c46a](https://github.com/szTheory/sigra/commit/a73c46a9ef0aabc5d68655be6e1d3252d49decc0))
* **06:** WR-05 pass required options to setup_totp and simulate_mfa_lockout in fixtures ([d8bf183](https://github.com/szTheory/sigra/commit/d8bf183bb1dc7120915d33d41953e6f59ebed56a))
* **06:** WR-06 handle trailing slashes in RequireMFA path comparison ([c1f5e89](https://github.com/szTheory/sigra/commit/c1f5e89b24248e2d124219617296587e9ba73b6e))
* **07:** revise plans based on checker feedback ([2fd57a5](https://github.com/szTheory/sigra/commit/2fd57a502c18ace9d4dcdaf0de20593917c7cdad))
* **08-05:** update migration test to match partial unique index from Plan 04 ([6037d26](https://github.com/szTheory/sigra/commit/6037d26437d4dfcbafb2f106f9586e584a1113bb))
* **08:** CR-01 add missing callback fns to email change request and cancel flows ([befa404](https://github.com/szTheory/sigra/commit/befa4046fb52b63658aa5c494a5205abadf5c824))
* **08:** CR-02 add missing callback fns to email change confirm flow ([d8f7d08](https://github.com/szTheory/sigra/commit/d8f7d08a632b0f78aac76e7d6701d21595d75b4c))
* **08:** CR-03 add missing validate_password_fn to password change flow ([9903b78](https://github.com/szTheory/sigra/commit/9903b783f5190fb6a7b7e21f6c492637be10b913))
* **08:** WR-01 execute hook multi instead of discarding it ([4152725](https://github.com/szTheory/sigra/commit/4152725b822dd861f08fdf1b6db1f1b224da3c25))
* **08:** WR-02 document TTL-based cleanup for orphaned email change tokens ([5285e68](https://github.com/szTheory/sigra/commit/5285e6867a7f276bc2e81ada4a9807be5aa0767e))
* **08:** WR-03 include email and hashed_password in deletion_changeset for anonymize strategy ([6b775d0](https://github.com/szTheory/sigra/commit/6b775d0039293b6d64c61b9f4ed0b1c3e4ba55ea))
* **08:** WR-04 validate deletion strategy against known values with safe default ([debe7fc](https://github.com/szTheory/sigra/commit/debe7fc525d76c999d9d19b88a2af38e977e23d1))
* **09:** CR-01 harden validate_metadata_size against non-map and unencodable metadata ([58120a9](https://github.com/szTheory/sigra/commit/58120a91ed72177efe4f4840f164634e8d429a10))
* **09:** WR-02 raise in Sigra.Audit.stream/2 when repo.stream/1 is unavailable ([78a3474](https://github.com/szTheory/sigra/commit/78a3474545b20d4482419b41d6eee5b76bcb18ea))
* **09:** WR-06 WR-07 honor configured retention and batch cleanup deletes ([065076f](https://github.com/szTheory/sigra/commit/065076f04802409b32d82f8d8a19ca4a977e382c))
* **09:** WR-08 WR-01 sanitize log_safe error telemetry + surface missing repo ([41ec4a0](https://github.com/szTheory/sigra/commit/41ec4a084aae93dc01a0978d9e3feb46dd6e0123))
* **10-review:** CR-01 guard Mix.env() in generated UserAuth remember_me_options ([7a922e7](https://github.com/szTheory/sigra/commit/7a922e728a9151da8b23713080394efb4a412151))
* **10-review:** WR-01 correct MFA guide function references ([fc43f52](https://github.com/szTheory/sigra/commit/fc43f527277b79cc187ca1c7a54f3e10ee9625a2))
* **10-review:** WR-02 preserve false/nil in assert_audit_event metadata lookup ([138777c](https://github.com/szTheory/sigra/commit/138777cfde7cd41fbc6a72011e2a53dec923ea1e))
* **10-review:** WR-03 make Sigra.MFA.Trust.cookie_opts/0 raise to prevent silent cookie_domain drop ([009d424](https://github.com/szTheory/sigra/commit/009d4240fdb5d55d9f7d81da8ee5244e3a9212d0))
* **10-review:** WR-04 oauth_enabled? requires at least one configured provider ([1aae029](https://github.com/szTheory/sigra/commit/1aae029d4b93e014e080885d4937486be71e9efd))
* **10.1 IN-01,IN-02:** robust migration timestamp offsets and pad/1 cleanup ([8d031be](https://github.com/szTheory/sigra/commit/8d031be142e4e26ce47c07a4e5e920e44e0b1071))
* **10.1 IN-03:** route password reset through Sigra.Auth.reset_password/4 ([90d7adb](https://github.com/szTheory/sigra/commit/90d7adbc8de4a5c438c6a4dae934b8ded92194ab))
* **10.1 IN-05:** stop passing :secret_key_base to verify_confirmation_code/3 ([7eef6d8](https://github.com/szTheory/sigra/commit/7eef6d88567a2e2894069e033eeaefbc0663d417))
* **10.1 IN-06 follow-up:** move helper after handle_event clauses to satisfy --warnings-as-errors ([d64177f](https://github.com/szTheory/sigra/commit/d64177f163b2f867fe786d1b4872e84d58b8075a))
* **10.1-01:** build proper UserToken structs in request_password_reset and request_magic_link ([10c7cf9](https://github.com/szTheory/sigra/commit/10c7cf9be31d28e50d42a37a17091a7fef771788))
* **10.1-02:** backport installer template fixes [#1](https://github.com/szTheory/sigra/issues/1)-8 ([0ab0d04](https://github.com/szTheory/sigra/commit/0ab0d043b573a13a9f5cfdb03c242a202a6c94e8))
* **10.1-02:** backport installer template fixes [#9](https://github.com/szTheory/sigra/issues/9)-16 ([b19bdf3](https://github.com/szTheory/sigra/commit/b19bdf3c58cbac2920427bcd14f51ece152210fa))
* **10.1-03:** eliminate mix docs --warnings-as-errors `@doc` reference warnings ([b1f49d3](https://github.com/szTheory/sigra/commit/b1f49d39d0bd7bd76c6cecf077a678243b0f2478))
* **10.1-05:** scenario/2 raises ArgumentError with valid atoms on unknown scenarios ([95987e2](https://github.com/szTheory/sigra/commit/95987e239f6b544af2ac39b6549ae82f90995a16))
* **10.1-06:** delete aspirational cursor_portability_test ([182edbf](https://github.com/szTheory/sigra/commit/182edbfc87eee7acb6d7534607ef365cf0e929aa))
* **10.1-06:** generator_reset_test stale alias assertion ([81d66fd](https://github.com/szTheory/sigra/commit/81d66fd5354de24fa048ddb9e14081c681735a64))
* **10.1-06:** sigra.install_test bindings — stale after plan 10.1-02 ([32dbae1](https://github.com/szTheory/sigra/commit/32dbae1175107ba8dee7c7253dba4e73d17cfc08))
* **10.1.1-02:** fix /users/sudo KeyError on render (B7, D-08) ([388856f](https://github.com/szTheory/sigra/commit/388856fe1e7810fa1b231ad30de97065280a2caa))
* **10.1.1-02:** wire confirmation email in RegistrationLive (B5, D-05) ([fbdc743](https://github.com/szTheory/sigra/commit/fbdc743bb31360afb8c6601296506a346ec6a75b))
* **10.1.1-04:** replace LoginLive with plain SessionController + SessionHTML (B9/D-12) ([ba66d76](https://github.com/szTheory/sigra/commit/ba66d76a094d361f874b502c0e37dd310f8896dd))
* **10.1.1-05:** flip test/example to uuid PKs end-to-end (B8 root fix) ([949f182](https://github.com/szTheory/sigra/commit/949f1829bc1e5c2ccdfcac75447c36924f592fa3))
* **10:** revise plans per checker iteration 1 feedback ([c70ec28](https://github.com/szTheory/sigra/commit/c70ec28eb22ba699306043b9cda4220c166a84bc))
* **44:** document APIToken.revoke/2 changeset error in typespec ([8df3957](https://github.com/szTheory/sigra/commit/8df395749ef8380dba20d23bd806fac2594cc8da))
* **49-01:** scope ci.audit_45 to one multi-path mix test ([c658a74](https://github.com/szTheory/sigra/commit/c658a745826623e79ce1c3eef8e90cc5ff8a8647))
* **docs:** include Nyquist matrix extra for ExDoc link validation ([cac5a01](https://github.com/szTheory/sigra/commit/cac5a01188943f2e6ab864edfce6cf58bacbf0b4))
* **example:** JS bundle + endpoint socket + router auth pipeline ([58b7122](https://github.com/szTheory/sigra/commit/58b7122df97529a9604e06ea1b18071fb021785e))
* **mfa:** correct Ecto.Multi.merge arity for lockout audit Multis ([09e2263](https://github.com/szTheory/sigra/commit/09e22637898512404ac7c81d1e488685d8215699))
* **MFA:** handle cleanup Multi errors in disable flows ([2e1d309](https://github.com/szTheory/sigra/commit/2e1d30936b7ab4d40f458eb49d4b91ae7d438d67))

- **Chore:** Root `.formatter.exs` no longer scans `test/example/_build` (and
  other generated trees) where Hex-copied `*.ex` install templates are not
  valid Elixir — restores reliable `mix format --check-formatted` for contributors.
- Human GA (v1.4): see .planning/v1.4-GA-UAT.md
- **AUD-04:** Auth `log_safe` → `Ecto.Multi` migration inventory for `Sigra.Auth`
  (prioritized `AUD-05` batches **B1–B3**, exclusions, grep evidence) in
  [`43-AUD-04-INVENTORY.md` (tag snapshot)](https://github.com/sztheory/sigra/blob/v0.2.0/.planning/phases/43-audit-inventory-auth-atomic-batch/43-AUD-04-INVENTORY.md).
- **AUD-04 (continuation):** MFA + Account + API token inventory (**AUD-04-020+**,
  `AUD-06` / `AUD-07` batches) in
  [`44-AUD-04-INVENTORY.md` (tag snapshot)](https://github.com/sztheory/sigra/blob/v0.2.0/.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md).
- **AUD-08 / Phase 45:** OAuth + ops + worker **AUD-04** slice (**AUD-04-050+**) in
  [`45-AUD-04-INVENTORY.md` (tag snapshot)](https://github.com/sztheory/sigra/blob/v0.2.0/.planning/phases/45-oauth-ops-c1-signoff/45-AUD-04-INVENTORY.md).
- **AUD-05 (Auth):** When `:audit_schema` is configured, success audits for
  `auth.register.success`, magic-link and password-reset request/verify flows,
  and confirmed-password `auth.login.success` (including lockout reset and
  optional hash upgrade) are written in the same `Repo` transaction as the
  associated data changes via `Ecto.Multi` and `Sigra.Audit.log_multi_safe/3`.

### Roadmap traceability

Planning milestone **v1.4** (GA readiness & audit trail completeness; **not** a Hex version): shipped **2026-04-22** per `.planning/MILESTONES.md` — see `.planning/milestones/v1.4-ROADMAP.md`, `.planning/milestones/v1.4-REQUIREMENTS.md`, `.planning/milestones/v1.4-MILESTONE-AUDIT.md`, and the GA matrix framing in `.planning/v1.4-GA-UAT.md` (Executed / Waived language; do not duplicate the matrix here).

## [0.2.0] - 2026-04-19

### Roadmap traceability

Planning milestone **v1.3** (cleanup & hardening tranche; **not** a Hex version): shipped **2026-04-19** per `.planning/MILESTONES.md` — see `.planning/milestones/v1.3-ROADMAP.md`, `.planning/milestones/v1.3-REQUIREMENTS.md`, and `.planning/milestones/v1.3-MILESTONE-AUDIT.md`.

### Added

- `docs/NEXT-STEPS-MANUAL.md` — short post-merge checklist (PR merge, Hex,
  GitHub Release) for maintainers.
- `docs/audit-semantics.md` — public note on `log` / `log_multi` / `log_safe`, C-1
  hybrid status, and pointers to testing helpers (linked from README).
- `Sigra.Audit.Assertions` — ordered `latest_audit_event/3` + `assert_audit_fields/3`
  for tests; see `guides/recipes/testing.md`.
- Atomic `api.token_create` audit via `Ecto.Multi` / `Sigra.Audit.log_multi_safe/3` in
  `Sigra.APIToken` (telemetry from `emit_telemetry_from_changes/1` on successful
  commit only).
- Example app smoke tests assert login and MFA enrollment audit rows; host
  `get_user_by_email_and_password/2` now delegates to `Sigra.Auth.authenticate/2`
  with full `Sigra.Config` so `auth.login.*` audit runs.
- Human GA matrix in `v1.3-HUMAN-UAT.md` closed via machine substitutes; see
  `.planning/uat-evidence/v1.3.0/INDEX.md` for CI anchors and per-item evidence.
- **GA UAT shift-left:** `docs/uat-ci-coverage.md` maps SEED-001 items to CI and
  documents residual human checks; `test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts`
  covers invitation email-lock and MFA regenerate UI reachability; example app
  gains `EmailsLifecycleHtmlTest`; `scripts/ci/getting-started-contract.sh` plus
  `getting_started_uat_contract` CI job validate getting-started links/commands.
- Generated and example `MFASettingsLive` regenerate form uses an explicit
  `type="submit"` on the regenerate button so LiveView `phx-submit` fires reliably.
- Published to [Hex.pm](https://hex.pm/packages/sigra) as **0.2.0** (initial package listing).

## [0.1.0] - 2026-04-17

First library version line with Hex-oriented `mix.exs` packaging; upgrade to **0.2.0** for the Hex listing and additions above.

### Roadmap traceability

Planning milestone **v1.2** (admin dashboard tranche; **not** a Hex version): shipped **2026-04-17** per `.planning/MILESTONES.md` — see `.planning/milestones/v1.2-ROADMAP.md`, `.planning/milestones/v1.2-REQUIREMENTS.md`, and `.planning/milestones/v1.2-MILESTONE-AUDIT.md`.

### Changed

- **BREAKING (behavior):** `session.create` audit now fires AFTER
  `select_active_organization` during login, so the very first audit event
  of a successful login carries the real `organization_id` rather than a
  `nil` one. Previously, `session.create` fired before the active-org
  selection step and always had a null org, meaning the v1.2 impersonation
  anchor would have no tenant to pin against. If you were relying on the
  old ordering (e.g. a log scraper keyed on null-org events for login
  detection), update your consumers to match the new ordering.
- **BREAKING (API):** `Sigra.Audit.Query.build/2` now raises
  `ArgumentError` on unknown filter keys instead of silently ignoring them.
  If your host app was passing an unknown key (e.g. `actor:` instead of
  `actor_id:`) the query previously returned unfiltered results — now it
  fails loudly. Rationale: silent-ignore on an audit query is a
  security-adjacent bug; audit systems must be loud about
  misconfiguration.
- **BREAKING (installer):** `Sigra.Workers.AccountDeletion` job args now
  require five additional stringified keys at enqueue time:
  `"organization_id"`, `"actor_id"`, `"scope_module"`, `"organization_schema"`,
  and `"audit_schema"`. Host apps that use the Sigra installer to generate
  the account-deletion Oban enqueue site should regenerate that site (or
  manually add the new args). The worker validates presence of all five
  via `fetch_arg!/2` up front BEFORE any `Module.safe_concat` call so the
  `KeyError` surfaces with the actual missing key.

### Fixed

- Hex package `files` list includes `priv/` (installer, upgrade, and OAuth generator templates) so `mix sigra.install` / `mix sigra.upgrade` work when the dependency is pulled from Hex.

### Added

- `Sigra.Audit.log_safe/3` accepts a scope as the second positional argument.
  The scope is duck-typed on `%{user, active_organization, impersonating_from}`;
  pass `nil` explicitly for pre-authentication or truly anonymous call sites.
  `log_safe/2` remains as a thin shim that delegates to `log_safe/3` with a
  `nil` scope.
- `Sigra.Audit.Query` supports `:organization_id`, `:effective_user_id`, and
  `:organization_scope` filters. `:organization_scope` accepts `{:only, org_id}`
  or `{:including_global, org_id}` tagged tuples. The composite index
  `(organization_id, inserted_at)` is created on `audit_events` by the new
  alter migration to keep org-scoped queries off seq-scan plans at scale.
- `Sigra.Scope.build/3` library constructor for the host-app `%Scope{}` struct,
  used by login-time scope synthesis and by Sigra-aware workers. Also adds
  `Sigra.Scope.from_opts/2` and `Sigra.Scope.from_config/2` convenience
  constructors.
- `Sigra.Workers` behaviour — single `@callback perform(scope, args)` contract
  for Oban workers requiring tenant context. `Sigra.Workers.new/3` fails fast
  when required `"organization_id"` / `"actor_id"` arg keys are absent;
  `Sigra.Workers.fetch_arg!/2` is a belt+suspenders helper for worker
  `perform/1` implementations. `Sigra.Workers.AccountDeletion` is the
  reference implementation — it reconstructs the scope inside `perform/1`
  and delegates to `perform/2` with a real `%Scope{}`.
- `Sigra.Testing.assert_audit_logged/2` helper — a thin alias for
  `assert_audit_event/2` with the REQ DX-02 naming convention. Signature is
  `(map, keyword)` to match `assert_audit_event/2` exactly.
- Custom Credo check `Sigra.Credo.NoLogSafe2InLib` that forbids arity-2
  `Sigra.Audit.log_safe` calls in `lib/sigra/**` (with an exception for the
  shim definition itself and for `test/**`). Registered in `.credo.exs` via
  the `requires:` field so host apps pulling Sigra as a dep are not forced
  to take a Credo dependency.
- New migration `alter_audit_events_add_org_columns.exs` adds
  `organization_id :binary_id` (nullable, FK with
  `on_delete: :nilify_all` so historical rows survive organization deletion)
  and `effective_user_id :binary_id` (nullable, v1.2 impersonation anchor)
  columns to `audit_events`, plus the composite index
  `(organization_id, inserted_at)`. On Postgres, the migration uses
  `@disable_ddl_transaction true` + `create index(..., concurrently: true)`
  for zero-downtime deploy on production audit tables. On SQLite/MySQL, a
  plain `change/0` migration emits the same shape non-concurrently.

[Unreleased]: https://github.com/sztheory/sigra/compare/v0.3.0...HEAD
[0.2.0]: https://github.com/sztheory/sigra/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/sztheory/sigra/releases/tag/v0.1.0
