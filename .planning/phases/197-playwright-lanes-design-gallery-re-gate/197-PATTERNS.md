# Phase 197: Playwright Lanes & Design-Gallery Re-Gate - Pattern Map

**Mapped:** 2026-06-20
**Files analyzed:** 7 (modified) + 2 (new assets)
**Analogs found:** 9 / 9 (every file in play has a concrete in-repo analog; this is an infra/config phase — no greenfield)

> This is a CI/test-infra + render-determinism phase. There are no "controllers/services/models." Files are classified by infra role (workflow job/step, browser spec helper, served CSS, seed orchestrator, CI guard script) and data flow (orchestration, poll/readiness, render-asset, fixture-data, drift-gate). Every analog already lives in this repo — the work is *extend an existing pattern in place*, not invent one.

## File Classification

| File (modified/new) | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `.github/workflows/ci.yml` — `if:` guards + aggregator on `example_playwright_smoke` test steps | workflow-step | orchestration / failure-surfacing | existing `if: success()` / `if: always()` / `if: failure()` steps in the same job (ci.yml:1015, 1078, 1087, 1094) | exact (same job, same idiom) |
| `.github/workflows/ci.yml` — NEW `admin_design_recapture` sibling job | workflow-job | non-PR-gated batch recapture | Phase-196 conditional jobs `upgrade_smoke` (ci.yml:512–563), `passkeys_manual_fallback_smoke` (565+) | exact (sibling job, same trigger precedent) |
| `test/example/priv/static/assets/fonts/space-grotesk-var.woff2` — NEW committed font binary | render-asset | static asset | `scripts/brand/fonts/SpaceGrotesk[wght].ttf` (in-repo variable TTF source) | source-present (convert, not author) |
| `test/example/priv/static/assets/css/app.css` — `@font-face` + `--font-sans` override | served-CSS | render-determinism | `default.css:9` `--font-sans` declaration; `app.css` is last in cascade (`root.html.heex:12`) | role-match (same token, durable home) |
| `test/example/priv/playwright/tests/admin-design.spec.ts` — `document.fonts.ready` in `waitForLiveViewReady`; MG-5/6 `test.fail()` → seed-or-skip | browser-spec-helper | render-readiness + data-dependency | the existing `waitForLiveViewReady` (admin-design.spec.ts:15–19) itself | exact (extend in place) |
| `test/example/priv/playwright/tests/organizations.spec.ts:152` — `waitForTimeout(1_000)` → `expect.poll()` | browser-spec-helper | poll/readiness | `passkeys-hooks.spec.ts:101–114` `await expect.poll(...)` (real in-suite usage) | exact (idiomatic analog) |
| `test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts:106` — same rewrite | browser-spec-helper | poll/readiness | `passkeys-hooks.spec.ts:101–114`; also `organizations.spec.ts:115–156` (byte-identical loop to port together) | exact |
| `test/example/lib/example/demo/seeds.ex` (and/or `priv/repo/seeds.exs`) — ≥25-event user for MG-5/6 | seed-orchestrator | fixture-data | `seed_audit_events/2` + `insert_audit_batch/3` (seeds.ex:634–706) | exact (the audit-seed path already exists) |
| `scripts/ci/snapshot-canary-guard.sh` usage in the recapture job | CI-drift-gate | drift-gate / commit-path | the guard's own `--allow` / `--allowlist` / `--canary` flag handling (snapshot-canary-guard.sh:27–29, 89–112) | exact (consume, do not edit the script) |

---

## Pattern Assignments

### `.github/workflows/ci.yml` — D-01/D-02 guards + aggregator (workflow-step, orchestration)

**Analog:** the same `example_playwright_smoke` job already uses every guard idiom needed. Copy these verbatim conditionals; the only new thing is giving each test step an `id:` and adding one aggregator step.

