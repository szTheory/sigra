# Phase 236: Flake Root Cause — Reproduce, Name, Fix - Pattern Map

**Mapped:** 2026-09-15
**Files analyzed:** 7 (3 modified, 4 created)
**Analogs found:** 7 / 7
**Line numbers:** every citation below was re-opened at HEAD this session (RESEARCH C-4 drift warning honoured). Do **not** trust line numbers copied from CONTEXT.md.

> **Correction carried forward (RESEARCH C-1, BLOCKING):** CONTEXT D-16's "zero-hit grep for
> `<.link patch>` in `lib/sigra/admin/`" is **false**. `lib/sigra/admin/live/branding_live.ex`
> ships three `<.link ... patch={panel_path(...)}>` tabs at `:126-148`, backed by
> `handle_params/3` at `:87` and a local-path helper at `:595`. **`branding_live.ex` is the
> primary analog for BOTH halves of the `lib/` fix.** The only genuinely new construct is the
> server-side `push_patch/2` (0 hits in `lib/`) — state *that* narrower claim, never the
> zero-hit grep.

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/sigra/admin/live/audit_index_live.ex` (M) | LiveView (view + URL owner) | request-response / URL-state transform | `lib/sigra/admin/live/branding_live.ex` | **exact** (same dir, same `use Phoenix.LiveView`, same `handle_params` + patch-link + `phx-submit` shape) |
| `.github/workflows/ci.yml` (M) | config (CI workflow) | batch / event-driven | itself — env-key deletion, no analog needed | n/a (deletion only) |
| `.planning/research/STACK.md` (M) | doc | n/a | n/a | n/a (prose correction) |
| `scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs` (C) | test (prohibition guard) | file-I/O + pure transform | `scripts/ci/prohibitions/p02-axe-signal-not-reduced.test.mjs` (TS subject + committed fixture) **and** `p16-no-schedule-lane-leniency.test.mjs` (pure-checker + negative control) | **exact** (two complementary analogs) |
| `test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts` (C) | test fixture (known-bad) | file-I/O | `test/fixtures/prohibitions/p02-axe-test-tagged-snapshot.ts` | **exact** (only committed `.ts` fixture in the dir) |
| `test/sigra/planning/phase_236_audit_url_ownership_test.exs` (C) | test (source-contract ExUnit) | file-I/O + regex assert | `test/sigra/planning/phase_232_playwright_economics_test.exs` (source-string contract) + `phase_230_ci_timeouts_test.exs` (non-vacuity floor + ci.yml job-block walk) | **exact** |
| `.planning/phases/236-.../236-EVIDENCE.md` (C) | doc (evidence ledger, machine-parsed) | file-I/O | `.planning/milestones/v1.47-phases/232-.../232-EVIDENCE.md` | **exact** (parses cleanly under `_lib.mjs` `SLOT_HEADING_RE`) |

All analog paths verified git-TRACKED via `git ls-files`. No gitignored mirror paths appear in this document.

---

## Pattern Assignments

### `lib/sigra/admin/live/audit_index_live.ex` (LiveView, URL-state request-response) — MODIFIED

**Analog:** `lib/sigra/admin/live/branding_live.ex` — same directory, same module shape, already
does patch-links + `phx-submit` + `handle_event`, and already has committed PNG baselines that
prove the attribute-passthrough is render-neutral in this repo.

**Pattern A — `<.link patch>` anchor, with `id`/`class`/`aria-current` carried through `@rest`**
(`lib/sigra/admin/live/branding_live.ex:126-133`, verbatim):

```heex
<.link
  id="branding-tab-light"
  class={tab_class(@active_panel, :light)}
  patch={panel_path(:light)}
  aria-current={current_panel_attr(@active_panel, :light)}
>
  Light
