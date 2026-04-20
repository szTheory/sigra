# Phase 34: Generated-Host E2E Coverage and Phase 28 Retroactive Verification - Context

**Gathered:** 2026-04-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Close **VFY-01** on the **generated-host** path and retroactively document **Phase 28** goal achievement:

1. Author **`28-VERIFICATION.md`** under `.planning/phases/28-user-operations-surface/` so Phase 28 has the same audit-grade closure pattern as adjacent phases.
2. Extend **`test/example/priv/playwright/tests/admin-generated.spec.ts`** so a **freshly scaffolded + installed** host proves `GET /admin/users`, an **authenticated** impersonation start (POST), and `GET /admin/audit/export.csv` with expectations tight enough to catch regressions but aligned with **layered** verification (not a second full product suite).
3. Extend **`scripts/ci/admin-acceptance-smoke.sh`** with **`--test audit-export`** and **`--test impersonation-controller`** (ROADMAP verbatim) and ensure they compose under **`--test all`** exactly as the **`generated_admin_playwright_smoke`** CI job expects.

**Explicitly not in scope:** Phase 35 shift-left gates (missing-VERIFICATION CI blocker, generator emission audit harness, axe/screenshot matrix), new admin features, or moving broad negative matrices from ExUnit into Playwright.

</domain>

<decisions>
## Implementation Decisions

### Synthesis source

User directed **full coverage** of four gray areas in one pass, with subagent research on tradeoffs, ecosystem idioms, and DX. Decisions below unify: (1) `28-VERIFICATION.md` evidence model, (2) Playwright depth for `admin-generated.spec.ts`, (3) bash vs browser split, (4) CI wiring. They are **coherent with Phase 31** (`31-CONTEXT.md` D-02–D-06, D-08–D-11, D-17): example app stays deep; generated host stays **narrow, parity-focused, deterministic**; ExUnit keeps correctness and security matrices.

---

### A — `28-VERIFICATION.md` (retroactive Phase 28)

- **D-01 (Hybrid evidence lanes):** The file MUST use **three explicit lanes** in table text or column tags: **`(library)`**, **`(test/example)`**, **`(generated host / CI)`**. No claim may imply “every host” unless **generated-host** evidence exists for that row. Until Phase 34 automation is green, generated-host rows may show `? SKIP` / `human_needed` with the **exact** command deferred (`GITHUB_WORKSPACE=… scripts/ci/admin-acceptance-smoke.sh --test all`), mirroring honesty in `32-VERIFICATION.md`.
- **D-02 (Skeleton parity):** Mirror **`30-VERIFICATION.md` / `32-VERIFICATION.md`**: YAML frontmatter (`phase`, `verified`, `status`, `score`, `overrides_applied`, `human_verification`), then **Goal achievement → Observable Truths**, **Required Artifacts**, **Key Link Verification**, **Data-flow trace** (or “N/A” with rationale), **Behavioral spot-checks**, **Requirements coverage** (map **USER-01–USER-05**), **Anti-patterns**, **Gaps summary**, **Disconfirmation pass** (what tests do *not* prove), footer metadata.
- **D-03 (Score anchor):** Minimum **M = 5** must-haves tied to **ROADMAP Phase 28** success criteria; add rows for cross-cutting invariants already locked in **`28-CONTEXT.md`** (URL-addressable filters **D-04**, scope-visible chrome **D-08**, preview vs explorer **D-24**) only where they are **falsifiable** with cited tests or scripts.
- **D-04 (Spot-check commands):** Reuse commands from **`28-VALIDATION.md`** where they exist; do not invent a divergent “second test story.”
- **D-05 (Human verification):** Any subjective **readability / mobile feel** or **not run locally** full smoke stays under **`human_verification:`** with crisp `test` / `expected` / `why_human` — same pattern as Phase 32’s CI-deferred items.

---

### B — `admin-generated.spec.ts` depth and “strict status”