**Existing guard idioms already in the job** (no invention needed):
```yaml
# ci.yml:1015  — gate on cumulative success (will be REPLACED per Pitfall 4)
- name: Stage admin checkpoint PNGs (before later runs clear test-results)
  if: success()
# ci.yml:1078  — run only on failure
- name: Dump example app log (on failure)
  if: failure()
# ci.yml:1087 / 1094 — always run
- name: Cache hit summary
  if: always()
```

**Apply D-01** — add to EACH `npx playwright test` step (ci.yml:973, 991, 1027, 1050, 1068). These steps currently carry NO `if:` (verified — only `working-directory` + `env`), so the first failure masks the rest:
```yaml
- name: Run admin behavior browser truth (chromium)
  id: admin_behavior            # NEW: aggregator reads steps.<id>.outcome
  if: ${{ !cancelled() }}       # ≡ success() || failure(); runs unless job cancelled
  working-directory: test/example/priv/playwright
  env:
    CI: "true"
    SIGRA_EXAMPLE_URL: "http://localhost:4000"
  run: |
    npx playwright test \
      tests/admin-user-operations.spec.ts \
      ... --project=chromium
```

**Apply D-02** — one new aggregating step after the last test step (before the existing `if: failure()` dump at 1078), modeled on the bash idiom already used in `release_ref_guard` (ci.yml:38–52) and the cache-summary heredoc style:
```yaml
- name: Aggregate Playwright step outcomes
  if: always()
  run: |
    set -euo pipefail
    fail=0
    for o in "${{ steps.admin_behavior.outcome }}" \
             "${{ steps.admin_checkpoints.outcome }}" \
             "${{ steps.design_gallery.outcome }}" \
             "${{ steps.non_admin_smoke.outcome }}" \
             "${{ steps.demo_showcase.outcome }}"; do
      [ "$o" = "failure" ] && fail=1
    done
    if [ "$fail" -eq 1 ]; then
      echo "::error::one or more Playwright seams failed"; exit 1
    fi
    echo "all seams passed"
```

**Pitfall 4 (Staging-step guard interaction)** — the `Stage admin checkpoint PNGs` step (ci.yml:1015) is `if: success()`. With `!cancelled()` guards, `success()` (= "no previous step failed") goes false after any guarded failure, so staging would skip even when checkpoints itself passed. Change it to read the checkpoints step outcome directly:
```yaml
- name: Stage admin checkpoint PNGs (before later runs clear test-results)
  if: ${{ steps.admin_checkpoints.outcome == 'success' }}   # was: if: success()
```

**D-10 (re-gate the gallery)** — DELETE `continue-on-error: true` at ci.yml:1043 from the "Run design gallery boards" step, AND rewrite the stale comment block at ci.yml:1032–1042 ("the brand webfont does not load in this dev-mode boot…") which encodes the SEED-006 false premise (D-07). The step keeps its `id: design_gallery` + `if: ${{ !cancelled() }}` and now hard-gates via the aggregator.

**D-04 (webkit NOT droppable)** — leave ci.yml:937 `npx playwright install --with-deps chromium webkit` unchanged. Record in VERIFICATION that the `webkit` drop is infeasible (three mobile projects use `iPhone 13` = webkit). The only safe consolidation lever yields near-zero wall-clock (serial `workers:1`); frame criterion 1b as "modestly met."

---

### `.github/workflows/ci.yml` — NEW `admin_design_recapture` job (workflow-job, batch recapture)

**Analog:** `upgrade_smoke` (ci.yml:512–563) — a non-PR-gated sibling job. Copy its exact header shape; the boot prelude is identical to `example_playwright_smoke` (ci.yml:885–968).

**Trigger + needs pattern** (copy verbatim from upgrade_smoke:512–516, the Phase-196 precedent live at ci.yml:515/568/619/749/1173/1352):
```yaml
admin_design_recapture:
  name: Recapture admin-design baselines (in-CI)
  runs-on: ubuntu-latest
  if: github.event_name != 'pull_request'   # schedule + push(main) + dispatch only
  needs: release_ref_guard
  permissions:
    contents: write                          # REQUIRED — workflow default is `contents: read` (ci.yml:26)
```

