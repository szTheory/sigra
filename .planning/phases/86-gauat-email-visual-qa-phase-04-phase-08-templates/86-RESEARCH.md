# Phase 86: GAUAT email visual regression harness (Phase 04 + Phase 08 templates) - Research

**Researched:** 2026-04-26
**Domain:** Elixir/Phoenix email template rendering, Playwright visual regression, and CI evidence generation for transactional email templates. [VERIFIED: codebase grep]
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

Source: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md` [VERIFIED: codebase grep]

### Locked Decisions

#### Phase boundary

Phase 86 ships an **automated email visual regression harness** that produces audit-defensible CI evidence for the 9 transactional email templates (2 Phase 04 security: `lockout_notification_email`, `suspicious_login_email`; 7 Phase 08 lifecycle: `email_change_confirmation_email`, `email_change_notification_email`, `email_changed_email`, `password_changed_email`, `deletion_scheduled_email`, `deletion_cancelled_email`, `deletion_finalized_email`) **without any human MUA pass**. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]

The launch claim is downgraded from "real-mail-client tested" to **"render-tested across Chromium + WebKit engines × light + dark mode, with caniemail-validated CSS for Gmail web / new Outlook web / Apple Mail; legacy Outlook Word-engine desktop documented as out-of-scope (Microsoft EOL Oct 2026)"**. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]

#### Implementation decisions

- **D-86-01:** The phase's verdict is **0 human UAT** for v1.20. The recommended pipeline is genuinely stronger than 3 humans clicking through preview windows on every release boundary because it is reproducible from any SHA and tied to commit via artifact naming + manifest. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
- **D-86-02:** Use the four-layer pipeline: L1 ExUnit coverage extensions, L2 Premailex + Playwright visual regression, L3 caniemail CSS lint, L4 optional Mailtrap sandbox job. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
- **D-86-03:** Engines are Chromium and WebKit; color schemes are light and dark; viewport is 640×1200; total committed baselines are 36 PNGs; recommended diff tolerance starts at `maxDiffPixels: 50`. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
- **D-86-04:** All snapshot tests use frozen fixtures: fixed time, fixed IP, fixed city/device strings, fixed emails, fixed app name, and fixed scheduled-deletion date. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
- **D-86-05:** Phase 86 closes nine coverage gaps through `Example.EmailAssertions` and `Sigra.A11y.Contrast`: computed contrast, Gmail byte budget, multipart parity, recipient correctness, XSS regression, Outlook deny-list, image tripwire, default-arg time branch, and backup-code boundary coverage. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
- **D-86-06:** Evidence layout is hybrid: committed README/manifest/reports/hero PNGs in `.planning/uat-evidence/v1.20/email-phase-04|08/`, plus full CI artifact bundles and release-asset promotion at tag time. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
- **D-86-07:** `cta_button/2` color is bumped from `#2563eb` to `#1d4ed8` so CTA contrast clears the stronger 4.5:1 gate without relying on the large-bold exception. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
- **D-86-08:** `REQUIREMENTS.md`, `ROADMAP.md`, and `docs/uat-ci-coverage.md` are part of the phase closure because the launch claim and residual model changed. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
- **D-86-09:** Residual policy is documentation-only, not a waiver: legacy Outlook desktop Word engine, subjective copy tone, and spam-folder placement are explicitly outside the recurring CI claim. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
- **D-86-10:** Extend the existing `emails_security_html_test.exs` and `emails_lifecycle_html_test.exs`; keep the visual harness under `test/example/priv/playwright/tests/email-visual.spec.ts`; pre-render HTML via a mix task. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
- **D-86-11:** Keep the phase reviewable as two commits: Commit A for ExUnit/a11y/CSS lint/template color; Commit B for Playwright/baselines/evidence/CI/planning truth. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]

### Claude's Discretion

Source: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md` [VERIFIED: codebase grep]

- Exact location of `mix sigra.email.snapshot` (`lib/mix/tasks/` vs `test/example/lib/mix/tasks/`). [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
- Whether `Sigra.A11y.Contrast` lives under `lib/sigra/a11y/` or `lib/sigra/email/`. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
- Mailtrap L4 inclusion. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
- Final `maxDiffPixels` value after observing flake. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
- Exact caniemail allowlist entries. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
- Whether `mix sigra.uat.report` is one task or split. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]

### Deferred Ideas (OUT OF SCOPE)

Source: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md` [VERIFIED: codebase grep]

- Litmus / Email on Acid integration. [VERIFIED: codebase grep]
- Legacy Outlook desktop Word-engine rendering beyond deny-list + compatibility lint. [VERIFIED: codebase grep]
- Spam-folder placement verification. [VERIFIED: codebase grep]
- i18n / RTL coverage. [VERIFIED: codebase grep]
- MJML / Foundation template rewrite. [VERIFIED: codebase grep]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GAUAT-01 | Phase 04 lockout + suspicious-login automated visual regression and evidence. [VERIFIED: `.planning/REQUIREMENTS.md`] | Premailex inlining, ExUnit assertion extension, Playwright snapshot matrix, caniemail lint, CI artifact manifest flow. [VERIFIED: codebase grep] |
| GAUAT-02 | Phase 08 lifecycle-template automated visual regression and evidence. [VERIFIED: `.planning/REQUIREMENTS.md`] | Same harness applied to seven lifecycle templates with deterministic fixtures and two-theme/two-engine baselines. [VERIFIED: codebase grep] |
</phase_requirements>