</.link>
```

Copy this shape verbatim onto the **raw anchors** in `audit_index_live.ex`. Current state at HEAD
(verified by opening the file):

| Line | Current | Convert? |
|---|---|---|
| `:60-66` | `<a href={preset_path(@admin_scope, @current_params, "outcome", "failure")} class="sg-btn sg-btn--secondary sg-btn--sm" aria-current={...}>` Failures | **yes** |
| `:67-73` | same shape, `"action_prefix", "admin.impersonation"` → Impersonation | **yes** |
| `:121` | `<a href={index_path(@admin_scope)} class="sg-btn sg-btn--ghost">Clear</a>` | **yes** |
| `:122` | `<a href={export_path(@admin_scope, @current_params)} class="sg-btn sg-btn--secondary">Export CSV</a>` | **NO** — controller CSV download, must stay a document navigation (D-08.5) |
| `:142` | `<a href={index_path(@admin_scope)} class="sg-btn sg-btn--ghost sg-btn--sm">Clear all</a>` | **yes** |
| `:155` | `<th><a href={sort_path(@admin_scope, @current_params, "inserted_at")}>Occurred</a></th>` | **yes** |
| `:180` | `<a href={index_path(@admin_scope)} class="sg-btn sg-btn--secondary sg-btn--sm">Clear all filters</a>` | **yes** |
| `:140` `remove_href={remove_chip_path(...)}` | **component attr**, not an anchor | **NO — out of scope** |
| `:189-190` `prev_href=` / `next_href=` | **component attrs**, not anchors | **NO — out of scope** |

**Component boundary VERIFIED this session (closes RESEARCH assumption A2):**
`def applied_chip` lives at `lib/sigra/admin/components.ex:372` and `def audit_pagination_nav` at
`lib/sigra/admin/components.ex:827`; both are consumed by `audit_user_live.ex:157,210` and
`users_index_live.ex:144` as well. Converting them edits a **shared** component and drags D-30's
excluded views (and `user-audit-*.png` ×3) into the blast radius. **Leave `.applied_chip` and
`.audit_pagination_nav` as `<a href>` this phase and record that scope line in the plan.**

⚠ `href` is an explicit attr on `<.link>`, named `patch`. So `href={f(...)}` → `patch={f(...)}`;
every other attribute (`class`, `id`, `aria-current`) is carried verbatim. The rendered `href`
string is byte-identical (`<.link>` renders `href={@patch}`), which is what keeps the existing
dead-render `href` assertions in `test/example/test/example_web/live/admin_audit_index_live_test.exs`
green and keeps the four `/admin/audit` PNG baselines from moving.

**Pattern B — `phx-submit` on the form, keeping progressive enhancement.**
Analog (`lib/sigra/admin/live/branding_live.ex:150-158`, verbatim):

```heex
<form
  id="auth-branding-form"
  class="sg-stack sg-stack--4"
  phx-change="validate"
  phx-submit="save"
  phx-hook="AuthBrandingPreview"
  data-sg-auth-branding-preview-form="true"
  data-testid="admin-auth-branding-form"
>
```

Target at HEAD (`lib/sigra/admin/live/audit_index_live.ex:76`, verbatim):

```heex
<form method="get" action={index_path(@admin_scope)} class="sg-filter-panel sg-stack">
```

Add **only** `phx-submit="apply_filters"`. Keep `method="get"` and `action=` (D-10 — verified
hazard-free: `live_socket.js:1188` `preventDefault()`s unconditionally once `phx-submit` is
present). Do **not** copy `phx-change` from the analog (D-09). Keep
`<button type="submit" class="sg-btn sg-btn--primary">Apply filters</button>` at `:117` — it is
clicked by role in `admin-audit.spec.ts` and is in the PNG baselines.

**Pattern C — `handle_params/3` stays the sole loader.** Already true at HEAD
(`lib/sigra/admin/live/audit_index_live.ex:24-25`):

```elixir
@impl true
def handle_params(params, _uri, socket) do
  case Explorer.list_events(socket.assigns.sigra_config, socket.assigns.admin_scope, params) do
```

Analog `branding_live.ex:86-91` is the same `@impl true` + `handle_params/3` + assign-only shape.
Do not add loading to `handle_event`.

**Pattern D — `handle_event/3` clause shape.** Analog
(`lib/sigra/admin/live/branding_live.ex:396-397` and `:418-419`):

```elixir
@impl true
def handle_event("validate", %{"branding" => params}, socket) do
  ...
  {:noreply, socket |> assign(...)}
