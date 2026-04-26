# Phase 86: GAUAT email visual QA — automated visual regression harness — Context

**Gathered:** 2026-04-26
**Status:** Ready for planning

<domain>

## Phase boundary

Phase 86 ships an **automated email visual regression harness** that produces audit-defensible CI evidence for the 9 transactional email templates (2 Phase 04 security: `lockout_notification_email`, `suspicious_login_email`; 7 Phase 08 lifecycle: `email_change_confirmation_email`, `email_change_notification_email`, `email_changed_email`, `password_changed_email`, `deletion_scheduled_email`, `deletion_cancelled_email`, `deletion_finalized_email`) **without any human MUA pass**. The phase reshapes from "execute human matrix and file screenshots" to "build CI harness whose green-on-tag SHA is the evidence." The launch claim is downgraded from "real-mail-client tested" to **"render-tested across Chromium + WebKit engines × light + dark mode, with caniemail-validated CSS for Gmail web / new Outlook web / Apple Mail; legacy Outlook Word-engine desktop documented as out-of-scope (Microsoft EOL Oct 2026)"** — accurate, defensible, and reproducible from any SHA by any reviewer.

**Explicitly out of scope:** Litmus / Email-on-Acid integration ($500/mo Enterprise post-Sept-2025; also wrong-shape for an OSS lib whose templates are app-customized — vendor renders a synthetic example, not the adopter's brand-customized output); legacy Outlook desktop Word-engine rendering (no OSS renderer exists; EOL Oct 2026; compensating controls = structural deny-list + caniemail lint); spam-folder placement (deliverability surface, not template rendering — adopter's DKIM/SPF/DMARC alignment dominates); i18n / RTL coverage (Sigra is English-only in v1.20); MJML / Foundation rewrite of templates (real win, but a separate effort, not v1.20).

</domain>

<decisions>

## Implementation decisions (research-backed, coherent set)

### D-86-01 — Reshape Phase 86 from manual matrix to automation-build (the verdict)

The phase's verdict is **0 human UAT** for v1.20. The recommended pipeline is genuinely stronger than 3 humans clicking through 27 (9×3) preview windows on every release boundary, because it: (a) catches CSS-inline regressions, dark-mode-meta-tag drift, accessibility regressions, byte-budget overflow, and XSS leaks on every PR — not just at release boundaries; (b) is reproducible from any SHA by any reviewer; (c) is cryptographically tied to commit via filename-encoded short-SHA + manifest hash; (d) survives reviewer turnover (manual screenshots are not auditable evidence — "I trust the human who took these" is not a SOC-2 control). The v1.4 GA-02 waiver explicitly stated `do not claim "triple-client verified" from screenshots alone (D-42-02)` — Phase 86's reshape honors that constraint instead of reversing it.

**Carries the milestone-scope edits in D-86-08 (REQUIREMENTS.md GAUAT-01/02 + ROADMAP.md Phase 86 success criteria).** Both happen in the same commit as this CONTEXT.md so the planner inherits the corrected scope without drift.

### D-86-02 — The four-layer pipeline (one stack)

| Layer | What | Tooling | Files (representative) |
|-------|------|---------|------------------------|
| **L1** | Extend ExUnit `*_html_test.exs` with 9 coverage gaps | Floki + new `Sigra.A11y.Contrast` (~30 LOC) + `Example.EmailAssertions` helper (~100 LOC) | `lib/sigra/a11y/contrast.ex`, `test/example/test/support/email_assertions.ex`, edits to `test/example/test/example/accounts/emails_security_html_test.exs` and `emails_lifecycle_html_test.exs` |
| **L2** | Headless visual regression: Premailex inline + Playwright pixel-diff (Chromium + WebKit, light + dark) | `:premailex ~> 0.3` (Schultzer, peer of Assent), Playwright (already in `test/example/priv/playwright/`) | `lib/mix/tasks/sigra.email.snapshot.ex` (or `test/example/lib/mix/tasks/`), `test/example/priv/playwright/tests/email-visual.spec.ts`, `test/example/priv/playwright/__snapshots__/email-visual.spec.ts/*.png` (36 baselines committed) |
| **L3** | caniemail.com CSS feature lint | New `Sigra.Email.CssLint` module + maintainer-curated allowlist sourced from open-data caniemail (MIT-licensed) | `lib/sigra/email/css_lint.ex`, `priv/sigra/email/caniemail-allowlist.json` |
| **L4** | Optional Mailtrap Sandbox API job (HTML-check + spam-score) | Mailtrap free tier; secret-gated; non-blocking signal | `.github/workflows/ci.yml` `email_mailtrap` job, skipped on PRs from forks |