- **D-06 (Contract tests, not product UX tests):** Treat this file as **generator + installer + runtime wiring contract** for the default admin seams. Assert **stable operator-visible outcomes** (roles/labels, scope text, denial copy already in Phase 31) and **security invariants** (e.g. org admin still blocked from global `/admin`). Avoid encoding **example-only** cosmetic copy unrelated to the generator contract.
- **D-07 (Strict vs semantic HTTP):** Use **strict** expectations where ambiguity hides security regressions (e.g. unknown-org audit must not become **200**; unauthenticated access to privileged admin surfaces must not “accidentally succeed”). Use **small allowed sets** `[200, 302]` (or documented equivalents) **only** when the **generator explicitly allows** multiple legitimate transport shapes (e.g. export behind auth may redirect to login **or** return **403** — pick the set **once** from observed Phoenix/Sigra behavior and document it in the spec comment + VERIFICATION row). Prefer **outcome assertions** (final URL, presence of CSV/disposition signal, key body substring) over fragile multi-hop redirect chains.
- **D-08 (GET /admin/users):** After platform-admin login, assert **200** on global `/admin/users` and that the page exposes **list semantics** (e.g. heading/table or landmark consistent with library LiveView) using **`getByRole` / labels** per Playwright best practices — not CSS nth-child paths.
- **D-09 (POST impersonation):** Prove **authenticated** platform admin can **start** impersonation for a **seeded non-admin** user after **sudo is fresh** (follow the **example** specs’ pattern: `test/example/priv/playwright/tests/impersonation.spec.ts` and fixtures). Assert **banner or equivalent visible marker** on a subsequent navigation if that is already the contract in example tests; if that is too heavy for flake budget, minimum bar is: **POST succeeds** (expected **3xx** redirect to target) **and** a follow-up **GET** shows **effective user changed** per a stable DOM signal — document whichever tier Phase 34 implements in **Observable Truths** so planners cannot silently weaken it later.
- **D-10 (GET audit export):** Assert **CSV response** invariants: **200**, `content-type` compatible with CSV, and **non-empty body** with **header row** present; do **not** snapshot full CSV bytes (timestamps and audit IDs drift). Cross-check scope (global vs org) matches the **seeded** scenario.
- **D-11 (No suite duplication):** Do **not** copy the entire **`admin-user-operations.spec.ts` / `admin-audit.spec.ts`** matrix into `admin-generated.spec.ts`. **Share** login helpers from **`helpers/fixtures.ts`** (or extract a tiny shared module) so seeds and passwords stay single-sourced.
- **D-12 (Isolation and flakes):** Prefer **web-first assertions**, no fixed `sleep`, reuse CI’s existing **trace / video on failure** policy from `playwright.config.ts` for the generated-host project. If retries are added, do so via **Playwright config** (`retries` in CI), not ad-hoc script reruns that re-scaffold.

---

### C — `admin-acceptance-smoke.sh` vs Playwright

- **D-13 (Mandatory bash gate):** **Always** run the existing **HTTP parity block** (`gen_expect_non_5xx`, unknown-org denial, unauthenticated POST impersonation **non-5xx** probe) **before** Playwright for every `--test` target, including new slices. Bash proves **scaffold + install + compile + boot + dispatch without 5xx** including cases **compilation cannot catch** (commentary already in script around impersonation).
- **D-14 (Orthogonal duplication only):** Bash asserts **mount / non-5xx / catastrophic denial** semantics; Playwright asserts **session, CSRF, sudo, and operator-visible success paths**. Do **not** duplicate CSV row-level correctness in bash **and** Playwright — row logic remains **ExUnit**-owned per Phase 31.
- **D-15 (`--test` naming):** Match **ROADMAP** literals: **`audit-export`** and **`impersonation-controller`**. Each runs a **filtered Playwright subset** (e.g. `-g` title regex or equivalent) after the standard bash probes. Optional: accept **`impersonation`** as a hidden **alias** for `impersonation-controller` in the `case` statement for ergonomics only — document alias in script header if added.
  Keep **`all`** = **bash probes + full `admin-generated.spec.ts` suite** (union of release-blocking slices). Document in **`sed -n` help** header that feature slices **do not skip** bash probes.
- **D-16 (curl discipline):** Keep using **`-w "%{http_code}"`** without **`curl -f`** on probes that intentionally accept **302/403/404**. Stay deliberate about **`-L`** and max redirects; document any new probe’s redirect behavior in script comments.

---

### D — CI / `generated_admin_playwright_smoke`

- **D-17 (Single job default):** Keep **one** `generated_admin_playwright_smoke` job invoking **`scripts/ci/admin-acceptance-smoke.sh --test all`**. Phase 34 extends **ordering inside the script** rather than fanning parallel jobs (cold `mix phx.new` + compile dominates; parallel without artifact reuse multiplies cost).
- **D-18 (Timeouts and retries):** Add **`timeout-minutes`** on the job (recommend **45–60** initially; tune from observed p95). Surface **`PLAYWRIGHT_RETRIES`** (or config `retries`) via workflow `env` for one-knob CI flake mitigation **without** re-scaffolding on retry.
- **D-19 (Artifacts):** Preserve the **two-tier** policy already in `ci.yml`: **always** upload HTML report + curated `admin-*.png`; **failure-only** upload `test-results/` traces/videos. New specs must write diagnostics under existing paths unless a strong reason exists to extend.
- **D-20 (Local repro):** Treat **`GITHUB_WORKSPACE=$(pwd)`** + Postgres trio + optional `PORT` / `TMP_APP_DIR` as the **only** supported local contract; extend script `--help` text so bisecting **`--test audit-export`** / **`--test impersonation`** is copy-paste identical to CI semantics (modulo machine speed).
- **D-21 (Phase 35 coordination):** Any **`{N}-VERIFICATION.md` gate** belongs in a **fast, separate** workflow job (checkout-only). Do **not** fold doc presence checks into this smoke job.

---

### Claude's Discretion

- Exact Playwright **grep / tag** wiring for `--test audit-export` vs `--test impersonation-controller` (project may use `-g` title regex or `@tag` — pick one style and stay consistent with existing `chrome` / `errors` slices).
- Minor timeout / retry integers after first CI timing samples.
- Exact CSV header string constant **if** the export template offers multiple acceptable spellings — prefer matching **library-owned** fixture text.