end

def handle_event("save", %{"branding" => params}, socket) do
```

Note the analog's convention: `@impl true` on the **first** clause only; subsequent clauses are
bare `def handle_event(...)`. `audit_index_live.ex` currently has **zero** `handle_event/3`, so the
new clause carries the `@impl true`.

**Path-building helpers to reuse, not reinvent** (`lib/sigra/admin/live/audit_index_live.ex:286-308`,
verbatim):

```elixir
defp index_path(%Scope{mode: :organization, organization_slug: slug}) when is_binary(slug),
  do: "/admin/organizations/#{slug}/audit"

defp index_path(_admin_scope), do: "/admin/audit"
```

```elixir
defp append_query(path, params) do
  cleaned =
    params
    |> Enum.reject(fn {_key, value} -> value in [nil, "", false] end)
    |> Enum.into(%{})

  case cleaned do
    empty when map_size(empty) == 0 -> path
    _ -> path <> "?" <> URI.encode_query(cleaned)
  end
end
```

**RESEARCH assumption A4 is now VERIFIED: `append_query/2` already rejects `nil`/`""`/`false`.**
So D-14's "JS and no-JS paths must produce the same URL" holds *by construction* if the new
`handle_event` pipes through `index_path/1 |> append_query/2` — no separate blank-normalizer is
needed, only a key **whitelist** (ASVS V5, and the mechanism behind the already-fixed
duplicate-`action_prefix` bug). `index_path/1`'s scope branch is also what keeps `push_patch` from
crossing `live_session` (`:admin_global` vs `:admin_organization`) — a cross-session `push_patch`
raises `ArgumentError` server-side (RESEARCH C-3), unlike `<.link patch>` which degrades to a full
navigation.

Target shape (`push_patch` has no in-`lib/` precedent — this is the one new construct):

```elixir
@impl true
def handle_event("apply_filters", params, socket) do
  path =
    socket.assigns.admin_scope
    |> index_path()
    |> append_query(Map.take(params, @filter_keys))

  {:noreply, push_patch(socket, to: path)}
end
```

`to:` must be a **local path** (`validate_local_url!`, D-13) — `index_path/1` already returns one.

**Error handling:** the file has no try/rescue idiom; `handle_params/3` pattern-matches
`{:ok, {rows, meta, current_params}}` from `Explorer.list_events/3`. The new `handle_event` does no
I/O, so it needs no error branch — it only computes a path and patches.

---

### `.github/workflows/ci.yml` (config, event-driven) — MODIFIED

Single deletion. Verified at HEAD, `.github/workflows/ci.yml:1454-1460`:

```yaml
      - name: Run generated admin acceptance smoke
        env:
          PGUSER: postgres
          PGPASSWORD: postgres
          PGHOST: localhost
          GITHUB_WORKSPACE: ${{ github.workspace }}
          PLAYWRIGHT_RETRIES: 1
```

Delete the `PLAYWRIGHT_RETRIES: 1` line only. Zero readers repo-wide outside `.planning/` prose.
The four surviving `env:` keys are the non-vacuity floor the new ExUnit contract test asserts on.

**No other workflow edit is needed** — the guard is auto-discovered by the existing glob
(`.github/workflows/ci.yml:393`, verbatim):

```yaml
        run: node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs
