# Phase 218: Elevation Wave + Nit Cleanup - Pattern Map

**Mapped:** 2026-07-08
**Files analyzed:** 9 (7 modified + 2 net-new artifact-slices)
**Analogs found:** 9 / 9 (all in-repo; this wave DRIVES existing 216/217 machinery)

> **No RESEARCH.md** — file list extracted from `218-CONTEXT.md` `<decisions>` / `<canonical_refs>` / `<code_context>`. This phase is almost entirely **modification** of existing harness files plus **data expansion** of two committed ledgers. There are essentially no net-new source modules — the harness loop already exists (216/217).

---

## File Classification

| File | Role | Data Flow | Closest Analog | Match Quality | Driver |
|------|------|-----------|----------------|---------------|--------|
| `test/example/priv/playwright/tests/admin-eval.spec.ts` | test (render spec) | transform / batch | itself (`GROUP_BOARDS` loop) + `admin-design.spec.ts` (`COMPONENT_BOARDS` loop) | exact (self-extension) | D-02, D-09 |
| `test/example/priv/playwright/lib/eval/probes.ts` | utility (probe lib) | transform | `scripts/ci/lib/eval-probe-ids.mjs` (canonical `PROBE_IDS`) | exact | D-08 |
| `guides/reference/admin-render-sha.json` | config (ledger) | batch/data | its own `board-mg-5-*` / `board-mg-9-*` entry shape | exact (self-expansion) | D-02 |
| `guides/reference/admin-award-ledger.json` | config (ledger) | batch/data | its own `users-index-live` / `user-show-live` cell shape | exact (self-expansion) | D-02, D-05 |
| `scripts/uat/up.sh` | config (shell orchestrator) | event-driven | itself (`print_status` / `wait_for_http` / flag `case`) | exact (self-modification) | D-10 (UI-01) |
| `test/example/lib/example_web/live/mfa_settings_live.ex` | component (LiveView) | request-response | `test/example/lib/example_web/live/settings_live.ex` (already vt-*) | role+flow match | D-11 (UI-02) |
| `test/example/lib/example_web/live/organization_members_live.ex` | component (LiveView) | request-response | `settings_live.ex` (vt-form/vt-panel) + missing `vt-modal` (net-new class) | role match | D-11 (UI-02) |
| 6 L3→board-proxy entries in the two ledgers above | config (data rows) | data | the 2 pilots (`users-index-live`=mg-5, `user-show-live`=mg-9/10/11) | exact | D-02 |
| `guides/reference/fix-queue.json` (regenerated, not hand-edited) | config (derived) | batch | current 117-finding entry shape | derived output | D-02/D-06 |

---

## Pattern Assignments

### 1. `admin-eval.spec.ts` — L1-board + L3-proxy render extension (D-02)

**Analog A (self):** the current `GROUP_BOARDS` iteration is the exact template a new `COMPONENT_BOARDS` (L1) loop must copy. The spec already has all the machinery — `captureSurface`, `writeBundleLocal`, `waitForLiveViewReady`, project→theme/viewport mapping. The extension is **adding board lists + their state markers**, not new capture logic.