## Summary

The codebase already has the three core seams this phase should extend rather than replace: generated email builders in [`priv/templates/sigra.install/core/emails.ex`](/Users/jon/projects/sigra/priv/templates/sigra.install/core/emails.ex:22), HTML-focused ExUnit coverage in [`emails_security_html_test.exs`](/Users/jon/projects/sigra/test/example/test/example/accounts/emails_security_html_test.exs:25) and [`emails_lifecycle_html_test.exs`](/Users/jon/projects/sigra/test/example/test/example/accounts/emails_lifecycle_html_test.exs:15), and a real-server Playwright harness under [`test/example/priv/playwright/`](/Users/jon/projects/sigra/test/example/priv/playwright/playwright.config.ts:1) that CI already boots with Chromium and WebKit. [VERIFIED: codebase grep]

The implementation-ready shape is: render deterministic HTML files from the existing `Example.Accounts.Emails` builders, inline CSS with Premailex before snapshotting, keep structural and security assertions in ExUnit, and use Playwright `toHaveScreenshot()` only for the committed 36-cell visual matrix. That matches the official Premailex Swoosh flow, Playwright’s committed-baseline model, and the repo’s existing pattern of real-server browser specs plus retained artifacts. [CITED: https://hexdocs.pm/premailex/README.html] [CITED: https://playwright.dev/docs/test-snapshots] [VERIFIED: codebase grep]

The likely failure modes are not “email rendering is impossible to automate”; they are determinism and provenance problems: time-dependent template branches, OS/font drift in screenshots, using the wrong Swoosh adapter for the wrong test tier, overgrowing artifacts, and letting CSS rules drift outside the intended email-client allowlist. All of those are solvable with frozen fixtures, one CI screenshot environment, ExUnit for semantic correctness, caniemail-backed compatibility lint, and manifest/artifact digests in the evidence layer. [CITED: https://docs.github.com/en/actions/tutorials/store-and-share-data] [CITED: https://www.caniemail.com/support/] [CITED: https://hexdocs.pm/swoosh/Swoosh.TestAssertions.html] [VERIFIED: codebase grep]

**Primary recommendation:** Keep the harness repo-native: add `:premailex`, extend the existing email ExUnit files, prerender HTML to disk from Elixir, run one dedicated Playwright email spec against those local files in CI, and generate committed evidence manifests plus uploaded artifacts from the same source data. [CITED: https://hexdocs.pm/premailex/README.html] [CITED: https://playwright.dev/docs/test-snapshots] [VERIFIED: codebase grep]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Render transactional email HTML/text from fixtures | API / Backend | — | The source of truth is the generated Elixir email builders in [`emails.ex`](/Users/jon/projects/sigra/priv/templates/sigra.install/core/emails.ex:22), not browser-side templates. [VERIFIED: codebase grep] |
| Inline CSS for snapshot inputs | API / Backend | — | Premailex operates on HTML strings before delivery or snapshotting; it is not a browser concern. [CITED: https://hexdocs.pm/premailex/README.html] |
| Semantic/security assertions (recipient, XSS, multipart parity, byte size) | API / Backend | — | These checks are properties of the `Swoosh.Email` struct and rendered bodies; ExUnit can verify them faster and more deterministically than a browser lane. [CITED: https://hexdocs.pm/swoosh/Swoosh.TestAssertions.html] [VERIFIED: codebase grep] |
| Visual regression across engine/theme matrix | Browser / Client | Frontend Server (SSR) | Screenshot truth belongs to Playwright because the output differences are engine-rendering differences; CI provides the stable host environment. [CITED: https://playwright.dev/docs/test-snapshots] [VERIFIED: codebase grep] |
| CSS compatibility policy | API / Backend | — | The allowlist/deny-list is static data + linting logic against rendered markup and extracted declarations. [CITED: https://github.com/hteumeuleu/caniemail] [CITED: https://www.caniemail.com/support/] |
| Evidence manifest + report generation | API / Backend | CDN / Static | The manifest is generated from CI outputs, then published as repo docs and workflow artifacts/release assets. [CITED: https://docs.github.com/en/actions/tutorials/store-and-share-data] [CITED: https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations] |
| Artifact retention / provenance | CDN / Static | API / Backend | GitHub Actions artifacts and attestations own retention/digest/provenance, while Elixir tasks only prepare the files to publish. [CITED: https://docs.github.com/en/actions/tutorials/store-and-share-data] [CITED: https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations] |

## Project Constraints (from CLAUDE.md)

- The blessed stack is Phoenix 1.8+ / Ecto 3.x, so phase recommendations should stay inside the existing Elixir/Phoenix/Swoosh setup rather than introduce a separate email build system. [VERIFIED: CLAUDE.md]
- Security-sensitive behavior belongs in the library and generated code, so the harness should inspect the shipped template builders instead of synthetic mock HTML. [VERIFIED: CLAUDE.md]
- Tests should cover happy path, main error cases, and boundary conditions; this aligns with the locked D-86-05 gap list. [VERIFIED: CLAUDE.md]
- Local `mix test` expects Postgres on `localhost:5432` with `postgres/postgres`; the environment currently satisfies that. [VERIFIED: CLAUDE.md] [VERIFIED: local command]
- There are no project skills to apply for this phase. [VERIFIED: CLAUDE.md]

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `premailex` | `0.3.20` (published 2025-01-20) [VERIFIED: hex.pm API] | Inline CSS and derive text from HTML before snapshotting. [CITED: https://hexdocs.pm/premailex/README.html] | Official docs show the exact `html_body` -> `to_inline_css` / `to_text` flow for Swoosh, which matches this repo’s email builders. [CITED: https://hexdocs.pm/premailex/README.html] |
| `@playwright/test` | `1.59.1` current and installed locally. [VERIFIED: npm registry] [VERIFIED: local command] | Pixel-diff visual baselines for Chromium/WebKit and light/dark permutations. [CITED: https://playwright.dev/docs/test-snapshots] | CI already installs Chromium + WebKit and the repo already commits Playwright baselines for admin checkpoints. [VERIFIED: codebase grep] |
| `swoosh` | `1.25.0` current. [VERIFIED: hex.pm API] | Canonical `Swoosh.Email` struct and adapters in the example app. [CITED: https://hexdocs.pm/swoosh/Swoosh.html] | Existing email builders and test configs already rely on Swoosh adapters in dev/test. [VERIFIED: codebase grep] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `@axe-core/playwright` | `4.11.2` current and installed locally. [VERIFIED: npm registry] [VERIFIED: local command] | Optional browser-side a11y JSON alongside snapshots. [VERIFIED: codebase grep] | Use only for evidence augmentation; do not replace the locked Elixir contrast gate with axe-only heuristics. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`] |
| `Swoosh.TestAssertions` | bundled with Swoosh docs, no separate package. [CITED: https://hexdocs.pm/swoosh/Swoosh.TestAssertions.html] | ExUnit assertions over sent emails and `Swoosh.Email` contents. [CITED: https://hexdocs.pm/swoosh/Swoosh.TestAssertions.html] | Use in unit/basic integration tiers only. [CITED: https://hexdocs.pm/swoosh/Swoosh.TestAssertions.html] |
| `Swoosh.Adapters.Local` | existing example dev adapter. [VERIFIED: codebase grep] | Preview/browser mailbox flows. [CITED: https://hexdocs.pm/swoosh/Swoosh.html] | Keep for ad hoc manual preview and existing Playwright mailbox helpers; Phase 86’s snapshot harness does not need to deliver mail. [VERIFIED: codebase grep] |
| `caniemail` open data | JSON/data repo, no package version. [CITED: https://github.com/hteumeuleu/caniemail] | CSS feature allowlist and client-compatibility policy input. [CITED: https://github.com/hteumeuleu/caniemail] | Use for curated lint input, not for dynamic runtime fetching during CI. [CITED: https://www.caniemail.com/support/] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `premailex` | hand-written inline-style rewriting | Bad trade: CSS inlining and HTML-to-text conversion already exist in a maintained Elixir package with Swoosh examples. [CITED: https://hexdocs.pm/premailex/README.html] |
| Playwright baselines | screenshot attachments without committed expectations | Bad trade: the repo already uses committed `toHaveScreenshot` baselines; uncommitted screenshots are evidence, not regression tests. [CITED: https://playwright.dev/docs/test-snapshots] [VERIFIED: codebase grep] |
| caniemail allowlist | ad hoc deny-list with no external source | Bad trade: drift risk and unverifiable compatibility claims. [CITED: https://github.com/hteumeuleu/caniemail] |
| `Swoosh.Adapters.Test` in browser/E2E | `Swoosh.Adapters.Sandbox` or `Local` | Official Swoosh docs say feature/browser/E2E tiers should use `Sandbox` or `Local`, not `TestAssertions` process-message capture. [CITED: https://hexdocs.pm/swoosh/Swoosh.TestAssertions.html] [CITED: https://hexdocs.pm/swoosh/Swoosh.html] |

**Installation:**
```bash
# root mix.exs
mix deps.get

# add only the new Elixir dependency required by this phase
# {:premailex, "~> 0.3.20"}

# Playwright workspace already exists
cd test/example/priv/playwright
npm ci
npx playwright install --with-deps chromium webkit
```

**Version verification:** `premailex 0.3.20` was verified from the Hex API with `inserted_at: 2025-01-20T18:30:08.001072Z`. `@playwright/test 1.59.1` and `@axe-core/playwright 4.11.2` were verified from the npm registry and the checked-in local workspace. `swoosh 1.25.0` was verified from the Hex API with `inserted_at: 2026-04-02T12:23:34.082800Z`. [VERIFIED: hex.pm API] [VERIFIED: npm registry] [VERIFIED: local command]

## Architecture Patterns

### System Architecture Diagram
```text
Frozen Elixir fixtures
  -> Example.Accounts.Emails.* builders
  -> HTML/text bodies
  -> Premailex inline CSS + text normalization
  -> L1 ExUnit semantic/security assertions
  -> prerendered HTML files on disk
  -> Playwright email-visual.spec.ts
      -> Chromium light/dark
      -> WebKit light/dark
      -> toHaveScreenshot baselines
  -> screenshot/report outputs
  -> manifest/report generation
  -> committed README/manifest/hero PNGs
  -> CI artifacts + optional release assets / attestations
```

### Recommended Project Structure
```text
lib/
├── mix/tasks/
│   ├── sigra.email.snapshot.ex   # prerender deterministic email HTML to disk
│   └── sigra.uat.report.ex       # manifest + README/report generation
├── sigra/a11y/
│   └── contrast.ex               # WCAG contrast math
└── sigra/email/
    └── css_lint.ex               # caniemail allowlist / deny-list checks

test/example/test/support/
└── email_assertions.ex           # shared helpers for HTML/text/recipient/XSS checks

test/example/priv/playwright/
├── tests/email-visual.spec.ts    # 36-cell screenshot matrix
└── email_snapshots/              # generated HTML inputs (gitignored)

.planning/uat-evidence/v1.20/
├── email-phase-04/
└── email-phase-08/
```

### Pattern 1: Pre-render Local HTML, Then Snapshot `file://` Inputs
**What:** Use a mix task to call the real `Example.Accounts.Emails` builders, inline CSS with Premailex, and write deterministic `.html` files that Playwright opens from disk. [CITED: https://hexdocs.pm/premailex/README.html] [VERIFIED: codebase grep]
**When to use:** Visual diffs for email output where the DOM does not need a running Phoenix route to render. [VERIFIED: codebase grep]
**Example:**
```elixir
# Source: https://hexdocs.pm/premailex/README.html
html =
  user
  |> Example.Accounts.Emails.suspicious_login_email(details)
  |> Map.fetch!(:html_body)
  |> Premailex.to_inline_css()

File.write!(Path.join(out_dir, "suspicious-login.html"), html)
```

### Pattern 2: Keep Semantic Assertions in ExUnit, Not in Browser Screenshots
**What:** Assert recipient, multipart parity, escaped interpolations, byte size, and deny-list violations directly against `Swoosh.Email` and rendered strings. [CITED: https://hexdocs.pm/swoosh/Swoosh.TestAssertions.html] [VERIFIED: codebase grep]
**When to use:** Any condition that is easier to prove textually than visually. [VERIFIED: codebase grep]
**Example:**
```elixir
email = Emails.email_change_notification_email(user, "new@example.test", cancel_url)

assert [{"", "lifecycle-html@example.test"}] = email.to
assert email.html_body =~ "Cancel email change"
assert email.text_body =~ cancel_url
refute email.html_body =~ "<script>"
assert byte_size(email.html_body) < 100_000
```

### Pattern 3: Commit Playwright Baselines and Update Them Explicitly
**What:** Rely on Playwright `toHaveScreenshot()` with committed `*-snapshots/` baselines and a deliberate `--update-snapshots` workflow for expected visual changes. [CITED: https://playwright.dev/docs/test-snapshots]
**When to use:** Stable, deterministic email renderings across a fixed engine/theme matrix. [CITED: https://playwright.dev/docs/test-snapshots]
**Example:**
```typescript
// Source: https://playwright.dev/docs/test-snapshots
await page.goto(`file://${snapshotPath}`);
await page.emulateMedia({ colorScheme: theme });
await expect(page).toHaveScreenshot(`${template}__${engine}__${theme}.png`, {
  maxDiffPixels: 50,
});
```

### Pattern 4: Treat caniemail Data as Build-Time Policy Input
**What:** Vendor a small allowlist/deny-list JSON derived from caniemail-supported properties/constructs for Gmail web, new Outlook web, and Apple Mail; fail CI when rendered CSS escapes that set. [CITED: https://github.com/hteumeuleu/caniemail] [CITED: https://www.caniemail.com/support/]
**When to use:** Compatibility claims that need a reproducible source rather than subjective reviewer memory. [CITED: https://github.com/hteumeuleu/caniemail]
**Example:**
```json
{
  "clients": ["gmail-web", "outlook-web-new", "apple-mail-macos"],
  "allow_css": ["background-color", "color", "font-size", "font-weight", "padding", "margin", "border-radius"],
  "deny_css": ["position", "display:flex", "display:grid", "background-image"]
}
```

### Anti-Patterns to Avoid

- **Rendering through `/dev/mailbox` for baselines:** that adds adapter/process routing noise when phase 86 only needs the actual HTML bodies. [VERIFIED: codebase grep]
- **Using `Swoosh.TestAssertions` from browser tests:** official docs say feature/E2E tiers should use `Sandbox` or `Local` instead. [CITED: https://hexdocs.pm/swoosh/Swoosh.TestAssertions.html] [CITED: https://hexdocs.pm/swoosh/Swoosh.html]
- **Cross-OS baseline generation:** Playwright warns that rendering varies by OS, fonts, hardware, and mode; keep one CI baseline environment. [CITED: https://playwright.dev/docs/test-snapshots]
- **Live-fetching caniemail data in CI:** it makes builds network-sensitive and non-reproducible; vendor the curated subset. [CITED: https://github.com/hteumeuleu/caniemail]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CSS inlining for email | custom HTML/CSS rewriter | `Premailex.to_inline_css/1` [CITED: https://hexdocs.pm/premailex/README.html] | CSS inlining is edge-case heavy and already solved in the Elixir ecosystem. [CITED: https://hexdocs.pm/premailex/README.html] |
| HTML-to-text derivation | custom DOM stripping heuristics | `Premailex.to_text/1` [CITED: https://hexdocs.pm/premailex/README.html] | Text-part parity becomes easier when both views come from the same renderer contract. [CITED: https://hexdocs.pm/premailex/README.html] |
| Visual diff engine | raw PNG compare shell scripts | Playwright `toHaveScreenshot()` [CITED: https://playwright.dev/docs/test-snapshots] | Playwright already owns baseline storage, update flow, and diff thresholds. [CITED: https://playwright.dev/docs/test-snapshots] |
| Browser-email assertions | custom mailbox polling for everything | `Swoosh.Adapters.Local` preview helpers already present, plus direct builder calls for snapshot generation. [CITED: https://hexdocs.pm/swoosh/Swoosh.html] [VERIFIED: codebase grep] | The repo already has the mailbox path and helper code; phase 86 does not need a new transport abstraction. [VERIFIED: codebase grep] |
| CSS compatibility truth | maintainer memory | caniemail repo + curated allowlist JSON. [CITED: https://github.com/hteumeuleu/caniemail] | The support claim becomes inspectable and reviewable. [CITED: https://www.caniemail.com/support/] |
| Artifact integrity hashing | home-grown SHA bookkeeping only | GitHub artifact digests / attestations plus manifest hashes. [CITED: https://docs.github.com/en/actions/tutorials/store-and-share-data] [CITED: https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations] | GitHub already emits digest/provenance primitives in CI. [CITED: https://docs.github.com/en/actions/tutorials/store-and-share-data] |

**Key insight:** The fragile part of this phase is not screenshot capture; it is keeping semantics, rendering, compatibility policy, and evidence provenance anchored to one deterministic source of truth. Reuse the existing builders, existing Playwright lane, and existing GitHub artifact model. [VERIFIED: codebase grep] [CITED: https://playwright.dev/docs/test-snapshots] [CITED: https://docs.github.com/en/actions/tutorials/store-and-share-data]

## Common Pitfalls

### Pitfall 1: Snapshot flake from host-environment drift
**What goes wrong:** Identical HTML produces different PNGs on local macOS vs CI Linux or when fonts/headless mode differ. [CITED: https://playwright.dev/docs/test-snapshots]
**Why it happens:** Playwright explicitly warns that rendering varies by OS, hardware, settings, and mode. [CITED: https://playwright.dev/docs/test-snapshots]
**How to avoid:** Generate and update baselines in one environment only, preferably the same CI image that will verify them. [CITED: https://playwright.dev/docs/test-snapshots]
**Warning signs:** Large diff churn with no template edits, especially across local-vs-CI runs. [CITED: https://playwright.dev/docs/test-snapshots]

### Pitfall 2: Time- or data-dependent template branches making baselines churn
**What goes wrong:** `DateTime.utc_now/0`, dynamic IP/device strings, or scheduled dates produce different screenshots or copy on each run. [VERIFIED: codebase grep]
**Why it happens:** Several builders already default time-related fields when a fixture is not supplied, for example `suspicious_login_email/2` and `password_changed_email/2`. [VERIFIED: codebase grep]
**How to avoid:** Freeze every fixture used by the snapshot mix task and add separate unit tests for the default-argument branches. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
**Warning signs:** Snapshot filenames remain stable but the rendered copy changes on every run. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]

### Pitfall 3: Using the wrong Swoosh adapter for the wrong test tier
**What goes wrong:** Browser/E2E tests fail to observe emails reliably, or async tests become flaky. [CITED: https://hexdocs.pm/swoosh/Swoosh.TestAssertions.html] [CITED: https://hexdocs.pm/swoosh/Swoosh.html]
**Why it happens:** `Swoosh.TestAssertions` is process-message based and the docs scope it to unit/basic integration tiers; feature/E2E tiers should use `Sandbox` or `Local`. [CITED: https://hexdocs.pm/swoosh/Swoosh.TestAssertions.html] [CITED: https://hexdocs.pm/swoosh/Swoosh.html]
**How to avoid:** Keep phase 86 snapshot generation off the delivery path entirely; where browser flows need mailbox access, stay on the repo’s existing `Local` preview seam. [VERIFIED: codebase grep]
**Warning signs:** Tests pass when run alone but fail under async or browser orchestration. [CITED: https://hexdocs.pm/swoosh/Swoosh.TestAssertions.html]

### Pitfall 4: Over-claiming client compatibility from caniemail aggregate scores
**What goes wrong:** A maintainer interprets caniemail’s support score as proof of exact real-client parity, including legacy Outlook desktop. [CITED: https://www.caniemail.com/support/]
**Why it happens:** caniemail’s own support page notes that the estimate uses latest tested versions and can average across materially different clients. [CITED: https://www.caniemail.com/support/]
**How to avoid:** Use caniemail only as a policy input for allowed CSS/features and keep the residual statement explicit in docs/evidence. [CITED: https://www.caniemail.com/support/] [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
**Warning signs:** Documentation starts implying Outlook desktop Word-engine coverage or exact market-share guarantees. [CITED: https://www.caniemail.com/support/]

### Pitfall 5: Artifact evidence drifting from committed planning docs
**What goes wrong:** README tables, manifest JSON, and uploaded artifacts describe different SHA/count/disposition values. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
**Why it happens:** Multiple hand-maintained evidence files are updated separately. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
**How to avoid:** Generate the manifest and README from one task and carry SHA/digest values forward from CI outputs. [CITED: https://docs.github.com/en/actions/tutorials/store-and-share-data] [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
**Warning signs:** Snapshot count mismatches, missing cells, or stale SHA suffixes in evidence folders. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]

## Code Examples

Verified patterns from official sources and this repo:

### Premailex Swoosh-style normalization
```elixir
// Source: https://hexdocs.pm/premailex/README.html
html = Premailex.to_inline_css(email.html_body)
text = Premailex.to_text(email.html_body)

email
|> html_body(html)
|> text_body(text)
```

### Playwright visual baseline assertion
```typescript
// Source: https://playwright.dev/docs/test-snapshots
await expect(page).toHaveScreenshot('landing.png', {
  maxDiffPixels: 50,
});
```

### Repo-grounded ExUnit mail assertion posture
```elixir
// Source: https://hexdocs.pm/swoosh/Swoosh.TestAssertions.html
import Swoosh.TestAssertions

assert_email_sent(fn email ->
  assert [{"", "security-html-contract@example.test"}] = email.to
  assert email.html_body =~ "/users/reset-password"
end)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual “open previews in MUAs and capture screenshots” for SEED-1/2 residuals. [VERIFIED: codebase grep] | Repo-native visual regression harness with committed Playwright baselines and CI evidence. [VERIFIED: `.planning/REQUIREMENTS.md`] | v1.20 planning, Phase 86 context and requirements rewording on 2026-04-25/26. [VERIFIED: codebase grep] | The claim becomes reproducible from any SHA instead of reviewer-memory based. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`] |
| Structural HTML assertions only in ExUnit. [VERIFIED: codebase grep] | Structural assertions plus contrast, byte budget, recipient/XSS/multipart checks, plus browser-render baselines. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`] | Phase 86 scope. [VERIFIED: `.planning/REQUIREMENTS.md`] | Moves most email-regression risk from launch-time spot checks into PR-time CI. [VERIFIED: `.planning/REQUIREMENTS.md`] |
| Artifact uploads used mainly for admin Playwright reviewer bundles with 7/14-day retention. [VERIFIED: codebase grep] | Email evidence should use the same upload-artifact mechanism, plus optional tag-time release assets and attestations for longer-lived evidence. [CITED: https://docs.github.com/en/actions/tutorials/store-and-share-data] [CITED: https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations] | Phase 86 recommendation. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`] | Better provenance and longer-lived auditability. [CITED: https://docs.github.com/en/actions/tutorials/store-and-share-data] |

**Deprecated/outdated:**

- Human-only SEED-1/SEED-2 residual claims in `docs/uat-ci-coverage.md` are outdated once Phase 86 lands and should be rewritten to point at the `email_visual_regression` lane. [VERIFIED: codebase grep]
- Treating CTA contrast as acceptable solely because the button qualifies as large bold text is intentionally superseded by the locked color bump and 4.5:1 gate. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`] [CITED: https://www.w3.org/WAI/GL/UNDERSTANDING-WCAG20/visual-audio-contrast-contrast.html]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | GitHub release-asset promotion should happen in Phase 86 rather than waiting for Phase 89 tag publication. [ASSUMED] | Common Pitfalls / Evidence flow implications | Low: planner can move release-asset promotion to Phase 89 if tag-only release mechanics are preferred. |

## Open Questions

1. **Should the full-bundle GitHub release asset be produced in Phase 86 or deferred to the actual `v1.20.0` tag workflow?**
   - What we know: the locked context wants long-lived evidence and explicitly references release assets at tag time. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
   - What's unclear: whether the phase should implement only artifact upload on PR/main and leave release publication wiring to the launch/tag phase. [ASSUMED]
   - Recommendation: implement artifact upload + manifest digests in Phase 86, and make release-asset promotion a tag-conditional extension that can be exercised in Phase 89 if needed. [CITED: https://docs.github.com/en/actions/tutorials/store-and-share-data]

2. **Where should the prerender/report mix tasks live?**
   - What we know: the context explicitly leaves `lib/mix/tasks/` vs `test/example/lib/mix/tasks/` to planner discretion. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
   - What's unclear: whether the task should be library-root for easier CI invocation or example-app-scoped for easier access to `Example.Accounts.Emails`. [VERIFIED: codebase grep]
   - Recommendation: put the tasks at the repo root if they can boot the example app code explicitly; otherwise keep them in `test/example` and call them from CI with `working-directory: test/example`. [VERIFIED: codebase grep]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir / Mix | prerender task, ExUnit, report generation | ✓ | `Mix 1.19.5` / `OTP 28` [VERIFIED: local command] | — |
| Node.js | Playwright runner | ✓ | `v22.14.0` [VERIFIED: local command] | — |
| npm / npx | Playwright workspace install/run | ✓ | `11.1.0` [VERIFIED: local command] | — |
| Playwright CLI | snapshot execution | ✓ | `1.59.1` [VERIFIED: local command] | Local `npx playwright test` from checked-in workspace |
| PostgreSQL server | existing example/lib tests and CI parity | ✓ | `localhost:5432 accepting connections` [VERIFIED: local command] | none for full local parity |
| Docker | disposable local Postgres if needed | ✓ | `docker` present; version previously reported `29.3.1` [VERIFIED: local command] | use existing local Postgres service |
| `curl` / `jq` | manifest/version helpers and CI scripting | ✓ | `curl 8.7.1`, `jq 1.7.1` [VERIFIED: local command] | Elixir JSON writer if shell helpers are avoided |

**Missing dependencies with no fallback:**

- None found for planning this phase. [VERIFIED: local command]

**Missing dependencies with fallback:**

- None. [VERIFIED: local command]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (repo-native) + Playwright `@playwright/test 1.59.1`. [VERIFIED: codebase grep] [VERIFIED: local command] |
| Config file | [`test/test_helper.exs`](/Users/jon/projects/sigra/test/test_helper.exs:1), [`test/example/test/test_helper.exs`](/Users/jon/projects/sigra/test/example/test/test_helper.exs:1), [`test/example/priv/playwright/playwright.config.ts`](/Users/jon/projects/sigra/test/example/priv/playwright/playwright.config.ts:1). [VERIFIED: codebase grep] |
| Quick run command | `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/example/accounts/emails_security_html_test.exs test/example/accounts/emails_lifecycle_html_test.exs -x` after the phase lands. [VERIFIED: codebase grep] |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test && (cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test --include example_app) && (cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/email-visual.spec.ts)` after the phase lands. [VERIFIED: codebase grep] [ASSUMED] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GAUAT-01 | `lockout_notification_email` and `suspicious_login_email` semantic correctness, compatibility lint, and 8 visual baselines. [VERIFIED: `.planning/REQUIREMENTS.md`] | unit + browser visual | `cd test/example && mix test test/example/accounts/emails_security_html_test.exs -x` and `cd test/example/priv/playwright && npx playwright test tests/email-visual.spec.ts --grep "phase-04"` [ASSUMED] | ❌ Wave 0 for visual spec / ✅ current HTML tests |
| GAUAT-02 | Seven lifecycle templates semantic correctness, compatibility lint, and 28 visual baselines. [VERIFIED: `.planning/REQUIREMENTS.md`] | unit + browser visual | `cd test/example && mix test test/example/accounts/emails_lifecycle_html_test.exs -x` and `cd test/example/priv/playwright && npx playwright test tests/email-visual.spec.ts --grep "phase-08"` [ASSUMED] | ❌ Wave 0 for visual spec / ✅ current HTML tests |

### Sampling Rate

- **Per task commit:** targeted email ExUnit files, then the visual spec if Playwright inputs changed. [VERIFIED: codebase grep]
- **Per wave merge:** full `example_unit_smoke` and the dedicated `email_visual_regression` CI lane. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
- **Phase gate:** all existing CI jobs plus the new email lane green before `86-VERIFICATION.md` is written. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]

### Wave 0 Gaps

- [ ] `lib/sigra/a11y/contrast.ex` and `test/sigra/a11y/contrast_test.exs` — covers WCAG contrast math. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
- [ ] `test/example/test/support/email_assertions.ex` — shared semantic/security assertions for the two existing email test files. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
- [ ] `lib/sigra/email/css_lint.ex` and vendored allowlist data — covers caniemail-backed lint. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
- [ ] `test/example/priv/playwright/tests/email-visual.spec.ts` and committed snapshot directory — covers GAUAT-01/02 browser matrix. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]
- [ ] `mix sigra.email.snapshot` and `mix sigra.uat.report` task(s) — generate deterministic inputs and evidence outputs. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | The phase does not change auth decisions; it verifies email evidence and rendering. [VERIFIED: `.planning/REQUIREMENTS.md`] |
| V3 Session Management | no | No session-creation or rotation behavior changes are required in this phase. [VERIFIED: `.planning/REQUIREMENTS.md`] |
| V4 Access Control | no | The work is template/test/CI focused, not authorization focused. [VERIFIED: `.planning/REQUIREMENTS.md`] |
| V5 Input Validation | yes | Escape interpolated user-controlled fields and fuzz them in ExUnit assertions. [VERIFIED: codebase grep] [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`] |
| V6 Cryptography | no | The phase consumes already-generated reset/confirm URLs but does not modify token generation. [VERIFIED: codebase grep] |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Unescaped interpolated field in email HTML/text | Tampering / Information Disclosure | Assert escaped output in ExUnit and retain `html_escape_string/1` usage in the template builders. [VERIFIED: codebase grep] |
| Wrong-recipient delivery on email-change flows | Spoofing / Information Disclosure | Add recipient assertions on `email.to` for old-vs-new-email templates. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`] |
| Gmail clipping hides security instructions | Denial of Service | Enforce a body byte budget below 100 KB. [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`] |
| CSS feature causes catastrophic Outlook/new-client degradation | Denial of Service | caniemail-backed allowlist plus deny-list for unsupported patterns such as `position`, `flex`, `grid`, `background-image`. [CITED: https://github.com/hteumeuleu/caniemail] [VERIFIED: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md`] |
| Evidence provenance ambiguity | Repudiation | Include SHA in filenames/manifests and rely on artifact digests or attestations in GitHub Actions. [CITED: https://docs.github.com/en/actions/tutorials/store-and-share-data] [CITED: https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations] |

## Sources

### Primary (HIGH confidence)

- `86-CONTEXT.md` — locked implementation decisions, evidence shape, residual policy, and sequencing. [VERIFIED: codebase grep]
- [`priv/templates/sigra.install/core/emails.ex`](/Users/jon/projects/sigra/priv/templates/sigra.install/core/emails.ex:22) — actual template builders and helper locations. [VERIFIED: codebase grep]
- [`test/example/test/example/accounts/emails_security_html_test.exs`](/Users/jon/projects/sigra/test/example/test/example/accounts/emails_security_html_test.exs:25) and [`emails_lifecycle_html_test.exs`](/Users/jon/projects/sigra/test/example/test/example/accounts/emails_lifecycle_html_test.exs:15) — current assertion coverage. [VERIFIED: codebase grep]
- [`test/example/priv/playwright/playwright.config.ts`](/Users/jon/projects/sigra/test/example/priv/playwright/playwright.config.ts:1) and [`ci.yml`](/Users/jon/projects/sigra/.github/workflows/ci.yml:551) — existing Playwright and artifact patterns. [VERIFIED: codebase grep]
- https://hexdocs.pm/premailex/README.html — official Premailex usage and Swoosh integration. [CITED: https://hexdocs.pm/premailex/README.html]
- https://playwright.dev/docs/test-snapshots — official snapshot-baseline behavior, update flow, and diff options. [CITED: https://playwright.dev/docs/test-snapshots]
- https://hexdocs.pm/swoosh/Swoosh.TestAssertions.html and https://hexdocs.pm/swoosh/Swoosh.html — official Swoosh test-tier guidance. [CITED: https://hexdocs.pm/swoosh/Swoosh.TestAssertions.html] [CITED: https://hexdocs.pm/swoosh/Swoosh.html]
- https://github.com/hteumeuleu/caniemail and https://www.caniemail.com/support/ — caniemail data model, licensing, and support-estimate caveats. [CITED: https://github.com/hteumeuleu/caniemail] [CITED: https://www.caniemail.com/support/]
- https://docs.github.com/en/actions/tutorials/store-and-share-data and https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations — GitHub artifact digest/retention and attestation behavior. [CITED: https://docs.github.com/en/actions/tutorials/store-and-share-data] [CITED: https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations]

### Secondary (MEDIUM confidence)

- https://www.w3.org/WAI/GL/UNDERSTANDING-WCAG20/visual-audio-contrast-contrast.html — practical reference for 4.5:1 and 3:1 thresholds used by the phase’s contrast policy. [CITED: https://www.w3.org/WAI/GL/UNDERSTANDING-WCAG20/visual-audio-contrast-contrast.html]

### Tertiary (LOW confidence)

- None beyond the single explicit assumption in the Assumptions Log. [VERIFIED: this document]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — all recommended tools were verified against the current codebase and official package/docs sources. [VERIFIED: codebase grep] [VERIFIED: npm registry] [VERIFIED: hex.pm API]
- Architecture: HIGH — the proposed seams line up with actual repo structure and existing CI/Playwright patterns. [VERIFIED: codebase grep]
- Pitfalls: HIGH — determinism, adapter-scope, and artifact-retention concerns are directly documented by the official tools involved and already visible in this repo. [CITED: https://playwright.dev/docs/test-snapshots] [CITED: https://hexdocs.pm/swoosh/Swoosh.TestAssertions.html] [CITED: https://docs.github.com/en/actions/tutorials/store-and-share-data]

**Research date:** 2026-04-26
**Valid until:** 2026-05-26 for repo-grounded implementation guidance; recheck package/docs URLs sooner if dependencies are upgraded. [VERIFIED: npm registry] [VERIFIED: hex.pm API]

## RESEARCH COMPLETE