**Postgres service block** (copy verbatim from upgrade_smoke:517–525 / example_playwright_smoke:876–884):
```yaml
  services:
    postgres:
      image: postgres:15
      env:
        POSTGRES_PASSWORD: postgres
      ports: ['5432:5432']
      options: >-
        --health-cmd pg_isready --health-interval 10s
        --health-timeout 5s --health-retries 5
```

**Boot prelude** — copy steps `example_playwright_smoke:886–968` verbatim (checkout@v6 SHA-pinned, setup-beam@v1.24.0, setup-node@v6, cache example deps, `mix deps.get`, `mix compile --warnings-as-errors`, `ecto.create && ecto.migrate`, `mix run priv/repo/seeds.exs`, `npm ci`, `npx playwright install --with-deps chromium webkit`, `mix phx.server > /tmp/...log 2>&1 &`, the curl/warm-up readiness loops at 953–968). Same `MIX_ENV: dev` + `PGUSER/PGPASSWORD/PGHOST: postgres/postgres/localhost` env.

**Recapture step** — mirrors the design step (ci.yml:1027–1049) with `--update-snapshots` added:
```yaml
  - name: Recapture admin-design baselines
    working-directory: test/example/priv/playwright
    env:
      CI: "true"
      SIGRA_EXAMPLE_URL: "http://localhost:4000"
    run: |
      npx playwright test \
        tests/admin-design.spec.ts \
        --project=admin-design-chromium \
        --project=admin-design-mobile \
        --project=admin-design-dark \
        --update-snapshots
```

**Commit-path** — consume `snapshot-canary-guard.sh` (do NOT edit it); see the Shared Patterns section below for the `--allow`/`--canary board-notice` mechanics. **Open Questions 1 (board-notice canary re-baseline) and 2 (push-to-main vs open-a-PR) are planner decisions** — both flagged in RESEARCH §Open Questions.

---

### `test/example/priv/static/assets/fonts/space-grotesk-var.woff2` (render-asset, NEW)

**Analog:** `scripts/brand/fonts/SpaceGrotesk[wght].ttf` (in-repo, 136 KB variable wght, OFL). Generate the woff2 ONCE locally with the installed `python3 fontTools 4.62.1` and commit it (keeps the CI recapture job dependency-free — Assumption A1):
```bash
python3 - <<'PY'
from fontTools.ttLib import TTFont
f = TTFont("scripts/brand/fonts/SpaceGrotesk[wght].ttf")
f.flavor = "woff2"
f.save("test/example/priv/static/assets/fonts/space-grotesk-var.woff2")
PY
```
If `fontTools` raises `ImportError: No module named 'brotli'`, `pip install brotli` locally first. Verify the asset renders before committing.

---

### `test/example/priv/static/assets/css/app.css` (served-CSS, render-determinism)

**Analog:** `default.css:9` owns the canonical `--font-sans` system stack. **Do NOT edit `default.css`** — its header says "You can safely remove the whole file" (regenerable daisyUI dump, Pitfall 3). **Do NOT edit `sigra_admin.css`** — that's the installer template (`priv/templates/sigra.install/admin/sigra_admin.css`); editing it pulls installer-parity into scope (Anti-Pattern). `app.css` loads LAST (`root.html.heex:12`, after default → sigra_admin), so its `:root` override wins the cascade.

**Existing `--font-sans` to mirror** (default.css:9):
```css
--font-sans: ui-sans-serif, system-ui, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', ...;
```

**Add to `app.css`** (example-only, OS-independent render in both local capture and CI):
```css
@font-face {
  font-family: 'Space Grotesk';
  src: url('/assets/fonts/space-grotesk-var.woff2') format('woff2-variations');
  font-weight: 300 700;       /* variable wght axis range */
  font-display: swap;         /* moot for capture — the spec waits for fonts.ready */
  font-style: normal;
}
:root {
  --font-sans: 'Space Grotesk', ui-sans-serif, system-ui, sans-serif,
    'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji';
}
```

