# Phase 86: GAUAT email visual QA — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-26
**Phase:** 86-gauat-email-visual-qa-phase-04-phase-08-templates
**Areas discussed:** Delivery + trigger pipeline; Per-template visual rubric; Evidence layout + README format; Coverage scope + substitution policy

---

## Meta-pivot — discussion shape

User selected all 4 gray areas and added: "research using subagents, what is pros/cons/tradeoffs of each considering the example for each approach, what is idiomatic for elixir/plug/ecto/phoenix for this type of lib/app and in this ecosystem, lessons learned from other libs/apps in same space even from other languages/frameworks if they are popular successful, what did they do right that we should learn from, what did they do wrong/footguns we can learn from, great developer ergonomics/dx emphasized... user friendly (if it's a lib or app), think deeply one-shot a perfect set of recommendations so i don't have to think, all recommendations are coherent/cohesive with each other and move us toward the goals/vision of this project... using great software architecture/engineering, principle of least surprise and great UI/UX where applicable great dev experience... (shift this preference left within GSD as well if possible... except for VERY impactful ones that i might actually care about) ... if possible try to do all verification as integration/e2e shifted left automated... so that i don't have to do any work ... 0 human verification UAT required."

**Effect on discussion shape:**

1. The 4 gray areas were each researched in parallel by a `general-purpose` subagent — each produced a 1500-word report covering tradeoffs, idiomatic patterns, competitor lessons, footguns, and explicit verdicts.
2. The meta-question "can Phase 86 be 0-human UAT defensibly?" became the lens for all 4 areas; agent #4 produced the explicit verdict.
3. A new feedback memory was saved at `~/.claude/projects/-Users-jon-projects-sigra/memory/feedback_zero_human_uat.md` so this preference (shift-left to 0 human UAT, GSD-wide default) persists across sessions.
4. Final synthesis was presented as one coherent recommendation set, with only 2 genuine decisions surfaced for confirmation (milestone-scope edit timing; CTA contrast fix approach).

---

## Area 1 — Delivery + trigger pipeline

| Option | Description | Selected |
|--------|-------------|----------|
| HTML-structure ExUnit only (status quo) | Existing `EmailsSecurityHtmlTest` + `EmailsLifecycleHtmlTest` — `assert html =~ "..."` only | |
| Premailex + Playwright pixel-diff (light + dark) | CSS inline → headless Chromium + WebKit screenshot → pixelmatch goldens | ✓ (core L2) |
| Mailtrap Sandbox API HTML Check + spam score | SMTP deliver from CI, poll API for HTML score + SpamAssassin | ✓ (optional L4) |
| Litmus / Email-on-Acid Previews API | Vendor renders in real engines, returns PNG | ✗ (rejected — $500/mo Enterprise post-Sept-2025; wrong-shape for OSS lib whose templates are app-customized) |
| MJML / Foundation rewrite | Author templates in MJML, compile to Word-safe HTML | (deferred to v1.21+ as separate effort) |