Current L2 loop shape to mirror (`admin-eval.spec.ts:335-364`):
```typescript
for (const boardId of GROUP_BOARDS) {
  const markers = GROUP_STATE_MARKERS[boardId];
  const stateMap: Array<{ marker: string; state: 'populated'|'zero'|'loading'|'error' }> = [
    { marker: markers.find((m) => m.endsWith('-populated')) ?? '', state: 'populated' },
    { marker: markers.find((m) => m.endsWith('-zero') || m.endsWith('-zero-note')) ?? '', state: 'zero' },
    { marker: markers.find((m) => m.endsWith('-loading') || m.endsWith('-loading-note')) ?? '', state: 'loading' },
    { marker: markers.find((m) => m.endsWith('-error')) ?? '', state: 'error' },
  ].filter((entry) => entry.marker !== '');

  for (const { marker, state } of stateMap) {
    test(`render bundle: ${boardId}/${state}`, async ({ page }, testInfo) => {
      const surface = `${boardId}-${state}`;
      const board = page.locator(`#${boardId}`);
      await expect(board).toBeVisible();
      const outerHTML = await board.evaluate((el) => el.outerHTML);
      await captureSurface(page, testInfo, surface, boardId, outerHTML, theme, viewport, state);
    });
  }
}
```

**Analog B (L1 board list):** copy the 13-entry `COMPONENT_BOARDS` const **verbatim** from `admin-design.spec.ts:98-103`. The eval spec does not currently import it:
```typescript
const COMPONENT_BOARDS = [
  'board-stat', 'board-stat_link', 'board-task_card', 'board-summary_chip',
  'board-applied_chip', 'board-empty_state', 'board-page_back', 'board-scope_ribbon',
  'board-notice',       // designated canary (D-10)
  'board-notice_link', 'board-field_help', 'board-skeleton', 'board-audit_row',
] as const;
```
**Caveat for the planner:** L1 component boards are single-state (no `mg-N-{populated,zero,loading,error}` markers). `admin-design.spec.ts:257` iterates them as `board: ${boardId}` with one screenshot each. The L1 extension therefore captures ONE cell per board (or a synthetic `-default` state), NOT the 4-state matrix the L2 boards use. Do not fabricate 4 states for L1 boards that only expose one fixture.

**6 L3→board-proxy surfaces (D-02):** these are NOT new render loops — they are **ledger entries** that point at an already-rendered board's `render_sha256`. See §3. The pilots proved the pattern: `users-index-live` reuses `board-mg-5`'s sha; `user-show-live` reuses `board-mg-9`'s sha. The 6 unmapped surfaces (`index`, `organization`, `user-sessions`, `audit-index`, `audit-user`, `branding`) each pick a representative board and reuse its sha the same way.

---

### 2. `admin-eval.spec.ts` — first-nav flake fix (D-09)

**Analog (self):** the two `page.goto(...)` sites and the existing `waitForLiveViewReady` helper are already in-file.

`beforeEach` navigation (`admin-eval.spec.ts:318-323`) — the primary flake site:
```typescript
test.beforeEach(async ({ page }, testInfo) => {
  const adminEmail = adminEvalEmail(testInfo);
  await registerUser(page, adminEmail, TEST_PASSWORD);
  await page.goto('/admin/_design');          // ← add { waitUntil: 'domcontentloaded' }
  await waitForLiveViewReady(page);            // ← already the explicit LV-ready gate
});
```
`registerUser` goto (`admin-eval.spec.ts:153`): `await page.goto('/users/register');` — same treatment.

The ready gate to keep pairing with every `goto` (`admin-eval.spec.ts:141-148`, lifted verbatim from `admin-design.spec.ts` per D-03):
```typescript
async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector('[data-phx-session].phx-connected', { state: 'attached' });
  await page.evaluate(async () => { await (document as any).fonts.ready; });
  const ok = await page.evaluate(() => (document as any).fonts.check('16px "Space Grotesk"'));
  expect(ok, 'Space Grotesk must be loaded before snapshot').toBe(true);
}
```
**Fix shape:** `page.goto(url, { waitUntil: 'domcontentloaded' })` + keep the existing `waitForLiveViewReady`; optionally lower the `registerUser` `waitForURL` timeout (currently `30_000`, `admin-eval.spec.ts:158`) so a stuck first-nav fails fast into its retry instead of hanging ~16 min. Verify by re-running `scripts/ci/admin-eval-harness.sh` and confirming near-zero `flaky` count.

---

### 3. Ledger promotion — full-matrix expansion (D-02)

**`admin-render-sha.json` analog (self):** the committed `board-mg-5-*` block is the exact per-cell shape to replicate across all 11 L2 boards + 13 L1 boards. Current entry (`admin-render-sha.json:5-14`):
```json
"board-mg-5-populated": {
  "light-desktop-populated": { "render_sha256": "8b92c47...afb8", "open_findings": 0 },
  "dark-desktop-populated":  { "render_sha256": "8b92c47...afb8", "open_findings": 0 }
}
```
**L3→board proxy entry shape (self):** the two pilots reuse a board's sha under a live-surface key (`admin-render-sha.json:85-118`):
```json
"users-index-live": {
  "light-desktop-populated": { "render_sha256": "8b92c47...afb8", "open_findings": 197 },
  ...
}
```
`8b92c47…afb8` is byte-identical to `board-mg-5`'s sha — that IS the proxy mechanism. The 6 new L3 proxies (`index`, `organization`, `user-sessions`, `audit-index`, `audit-user`, `branding`) each copy this shape and paste their representative board's `render_sha256`. **Do NOT run `fix-queue-build.mjs` on the mg-5/mg-9 proxy cells** — the notes field warns `open_findings` is pinned to 0 there (panel reads only `render_sha256`).

**`admin-award-ledger.json` analog (self):** the `users-index-live` cell (`admin-award-ledger.json:5-28`) is the full award-cell template. Key fields for a D-05 verify-then-climb entry:
```json
"users-index-live": {
  "axes": { "token_fidelity": "A2", "rhythm": "A2", "a11y_polish": "A2", "states": "A2" },
  "band": "A2",
  "verified_at_sha": "eeb6bf14f6ad1e6d4802ac56adbf852db50b533f",
  "rendered": true,
  "evidence_ref": [ "probe:off-token-spacing", ... "test:admin-eval-spec-gallery-boards-mg2-mg5" ]
}
```
**Verify-then-climb rule (D-05):** re-run against rendered output; `verified_at_sha` must be updated to the clean-tree HEAD at re-verification; `evidence_ref` entries must resolve via `resolveEvidenceRef` (see §4 — only `probe:<known-id>` / `test:` / `conformance:` prefixes pass). Every raise is protected by `scripts/ci/award-guard.mjs` (monotonic) — do not lower any sub-score.

---

### 4. `probes.ts` — single-source `PROBE_IDS` fold (D-08)

**Canonical source** (`scripts/ci/lib/eval-probe-ids.mjs:19-29`):
```javascript
export const PROBE_IDS = Object.freeze([
  'off-token-spacing', 'misalignment', 'size-weight-budget',
  'ember-reserved-for', 'off-scale-radius-shadow-control', 'target-size',
  'focus-ring', 'card-in-card', 'below-fold-primary',
]);
```

**Duplicate to eliminate** (`probes.ts:39-49`, carrying the `// FOLLOW-UP(216)` marker at lines 27 + 35):
```typescript
// FOLLOW-UP(216): import PROBE_IDS from scripts/ci/lib/eval-probe-ids.mjs (D-12 single-source)
export const PROBE_IDS = Object.freeze([
  'off-token-spacing', 'misalignment', 'size-weight-budget',
  'ember-reserved-for', 'off-scale-radius-shadow-control', 'target-size',
  'focus-ring', 'card-in-card', 'below-fold-primary',
] as const);
```
**Fix shape (D-08):** import from the canonical `.mjs`. If Playwright's CJS/ESM transform can't resolve the cross-tree import (the documented reason it was deferred — same class of issue as the `import.meta.url` workaround at `admin-eval.spec.ts:14-20`), fall back to a **deep-equal self-test** that fails if the two arrays drift, and remove both `// FOLLOW-UP(216)` markers. Do this BEFORE matrix expansion (a larger surface set raises drift risk).