---

### `test/example/priv/playwright/tests/admin-design.spec.ts` (browser-spec-helper)

**D-08 — extend `waitForLiveViewReady` in place.** Current helper (admin-design.spec.ts:15–19):
```typescript
async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector('[data-phx-session].phx-connected', {
    state: 'attached',
  });
}
```
Add the font wait (and optionally a hard-guard assert, Pitfall 7):
```typescript
async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector('[data-phx-session].phx-connected', { state: 'attached' });
  // D-08: wait for the brand webfont so element heights are font-stable before capture.
  await page.evaluate(async () => { await (document as any).fonts.ready; });
  // Optional loud guard — fail if the face never loaded:
  // const ok = await page.evaluate(() => (document as any).fonts.check('16px "Space Grotesk"'));
  // expect(ok, 'Space Grotesk must be loaded before snapshot').toBe(true);
}
```

**D-11 — MG-5/6 `test.fail()`.** Current block (admin-design.spec.ts:318–386): `test.fail()` at line 323, then it navigates to the REAL `/admin/users`, `/admin/audit`, and a user-detail audit page and asserts `getByRole('link', { name: 'Previous page' })` is attached — pagination only renders at ≥25 rows (`@default_limit 25`, `lib/sigra/admin/audit/query_params.ex:22`). The per-test user is freshly registered (admin-design.spec.ts:21–31) with ~3–5 events. Remediation:
- **Preferred (D-11a):** ensure a seeded user with ≥25 audit events exists in the dev DB the lane boots against, then DELETE `test.fail()` (line 323). See the seeds analog below.
- **Fallback (D-11b):** replace `test.fail();` with `test.skip('data-dependent pagination; tracked in <todo>');`.
- **Either way: remove `test.fail()`** — it spuriously passes if pagination ever appears.

---

### `organizations.spec.ts:152` + `ga-uat-shift-left.spec.ts:106` (browser-spec-helper, poll/readiness)

**Analog — real `expect.poll` usage in the suite** (`passkeys-hooks.spec.ts:101–114`):
```typescript
await expect
  .poll(async () =>
    page.evaluate(() => { /* read browser state */ return { reg: ..., auth: ... }; }),
  )
  .toEqual({ reg: 'function', auth: 'function' });
```
`admin-theme.spec.ts` also uses `expect.poll(...).toBe*(...)` with timeouts extensively (lines 112, 532–583, 805–816) — the in-repo precedent for `expect.poll` is well established.

**Current code to replace** — BOTH files have a byte-identical loop ending in `await page.waitForTimeout(1_000)` (`organizations.spec.ts:115–156`, `ga-uat-shift-left.spec.ts:74–109`). The org version (lines 119–156):
```typescript
for (let attempt = 0; attempt < 30; attempt += 1) {
  const mailbox = (await page.evaluate(async () => {
    const response = await fetch('/dev/mailbox/json');
    return response.json();
  })) as { data: Array<{ to: string[]; html_body: string | null; text_body: string | null }> };
  const invitationEmail = mailbox.data.find((email) => {
    const recipients = email.to.join(' ');
    const body = [email.html_body || '', email.text_body || ''].join('\n');
    return recipients.includes(recipient) && body.includes('/invitations/');
  });
  if (invitationEmail) { /* extract /invitations/.../accept link, return */ }
  await page.waitForTimeout(1_000);   // ← D-06: the only fixed sleeps in browser-lane code
}
throw new Error(`No invitation link found in mailbox JSON for ${recipient}`);
```