```

with the load-bearing comment two lines above: *"A bare directory arg is NOT valid here (node 22
resolves it as a module); the shell glob is load-bearing."*

---

### `.planning/research/STACK.md` (doc) — MODIFIED

Two false claims, both verified present at HEAD:

- `:82` — *"`playwright.config.ts:81` already sets `trace: 'on-first-retry'`, and the smoke job
  already sets `PLAYWRIGHT_RETRIES: 1` (`ci.yml:1460`) — **traces for the flaky runs already exist
  as artifacts**. Harvest them before adding instrumentation"*
- `:197` (step 1 of the diagnosis list) — *"**Harvest the traces that already exist.**
  `trace: 'on-first-retry'` + `PLAYWRIGHT_RETRIES: 1` means every intermittent red already produced
  a trace zip for the failing attempt."*

Both are false because `playwright.config.ts:59` is `retries: 0`, so `on-first-retry` never fires
and `PLAYWRIGHT_RETRIES` has no reader. Correct in place; the phase's own deletion of
`PLAYWRIGHT_RETRIES` makes the second claim doubly stale.

---

### `scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs` (test/guard, file-I/O + pure transform) — CREATED

**Two analogs, both needed:**
- `scripts/ci/prohibitions/p02-axe-signal-not-reduced.test.mjs` — the only guard whose subject is a
  **TypeScript** file read through `readSubject` + `stripJsComments`, and the only one with a
  committed `.ts` known-bad fixture.
- `scripts/ci/prohibitions/p16-no-schedule-lane-leniency.test.mjs` — the pure-checker-function +
  negative-control shape, and the "the parse broke, this is not a pass" message convention.

**Header-comment convention** (mandatory — every guard has one). `p02:1-12`, verbatim:

```js
// P2 (230-02-PLAN.md) — mechanical enforcement.
//
//   MUST NOT reduce or drop the axe WCAG signal while relocating it; the three design
//   projects (Desktop Chrome, iPhone 13, dark) each keep a full-document WCAG 2.1/2.2 AA
//   scan on every PR.
//
// Subject: test/example/priv/playwright/tests/admin-design.spec.ts (via GSD_PROHIB_SUBJECT).
// Secondary: playwright.config.ts (the three projects) and ci.yml (the PR-lane filter).
//
// What silently breaks if this guard is deleted: the axe test acquires a `@snapshot` tag —
// or the PR-lane step's `--grep-invert '@snapshot'` starts excluding it — and the WCAG scan
// leaves the pull_request lane entirely while the gallery still reports green.
```

Four required sections: `PNN (<plan>) — mechanical enforcement.` / the indented MUST-NOT statement
/ `Subject:` (+ `Secondary:`) / `What silently breaks if this guard is deleted:`. `p16` adds a
"why comments are stripped" paragraph — copy that too, since D-25's comment-stripping is
load-bearing here for the same reason.

**Imports + subject read** (`p02:14-21`, verbatim):

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { readSubject, readRepoFile, stripYamlComments, stripJsComments } from './_lib.mjs';

const SPEC = 'test/example/priv/playwright/tests/admin-design.spec.ts';
// Comments stripped: the spec documents that its axe scan "carries no `.include()`", so
// matching raw text would red the shipped file precisely for explaining that it is correct.
const spec = stripJsComments(readSubject(SPEC));
```

For `p17`: `const SUBJECT = 'test/example/priv/playwright/playwright.config.ts';` — **exactly one**
substitutable subject (`_lib.mjs:11-17`: *"a guard has exactly one substitutable subject"*).
Secondary artifacts (the 20 `tests/*.spec.ts` files) are read from their **real** locations via
`readRepoFile` / a `readdirSync` walk, never through `readSubject`.

D-25 is verified: `test/example/priv/playwright/playwright.config.ts:15-16` reads
*"// Retries stay at zero everywhere; CI shard commands repeat --retries=0 explicitly so / //
observed isolation evidence cannot be masked by a recovered attempt."* — a naive `/retries/` match
reds the compliant file. `stripJsComments` (`scripts/ci/prohibitions/_lib.mjs:147-177`) is the
required tool; do not hand-roll a regex.

**Pure-checker + named-message shape** (`p16:59-85`, verbatim):

```js
function leniencyIssue(body) {
  if (!body || body.trim() === '') {
    return 'the parse broke, this is not a pass — verdict step body not found';
  }
  if (/::warning::Demotion receipt FAILED/.test(body)) {
    return 'the warn-instead-of-fail annotation string ("::warning::Demotion receipt FAILED") ' +
      'survives — a demoted construct can silently stop executing on the nightly while the ' +
      'receipt merely warns instead of failing';
  }
  ...
  return null;
}
```

`retryWrapperIssue(text)` mirrors this: returns `null` when clean, a **named, explanatory string**
when violating. Never a boolean.

**Non-vacuity floor + assertion shape** (`p16:87-105`, verbatim):