---

### 5. `scripts/uat/up.sh` — UI-01 demo-DX nits (D-10)

**Analog (self):** every target already has a home in-file. Self-contained bash; no new modules.

- **`--status` re-probe** — `print_status` (`up.sh:161`) currently reads state but does not re-probe liveness; D-10 wants a `curl -fsS --max-time 2` re-check. The exact curl pattern already exists in `wait_for_http` (`up.sh:541`): `if curl -fsS --max-time 2 "${url}" >/dev/null 2>&1; then`. Copy that guard into `print_status` to flip the `STARTING — not yet responding` branch (`up.sh:169-171`) live.
- **`wait_for_http` timeout bump** — `wait_for_http()` (`up.sh:534-553`) defaults `timeout="${2:-60}"`; D-10 wants host-run bumped to ~120s (or detect `Compiling` in the log and extend). The single call site to bump is `up.sh:526` / `up.sh:865` (`wait_for_http "${SIGRA_UAT_RAW_URL}"`).
- **Flag-inert warnings** — the arg `case` (`up.sh:629-680`) sets booleans with no cross-mode validity check. D-10 wants an "ignored in `<mode>` mode" warning for no-op flags. The existing mutual-exclusion check at `up.sh:698` (`--proxy` + `--private-traefik`) is the precedent shape for a post-parse validity pass. Use the existing `yellow`/`red` helpers (`yellow` used at `up.sh:551`).
- **Stale leaked-UAT-stack reap** — the stale-build wipe precedent is already in-file (`up.sh:450` "Wipe a stale example build whose frozen endpoint port differs"); mirror that for a leaked stack reap.