**Rewrite** (capture `link` via closure; ~30×1s old budget → `timeout: 30_000`; intervals are Claude's-discretion):
```typescript
let link: string | null = null;
await expect.poll(async () => {
  const mailbox = (await page.evaluate(async () => {
    const r = await fetch('/dev/mailbox/json'); return r.json();
  })) as { data: Array<{ to: string[]; html_body: string | null; text_body: string | null }> };
  const row = mailbox.data.find((e) => {
    const body = [e.html_body || '', e.text_body || ''].join('\n');
    return e.to.join(' ').includes(recipient) && body.includes('/invitations/');
  });
  if (row) {
    const body = [row.html_body || '', row.text_body || ''].join('\n');
    const m = body.match(/https?:\/\/[^\s"'<>]*\/invitations\/[^\s"'<>]*\/accept/);
    if (m) {
      const u = new URL(m[0], page.url());
      u.protocol = new URL(page.url()).protocol;
      u.host = new URL(page.url()).host;
      link = u.toString();
    }
  }
  return link !== null;
}, {
  message: `No invitation link found in mailbox JSON for ${recipient}`,
  intervals: [250, 500, 1000],
  timeout: 30_000,
}).toBe(true);
if (!link) throw new Error(`No invitation link for ${recipient}`);
return link;
```
**Note:** `organizations.spec.ts:115` types `page` as `Parameters<typeof test>[0]['page']`; `ga-uat-shift-left.spec.ts` uses the same shape — keep each file's existing signature, only swap the loop body. Mind ESLint (`let link` then closure assignment is the faithful port).

---

### `test/example/lib/example/demo/seeds.ex` — ≥25-event user (seed-orchestrator, fixture-data)

**Analog — the audit-seed path ALREADY exists.** `priv/repo/seeds.exs` (line 21) delegates to `Example.Demo.Seeds.run()`, which calls `seed_audit_events(users, %{acme, beta})` (seeds.ex:59). That function already inserts **41 `@audit_actions` rows ALL tied to the `admin` user** via `effective_user_id: admin.id` (seeds.ex:660–681) — i.e. the seed path can already make a user with ≥25 events. The lane boots dev and runs `mix run priv/repo/seeds.exs` (ci.yml:931), so the seeded heavy user is present in the DB the spec hits.

**Insertion pattern to copy** (seeds.ex:666–680) — note the two load-bearing details:
```elixir
%AuditEvent{}
|> AuditEvent.changeset(
  %{
    action: action,
    outcome: outcome,
    occurred_at: occurred_at,            # DateTime.add(@seed_reference_ts, -offset*86_400, :second) — pinned, NOT utc_now
    actor_id: admin.id,
    actor_type: "user",
    # TIE-TO-USER: effective_user_id (not just actor_id) so rows surface on the
    # user's detail/audit page (lib/sigra/admin/audit/query.ex:32).
    effective_user_id: admin.id
  },
  allow_reserved: true                   # REQUIRED 3rd arg on every AuditEvent.changeset/3 insert
)
|> Repo.insert!()
```
**Idempotency contract to preserve** (seeds.ex:638–650): the batch is guarded by a count threshold (`demo_tied_count < length(@audit_actions) + length(persona_audit_events())`) and wrapped in `Repo.transaction` (all-or-nothing) — any added rows must keep `run/0` a no-op on a second call. Whatever seeds the ≥25-event user must respect this guard (raise the threshold or fold the new rows into the existing `@audit_actions`/`persona_audit_events` lists, not bolt on an unguarded insert).

**Per Pitfall 5 / Assumption A3:** the gallery boards (`design_gallery_live.ex:611–833`) render static literal markup, so real-data seeding does NOT perturb the 72 element-scoped baselines. The D-11 fallback condition ("if seeding perturbs other boards") does not apply.

---

## Shared Patterns

### Non-PR (nightly/dispatch) job gating — Phase-196 precedent
**Source:** `if: github.event_name != 'pull_request'` (live at ci.yml:515, 568, 619, 749, 1173, 1352)
**Apply to:** the new `admin_design_recapture` job (D-09). Do NOT create a new workflow file; add a sibling job to `ci.yml`. This keeps the required-check surface stable (no branch-protection churn).

### Least-privilege permissions override
**Source:** workflow default `permissions: { contents: read }` (ci.yml:26)
**Apply to:** the recapture job ONLY — add a job-level `permissions: { contents: write }`. Never widen the global block.

### SHA-pinned action references
**Source:** every `uses:` in ci.yml is pinned to a full commit SHA with a `# vX.Y.Z` comment (e.g. `actions/checkout@df4cb1c…  # v6.0.3`, `erlef/setup-beam@fc68ffb…  # v1.24.0`, `actions/cache@27d5ce7…  # v5.0.5`, `actions/setup-node@53b8394…  # v6.3.0`)
**Apply to:** the recapture job's boot prelude — copy the EXACT pinned SHAs from `example_playwright_smoke:886–899`; do not float to `@v6`.

### WR-04 backgrounded-server log idiom
**Source:** ci.yml:946–949 (`mix phx.server > /tmp/example-playwright-server.log 2>&1 &`) + ci.yml:1077–1085 (`if: failure()` → `cat` the log)
**Apply to:** the recapture job's boot — reuse the same redirect + failure-dump so a recapture boot failure is legible.

### Snapshot drift gate / commit-path (do NOT re-implement)
**Source:** `scripts/ci/snapshot-canary-guard.sh` — flags `--allowlist` / `--allow <slug>` / `--canary <slug>` (lines 27–29); slug derivation strips `-admin-design-(chromium|mobile|dark).png` (lines 53–57) so ONE slug covers all 3 projects; canary tolerates `added` but FORBIDS `modify`/`delete` (lines 93–104).
**Apply to:** the recapture commit step. Pass `--allowlist test/example/priv/playwright/snapshot-allowlist-design --canary board-notice` and `--allow <slug>` for each recaptured slug (steady-state allowlist is empty — verified 0 non-comment lines). **`board-notice` is the design-lane canary AND the font change modifies it** → the guard will reject it as `modified`. This is RESEARCH Open Question 1 (deliberate canary re-baseline vs scoped override) — a planner decision, do not auto-relax.

### `@font-face` precedent
**None exists in the served example CSS** (verified: no `@font-face`, no `*.woff*`, no Google Fonts link anywhere in `test/example/assets` or `priv/static/assets/*.css`). This confirms D-07's root-cause correction (the SEED-006 "webfont fails to load in CI" premise is false — there was never a webfont). The `app.css` `@font-face` in this phase is the FIRST self-hosted face; use the standard W3C `@font-face` form (no in-repo analog to copy, RESEARCH Code Examples §3 is the template).

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `test/example/priv/static/assets/css/app.css` `@font-face` rule | served-CSS | render-asset | No `@font-face` exists anywhere in the served example CSS (D-07-confirming). The `--font-sans` *token* has an analog (default.css:9); the face itself is net-new. Use the standard W3C form (RESEARCH §3). |
| D-02 aggregating step (job-fails-if-any-seam-failed) | workflow-step | orchestration | No existing step reads sibling `steps.<id>.outcome` to re-fail the job. Closest behavioral kin is the `release_ref_guard` bash exit-1 idiom (ci.yml:38–52). Net-new logic; structure is trivial bash. |

Everything else maps cleanly to an in-place extension of an existing pattern.

## Metadata

**Analog search scope:** `.github/workflows/ci.yml`; `test/example/priv/playwright/tests/`; `test/example/priv/static/assets/`; `test/example/lib/example/demo/`; `test/example/priv/repo/`; `scripts/ci/`; `scripts/brand/fonts/`
**Files scanned:** ~14 (ci.yml, 4 specs, 2 CSS, seeds.exs + seeds.ex, snapshot-canary-guard.sh, root.html.heex, font dir, design allowlist)
**Pattern extraction date:** 2026-06-20