```js
test('the parse locates the demotion_receipt job and its Verdict step body', () => {
  assert.ok(
    receiptBlock,
    'job `demotion_receipt` not found in ci-observe.yml — the parse broke, this is not a pass',
  );
  ...
});

test('no trigger-dependent early exit and no warn-instead-of-fail branch survives', () => {
  const issue = leniencyIssue(verdictBody);
  assert.equal(issue, null, issue ?? '');
});
```

For `p17` the two floors D-24 requires: (1) the config parse located a `retries:` line at all;
(2) the spec walk found ≥10 spec files — **verified there are 20 at HEAD**
(`ls test/example/priv/playwright/tests/*.spec.ts | wc -l` → `20`), so a floor of 10 is honest and
has headroom.

**Negative control in-file** (`p16:124-137`) — `p16` keeps an inline fixture *in addition to* the
real subject. Per D-26, `p17` uses the **committed** fixture convention of `p01`–`p13` instead
(`GSD_PROHIB_SUBJECT`), but an extra inline negative control costs nothing and matches `p16`.

**RESEARCH Pitfall 4 (do not lose this):** only ONE artifact is substitutable. When the fixture is
injected as `GSD_PROHIB_SUBJECT`, the `tests/*.spec.ts` walk still reads the **real, clean** specs.
So `retryWrapperIssue(text)` must apply **all six** patterns to the subject text — including
`waitForTimeout(` and `test.slow(` — or the fixture cannot go RED. Do not split "config patterns"
from "spec patterns".

**RESEARCH Pitfall 3:** do **not** assert on `trace` — a leftover diagnostic `trace: 'on'` would
otherwise red `fast_checks` during the very diagnosis this phase performs. Scope `p17` to
`retries` / `waitForTimeout` / `test.slow` / `test.describe.configure({ retries`.

---

### `test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts` (test fixture, file-I/O) — CREATED

**Analog:** `test/fixtures/prohibitions/p02-axe-test-tagged-snapshot.ts` — the only committed `.ts`
fixture in the directory. Verbatim in full:

```ts
// KNOWN-BAD fixture for P2 (230-02). Declares the helper and the axe test so the guard's
// structural tests pass; the defect is the `{ tag: '@snapshot' }` on the axe test, which
// the PR lane's `--grep-invert '@snapshot'` then excludes -- removing the WCAG scan from
// every pull request while the gallery lane still reports green.
import AxeBuilder from '@axe-core/playwright';
import { test, expect, type Page } from '@playwright/test';

async function assertNoAxeViolations(page: Page, label: string) {
  const { violations } = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'])
    .analyze();
  expect(violations, `${label}: axe violations`).toHaveLength(0);
}

const RESPONSIVE_WIDTHS = [390, 1280];

test.describe('Design gallery board snapshots', () => {
  test('axe: full-page WCAG 2.1/2.2 AA on the design gallery', { tag: '@snapshot' }, async ({ page }) => {
    await assertNoAxeViolations(page, 'design-gallery');
  });
});
```

**Conventions to honour, all visible above:**
1. Opening comment starts literally `// KNOWN-BAD fixture for PNN (<plan-id>).`
2. It **names the defect explicitly** and says what silently breaks.
3. It is **structurally valid** for the guard's parse — it satisfies every *structural* assertion so
   the RED comes from the *substantive* check, not from a "the parse broke" message. For `p17` that
   means the fixture must still be a recognisable `defineConfig({...})` with a locatable `retries:`
   line, so the non-vacuity floor passes and `retryWrapperIssue` is the thing that fires.
4. It is never imported or executed — it is read as text.

Per D-26 the `p17` fixture carries **all three** violations in one file:
`retries: Number(process.env.PLAYWRIGHT_RETRIES ?? 1)` inside `defineConfig`, a
`page.waitForTimeout(500)`, and a `test.slow()`.

**Where the fixture path is declared:** NOT in the guard. `grep -rn "test/fixtures/prohibitions"
scripts/ci/prohibitions/` returns zero hits. It goes in the PLAN frontmatter
(`check_violation_fixture:` / `check_clean_fixture:`), per the `230-07-PLAN.md:26-34` shape quoted
in RESEARCH.