### Folded Todos

_None — `gsd-sdk query todo.match-phase` unavailable in this environment._

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap and requirements
- `.planning/ROADMAP.md` — Phase 34 goal, success criteria, dependency on Phase 33.
- `.planning/milestones/v1.2-REQUIREMENTS.md` — **VFY-01**, **USER-01–USER-05** traceability (archived v1.2 requirements; live `.planning/REQUIREMENTS.md` is recreated per milestone).
- `.planning/PROJECT.md` — automation-first milestone posture, hybrid lib+generator architecture.

### Phase intent (locked behavior from earlier work)
- `.planning/phases/28-user-operations-surface/28-CONTEXT.md` — user-ops IA, URL-addressable filters, scope chrome, session revocation, preview vs explorer.
- `.planning/phases/31-automation-first-verification/31-CONTEXT.md` — **layered model**: example deep, generated shallow, ExUnit owns security matrices, smoke is thin wiring proof.
- `.planning/phases/33-admin-shell-navigation-and-audit-preview-polish/33-CONTEXT.md` — explicit handoff: generated-host browser/smoke extensions are **Phase 34**.

### Verification templates
- `.planning/phases/30-audit-exploration-and-export/30-VERIFICATION.md` — skeleton, disconfirmation pass, human_verification pattern.
- `.planning/phases/32-generated-installer-admin-surface-parity/32-VERIFICATION.md` — generator honesty, deferred-to-CI language, observable truths tables.

### Implementation touchpoints
- `scripts/ci/admin-acceptance-smoke.sh` — scaffold, seed, boot, `GENERATED_HOST_AUDIT_ROUTES`, impersonation POST probe, Playwright driver.
- `.github/workflows/ci.yml` — `generated_admin_playwright_smoke` job (Node, Playwright chromium, `--test all`, artifact uploads).
- `test/example/priv/playwright/tests/admin-generated.spec.ts` — narrow generated-host suite to extend.
- `test/example/priv/playwright/tests/impersonation.spec.ts` — reference patterns for sudo + impersonation flows on the **example** host (reuse helpers, do not fork behavior arbitrarily).
- `test/example/priv/playwright/tests/admin-audit.spec.ts` — audit + export patterns for the example host.
- `test/example/priv/playwright/playwright.config.ts` — project boundaries for admin-generated vs example suites.

### External guidance (HTTP/browser testing hygiene)
- [Playwright best practices](https://playwright.dev/docs/best-practices) — role-based locators, isolation, web-first assertions, trace-on-failure.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`admin-acceptance-smoke.sh`**: deterministic **`mix phx.new` + `mix sigra.install`**, seed snippet, **`gen_expect_non_5xx`**, unknown-org probe, Playwright **`SIGRA_EXAMPLE_URL`** override — extend before/after Playwright consistently.
- **`admin-generated.spec.ts`**: `logIn` helper, viewport constants, **`captureAdminCheckpoint`** — extend with shared login and new `test.describe` blocks rather than new files unless file length forces a split.
- **Example Playwright specs + `helpers/fixtures.ts`**: canonical passwords/emails aligned with smoke **`SIGRA_*`** env vars.

### Established Patterns
- **Phase 31 commentary** inside `admin-generated.spec.ts` explicitly forbids collapsing into a monolithic verification matrix — Phase 34 additions must stay **parity/wiring** scoped.
- **Bash probes** intentionally allow **non-5xx** unauthenticated POST to prove **controller load** — authenticated semantics stay Playwright (script comments already say this; keep that contract).

### Integration Points
- CI job **`generated_admin_playwright_smoke`** must remain **`--test all`** unless a measured need splits jobs with shared artifacts (defer until proven).
- **`28-VALIDATION.md`** (under phase 28 directory) is the command source of truth for **spot-checks** section of **`28-VERIFICATION.md`**.

</code_context>

<specifics>
## Specific Ideas

- User requested a **single coherent recommendation set** after research across all four gray areas; decisions above reflect merged subagent findings plus Sigra’s existing **Phase 31** layered verification contract.
- **`28-VERIFICATION.md`** should call out **Phase 30 human-UAT item #2** closure explicitly once generated-host export + impersonation automation lands (per ROADMAP gap-closure language).

</specifics>

<deferred>
## Deferred Ideas

- **Parallel CI jobs** or **cached generated-app tarball** between prepare and test shards — only if `generated_admin_playwright_smoke` wall-clock or flake taxonomy justifies the complexity (see Phase 35 for other gates).
- **Deeper visual regression** for generated host — Phase 35 territory (`toHaveScreenshot` matrix in ROADMAP Phase 35).

### Reviewed Todos (not folded)

_None — todo matcher unavailable in this environment._

</deferred>

---

*Phase: 34-generated-host-e2e-coverage-and-phase-28-retroactive-verification*
*Context gathered: 2026-04-17*