---

### 6. `mfa_settings_live.ex` + `organization_members_live.ex` — UI-02 vt-* residuals (D-11)

**vt-* analog (already-migrated authed screen):** `test/example/lib/example_web/live/settings_live.ex` is the reference — every sub-flow already uses the target classes. Copy these shapes.

Panel + vt-form (`settings_live.ex:88-103`):
```elixir
<section class="vt-panel" data-testid="settings-profile">
  <div class="vt-panel__header">
    <h2 class="vt-panel__title">Display name</h2>
  </div>
  <.form for={@profile_form} phx-submit="update_profile" class="vt-form">
    <.input field={@profile_form[:name]} type="text" label="Display name" />
    <.button class="vt-btn vt-btn--primary">Save profile</.button>
  </.form>
</section>
```
Button variants in use across the codebase: `vt-btn vt-btn--primary` / `--ghost` / `--danger` / `--danger-solid`.

**`mfa_settings_live.ex` residuals to migrate (D-11):** raw-Tailwind sub-flows, NOT yet vt-*:
- passkey rows (`mfa_settings_live.ex:311-330`) — `class="flex items-start justify-between p-4 bg-white rounded-lg border border-gray-200"` → `vt-panel` row treatment.
- backup-codes grid + QR step (`render_enrollment_qr` / `render_backup_codes`, dispatched at `mfa_settings_live.ex:238-241`) — raw `class="mt-1 block w-full rounded-lg text-base font-mono ... border-red-300 focus:ring-0"` inputs (`:159`, `:210`) → `.vt-form .input`.
- The panel shell is already `vt-panel` (`:71`, `:261`) — only the inner sub-flows carry residual daisy/Tailwind. Migrate inner, preserve the shell.

**`organization_members_live.ex` residuals (D-11) — the daisyUI modals:** native `<dialog class="modal">` with `modal-box` / `modal-action` / `modal-backdrop` and `input input-bordered`. Four dialogs at `:455` (invite), `:507` (revoke), `:537` (role), `:569` (remove). Representative (`organization_members_live.ex:455-505`):
```elixir
<dialog id="invite-member-modal" class="modal" phx-hook="DialogModal">
  <div class="modal-box">
    ...
    <input class="input input-bordered w-full" ... />
    <div class="modal-action">
      <button type="button" class="vt-btn vt-btn--ghost" phx-click="cancel_invite">Cancel</button>
      <button class="vt-btn vt-btn--primary">Send invite</button>
    </div>
  </div>
  <form method="dialog" class="modal-backdrop"><button>close</button></form>
</dialog>
```
**Note — vt-modal does not yet exist.** `grep vt-modal` returns zero hits repo-wide; `settings_live.ex` uses inline `phx-click` confirm/cancel toggles instead of `<dialog>`. D-11 explicitly calls for **building** a `vt-modal` (or restyling the native `<dialog>` with vt-* tokens) — this is the one net-new class in the phase. Buttons already carry vt-* classes (`:491`, `:496`, `:520`, `:525`); only the `modal`/`modal-box`/`modal-action`/`modal-backdrop`/`input input-bordered` daisy anchors remain. `phx-hook="DialogModal"` behavior must be preserved through the restyle (keep the hook, swap the classes).

---

### 7. `fix-queue.json` — derived, not hand-edited (D-02/D-06)