---

### `test/sigra/planning/phase_236_audit_url_ownership_test.exs` (test, file-I/O + regex) — CREATED

**Analogs:** `test/sigra/planning/phase_232_playwright_economics_test.exs` (source-string contract
over shipped files) and `test/sigra/planning/phase_230_ci_timeouts_test.exs` (non-vacuity floor +
ci.yml job-block walk). Naming convention across the 24 files in that directory:
`phase_NNN_<slug>_test.exs` → `defmodule Sigra.Planning.PhaseNNN<Slug>Test`.

**Module header + path constants** (`phase_232_playwright_economics_test.exs:1-7`, verbatim):

```elixir
defmodule Sigra.Planning.Phase232PlaywrightEconomicsTest do
  use ExUnit.Case, async: true

  @config_path "test/example/priv/playwright/playwright.config.ts"
  @setup_path "test/example/priv/playwright/tests/admin-design.setup.ts"
  @spec_path "test/example/priv/playwright/tests/admin-design.spec.ts"
  @workflow_path ".github/workflows/ci.yml"
```

**Assertion idiom — `File.read!` + `=~`, with an explanatory failure message**
(`phase_232_playwright_economics_test.exs:9-18`, verbatim):

```elixir
  test "chromium design project depends on one setup project with a private state path" do
    config = File.read!(@config_path)

    assert config =~ "name: 'admin-design-setup-chromium'"

    assert config =~
             ~r/name: 'admin-design-chromium',[\s\S]*dependencies: \['admin-design-setup-chromium'\],[\s\S]*storageState: 'test-results\/\.auth\/admin-design-chromium\.json'/,
           "the chromium design project must have exactly its own setup dependency and state path"
  end
```

and the `refute` half (`:38-42`, verbatim) — directly reusable for "no plain `<a href>` drives a
filter transition":

```elixir
    refute before_each =~ "registerUser"
    refute before_each =~ "waitForTimeout"
    refute before_each =~ "retry"
```

**Non-vacuity floor idiom** (`phase_230_ci_timeouts_test.exs:53-59`, verbatim):

```elixir
  test "job walk finds at least 20 job blocks (non-vacuous)" do
    blocks = job_blocks()
    count = length(blocks)

    assert count >= 20,
           "job walk found #{count} jobs — the parse broke, this is not a pass"
  end
```

The `"— the parse broke, this is not a pass"` suffix is the repo-wide convention (`_lib.mjs:20-24`
records that the node guards borrowed it *from this file*). Use it verbatim.

**Deriving a ci.yml job block without a YAML dep** (`phase_230_ci_timeouts_test.exs:24-45`) — copy
this `String.split(~r/\njobs:\s*\n/, parts: 2)` + `~r/(?=^  [a-zA-Z0-9_-]+:\s*$)/m` walk for the
`PLAYWRIGHT_RETRIES`-is-gone assertion, so the check is a parsed contract rather than a bare grep
(standing constraint 1 rejects count-only acceptance). The comment block at `:9-10` states the
no-YAML-parser rationale — reuse that reasoning verbatim.

**What this test must assert (from RESEARCH's Wave 0 gap list):**
form carries `phx-submit`; ≥1 `handle_event/3` exists; the six converted anchors are `<.link patch=`
not `<a href=`; `Export CSV` is still `<a href`; `method="get"` and `action=` survive; `ci.yml` has
zero `PLAYWRIGHT_RETRIES` occurrences **and** the `generated_admin_playwright_smoke` block still
parses with ≥1 `env:` key; plus a floor on the converted-anchor count.

**Run command:** covered by `mix ci`'s `test --exclude scaffold` (repo root, `elixirc_paths(:test)`
includes `lib` + `test/support`). Note RESEARCH C-9: `test/example`'s own ExUnit suite is a
**separate** job and is NOT run by `mix ci` — the plan's local gate must be both
`MIX_ENV=test mix ci` and `(cd test/example && MIX_ENV=test mix test --include example_app)`.

---