**Selected:** Premailex (Schultzer's lib, peer of Assent) + Playwright pixel-diff with both Chromium and WebKit, light + dark — CORE pipeline. Optional Mailtrap as a non-blocking L4 secret-gated CI job for HTML-check + spam-score signal.

**Notes:** Agent #1 explicitly recommended Chromium-only initially, but agent #4's WebKit-as-Apple-Mail-engine analysis carried — final matrix is 9 templates × 2 engines × 2 themes = 36 baselines. Litmus/EoA rejected on two converging grounds (cost + structural shape mismatch with hybrid lib+generator architecture).

---

## Area 2 — Per-template visual rubric

| Option | Description | Selected |
|--------|-------------|----------|
| Status quo (`assert html =~ ...` only) | Existing pattern; covers headlines, CTAs, ARIA, footer, dates | |
| Extended ExUnit with helper module + 9 coverage gaps | New `Sigra.A11y.Contrast` (~30 LOC) + `Example.EmailAssertions` (~100 LOC) closing G1-G9: contrast computation, byte budget, multipart parity, recipient correctness, XSS fuzz, Outlook deny-list, image tripwire, default-arg branch, low-codes boundary | ✓ (L1 of pipeline) |
| Pure Litmus integration (vendor-graded) | Even at $500/mo, Litmus returns PNGs that a human compares — moves the human cost, doesn't eliminate it | ✗ (rejected) |

**Selected:** Extended ExUnit + `Example.EmailAssertions` helper covering all 9 named coverage gaps, with concrete blocker rubric (8 rules: action impossible, wrong recipient, suppressed security signal, WCAG hard fail, missing plain-text part, > 100 KB clip, XSS leak, Outlook catastrophic break).

**Notes:** Agent #2's per-template rubric matrix (9 rows × pass/machine/human/blocker/non-blocker columns) is preserved verbatim in CONTEXT.md D-86-05. Agent surfaced the **CTA contrast hotspot** (`#2563eb`/`#ffffff` = 4.36:1) — surfaced as a separate decision (see below). Image tripwire is a deliberate-future-decision lock; commented loudly in helper.

---

## Area 3 — Evidence layout + README format

| Option | Description | Selected |
|--------|-------------|----------|
| Commit everything to repo | All PNGs + reports + manifests in git | ✗ (high recurring cost; repo bloat) |
| Link everything via CI | Only README + manifest in repo; PNGs/JSON in Actions artifacts | ✗ (CI artifacts expire 400d max; SOC 2 Type II window is 6-12mo) |
| Hybrid: README + manifest + hero PNGs in repo, full bundle in CI artifact + release asset | Small repo footprint; offline-reproducible verdict; release asset survives artifact expiry | ✓ |
| Waiver (v1.4 GA-02 style) | Skip the work; document compensating controls | ✗ (the v1.4 waiver template explicitly says do not claim "triple-client verified" from screenshots alone — would weaken v1.20 launch claim) |

**Selected:** Hybrid layout. In repo: `README.md` (YAML frontmatter), `manifest.json`, `reports/contrast-summary.json` + `byte-budget.csv`, hero PNGs (~3-4 MB total). Full bundle promoted to GitHub release asset at tag time so it doesn't expire. Naming: `{template}__{engine}__{theme}__sha-{short}.png`.

**Notes:** Agent #3's full README YAML frontmatter schema and manifest.json structure are preserved in CONTEXT.md D-86-06. Phase 88's `v1.20-GA-UAT-RESULTS.md` will follow the v1.4-GA-UAT.md matrix shape for cross-row linking.

---

## Area 4 — Coverage scope + substitution policy + meta-verdict

| Option | Description | Selected |
|--------|-------------|----------|
| Same scope, fully automated (Option A) | Keep "real-mail-client tested" claim, just shift execution to CI | ✗ (claim is dishonest — vendor-renderers can't test app-customized templates) |
| Smoke + CI baseline split (Option B) | Run a small human smoke + CI machine baseline for residual coverage | ✗ (adds residual human work for no incremental coverage) |
| Amended REQUIREMENTS / ROADMAP language (Option C) | Reword GAUAT-01/02 + Phase 86 success criteria to describe the CI harness; downgrade launch claim to honest version | ✓ |

**Selected:** Option C. REQUIREMENTS.md GAUAT-01/02 + ROADMAP.md Phase 86 reworded in this commit. Launch claim downgraded from "real-mail-client tested" to "render-tested across Chromium + WebKit engines × light + dark, with caniemail-validated CSS for Gmail web / new Outlook web / Apple Mail; legacy Outlook Word-engine desktop documented as out-of-scope (Microsoft EOL Oct 2026)."

**Coverage matrix (locked):** Gmail web (Chromium), new Outlook web (Chromium), Apple Mail macOS (WebKit) all IN; legacy Outlook desktop OUT (no OSS renderer; EOL Oct 2026); dark mode IN per client (Litmus' #1 2025-2026 complaint topic); plain-text multipart IN; mobile clients OUT (same engines, no separate axis); spam-folder placement OUT (deliverability surface, adopter responsibility); i18n / RTL OUT (English-only in v1.20).

**Residual policy:** 0 human UAT for v1.20 launch. Residual items (Word-engine Outlook, subjective copy tone in PR review, spam placement = deliverability) live in `docs/uat-ci-coverage.md` SEED-1/2 residual column — NOT a waiver, since no work is being skipped. No quarterly Litmus commitment (maintainer can't fulfill it; fake commitment is worse than none).

**Notes:** Agent #4 explicitly recommended Option C with REQUIREMENTS / ROADMAP rewording in the same commit; user confirmed via AskUserQuestion ("Edit now, commit with CONTEXT.md (Recommended)").

---

## Synthesis decision — CTA contrast bump

| Option | Description | Selected |
|--------|-------------|----------|
| Bump to `#1d4ed8` (Tailwind blue-700) | 5.17:1 contrast — clears WCAG AA for normal text outright; one template edit | ✓ |
| Keep `#2563eb`, document large-text exception | Honest but every reviewer asks "why is this below 4.5:1?" — maintenance friction | |
| Defer to separate template polish phase | Lock contrast at 3:1 large-text floor; bump in future polish | |

**Selected:** Bump to `#1d4ed8` as folded scope in Phase 86. Eliminates the WCAG large-text-bold edge case forever; one template edit (`priv/templates/sigra.install/core/emails.ex` `cta_button/2`).

**Notes:** Agent #2 surfaced the contrast hotspot. Tested against red-emphasis copy (`#dc2626`/`#ffffff` = 4.83:1) — passes WCAG AA by 0.33; will be locked with a contrast assertion to prevent silent regression to `#ef4444` (3.76:1) in a future "let's brighten the red" PR.

---

## Synthesis decision — milestone-scope edit timing

| Option | Description | Selected |
|--------|-------------|----------|
| Edit now, commit with CONTEXT.md | Reword GAUAT-01/02 + Phase 86 success criteria in the same commit so the planner inherits the corrected scope | ✓ |
| Defer rewording to Phase 86 plan tasks | Plan-phase emits explicit tasks to amend REQUIREMENTS.md and ROADMAP.md as part of phase execution | |
| Keep current text, add footnote "see CONTEXT.md" | Minimal-touch | |

**Selected:** Edit now. REQUIREMENTS.md GAUAT-01/02 + ROADMAP.md Phase 86 phase-summary bullet + Phase 86 detailed section all reworded in this commit alongside CONTEXT.md.

---

## Claude's Discretion

- Mix-task location (lib-side vs example-app-side)
- `Sigra.A11y.Contrast` namespace location (`lib/sigra/a11y/` vs `lib/sigra/email/contrast.ex`)
- L4 Mailtrap inclusion (recommend include; planner can drop if adds friction)
- `maxDiffPixels` final tuning (50 starting point)
- caniemail allowlist exact entries (planner curates from open-data source)
- Whether `mix sigra.uat.report` and the manifest generator are one task or split

## Deferred Ideas

- **MJML / React-Email / Maizzle template rewrite** — v1.21+ separate effort
- **Litmus / Email-on-Acid integration as a sponsor-funded feature** — post-launch in `MAINTAINING.md`
- **i18n / RTL email coverage** — when localization arrives
- **Mobile client matrix expansion** — only if adopter telemetry signals mobile-specific failure
- **Spam-folder placement automation / deliverability adopter recipe doc** — v1.21+ if user feedback signals demand
- **Phase 89 README "use this in production" section** — must inherit the corrected language ("render-tested across Chromium + WebKit … with caniemail-validated CSS"); not Phase 86's edit but Phase 89's plan should respect this constraint