L1+L2+L3 are the core, all required for green CI. L4 is optional, secret-gated, and non-blocking — it's the "nice-to-have" deliverability signal layer. If a future maintainer wants to drop L4 entirely for zero-vendor posture, that is acceptable and the launch claim is unchanged.

### D-86-03 — Engine and viewport matrix (locked)

- **Engines:** Chromium (Playwright default; covers Gmail web + new Outlook web) **and** WebKit (Playwright `browserName: 'webkit'`; covers Apple Mail rendering — same engine family as Apple Mail's HTML pipeline).
- **Color schemes:** light **and** dark via `page.emulateMedia({ colorScheme: 'dark' | 'light' })`. Dark mode is the #1 2025-2026 email rendering complaint topic per Litmus / Stripo / Mailchimp; no excuse to skip it.
- **Viewport:** 640px wide × 1200px tall (matches the email-card width baked into `priv/templates/sigra.install/core/emails.ex` `base_layout/1`). One viewport per template — mobile clients render via the same engines as desktop in 95%+ of cases (per agent #4 research); a separate mobile viewport axis is unjustified for v1.20.
- **Total baselines:** 9 templates × 2 engines × 2 color schemes = **36 PNGs** committed in `test/example/priv/playwright/__snapshots__/email-visual.spec.ts/`.
- **Baseline naming:** `{template-slug}__{engine}__{theme}.png` inside the Playwright snapshot folder (Playwright's convention); the `.planning/uat-evidence/v1.20/email-phase-04|08/snapshots/` evidence folder uses `{template-slug}__{engine}__{theme}__sha-{short-sha}.png` (D-86-06).
- **Diff tolerance:** `maxDiffPixels: 50` per snapshot (avoids font-rendering microflake while catching real layout breaks). Tune if needed; document final value in the spec file.

### D-86-04 — Frozen test fixtures (eliminates time-dependent flake)

All snapshot tests use frozen, deterministic fixtures so pixel-diff results don't churn on every run:

- `time:` `~U[2026-04-17 12:00:00Z]` (matches the existing `*_html_test.exs` convention)
- `details.ip:` `"203.0.113.42"` (RFC 5737 documentation IP — guaranteed not to be a real address)
- `details.geo_city:` `"Test City"`
- `details.device:` `"Test Browser on Test OS"`
- `user.email:` `"snapshot-fixture@example.test"` (or `"old@example.test"` / `"new@example.test"` for email-change templates)
- `app_name:` `"Example"` (the existing `test/example` value)
- `formatted_date:` `~D[2026-12-01]` for `deletion_scheduled_email`

Add a unit test that exercises the **default-arg** `DateTime.utc_now/0` branch of each affected template (separate from snapshot tests) so the production code path is regression-covered without flake.

### D-86-05 — Per-template rubric (the 9 coverage gaps L1 closes)

The existing `EmailsSecurityHtmlTest` + `EmailsLifecycleHtmlTest` cover headlines, CTA labels, hardcoded path fragments, ARIA roles, footer copy presence, date format, low-codes warning, and recipient (implicit). They do NOT cover the following — Phase 86 closes all 9 gaps via `Example.EmailAssertions`:

| Gap | What it asserts | Helper |
|-----|-----------------|--------|
| **G1** Computed contrast | Floki-extracted CTA fg/bg → WCAG luminance ratio ≥ threshold | `Sigra.A11y.Contrast.ratio/2` + `assert_cta_contrast/2` |
| **G2** Byte budget | `byte_size(html_body) < 100_000` (Gmail clip threshold = 102,400; 100K leaves margin) | `assert_under_gmail_clip/1` |
| **G3** Multipart parity | every URL in `html_body` also appears in `text_body` | `assert_text_part_mirrors_html/2` |
| **G4** Recipient correctness | `email.to` is the right address for each template (especially `email_change_*` where right-vs-wrong is security-critical) | `assert_email_to/2` |
| **G5** XSS regression | fuzz `details.ip` / `new_email` with `<script>` and `O'Brien` payloads → assert escaped form | `assert_xss_escaped/2` |
| **G6** Outlook Word-engine deny-list | no `<style>` block, no `position:`, no `flex|grid:`, no `background-image:`, no unsupported CSS keywords | `assert_no_outlook_landmines/1` |
| **G7** Image tripwire | `refute html =~ ~r/<img/i` (currently no images; future "let's add a logo" PR must hit a deliberate-decision tripwire about alt text + dark-mode invert) | inline assert in each test |
| **G8** Default-arg branch | `Calendar.strftime(DateTime.utc_now(), ...)` exercised in at least one test per template that uses it | new tests, no helper |
| **G9** Low-codes boundary | for `backup_code_used_email`, test `remaining: 1`, `remaining: 2`, `remaining: 3` — boundary-case coverage | parametrized describe block |

**Blocker rubric (8 rules — used by L1+L2 to fail the build, not "use judgment"):**

1. Action impossible (CTA href empty/malformed; broken in HTML, plain-text, or fallback raw-URL line).
2. Wrong recipient (e.g. `email_change_notification_email` reaching the new email instead of the old).
3. Security signal suppressed ("If this wasn't you" / "Not you?" copy missing in any security template).
4. WCAG 2.2 AA hard fail on a CTA or red-emphasis text (computed contrast < 3:1 large-text-bold floor).
5. Plain-text part missing/unusable (no `text_body`, missing URLs, contains raw HTML tags).
6. HTML byte size > 100 KB (Gmail clip).
7. XSS leak (any user-controlled field appears un-escaped).
8. Outlook Word-engine catastrophic break (CSS deny-list violation OR pixel-diff > 50px in WebKit/Chromium baseline).

Pixel-diff *anywhere else* (cosmetic drift in dark-mode tinting, border-radius fallback in Outlook 2016, font kerning) is **non-blocker** — fail the snapshot, file as a todo with `non-blocker` severity, ship anyway. The planner should make sure the snapshot-update path (`mix test --update-snapshots`) requires a reviewer note explaining what changed and why.

### D-86-06 — Evidence layout (hybrid: in-repo manifest + hero PNGs + release-asset full bundle)

```
.planning/uat-evidence/v1.20/
├── INDEX.md                                        # mirrors v1.4/INDEX.md shape
├── email-phase-04/
│   ├── README.md                                   # YAML frontmatter + per-cell outcome table
│   ├── manifest.json                               # machine-readable; one row per (template, engine, theme)
│   ├── waiver.md                                   # only if any cell waived (none expected for v1.20)
│   ├── reports/
│   │   ├── contrast-summary.json                   # axe-core / Sigra.A11y.Contrast output per template
│   │   └── byte-budget.csv                         # rendered HTML size per cell vs 102,400 threshold
│   └── snapshots/                                  # hero PNGs only (~1-2 MB total)
│       ├── lockout-notification__chromium__light__sha-3e9e58f.png
│       ├── lockout-notification__chromium__dark__sha-3e9e58f.png
│       ├── lockout-notification__webkit__light__sha-3e9e58f.png
│       ├── lockout-notification__webkit__dark__sha-3e9e58f.png
│       └── (8 more for suspicious-login)
└── email-phase-08/                                 # same shape; 7 templates × 4 = 28 hero PNGs
    └── (...)
```

- **In repo (always):** `README.md`, `manifest.json`, `reports/*`, hero PNGs (~3-4 MB total per release; if it grows, escalate to `git lfs` or split into a `sigra-evidence` orphan branch).
- **CI artifact at tag time:** full bundle (raw `.eml` per template, every snapshot-engine PNG at full res, axe-core JSONs) → uploaded as Actions artifact AND **promoted to GitHub release asset** at `v1.20.0` tag (release assets do NOT expire vs Actions artifacts capped at 400 days — matters for SOC 2 Type II 6-12 month audit windows).
- **README YAML frontmatter (machine-checkable):** `phase`, `gauat_requirement`, `hex_version`, `git_sha`, `git_tag`, `ci_run_url`, `ci_workflow`, `generated_by`, `generated_at`, `disposition`.
- **Naming:** `{template-slug}__{engine}__{theme}__sha-{short-sha}.png`. Double-underscore as field separator. Short-SHA (7 chars) at tail so files sort by template first.
- **Manifest schema:** one row per (template, engine, theme) cell with fields `template`, `engine`, `theme`, `viewport`, `git_sha`, `hex_version`, `snapshot_sha256`, `contrast_min_ratio`, `byte_size`, `byte_budget_max`, `outcome`, `ci_run_url`, `artifact_url`. Generated by a new `mix sigra.uat.report --phase=04|08` task; same task emits the README table from the same JSON to prevent drift.

### D-86-07 — CTA contrast bump (template edit; folded scope)

`priv/templates/sigra.install/core/emails.ex` `cta_button/2` currently uses `background-color: #2563eb` (Tailwind `blue-600`) on `#ffffff` text → **4.36:1 contrast**. That passes WCAG 2.2 AA only as large-text-bold (button is `font-size: 16px; font-weight: 700` — crosses the 14pt-bold large-text threshold). One template edit eliminates the edge-case footgun forever:

- **Bump to `#1d4ed8` (Tailwind `blue-700`)** → **5.17:1 contrast**. Clears WCAG AA for normal text outright.
- L1's `assert_cta_contrast/2` then asserts `≥ 4.5` (normal-text threshold) instead of `≥ 3.0` (large-text-bold floor) — stronger gate.
- This is a generated-template edit; adopters can override. The default is now WCAG-AA-clean without per-app effort.
- Same review for `password_changed_email` and `email_change_notification_email`: red-emphasis `#dc2626` × `#ffffff` = 4.83:1 (passes by 0.33). Lock with a contrast assertion so a future "let's brighten the red" PR to `#ef4444` (3.76:1) fails the build instead of silently regressing.

### D-86-08 — Milestone-scope edits (commit alongside this CONTEXT.md)

REQUIREMENTS.md GAUAT-01/02 + ROADMAP.md Phase 86 success criteria are reworded in the same commit as this CONTEXT.md so the planner inherits the corrected scope without drift. Old text ("Render … in Gmail (web), Outlook (web), Apple Mail (macOS). Capture screenshots") and old success criteria (manual screenshot count minimums) are replaced by language describing the CI-reproducible automation harness, evidence under `.planning/uat-evidence/v1.20/email-phase-04|08/`, and the documented residual. Phase 86 in the **Phase summary** bullet list at the top of ROADMAP.md is reworded from "Render … capture screenshots; file pass/fail per template" to "Ship automated visual regression harness (Premailex + Playwright Chromium+WebKit × light+dark + caniemail CSS lint) producing CI-reproducible evidence per template." The `docs/uat-ci-coverage.md` SEED-1/SEED-2 row residual columns get the new `email_visual_regression` job marked as covering the residual that was previously human-residue. The v1.4 GA-02 waiver template stays as historical-only.

### D-86-09 — Residual policy (documented, NOT waived)

**0 residual human work for v1.20 launch.** The following items live in `docs/uat-ci-coverage.md` SEED-1/2 row residual column (NOT in a waiver, because there is nothing being waived — the work isn't expected):

1. **Legacy Outlook desktop (Word engine, EOL Oct 2026)** — no OSS renderer exists. Compensating: structural deny-list (no `<style>`, only `role="presentation"` tables, all colors inline) + caniemail CSS lint asserting Word-engine-safe property subset. Residual is shrinking as Microsoft sunsets the engine.
2. **Subjective copy tone in security templates** — handled in PR review during template authoring (Mailchimp / SendGrid / industry-norm pattern), not as a recurring UAT step.
3. **Spam-folder placement** — deliverability surface, not template rendering. Adopter's DKIM/SPF/DMARC alignment dominates. Document in adopter deployment recipe, not v1.20 scope.

**No quarterly Litmus / Email-on-Acid commitment.** The maintainer cannot fulfill it (no license; $500/mo Enterprise post-Sept-2025); a fake commitment is worse than none. If a community sponsor donates a Litmus license post-launch, document as a future-enhancement track in `MAINTAINING.md` "Post-launch monitoring" lane — out of v1.20 scope.

### D-86-10 — Tests (the L1 unit-extension layer)

Extend `test/example/test/example/accounts/emails_security_html_test.exs` (~65 LOC currently) and `emails_lifecycle_html_test.exs` (~151 LOC currently) by ~3-5 lines per existing describe block plus 9 new describes (one per coverage gap G1-G9). Total new LOC: ~100 in the helper + ~50 in the test files = ~150 net. Plus one new test file `test/sigra/a11y/contrast_test.exs` for the new `Sigra.A11y.Contrast` module (~50 LOC, AAA-flat).

The L2 snapshot harness lives in `test/example/priv/playwright/tests/email-visual.spec.ts` — a single spec file iterating all 9 templates × 2 engines × 2 themes via Playwright's project matrix; one `mix sigra.email.snapshot` mix task pre-renders the HTML to `priv/email_snapshots/*.html` (Premailex-inlined) and Playwright `goto`s `file://` URLs.

### D-86-11 — Two-commit closure sequencing

Mirror Phase 85's sequencing for reviewability:

1. **Commit A (Phase 86 plan-1):** L1 ExUnit extensions + `Sigra.A11y.Contrast` module + CTA contrast template bump (`#2563eb` → `#1d4ed8`) + caniemail CSS lint module + new tests. **Gate:** library test suite + `example_unit_smoke` green; new `example_email_a11y` job (or extension of existing `example_unit_smoke`) green.
2. **Commit B (Phase 86 plan-2):** L2 Playwright spec + `mix sigra.email.snapshot` mix task + 36 baseline PNGs + `mix sigra.uat.report` task + `.planning/uat-evidence/v1.20/email-phase-04|08/{README.md,manifest.json,reports/,snapshots/}` + `email_visual_regression` CI job + `docs/uat-ci-coverage.md` SEED-1/2 residual column update + `86-VERIFICATION.md` recording the merge gate outcome (CI run URL, snapshot count, contrast min ratio, byte budget max, dated PASS attestation per GAUAT-01/02). **Gate:** all CI jobs green at SHA; manifest matches README table.

### Claude's discretion

- Exact location of `mix sigra.email.snapshot` (lib-side under `lib/mix/tasks/` vs example-app-side under `test/example/lib/mix/tasks/`). Lib-side is more idiomatic for a library that ships generators; example-side is simpler if it depends on `Example.Accounts.Emails`. Planner picks.
- Whether `Sigra.A11y.Contrast` lives under `lib/sigra/a11y/` (its own namespace) or `lib/sigra/email/contrast.ex` (scoped to email). Planner picks based on whether contrast logic might extend to LiveView UI assertions later.
- Mailtrap L4 inclusion. Free tier covers volume; secret-gated; non-blocking. Recommend include; if planner finds it adds friction, drop without renegotiating the rest.
- `maxDiffPixels` final value (50 is the recommended starting point; tune in commit-B based on observed flake).
- caniemail allowlist exact entries (allow CSS properties supported in Gmail web + new Outlook web + Apple Mail per caniemail data; planner curates from open-data source).
- Whether `mix sigra.uat.report` and the manifest generator live as a single task or split. Pragmatic call.

### Folded scope

- **CTA contrast bump (`#2563eb` → `#1d4ed8`)** — explicitly approved as part of Phase 86 scope (single template edit; eliminates accessibility edge-case footgun forever; cleaner than documenting large-text exception). Touches `priv/templates/sigra.install/core/emails.ex` `cta_button/2`.
- **REQUIREMENTS.md GAUAT-01/02 + ROADMAP.md Phase 86 rewording** — explicitly approved as part of this discuss commit (so the planner inherits the corrected scope without drift). Counts as milestone-level scope edit but is a verification-approach correction, not a new capability.

### Folded todos

_None — `gsd-sdk query todo.match-phase 86` returned 0 matches._

</decisions>

<canonical_refs>

## Canonical references

**Downstream agents MUST read these before planning or implementing.**

### Requirements and roadmap

- `.planning/REQUIREMENTS.md` — **GAUAT-01**, **GAUAT-02** (reworded in this commit per D-86-08); **GAUAT-09** (Phase 88 results-filing matrix that links back here)
- `.planning/ROADMAP.md` — Phase 86 goal + reworded success criteria (this commit per D-86-08); Phase summary bullet (this commit)
- `.planning/PROJECT.md` — v1.20 GA framing + "use this in production" launch positioning + minimal-deps DX value
- `.planning/STATE.md` — v1.20 leg-2 framing (Phase 86 = SEED-001 leg start)

### Seed and prior-phase context

- `.planning/seeds/SEED-001-v1.0-ga-human-uat-gate.md` — original 8-item human gate framing; the seed already contemplates machine substitutes per `docs/uat-ci-coverage.md`. Phase 86 closes items 1-2 (Phase 04 + Phase 08 email visual QA) via shift-left automation, not human matrix.
- `.planning/uat-evidence/v1.4/GA-02/{README.md,steps.md,waiver.md}` — v1.4 GA-02 was waived; the waiver template (`waiver.md` six-field schema) is the fallback shape if any future cell needs to be waived. v1.20 expects no waivers.
- `.planning/uat-evidence/v1.4/INDEX.md` — top-level index pattern; `.planning/uat-evidence/v1.20/INDEX.md` mirrors this shape.
- `.planning/uat-evidence/v1.4/GA-01-pointer/README.md` — the "evidence as CI link" pattern that v1.20 generalizes (CI workflow URL + manifest as primary evidence).
- `.planning/uat-evidence/v1.3.0/item-01-lockout-mail/{README.md,steps.md}` — earlier minimal CI-substitute precedent.
- `.planning/v1.4-GA-UAT.md` — matrix-file shape; Phase 88's `v1.20-GA-UAT-RESULTS.md` should follow this column set.
- `.planning/phases/85-oauth-audit-atomicity-closure-aud-21/85-CONTEXT.md` — Phase 85 sequencing pattern (two-commit closure; mirror in D-86-11).

### Code (integration points)

- `priv/templates/sigra.install/core/emails.ex` — the 9 rendered template builders (lines 152, 224, 289, 330, 366, 397, 447, 485, 522, 561, 594, 633, 662, 690 per `grep "^  def " priv/templates/sigra.install/core/emails.ex`); `base_layout/1` (lines 878-928); `cta_button/2` (lines 930-942 — **edited by D-86-07**); `html_escape_string/1` (lines 960-964); `footer_text/0` and `security_footer_text/0`
- `lib/sigra/email_templates.ex` — behaviour callbacks (the 9 templates' contracts)
- `test/example/test/example/accounts/emails_security_html_test.exs` (~65 LOC; extended by L1)
- `test/example/test/example/accounts/emails_lifecycle_html_test.exs` (~151 LOC; extended by L1)
- `test/example/lib/example_web/router.ex` (line 175) — existing `Plug.Swoosh.MailboxPreview` at `/dev/mailbox` (kept for ad-hoc human preview; not depended on by CI)
- `test/example/config/dev.exs` (line 91) — `Swoosh.Adapters.Local` (existing; unchanged)
- `test/example/config/test.exs` (line 25) — `Swoosh.Adapters.Test` (existing; unchanged)
- `test/example/priv/playwright/` — existing Playwright harness directory; new `tests/email-visual.spec.ts` joins existing specs
- `.github/workflows/ci.yml` — gains `email_visual_regression` job (and optional `email_mailtrap` job per D-86-02 L4)

### Verification + planning truth touch points

- `docs/uat-ci-coverage.md` — SEED-1/SEED-2 rows: residual column updated to point at `email_visual_regression` job; v1.4 GA-02 waiver demoted to historical-only.
- `MAINTAINING.md` — "Post-launch monitoring (v1.20)" lane (added in Phase 90); Phase 86 does not edit it.
- `.planning/v1.20-GA-UAT-RESULTS.md` — filed in Phase 88; carries one row per (template, engine, theme) for GAUAT-01/02 with link back into evidence under `.planning/uat-evidence/v1.20/email-phase-04|08/`.
- `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-VERIFICATION.md` — to be authored at phase close (records CI run URL, snapshot counts, contrast min ratio, byte budget max, dated PASS attestation per GAUAT-01/02).

### External (research-cited; downstream agents may verify)

- [caniemail.com](https://www.caniemail.com/) / [hteumeuleu/caniemail](https://github.com/hteumeuleu/caniemail) — open-data CSS support tables; allowlist source for L3
- [hex.pm/packages/premailex](https://hex.pm/packages/premailex) — Schultzer's CSS inliner, peer of Assent
- [Playwright `toHaveScreenshot` docs](https://playwright.dev/docs/test-snapshots) — visual regression API used by L2
- [W3C WCAG 2.2 Recommendation](https://www.w3.org/TR/WCAG22/) — contrast rule reference for `Sigra.A11y.Contrast`
- [Litmus dark-mode guide](https://www.litmus.com/blog/the-ultimate-guide-to-dark-mode-for-email-marketers) — basis for D-86-03 dark-mode requirement
- [Litmus 2026 email client market share](https://www.litmus.com/email-client-market-share) — Apple Mail + Gmail = 87.74% of opens; basis for D-86-03 engine choice
- [GitHub artifact attestations docs](https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations/using-artifact-attestations-to-establish-provenance-for-builds) — provenance pattern for L2 snapshot bundle
- [Postmark transactional best practices 2026](https://postmarkapp.com/guides/transactional-email-best-practices) — basis for D-86-09 spam-placement-out-of-scope rationale

</canonical_refs>

<code_context>

## Existing code insights

### Reusable assets

- **`Example.Accounts.Emails.*_email/N` builder functions** — already produce `Swoosh.Email` structs with `html_body` + `text_body` set. L2 mix task calls these directly; no need to round-trip through `Mailer.deliver/1` for visual snapshots.
- **`Plug.Swoosh.MailboxPreview` at `/dev/mailbox`** (`test/example/lib/example_web/router.ex:175`) — kept for ad-hoc human preview during template authoring; not in CI critical path.
- **`Swoosh.Adapters.Test`** (`test/example/config/test.exs:25`) — captures emails for `assert_email_sent/1`-style assertions. L1 builds on the already-canonical Phoenix test pattern.
- **`Floki`** — already a transitive dep via Phoenix's HTML test stack; L1 uses for DOM extraction (CTA node, contrast color extraction, `<style>` deny-list, image tripwire).
- **Existing Playwright harness** (`test/example/priv/playwright/tests/golden-path.spec.ts`, `ga-uat-shift-left.spec.ts`) — proves Playwright is wired in CI; L2 adds one new spec file and a project matrix.
- **Existing `*_html_test.exs` shape** — flat AAA, `assert html =~ ...`, `describe "fn_name/N"` blocks. L1 extends this without changing style.
- **v1.4 `waiver.md` schema** (`reason / compensating controls / residual risk / expiry_or_next_trigger / owner / date`) — the right shape for any future fall-through cell. Reuse verbatim if needed; v1.20 expects no invocation.

### Established patterns

- **Two-commit closure (Phase 85 D-85-06 pattern)** — code+tests commit, then verification+narrative commit. Mirror in D-86-11.
- **Surgical planning-truth edits (Phase 81 / 82 D-X-04 pattern)** — dated supersession footnote + one CHANGELOG bullet + one paragraph in summary doc. Apply to `docs/uat-ci-coverage.md` SEED-1/2 row updates.
- **Frozen test fixtures for time-dependent code** (existing `*_html_test.exs` uses `~U[2026-04-17 12:00:00Z]`) — extend to all snapshot test fixtures.
- **`role="presentation"` table layout + inline CSS only** (`base_layout/1` already follows this) — the canonical Word-engine-safe pattern; L3 caniemail lint enforces this stays true.

### Integration points

- **CI workflow:** `email_visual_regression` is a new job; runs on every PR. `email_mailtrap` is a new optional job; secret-gated, non-blocking.
- **Adopters:** template edit (D-86-07 CTA color bump) is in a `priv/templates/sigra.install/` file — shipped to host apps via `mix sigra.install`. Existing adopters won't see it auto-update; documented in CHANGELOG `[Unreleased]` as an aesthetic + WCAG-AA improvement to the default template (adopter override is preserved if they've customized).
- **`mix sigra.gen.session` and other generators:** no changes; visual QA is concerned with templates that already exist.

</code_context>

<specifics>

## Specific ideas

- **WebKit ≠ Apple Mail entirely.** Apple Mail uses WebKit but with mail-specific CSS sandboxing (transparent-bg → invert in dark mode is the canonical gotcha). The README in `email-phase-04|08/` must claim "WebKit-rendered with Apple-Mail CSS subset enforced via caniemail lint" — not "Apple Mail rendered." Honest claim language is load-bearing for the launch.
- **Litmus / Email-on-Acid is rejected for two converging reasons:** (a) cost — $500/mo Enterprise-only post-Sept-2025; (b) wrong-shape — Sigra ships generated, app-customized templates; vendor renders a synthetic example, not the adopter's brand-customized output. This is structurally why vendor-rendering services don't fit a hybrid lib+generator architecture, and is itself a Sigra differentiator vs vendor-managed competitors.
- **CTA contrast bump (`#2563eb` → `#1d4ed8`)** is folded scope, not a deferred polish item. Eliminates the WCAG large-text-bold edge case forever; one template-edit line. The new contrast assertion gates `≥ 4.5:1` (normal-text) thereafter, so a future "let's go back to blue-600" PR fails the build.
- **Image tripwire (`refute html =~ ~r/<img/i`)** — currently zero `<img>` tags in the 9 templates. A future "let's add a logo" PR must hit a deliberate-decision tripwire about alt-text + dark-mode invert behavior. Comment this loudly in the helper so a contributor doesn't surprise-fix it.
- **`#dc2626` red on `#ffffff` = 4.83:1** — passes WCAG AA by 0.33. Lock with a contrast assertion so a future "brighten the red" PR to `#ef4444` (3.76:1) fails the build instead of silently regressing.
- **Documented residual is NOT a waiver** — there's no work being skipped; the residual items (Word-engine Outlook, copy tone, spam placement) are out of scope by architectural classification, not by deferral. Mirrors the Phase 85 D-AUD-06 sub-class framing.

</specifics>

<deferred>

## Deferred ideas

- **MJML / React-Email / Maizzle template rewrite** — would eliminate many client-specific bugs at the source by authoring in a known-good email-DSL. Real win, but a substantial rewrite of all 9 templates. Belongs in v1.21+ as a separate effort; out of v1.20 scope.
- **Litmus / Email-on-Acid integration as a sponsor-funded feature** — if a community sponsor donates a license post-launch, add a `litmus_capture` CI job that posts vendor-rendered screenshots from the same HTML CI snapshots. Documented as future-enhancement track in `MAINTAINING.md` "Post-launch monitoring" lane (added in Phase 90).
- **i18n / RTL email coverage** — Sigra is English-only in v1.20. When localization arrives, RTL bidi rendering on the IP/location card needs structural review. Future v1.21+ phase.
- **Mobile client matrix expansion (Gmail iOS, Outlook iOS, Apple Mail iOS)** — iOS clients render via the same engines as their desktop counterparts in 95%+ of cases per agent #4 research; a separate axis is unjustified for v1.20. Revisit if adopter telemetry shows mobile-specific failure modes.
- **Spam-folder placement automation** — adopter's DKIM/SPF/DMARC alignment dominates. A "deliverability recipe" doc for adopters could land in v1.21+ if user feedback signals demand.
- **`mix.exs` `@version` "real-mail-client tested" marketing claim** — Phase 89 README promotion must use the corrected language ("render-tested across Chromium + WebKit … with caniemail-validated CSS"). Not Phase 86's edit, but the Phase 89 plan should inherit this constraint.
- **Deliverability adopter recipe doc** — DKIM/SPF/DMARC alignment guidance for adopters' production setup. Not v1.20 scope; documents the spam-placement carve-out.

### Reviewed todos (not folded)

_None — `gsd-sdk query todo.match-phase 86` returned 0 matches._

</deferred>

---

*Phase: 86-gauat-email-visual-qa-phase-04-phase-08-templates*
*Context gathered: 2026-04-26*