### `.planning/phases/236-flake-root-cause-reproduce-name-fix/236-EVIDENCE.md` (doc, machine-parsed) — CREATED

**Analog:** `.planning/milestones/v1.47-phases/232-playwright-economics-authenticate-once-then-shard/232-EVIDENCE.md`
(git-tracked; parses cleanly under `parseEvidenceSlots`). The format contract lives in
`scripts/ci/prohibitions/_lib.mjs:254` and is deliberately generic across `.planning/phases`:

```js
export const SLOT_HEADING_RE = /^##\s+((?:BEFORE|AFTER)-[A-Z0-9-]+)\s*$/;
```

with, from `parseEvidenceSlots` (`_lib.mjs:256-295`): a `Status:` line matched by
`/^Status:\s*(.+)$/m`; `captured` iff the status starts with `captured`; run IDs harvested as
`/\b(\d{8,12})\b/g`; fenced blocks as `/```[\s\S]*?```/g`; and a throw if zero slots parse.

`p12-run-id-provenance.test.mjs:38-48` additionally pins the **status grammar**:

```js
    assert.match(
      s.statusRaw,
      /^(captured \((run|runs) [\s\S]+\)|pending \(.+\))$/,
```

**Copy this structure verbatim** (`232-EVIDENCE.md:1-45`, abridged to its load-bearing shape):

```markdown
# Phase 232 Evidence Ledger

| Slot | What it is | How captured | Status |
|------|-----------|--------------|--------|
| [BEFORE-PW-01](#before-pw-01) | Same-current-topology design-gallery PR run `30537470157` | `gh run view`, job log, and `ci-run-metrics.sh --jobs` | captured |
| [AFTER-PW-01](#after-pw-01) | PW-01-only design-gallery PR run `30649942464` | ... | captured |

---

## BEFORE-PW-01

Status: captured (run `30537470157`)

Same-current-topology pre-change receipt. The run is a successful `pull_request` event at
head `a897e724b48c21fa25c8893ede99e1a3b3f56ca5`.

Commands:

```bash
gh run view 30537470157 --repo szTheory/sigra --json databaseId,event,headSha,conclusion,jobs
bash scripts/ci/ci-run-metrics.sh --jobs 30537470157
```

Observed design step:

```text
startedAt: 2026-07-30T11:17:21Z
conclusion: success
39 passed (3.6m)
```

---
```

Conventions the new ledger must honour:
1. `# Phase 236 Evidence Ledger` H1, then a summary table linking each slot by anchor.
2. Slot headings exactly `## BEFORE-FLAKE-RED` / `## AFTER-FIX-GREEN` (uppercase + hyphens only —
   `SLOT_HEADING_RE` rejects lowercase).
3. A bare `Status: captured (run \`NNNNNNNN\`)` or `Status: pending (<reason>)` line — the grammar
   above is enforced, and `captured` **must** carry an 8-12 digit run id in the Status line itself.
4. Every captured slot carries ≥1 fenced block whose content invokes the committed instrument
   (`ci-run-metrics.sh`) or `gh run|pr|api` — `p12:66-80` asserts this.
5. Non-slot analysis sections use a plain `## Heading` (they are skipped by the parser and need no
   `Status:` line) — `232-EVIDENCE.md:11` "## Historical baseline note" is the example.
6. `_lib.mjs`'s `archiveAwareRelPath` means the ledger keeps parsing after milestone close-out
   moves it to `.planning/milestones/` — no path pinning needed.

For SC-1's RED slot specifically: record the **absolute path of the failing attempt's `trace.zip`**,
the `--repeat-each` index, and the **received URL string verbatim** (it is what discriminates D-05's
three branches).

---

## Shared Patterns

### Non-vacuity floor + "the parse broke, this is not a pass"
**Source:** `test/sigra/planning/phase_230_ci_timeouts_test.exs:53-59`; mirrored in
`scripts/ci/prohibitions/_lib.mjs:20-24` and every `pNN` guard.
**Apply to:** `p17-*.test.mjs`, `phase_236_audit_url_ownership_test.exs`.
Every extractor either throws or is guarded by an explicit count floor, and the failure message
names the floor. A guard whose parse silently matches nothing reports green and protects nothing.