**Analog (self):** current entry shape (`fix-queue.json:2-25`) — regenerated by `scripts/ci/fix-queue-build.mjs`, never hand-edited. Each entry:
```json
{
  "finding_id": "0957c4a2...",
  "surface": "board-mg-10-error",
  "class": "misalignment",
  "anchor": ".sg-skeleton.sg-detail-panel",
  "lens": null,
  "severity": "warn",
  "fix_class": "judgment",
  "auto_eligible": false,
  "systemic_group": "9a1273...",
  "priority": "systemic",
  "surfaces_affected": ["board-mg-10-error", "board-mg-10-loading", ...]
}
```
`open_findings` is derived (built − settled). The 13 `token`-eligible findings cite `.error`-state CSS anchors that `fix-apply.mjs` refuses (locked 217 D-13) → they route to the operator PR queue, not the auto-apply rail. Do not reopen D-13.

---

## Shared Patterns

### finding_id key contract
**Source:** `admin-eval.spec.ts:85-102` (`enrichFindingsForBundle`) + `scripts/panel/panel-schema.mjs`.
**Apply to:** every new render cell, every ledger entry that references a finding.
```typescript
const finding_id = createHash('sha256')
  .update(surface).update('\0')
  .update(probeClass).update('\0')
  .update(anchor).digest('hex');
```
NUL-delimited `sha256(surface \0 class \0 anchor)` — one key space across probe findings, `settled-findings.tsv` waivers, and the fix queue. New L1/L3 surfaces MUST produce ids via this exact layout or they won't collide with settled waivers.

### Board-scoped probes (never global element-scan)
**Source:** `probes.ts:102-105` + `runAllProbes` root option (`probes.ts:768-775`); driven from `admin-eval.spec.ts:282-285`.
**Apply to:** every new L1/L2 capture.
```typescript
const findings = await runAllProbes(page, { isGateProject: gateProject, root: '#' + boardId });
```
Element-scan probes scope to `#{boardId}`; design-token reads (`--sg-space-*`, `--sg-radius-*`, `--sg-color-ember*`) stay global (`document.documentElement`). This is the 216-08 Gap-1 invariant — a new board that scans globally will emit cross-board anchors that fail `evidence-anchor-check`.

### evidence_ref resolution (award ledger)
**Source:** `scripts/ci/lib/eval-probe-ids.mjs:53-74` (`resolveEvidenceRef`).
**Apply to:** every `evidence_ref` entry in `admin-award-ledger.json`.
Only `probe:<one-of-the-nine-canonical-ids>`, `test:<non-empty>`, `conformance:<non-empty>` pass. An unknown `probe:` id fails the guard — new evidence refs must use the exact canonical id strings.

### JUDGE-CI-01 (panel advisory-only)
**Source:** 217 CONTEXT + `scripts/panel/` vs `scripts/ci/` split.
**Apply to:** the panel plan(s). Panel output lands in **parallel** `panel-findings.json` — never merged into `findings.json`, never enters `open_findings`, never gates. Missing `ANTHROPIC_API_KEY` → `exit 0`. Do not wire the panel into `fast_checks`.

---

## No Analog Found

| File | Role | Reason |
|------|------|--------|
| `vt-modal` component class (in `organization_members_live.ex`) | component/CSS | No `vt-modal` exists repo-wide; `settings_live.ex` uses inline `phx-click` toggles, not `<dialog>`. D-11 requires **building** it (restyle native `<dialog>` with vt-* tokens, preserve `phx-hook="DialogModal"`). Only genuinely net-new surface in the phase. Author against the `sg-*`/`vt-*` design contract (`guides/reference/admin-design-contract.md`). |

**Everything else has an exact in-repo analog** — the harness loop (216/217) is complete; this wave expands data and drives existing machinery.

---

## Metadata

**Analog search scope:** `test/example/priv/playwright/{tests,lib/eval}`, `scripts/ci/`, `scripts/ci/lib/`, `scripts/panel/`, `scripts/uat/`, `guides/reference/`, `test/example/lib/example_web/live/`.
**Files scanned:** ~18 (deep-read: admin-eval.spec.ts, probes.ts, eval-probe-ids.mjs, admin-render-sha.json, admin-award-ledger.json, up.sh sections, settings_live.ex, mfa_settings_live.ex, organization_members_live.ex, admin-design.spec.ts loop, fix-queue.json head).
**Pattern extraction date:** 2026-07-08