### Comment-stripping before any content assertion
**Source:** `scripts/ci/prohibitions/_lib.mjs:147-177` (`stripJsComments`), applied at
`p02-axe-signal-not-reduced.test.mjs:21`.
**Apply to:** `p17-*.test.mjs` (both the config subject and the spec walk).
The repo documents its own compliance in prose that necessarily contains the asserted tokens —
verified at `playwright.config.ts:15-16`. Comment-stripping is a correctness requirement here, not
a nicety. Never hand-roll a regex; import the helper.

### One substitutable subject, secondaries from real paths
**Source:** `scripts/ci/prohibitions/_lib.mjs:11-17` (doc comment) + `:33-78`
(`subjectPath` / `archiveAwareRelPath` / `readSubject`).
**Apply to:** `p17-*.test.mjs`.
`readSubject(DEFAULT_REL_PATH)` for the one artifact the fail-first producer substitutes;
`readRepoFile(...)` for everything else. `readSubject` **throws** on a missing subject — *"a missing
subject is a broken run, never an absent violation"*.

### Guard header comment: prohibition, subject, and what-breaks-if-deleted
**Source:** `scripts/ci/prohibitions/p02-...:1-12` and `p16-...:1-29`.
**Apply to:** `p17-*.test.mjs`.

### Committed known-bad fixture, structurally valid
**Source:** `test/fixtures/prohibitions/p02-axe-test-tagged-snapshot.ts` (and the `p01`–`p13` set).
**Apply to:** `test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts`.
Fixture path is declared in PLAN frontmatter, never in the guard.

### `@impl true` on the first clause only
**Source:** `lib/sigra/admin/live/branding_live.ex:395-397` then `:418` (bare `def handle_event`).
**Apply to:** `audit_index_live.ex`'s new `handle_event/3`.

### PNG-baseline safety: no class/tag/text change
**Source:** `lib/sigra/admin/live/branding_live.ex:126-148` — an already-shipping `<.link patch>`
with committed baselines, proving attribute passthrough is render-neutral *in this repo*.
**Apply to:** every anchor conversion in `audit_index_live.ex`.
Four PNGs render `/admin/audit` (RESEARCH C-7: `audit-explorer-admin-checkpoints-{chromium,dark,mobile}.png`
plus `audit-explorer-demo-showcase-chromium.png`). Carry every `class`/`id`/`aria-*` verbatim;
rename only `href=` → `patch=`.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| (none) | — | — | Every created/modified file has a tracked in-repo analog. |

**One construct within an analog-backed file has no precedent:** server-side `push_patch/2` — 0 hits
across `lib/`. `branding_live.ex` covers the `<.link patch>` and `phx-submit`/`handle_event` halves
but its `handle_event`s return `assign`, not `push_patch`. For that single call, follow
RESEARCH §Architecture Patterns / Pattern 2 and the `deps/phoenix_live_view` citations
(`phoenix_live_view.ex:1162-1167` `validate_local_url!`; `channel.ex:937-950` the cross-session
`ArgumentError`). State the narrow, true claim — "`push_patch/2` is new to `lib/`" — never the
false zero-hit grep from D-16.

**Deliberately excluded from conversion** (not "no analog", but a recorded scope line):
`lib/sigra/admin/components.ex:372` `applied_chip` and `:827` `audit_pagination_nav` — shared with
`audit_user_live.ex` and `users_index_live.ex` (D-30 excluded), and not on the failing test's path.

---

## Metadata

**Analog search scope:** `lib/sigra/admin/live/`, `lib/sigra/admin/components.ex`,
`scripts/ci/prohibitions/`, `test/fixtures/prohibitions/`, `test/sigra/planning/`,
`.planning/phases/` + `.planning/milestones/*/`, `.github/workflows/ci.yml`,
`test/example/priv/playwright/`.
**Files scanned:** ~30 (7 read in depth for excerpts).
**Tracked-source gate:** all 12 analog paths confirmed via `git ls-files`; no gitignored mirror
paths emitted.
**Pattern extraction date:** 2026-09-15 (HEAD: `718d1a56`)
