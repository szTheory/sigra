# Phase 236: Flake Root Cause — Reproduce, Name, Fix - Research

**Researched:** 2026-09-15
**Domain:** Phoenix LiveView 1.1.x navigation/form semantics · Playwright flake reproduction · node:test prohibition guards · GitHub Actions dispatch mechanics
**Confidence:** HIGH (every load-bearing claim below was verified by opening the source-of-truth file at HEAD `09ec1353` this session)

## Summary

CONTEXT.md is deep and mostly right. This research verified all 33 decisions against HEAD and found **three material errors** (one of which would put a false claim into the plan text), **two incomplete scope statements**, and **one structurally-impossible fallback contract**. Everything else checks out, and several claims are now stronger than CONTEXT stated them.

The single most important correction: **D-16's "zero `push_patch` / `<.link patch>` / `live_patch` anywhere in `lib/sigra/admin/` (grep → 0 hits)" is FALSE.** `lib/sigra/admin/live/branding_live.ex:126-148` already ships three `<.link ... patch={panel_path(...)}>` tabs backed by `handle_params/3` at `:87` and a local-path helper at `:595`. The plan must NOT cite a zero-hit grep — it would be a fabricated claim in a milestone whose thesis is honesty. D-08 is not a first-of-its-kind divergence; it is **applying the existing `branding_live.ex` idiom to a second admin surface**, which is a much easier sell and removes the D-16 framing burden entirely. (What IS zero in `lib/`: server-side `push_patch/2` — 0 hits. So only the `handle_event` → `push_patch` half is new.)

The second: **D-32's SC-5 fallback is structurally impossible as written.** `.github/ci-skip-manifest.tsv` is not a general quarantine ledger — `scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs:72-89` asserts *every* manifest `id` resolves to a real `ci.yml` job block or step `id:`, `:101-116` asserts `display_name` byte-matches ci.yml, `:118-175` asserts the `gate` column equals ci.yml's actual normalized `if:` expression, and `:211-226` asserts the reverse set-equality. A Playwright *test name* has none of those. Recommendation below.

The third: **D-20's conclusion is right but its reasoning was incomplete, and the correct reasoning makes it airtight** — `release_ref_guard` does exit 0 when `recapture_branch` is non-empty (`ci.yml:85-87`), which looks like a dispatch escape hatch, but `ci.yml:18-20` documents that a non-empty `recapture_branch` **runs `admin_design_recapture` and `admin_checkpoint_recapture` and opens their PRs**, i.e. it opens exactly the PNG recapture lane that ROADMAP standing constraint 7 forbids. So dispatch is closed by *two* independent gates, not one.

**Primary recommendation:** Plan three ordered slices — (1) repro + diagnosis artifact (SC-1/SC-2 first half, gates everything); (2) the `lib/` fix modelled verbatim on `branding_live.ex`, plus the `ci.yml:1460` deletion; (3) the `p17` guard + committed fixture + repeated-push green evidence. Do not let the planner cite the D-16 zero-hit grep, and do not let it plan an SC-5 quarantine row into `ci-skip-manifest.tsv` without the schema amendment described below.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Audit filter URL ownership | Frontend Server (LiveView process) | Browser (LiveView JS) | `handle_params/3` is already the sole loader (`audit_index_live.ex:25`); the bug is that the *browser* currently owns URL transitions via native nav |
| Preset/sort/pagination navigation | Browser → LiveView JS (`data-phx-link="patch"`) | Frontend Server (`handle_params/3`) | `<.link patch>` keeps the transition inside the live socket instead of tearing it down |
| Filter form submission | Frontend Server (`handle_event` → `push_patch`) | Browser (native GET, dead-render + no-JS fallback only) | Progressive enhancement: exactly one path fires per connection state |
| CSV export | Browser (document navigation) | API/Controller | Must stay `<a href>` — it is a controller download, `audit_index_live.ex:122` |
| Flake reproduction | CI (GitHub Actions) + local Playwright | — | No harness exists in-repo; both paths are manual |
| Retry-wrapper prohibition | CI (`fast_checks` → `node --test` glob) | — | `ci.yml:393`, auto-discovery, zero workflow edits |

---

## ⚠️ CORRECTIONS TO CONTEXT.md — read these first

### 🔴 C-1 (BLOCKING): D-16's zero-hit grep claim is FALSE

CONTEXT D-16 instructs the plan to "state this divergence explicitly and **cite the zero-hit grep**". The grep is not zero.

```
$ grep -rn "push_patch\|<\.link patch\|live_patch\|patch=" lib/sigra/admin/
lib/sigra/admin/live/branding_live.ex:128:            patch={panel_path(:light)}
lib/sigra/admin/live/branding_live.ex:136:            patch={panel_path(:dark)}
lib/sigra/admin/live/branding_live.ex:144:            patch={panel_path(:details)}
```

[VERIFIED: lib/sigra/admin/live/branding_live.ex:125-148] — verbatim, the first of three:

```heex
<nav class="sg-tabs" aria-label="Branding sections">
  <.link
    id="branding-tab-light"
    class={tab_class(@active_panel, :light)}
    patch={panel_path(:light)}
    aria-current={current_panel_attr(@active_panel, :light)}
  >
    Light
  </.link>
```

And [VERIFIED: lib/sigra/admin/live/branding_live.ex:595]:

```elixir
defp panel_path(panel) when panel in @panels, do: "/admin/auth-branding?panel=#{panel}"
```

with `def handle_params(params, _uri, socket) do` at `:87` [VERIFIED: lib/sigra/admin/live/branding_live.ex:87].

**Consequences for the plan:**
- The `<.link patch>` half of D-08 has a **direct, in-repo, same-directory precedent that already carries `id` + `class` + `aria-current` through `@rest`** — which independently proves D-11's attribute-passthrough claim in this codebase, not just in the framework.
- Rewrite the D-16 divergence note as: "`<.link patch>` is an established `lib/sigra/admin/` idiom (`branding_live.ex:126-148`); what is new here is the server-side `push_patch/2`, which has **0 hits repo-wide in `lib/`** — that narrower claim is true."
- `branding_live.ex` is therefore the model for **both** halves (patch links *and* `phx-submit` + `handle_event`), not just the `phx-submit` half. D-16's "closest precedent for a form owning its own state" framing understates what is available.

### 🔴 C-2 (BLOCKING): D-32's SC-5 quarantine cannot be written into `ci-skip-manifest.tsv` as-is

D-32 correctly identifies the 8-column schema and the under-filled-row throw. It misses that the manifest is a **ci.yml-construct enumeration**, enforced in four directions by `p10`:

[VERIFIED: scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs:72-89] — verbatim:

```js
test('every manifest id resolves to a real construct in ci.yml', () => {
  for (const r of rows) {
    if (r.kind === 'job') {
      assert.ok(
        blocks.some(([id]) => id === r.id),
        `manifest row \`${r.id}\` (tier ${r.tier}) names a job that does not exist in ci.yml. ` +
```

plus `:101` `display_name matches the construct name ci.yml actually declares`, `:118` `gate column matches the if: expression ci.yml actually declares`, `:211` `no event-gated job in ci.yml is missing from the manifest` (a `deepEqual` set comparison).

And the `observer` column is a **closed enum consumed by shell**, not free text [VERIFIED: scripts/ci/ci-demotion-observer.sh:83]:

```
  $8 == "assert" { print $2 "\t" $3 "\t" $4 "\t" $5 }
```

with a non-vacuity floor at `:88` requiring ≥2 assert rows.

Also: the manifest's own header cell is `parent_job_id` (snake_case), not `parentJobId` — that name is only the JS destructuring alias at `_lib.mjs:215` [VERIFIED: .github/ci-skip-manifest.tsv header row; scripts/ci/prohibitions/_lib.mjs:215].

Also: the manifest's comment block names `scripts/ci/prohibitions/honest-skip-parity.test.mjs` as the parity guard. **That file does not exist.** The parity guard is `p10-no-undocumented-demotion.test.mjs` (plus `p07`, `p13`, and `scripts/ci/honest-skip-verdict.sh`). [VERIFIED: `ls scripts/ci/prohibitions/` → `_lib.mjs, p01…p16` only]. The plan should not chase a nonexistent file.

**Recommendation (concrete, with parser evidence):**

Do **not** stuff date+owner into `observer` — `ci-demotion-observer.sh:83` keys `$8` and `p10` reads it. Do **not** add a `kind=job` row naming the Playwright test — `p10:72-89` hard-fails.

Recommend **two columns appended, making 10**: `quarantined_on` (`$9`, ISO date) and `owner` (`$10`). This is parser-safe (`_lib.mjs:212` rejects only `cells.length < 8`; the destructure at `:215` ignores extras) and observer-safe (`$8` unchanged). **But** the row still needs a `kind` that `p10` skips. So the amendment is **three parts**:
1. Append `quarantined_on` + `owner` columns (all existing rows get `-`/`-`).
2. Add `kind=spec` and exempt it from `p10:72-89`'s id-resolution branch and `p10:101`'s display-name branch, with an explicit comment saying why (a Playwright test is not a ci.yml construct).
3. Add the matching `MAINTAINING.md` entry, because the manifest's header documents MAINTAINING.md as a *renderer* of this file.

Because that is a real schema change to a file **Phase 241 explicitly depends on** (ROADMAP: "236 → 241 — the honest-skip-parity guard pins `ci.yml` job ids; writing it before 236's `ci.yml` edits pins a moving target"), the plan should treat SC-5 as a **documented contingency design, not a built artifact** — spec the amendment in the plan text, implement it only if root-cause genuinely fails. Building it speculatively costs Phase 241 a moving target.

### 🟡 C-3: D-12's "raises ArgumentError" is right, but its citation is wrong — and the client/server asymmetry is the load-bearing part

`route.ex:31-49` does **not** raise for a foreign view/session. It returns `{:external, route.uri}` [VERIFIED: deps/phoenix_live_view/lib/phoenix_live_view/route.ex:31-49] — verbatim:

```elixir
  def live_link_info!(%Socket{} = socket, view, uri) do
    %{private: %{live_session_name: session_name}} = socket

    case live_link_info_without_checks(socket.endpoint, socket.router, uri) do
      {:internal, %Route{view: ^view, live_session: %{name: ^session_name}} = route} ->
        {:internal, route}

      {:internal, %Route{} = route} ->
        {:external, route.uri}
```

The raise happens one layer up, **only on the server-side path** [VERIFIED: deps/phoenix_live_view/lib/phoenix_live_view/channel.ex:937-950] — verbatim:

```elixir
  defp patch_params_and_action!(socket, %{to: to}) do
    destructure [path, query], :binary.split(to, ["?", "#"], [:global])
    to = %{socket.host_uri | path: path, query: query}

    case Route.live_link_info!(socket, socket.private.root_view, to) do
      {:internal, %Route{params: params, action: action}} ->
        {params, action}

      {:external, _uri} ->
        raise ArgumentError,
              "cannot push_patch/2 to #{inspect(to)} because the given path " <>
                "does not point to the current root view #{inspect(socket.private.root_view)}"
    end
  end
```

The **client-side** `<.link patch>` path degrades gracefully instead [VERIFIED: deps/phoenix_live_view/lib/phoenix_live_view/channel.ex:138-153]:

```elixir
      {:external, _uri} ->
        {:noreply, reply(state, msg.ref, :ok, %{link_redirect: true})}
```

**Planner takeaway:** `<.link patch>` to a foreign session = safe full navigation. `push_patch/2` to a foreign session = **500 / process crash**. The `handle_event` → `push_patch` path is the only genuinely risky one, and its safety rests entirely on `index_path/1` resolving to the current scope. Both branches verified [VERIFIED: lib/sigra/admin/live/audit_index_live.ex:286-289]:

```elixir
  defp index_path(%Scope{mode: :organization, organization_slug: slug}) when is_binary(slug),
    do: "/admin/organizations/#{slug}/audit"

  defp index_path(_admin_scope), do: "/admin/audit"
```

The match is on **both** `view` and `live_session.name` — so a patch from `/admin/audit` (`:admin_global`) to `/admin/organizations/:org/audit` (`:admin_organization`) crosses sessions even though the module is identical.

### 🟡 C-4: line-number drift in SC-1 / D-06 / D-18 / D-21 / D-24 / D-25

All small, all worth correcting so plans don't edit the wrong line.

| Claim | Cited | Actual at HEAD | Evidence |
|---|---|---|---|
| Failing test declaration | `:427` (D-06), `:428` (ROADMAP SC-1) | **`:428`** (`test("generated audit presets…`) | [VERIFIED: test/example/priv/playwright/tests/admin-generated.spec.ts:428] |
| `press("Enter")` | `:457` (D-06) | **`:458`** (`:457` is `toHaveValue`) | [VERIFIED: …spec.ts:457-458] |
| Failing `toHaveURL` | `:459` (D-06) ✅ | `:459` ✅ | [VERIFIED: …spec.ts:459] |
| `retries: 0` | `playwright.config.ts:59` ✅ | `:59` ✅ | [VERIFIED: test/example/priv/playwright/playwright.config.ts:59] |
| `trace: 'on-first-retry'` | `:59` (D-18 bundles it) | **`:81`** (inside `use:`) | [VERIFIED: playwright.config.ts:81] |
| D-25's compliance prose | `:16-18` | **`:15-16`** | [VERIFIED: playwright.config.ts:15-16] `// Retries stay at zero everywhere; CI shard commands repeat --retries=0 explicitly so` / `// observed isolation evidence cannot be masked by a recovered attempt.` |
| `expect.timeout` | (unnumbered) | **`:68-69`**, `timeout: 15_000` | [VERIFIED: playwright.config.ts:68-69] — matches the todo's "19 polls / ~15s" exactly |
| Smoke-script Playwright call | `:398-404` | **`:398-404`** ✅ (`npx` at `:403`) | [VERIFIED: scripts/ci/admin-acceptance-smoke.sh:398-404] |
| `bindForms` | `live_socket.js:1158-1197` ✅ | `:1158`, second listener `:1181-1197` ✅ | [VERIFIED: deps/phoenix_live_view/assets/js/phoenix_live_view/live_socket.js:1158,1181-1197] |
| `<.link patch>` render | `phoenix_component.ex:3090-3120` | **`:3108-3120`** (patch clause) | [VERIFIED: deps/phoenix_live_view/lib/phoenix_component.ex:3108-3120] |
| `phx-no-format` strip | `tag_engine.ex:1538` ✅ | `:1538-1540` ✅ | [VERIFIED: deps/phoenix_live_view/lib/phoenix_live_view/tag_engine.ex:1538-1540] |
| Router two sessions | `router_injection.ex:28-41,56-69` ✅ | ✅ (`live_session :admin_global` `:28`, `AuditIndexLive` `:36`; `live_session :admin_organization` `:56`, `AuditIndexLive` `:69`) | [VERIFIED: priv/templates/sigra.install/admin/router_injection.ex:28,36,56,69] |
| All `audit_index_live.ex` anchor/form citations | `:59-74,76,121,122,140,142,155,180,189-190,286-289` | **all correct** | [VERIFIED: lib/sigra/admin/live/audit_index_live.ex — `href=` at 61, 68, 121, 122, 155, 180; `<form method="get"` at 76; `remove_href=` 140; `Clear all` 142; `prev_href/next_href` 189-190; `index_path/1` 286-289] |
| `ci.yml` regions | `:80-96, :393, :1401-1421, :1460` | **all correct** | [VERIFIED: .github/workflows/ci.yml:78 step, 393 glob, 1401 job, 1460 env] |

### 🟡 C-5: D-04's "stable control" is a **different LiveView**, and it uses a button, not Enter

D-04 calls `admin-audit.spec.ts:127-146` "the **identical** GET filter form". It is not the same view. That block is on the **org-scoped per-user audit page** (`audit_user_live.ex`), reached via `View full audit` [VERIFIED: test/example/priv/playwright/tests/admin-audit.spec.ts:130-143]:

```ts
    await page.getByRole('link', { name: 'View full audit' }).click();
    await waitForLiveViewReady(page);
    await expect(page).toHaveURL(new RegExp(`/admin/organizations/${orgSlug}/users/[^/]+/audit`));
```
```ts
    await page.getByRole('textbox', { name: 'Action prefix' }).fill('session');
    await page.getByRole('button', { name: 'Apply filters' }).click();
    await waitForLiveViewReady(page);
    await expect(page).toHaveURL(/action_prefix=session/);
```

Three differences from the failing spec, not one:
1. **Different module** — `audit_user_live.ex:98`, which D-30 explicitly excludes from scope. The "differential control" is the file the phase refuses to touch.
2. **Button click, not `press("Enter")`** — a different submission mechanism (explicit `.click()` on the default button vs. HTML implicit submission).
3. `waitForLiveViewReady` is called both before the fill **and** after the click — the generated spec does neither around the presets.

The `/admin/audit` (`audit_index_live.ex`) surface is reached in `admin-audit.spec.ts` only by direct `page.goto('/admin/audit?action_prefix=admin.impersonation')` at `:110` [VERIFIED: admin-audit.spec.ts:110] — **no spec anywhere drives `audit_index_live.ex`'s filter form except the failing one.** That is itself a finding: the surface has zero working browser control.

D-04's *conclusion* (waitForLiveViewReady sequencing is the discriminator) survives, but the plan must not describe the control as the same form, and must not treat "the control passes" as evidence that `audit_index_live.ex`'s form works.

### 🟢 C-6: NEW mechanism evidence that materially strengthens D-01 (not in CONTEXT)

Nobody checked what LiveView JS does on a submit of a form with **no** `phx-submit`. It tears down the socket [VERIFIED: deps/phoenix_live_view/assets/js/phoenix_live_view/live_socket.js:1181-1197] — verbatim:

```js
    this.on("submit", (e) => {
      const phxEvent = e.target.getAttribute(this.binding("submit"));
      if (!phxEvent) {
        if (DOM.isUnloadableFormSubmit(e)) {
          this.unload();
        }
        return;
      }
      e.preventDefault();
```

and [VERIFIED: deps/phoenix_live_view/assets/js/phoenix_live_view/live_socket.js:247-257]:

```js
  unload() {
    if (this.unloaded) {
      return;
    }
    if (this.main && this.isConnected()) {
      this.log(this.main, "socket", () => ["disconnect for page nav"]);
    }
    this.unloaded = true;
    this.destroyAllViews();
    this.disconnect();
  }
```

with `isUnloadableFormSubmit` returning `!e.defaultPrevented && !this.wantsNewTab(e)` [VERIFIED: deps/phoenix_live_view/assets/js/phoenix_live_view/dom.js:105-117].

**Why this matters:** on today's `/admin/audit`, pressing Enter in the filter form sets an irreversible `unloaded = true` latch, destroys every view and disconnects the socket — *in anticipation of* a native navigation. If that navigation is suppressed, delayed, or raced against the socket join, the page is left permanently socket-dead with the URL frozen at the prior preset's query string — **exactly the reported symptom** [CITED: .planning/todos/pending/2026-07-30-…-actor-filter-race.md, "the URL stays pinned to the prior preset's query string … across 19 polling attempts over ~15s"].

This is the strongest mechanism-level support D-01 has, and it comes from LiveView's own source. It also gives the fix a principled justification beyond "one URL owner": **both `phx-submit` and `<.link patch>` stop `unload()` from being called at all** — `:1188` `preventDefault()` runs before any unload branch, and patch links are handled by `bindNav`, not `isNewPageClick`.

The planner should fold this into the SC-2 differential diagnosis as the named mechanism. It does **not** relieve SC-1: D-05 still governs, and the trace is still the decider.

### 🟡 C-7: D-08/D-11 undercount the PNG baselines that render `/admin/audit` — there are **four**, not three

[VERIFIED: `find test/example/priv/playwright -name "*audit*png"`]:

- `tests/admin-checkpoints.spec.ts-snapshots/audit-explorer-admin-checkpoints-{chromium,dark,mobile}.png` — ×3, guarded by `snapshot-canary-guard.sh` at `ci.yml:205`
- `tests/demo-showcase.spec.ts-snapshots/audit-explorer-demo-showcase-chromium.png` — ×1, **not** covered by either canary-guard invocation (`ci.yml:205` covers admin-checkpoints, `ci.yml:206-212` covers admin-design), but hard-gated by the demo-showcase spec's own comparison

The demo-showcase PNG is captured on the real page [VERIFIED: test/example/priv/playwright/tests/demo-showcase.spec.ts:932-943]:

```ts
    await page.goto("/admin/audit");
    await waitForLiveViewReady(page);
    …
    await assertDemoScreenshot(page, testInfo, "audit-explorer");
```

The `admin-design` `board-cfg-audit-*` / `board-audit-row-*` boards are **safe**: they render a hand-copied static board in `design_gallery_live.ex`, not the LiveView [VERIFIED: test/example/lib/example_web/live/admin/design_gallery_live.ex:1329] — `<%!-- board-cfg-audit — Audit archetype; see audit_index_live.ex + admin-design-contract.md --%>`.

### 🟡 C-8: D-17 misses a second router

D-17 says the only outside mention is the design-gallery comment. There is also the example app's own router [VERIFIED: test/example/lib/example_web/router.ex:282,315]:

```
test/example/lib/example_web/router.ex:282:      live "/admin/audit", Elixir.Sigra.Admin.Live.AuditIndexLive, :index
test/example/lib/example_web/router.ex:315:      live "/audit", Elixir.Sigra.Admin.Live.AuditIndexLive, :index
```

Not a change surface (no LiveView mirror exists — D-17's core claim holds), but it confirms the two-`live_session` constraint of C-3 applies in the **example lane too**, not only the generated lane.

### 🟡 C-9: "`mix ci`, never root `mix test`" does not cover the ExUnit coverage this phase must protect

`mix ci` runs from the repo root [VERIFIED: mix.exs:149-157]:

```elixir
      ci: [
        "format --check-formatted",
        "deps.get --check-locked",
        "deps.unlock --check-unused",
        "compile --warnings-as-errors",
        "test --exclude scaffold",
        "ci.install_golden",
        "sigra.dep_off"
      ],
```

with `elixirc_paths(:test), do: ["lib", "test/support"]` [VERIFIED: mix.exs:55]. The example-app ExUnit suite runs in a **separate job with its own working directory** [VERIFIED: .github/workflows/ci.yml:704,710]:

```
        working-directory: test/example
…
        run: mix test --include example_app
```

So `test/example/test/example_web/live/admin_audit_index_live_test.exs` — the ExUnit coverage CONTEXT's Integration Points says "must keep passing under `mix ci`" — is **not** run by `mix ci`. The plan's local gate must be **both**:

```bash
MIX_ENV=test mix ci
(cd test/example && MIX_ENV=test mix test --include example_app)
```

Good news: that test asserts on rendered `href` strings from a dead render [VERIFIED: test/example/test/example_web/live/admin_audit_index_live_test.exs:41-59], e.g. `assert html =~ "/admin/audit?"`, `assert html =~ "order_direction=asc"`, `assert html =~ "cursor="`. Since `<.link patch>` emits an identical `href` (C-10 below), it should pass unchanged — but it must be *run* to know.

### 🟢 C-10: D-11 is fully VERIFIED, and stronger than stated

[VERIFIED: deps/phoenix_live_view/lib/phoenix_component.ex:3108-3120] — verbatim:

```elixir
  def link(%{patch: to} = assigns) when is_binary(to) do
    Phoenix.LiveView.Utils.valid_live_navigation_destination!(to, "<.link patch>")

    ~H"""
    <a
      href={@patch}
      data-phx-link="patch"
      data-phx-link-state={if @replace, do: "replace", else: "push"}
      phx-no-format
      {@rest}
    >{render_slot(@inner_block)}</a>
    """
  end
```

- Exactly two added attributes, `@replace` defaults false → `data-phx-link-state="push"` ✅
- `phx-no-format` is stripped before render [VERIFIED: deps/phoenix_live_view/lib/phoenix_live_view/tag_engine.ex:1538-1540]: `# removes phx-no-format, etc.` / `attrs_to_remove = ~w(phx-no-format phx-no-curly-interpolation)` ✅
- `class` is a declared global [VERIFIED: deps/phoenix_live_view/lib/phoenix_component/declarative.ex:26 inside `@globals ~w(` at `:21`] ✅
- `aria-` is a global **prefix** [VERIFIED: deps/phoenix_live_view/lib/phoenix_component/declarative.ex:16 `@global_prefixes ~w(` + `:137-139` prefix dispatch] ✅

So `class`, `id`, `aria-current` all pass through untouched. **No class, tag, text or layout change → the four audit PNGs cannot move.** Confirmed empirically in-repo by `branding_live.ex:126-148`, which already does exactly this with `id` + `class` + `aria-current` and has committed baselines.

⚠️ One caveat the planner must honour: `href` is an **explicit attr**, not a global, and `<.link patch>` names it `patch`. So `href={preset_path(...)}` must become `patch={preset_path(...)}`. The rendered `href` string is byte-identical (`href={@patch}`), which is what keeps the ExUnit assertions of C-9 green.

### 🟢 C-11: D-10, D-09, D-13, D-18, D-19, D-27, D-28, D-29, D-30, D-31 — all VERIFIED

- **D-10** ✅ [VERIFIED: live_socket.js:1181-1197] — see C-6's verbatim block. `e.preventDefault()` at `:1188` is unconditional once `phx-submit` is present; the native GET cannot double-fire while connected. Keeping `method="get"` + `action=` is genuinely hazard-free.
- **D-09** ✅ [VERIFIED: live_socket.js:1163-1180] — verbatim: `if (!externalFormSubmitted && phxChange && !phxSubmit) {` — the external-submit branch is keyed exactly on `phx-change && !phx-submit`. Adding `phx-change` would change semantics for no benefit.
- **D-13** ✅ [VERIFIED: deps/phoenix_live_view/lib/phoenix_live_view.ex:1162-1167]: `defp push_opts!(opts, context) do` / `to = Keyword.fetch!(opts, :to)` / `validate_local_url!(to, context)`. Contrast `<.link patch>`, which accepts `[nil, "http", "https"]` [VERIFIED: deps/phoenix_live_view/lib/phoenix_live_view/utils.ex:599-615].
- **D-18** ✅ `retries: 0` at `:59`, `trace: 'on-first-retry'` at `:81` — no trace artifact can exist today.
- **D-19** ✅ [VERIFIED: .github/workflows/ci.yml:1401-1421] — `generated_admin_playwright_smoke` has `needs: release_ref_guard` and **no `if:` at all**, with an 11-line comment forbidding reintroduction. A RED *is* capturable on an ordinary PR. Corroborated independently by `p09`'s pole pin [VERIFIED: scripts/ci/prohibitions/p09-timeouts-not-truncating.test.mjs:72] and `p10`'s tier-A floor comment [VERIFIED: p10:52-66], both of which record the row's deletion.
- **D-27** ✅ [VERIFIED: .github/workflows/ci.yml:393]: `run: node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs`, inside `fast_checks`, with a comment at `:391-392` noting the shell glob is load-bearing (a bare directory arg is invalid on node 22).
- **D-28** ✅ `PLAYWRIGHT_RETRIES` has **exactly one occurrence repo-wide** outside `.planning/`: `.github/workflows/ci.yml:1460`. Zero readers. Delete it.
- **D-29** ✅ [VERIFIED: .planning/research/STACK.md:81] — `**traces for the flaky runs already exist as artifacts**. Harvest them before adding instrumentation` — and `:195-204`, whose step 1 is `**Harvest the traces that already exist.**` Both false; both must be corrected.
- **D-30** ✅ [VERIFIED: lib/sigra/admin/live/audit_user_live.ex:98, lib/sigra/admin/live/users_index_live.ex:126] — identical `<form method="get" action={index_path(...)}` pattern; `sg-filter-chip` survives only at `users_index_live.ex:352`.
- **D-31** ✅ [VERIFIED: test/example/priv/playwright/tests/admin-generated.spec.ts:445-446]: `await expect(page.locator('[name="outcome"]')).toHaveCount(1);` / `await expect(page.locator('[name="action_prefix"]')).toHaveCount(1);` — the flaking test *is* that bug's regression test. Commit `2a96d72f ci: authenticate Playwright once, then shard (#168)` confirmed to exist.

---

## User Constraints (from CONTEXT.md)

### Locked Decisions
All 33 decisions D-01..D-33 in `.planning/phases/236-flake-root-cause-reproduce-name-fix/236-CONTEXT.md` are locked, **subject to the corrections C-1..C-9 above** (which correct facts CONTEXT asserted, not choices the user made). In particular:

- **D-05 is inviolable:** SC-1's captured trace is the decider, not D-01's diagnosis. Three outcomes are pre-defined: (a) `actor=` absent → D-01 product race → the D-08 fix; (b) `actor=` present-but-empty → connect-patch value-wipe → the form needs `phx-change` value ownership, not just submit ownership; (c) no keydown reached the document → pure harness actionability, **no `lib/` change**, GREEN-02 goes to the SC-5 quarantine branch.
- **D-33:** retry-wrapping is never the fallback. The only accepted non-root-cause close is the D-32 dated, attributed quarantine entry.
- **Repro before fix is a hard gate** (SC-1). No fix accepted without a recorded run id or local artifact path.
- **D-23:** this phase claims `p17`; Phase 241's SURF-04 moves to `p18` via a one-line edit to `.planning/REQUIREMENTS.md:37`.
- **D-15:** demoting `/admin/audit` to a controller is rejected on blast radius (generated-host contract + `waitForLiveViewReady`).
- **Standing constraints 1-7** from `.planning/ROADMAP.md` bind: one live-external observation per phase; evidence at final committed HEAD on a clean tree; `mix ci` before push (see C-9); found-while-cleaning → todo, **except** the pre-authorized `lib/` product-race fix; guards go in `scripts/ci/prohibitions/*.test.mjs` never `mix ci`; every guard needs a committed known-bad fixture and a demonstrated RED; the `REQUIREMENTS.md` Out of Scope table binds — **no PNG baseline-recapture lane opens**.

### Claude's Discretion
- Exact naming of the `handle_event` message and its param-normalization helper.
- Whether `handle_params/3` gains a shared param-normalizer with the new `handle_event` or they stay separate (D-14 only requires the two produce identical URLs).
- Internal structure of `retryWrapperIssue(text)` and whether the spec-file walk is a helper or inline, so long as the non-vacuity floors of D-24 hold.
- Plan/commit granularity, subject to repro-before-fix ordering (SC-1 gates the fix).

### Deferred Ideas (OUT OF SCOPE)
- The same GET-form-in-a-LiveView race on `/admin/users` and the per-user audit view (`users_index_live.ex:126`, `audit_user_live.ex:98`) — file as a new pending todo (D-30).
- Template↔example parity guard — tracked as FUT-01.
- Repo-wide convergence on `<.link patch>` for admin filter panels — explicitly not a v1.48 concern.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GREEN-01 | The failure is reproduced as a captured RED before any fix is written | §Reproduction Mechanics gives two runnable paths + the exact blocker (`admin-acceptance-smoke.sh:398-404` hardcodes args; the `trap cleanup EXIT` at `:76` kills the server) |
| GREEN-02 | The race is fixed in shipped `lib/`; `audit_index_live.ex` no longer runs a plain GET form + `<a href>` presets against `handle_params/3` with no `handle_event`. Dated quarantine if root-cause fails. Retry-wrapping prohibited. | C-1 (precedent exists), C-3 (push_patch safety), C-6 (the `unload()` mechanism), C-10 (baseline safety proven), C-2 (the quarantine fallback is not buildable as specced) |

---

## Standard Stack

No new dependencies. Everything this phase needs is already locked.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `phoenix_live_view` | 1.1.33 (locked) | `<.link patch>`, `push_patch/2`, `handle_event/3` | [VERIFIED: mix.lock:49] |
| `@playwright/test` | 1.59.1 (locked) | Reproduction + gate | [CITED: .planning/research/STACK.md:195] — Dependabot #213 proposes 1.62.1; **Phase 244 owns that bump, not 236** |
| `node:test` (Node 20) | built-in | `p17` guard runtime | [VERIFIED: .github/workflows/ci.yml:393, node-version `'20'` at `:1447`] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `<.link patch>` + `phx-submit` | Controller + dead view | Rejected by D-15 on blast radius (generated-host contract change + breaks every `waitForLiveViewReady`) |
| `<.link patch>` + `phx-submit` | `phx-change` + debounce | Rejected by D-09; verified against `live_socket.js:1163-1180` |
| Repeated push runs for SC-3 | `workflow_dispatch` | Closed by two gates: `release_ref_guard` (`ci.yml:78-96`) *and* the `recapture_branch` escape hatch triggering the forbidden recapture lane (`ci.yml:18-20`) |
| `retries: { mode: 'isolated' }` (Playwright 1.62) | — | Requires the 1.62 bump that Phase 244 owns; also a retry construct the `p17` guard will forbid |

## Package Legitimacy Audit

Not applicable — this phase installs **zero** new packages. Every dependency it touches is already in `mix.lock` / `package-lock.json`.

---

## Architecture Patterns

### Fix shape (D-08), with verified mechanics

```
BEFORE (today)                               AFTER (D-08)
──────────────                               ────────────
<a href={preset_path(…)}>                    <.link patch={preset_path(…)}>
   ↓ browser navigation                         ↓ data-phx-link="patch"
   ↓ live_socket.unload()  ← C-6                ↓ bindNav → "live_patch" msg
   ↓ full teardown + dead render                ↓ channel.ex:138-153
   ↓ websocket rejoin                           ↓ handle_params/3
   ↓ morphdom join-patch                        ↓ morphdom diff (socket alive)
   ✗ RACE WINDOW                                ✓ no teardown, no race

<form method="get" action=…>                 <form method="get" action=…
   (no phx-submit)                                  phx-submit="apply_filters">
   ↓ Enter → implicit submit                    ↓ live_socket.js:1188 preventDefault()
   ↓ live_socket.js:1184-1186                   ↓ JS.exec push "apply_filters"
   ↓ isUnloadableFormSubmit → unload()          ↓ handle_event/3 normalizes params
   ↓ native GET                                 ↓ push_patch(to: index_path(scope)…)
   ✗ socket destroyed, URL frozen               ↓ handle_params/3 (sole loader)
                                                ✓ action= still live when JS off
                                                  or in the dead-render window (D-22)
```

### Pattern 1: `<.link patch>` with full attribute carry-over
**What:** Replace `<a href={f(...)} class=… aria-current=…>` with `<.link patch={f(...)} class=… aria-current=…>`.
**When:** Every anchor at `audit_index_live.ex:61, 68, 121, 140 (via remove_href), 142, 155, 180, 189-190`.
**NOT:** `:122` `Export CSV` — a controller download, must stay a document navigation (D-08.5).
**Example (in-repo, already shipping):**
```heex
<!-- Source: lib/sigra/admin/live/branding_live.ex:126-133 -->
<.link
  id="branding-tab-light"
  class={tab_class(@active_panel, :light)}
  patch={panel_path(:light)}
  aria-current={current_panel_attr(@active_panel, :light)}
>
  Light
</.link>
```

⚠️ `remove_href={...}` at `:140` and `prev_href`/`next_href` at `:189-190` are **component attrs**, not raw anchors — the anchors live inside `.applied_chip` and `.audit_pagination_nav` in `lib/sigra/admin/components.ex`. Converting them means editing `components.ex`, which is **shared by `audit_user_live.ex` and `users_index_live.ex`** — i.e. it widens the blast radius into D-30's excluded files and puts `user-audit-*.png` ×3 at risk. **Recommendation: scope the fix to the raw anchors in `audit_index_live.ex` (`:61, :68, :121, :142, :155, :180`) plus the form, and explicitly record in the plan that `.applied_chip` / `.audit_pagination_nav` stay `<a href>` for this phase** — they are not on the failing test's path (the test only clicks presets and submits the form). The planner must verify this component boundary before writing tasks; CONTEXT's D-08 list reads as if `:140/:189-190` were plain anchors.

### Pattern 2: `phx-submit` + `handle_event` → `push_patch`, keeping progressive enhancement
```heex
<!-- audit_index_live.ex:76, after -->
<form method="get" action={index_path(@admin_scope)} phx-submit="apply_filters"
      class="sg-filter-panel sg-stack">
```
```elixir
# Source pattern: lib/sigra/admin/live/branding_live.ex:397 / :420 (phx-change/phx-submit + handle_event)
def handle_event("apply_filters", params, socket) do
  path =
    socket.assigns.admin_scope
    |> index_path()
    |> append_query(normalize_filter_params(params))

  {:noreply, push_patch(socket, to: path)}
end
```
`index_path/1` is scope-resolving [VERIFIED: audit_index_live.ex:286-289] → the patch never crosses `live_session` (C-3). `append_query/2` at `:298` already drops blanks — reuse it so D-14's "same URL from both paths" holds by construction.

### Anti-Patterns to Avoid
- **`push_patch` to a computed full URL** — `validate_local_url!` raises (C-11/D-13).
- **Adding `phx-change`** — changes debounce semantics; `live_socket.js:1163` keys the external-submit branch on `phx-change && !phx-submit` (D-09).
- **Dropping `method="get"` / `action=`** — kills the no-JS and dead-render fallback for adopters (D-10, D-22).
- **Changing any `class`, tag, or text** — opens a PNG recapture lane (four baselines, C-7); forbidden by standing constraint 7.
- **Widening into `components.ex`** — see Pattern 1's ⚠️.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Repeat-run green evidence | A new dispatch harness | ROADMAP: "Reuse the FAST-01 n=52 machinery; build no new harness". Closest in-repo primitives: `scripts/ci/ci-run-metrics.sh` (`--jobs <run_id>` + windowed `--limit/--since/--event`), `scripts/ci/capture-fast-01-remeasurement.sh` | Standing constraint + explicit ROADMAP scope line |
| Comment-stripping in the guard | A regex | `stripJsComments` from `_lib.mjs:156-177` | D-25: `playwright.config.ts:15-16` documents compliance in prose that a naive `/retries/` would red |
| Guard subject injection | Hardcoded path | `subjectPath()` / `readSubject()` from `_lib.mjs:33-78` | The fail-first producer requires exactly one substitutable subject |
| Skip-manifest parsing | Custom TSV split | `parseSkipManifest` from `_lib.mjs:201-225` | Throws rather than returning `[]` |
| Local repro driver | A new script | `scripts/ci/admin-acceptance-smoke.sh` to boot, then hand-run `npx playwright` — see §Reproduction | The script already handles phx.new + install + seed + boot |

## Common Pitfalls

### Pitfall 1: the smoke script kills the server before you can repeat
`trap cleanup EXIT` at `:76` kills `SERVER_PID` [VERIFIED: scripts/ci/admin-acceptance-smoke.sh:71-76]. And `PLAYWRIGHT_ARGS` is built by a closed `case` with no pass-through [VERIFIED: :361-396]. So `--repeat-each` cannot be threaded through the script.
**Avoid:** run the script in a backgrounded shell that you leave alive, or temporarily add a `SIGRA_SMOKE_KEEP_ALIVE` guard **that is reverted before merge**; then drive `npx playwright` by hand against `SIGRA_EXAMPLE_URL=http://localhost:4017`.
**Warning sign:** `ECONNREFUSED :4017` on the second invocation.

### Pitfall 2: the script revokes the platform admin after Playwright
`mix sigra.admin.revoke --email … --yes` runs at `:407` immediately after the Playwright block [VERIFIED: scripts/ci/admin-acceptance-smoke.sh:406-407]. Any hand-run repeat **must happen before** that, or logins fail for an unrelated reason and the repro is unattributable.

### Pitfall 3: a temporary `trace: 'on'` reds the `p17` guard on its own repo
D-24 has the guard assert on `playwright.config.ts`. If the guard also asserts on `trace`, a leftover `trace: 'on'` from the D-21(b) path breaks `fast_checks`. **Recommendation: do not have `p17` assert on `trace` at all** — `trace` is not a retry wrapper. Keep `p17` to `retries` / `waitForTimeout` / `test.slow` / `test.describe.configure({ retries`. Then a stray `trace: 'on'` is caught by review, not by a guard that would have blocked the diagnosis itself.

### Pitfall 4: `p17`'s fixture must trip the **subject** checker, not the spec walk
Only ONE artifact is substitutable (`_lib.mjs:11-17`). When the producer injects `test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts` as `GSD_PROHIB_SUBJECT`, the `tests/*.spec.ts` walk still reads the **real, clean** spec files and passes. So `retryWrapperIssue(text)` must apply **all six patterns to the subject text** — including `waitForTimeout(` and `test.slow(` — and the fixture must carry all three violations in one file (as D-26 specifies). Splitting "config patterns" from "spec patterns" makes the fixture unable to go RED.

### Pitfall 5: rapid repeated pushes cancel each other
`concurrency.group` keys on `github.event.pull_request.number || github.run_id` with `cancel-in-progress: true` [VERIFIED: .github/workflows/ci.yml:52-54]. On a PR, push N+1 **cancels** push N's whole run. And `push:` only fires on `branches: [main]` [VERIFIED: ci.yml:26-29] — a push to a feature branch produces no push run at all. So SC-3's repeats must be **sequential PR pushes, each allowed to complete** (or at least to reach `generated_admin_playwright_smoke`'s conclusion, ~3.7m measured per `ci.yml:1395`) before the next. Budget ~4-5 min per repeat.

### Pitfall 6: `example_unit_smoke` is not in `mix ci`
See C-9. Run both commands before every push.

## Code Examples

### Non-vacuity floor + pure checker, the `p16` shape
```js
// Source: scripts/ci/prohibitions/p16-no-schedule-lane-leniency.test.mjs:65-85 + :92-105
function leniencyIssue(body) {
  if (!body || body.trim() === '') {
    return 'the parse broke, this is not a pass — verdict step body not found';
  }
  // …pattern checks, each returning a named message…
  return null;
}

test('the parse locates the demotion_receipt job and its Verdict step body', () => {
  assert.ok(receiptBlock, 'job `demotion_receipt` not found — the parse broke, this is not a pass');
});

test('no trigger-dependent early exit and no warn-instead-of-fail branch survives', () => {
  const issue = leniencyIssue(verdictBody);
  assert.equal(issue, null, issue ?? '');
});
```

### The prohibition frontmatter that wires the fixture (this is where the fixture path lives — **not** in the guard)
```yaml
# Source: .planning/milestones/v1.47-phases/230-tier-1-critical-path-reclamation/230-07-PLAN.md:26-34
  prohibitions:
    - statement: "MUST NOT set a `timeout-minutes` tight enough to kill a run …"
      status: resolved
      verification: test
      check_kind: node-test
      check_target: scripts/ci/prohibitions/p09-timeouts-not-truncating.test.mjs
      check_violation_fixture: test/fixtures/prohibitions/p09-job-without-timeout.yml
      check_clean_fixture: .github/workflows/ci.yml
      reason: "…"
```
[VERIFIED: no guard file under `scripts/ci/prohibitions/` references `test/fixtures/prohibitions` — `grep -rn "test/fixtures/prohibitions" scripts/ci/prohibitions/` returns zero hits.] The producer `gsd_run check prohibition-enforcement` supplies the fixture via `GSD_PROHIB_SUBJECT`.

---

## Reproduction Mechanics (SC-1)

### Prerequisites (both paths)
```bash
mix archive.install --force hex phx_new 1.8.8        # CLAUDE.md: CI pin; a different version breaks golden_diff
export PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost
# If using the ephemeral Docker PG: scripts/db/up.sh && source tmp/db.env, then export PGPORT accordingly.
(cd test/example/priv/playwright && npm ci && npx playwright install --with-deps chromium)
```
Defaults confirmed: `PORT=4017` [VERIFIED: scripts/ci/admin-acceptance-smoke.sh:28], `PGUSER/PGPASSWORD/PGHOST` default to `postgres/postgres/localhost` [VERIFIED: :33-35], `PLAYWRIGHT_SPEC="tests/admin-generated.spec.ts"` [VERIFIED: :31].

### Path A — local `--repeat-each` (preferred; no config edit, no merge risk)

```bash
# Terminal 1 — boot the generated host and hold it open.
# The script's `trap cleanup EXIT` (:76) kills the server, so keep it in the foreground
# of its own terminal and interrupt it only when done. Use the `chrome` target: it is the
# cheapest Playwright leg and the app is fully booted before it runs.
cd /Users/jon/projects/sigra
GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test chrome
#   ⚠ once this prints "==> admin-acceptance: revoking platform admin" (:406) the
#     platform admin is gone — do the repeats BEFORE that, or comment the revoke out
#     temporarily (revert before commit).

# Terminal 2 — drive the failing test directly, 30x, with a trace on every attempt.
cd /Users/jon/projects/sigra/test/example/priv/playwright
CI=true SIGRA_EXAMPLE_URL=http://localhost:4017 \
  npx playwright test tests/admin-generated.spec.ts \
    --project=admin-generated \
    -g "generated audit presets expose one effective filter value" \
    --repeat-each=30 --workers=1 --retries=0 --trace=on \
    --output test-results/flake-repro --reporter=line

npx playwright show-trace test-results/flake-repro/**/trace.zip
```
`--project=admin-generated` is required: `admin-generated.spec.ts` is `testIgnore`d from `chromium` and `mobile` [VERIFIED: playwright.config.ts:98,111] and matched only by the `admin-generated` project [VERIFIED: :160-167].

**Artifact to record for SC-1:** the absolute path of the failing attempt's `trace.zip` plus the `--repeat-each` index at which it failed.

### Path B — dispatch-only `trace: 'on'`
Set `trace: 'on'` at `playwright.config.ts:81`, push to a PR branch (the smoke job runs on `pull_request` — D-19 ✅), harvest the `admin-checkpoints` artifact bundle. **Must be reverted before merge** (D-21, Pitfall 3).
Cost: one full PR run per attempt, and the flake is per-run stochastic — Path A is strictly cheaper.

### What to read out of the trace (D-05's decision tree)
| Observation in trace | Cause | Fix |
|---|---|---|
| No `actor=` key in the URL at all; no `navigation` / no `live_patch` frame after the Enter keydown | D-01 product race (C-6 `unload()` mechanism) | The D-08 fix |
| `actor=` present but **empty** in the resulting URL | Connect-patch value wipe | Form needs `phx-change` value ownership, not just submit ownership — **different fix**, re-plan |
| No `keydown` event reaches the document at all | Pure harness actionability | **No `lib/` change.** GREEN-02 → SC-5 quarantine branch (see C-2) |

---

## Runtime State Inventory

Not a rename/refactor/migration phase — the `lib/` change is behaviour-preserving in rendered output and stores nothing. Explicitly:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — the fix touches only render + one new `handle_event`; no schema, no persisted param shape. Verified by reading `audit_index_live.ex` in full (309 lines). | none |
| Live service config | None. | none |
| OS-registered state | None. | none |
| Secrets/env vars | `PLAYWRIGHT_RETRIES` at `ci.yml:1460` — **deleted**, zero readers repo-wide (C-11/D-28). | delete only |
| Build artifacts | Committed PNG baselines ×4 render `/admin/audit` (C-7). Must NOT move. `test/example/priv/playwright/node_modules` unchanged (no package edits). | verify-no-drift |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `deps/phoenix_live_view` | Verifying D-10/D-11/D-12/D-13 | ✓ | 1.1.33 | — |
| PostgreSQL | Local repro + `mix ci` | ✓ (per CLAUDE.md: `scripts/db/up.sh` or Homebrew 5432) | — | — |
| `phx_new` 1.8.8 archive | `admin-acceptance-smoke.sh` + golden tests | ✗ (not verified installed this session) | — | `mix archive.install --force hex phx_new 1.8.8` |
| Node 20 + `node --test` | `p17` guard | ✓ (CI pins `'20'` at `ci.yml:1447`) | — | — |
| `gh` CLI (Actions API) | SC-3 evidence | ✗ (not probed this session) | — | none — SC-3 is blocked without it |
| `npx playwright` browsers | Local repro | ✗ (not probed) | — | `npx playwright install --with-deps chromium` |

**Missing dependencies with no fallback:** none confirmed blocking; `gh` auth should be confirmed at plan time.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework (library) | ExUnit via `mix ci` alias [VERIFIED: mix.exs:149-157] |
| Framework (example app) | ExUnit, separate working directory [VERIFIED: ci.yml:704,710] |
| Framework (browser) | `@playwright/test` 1.59.1, `admin-generated` project [VERIFIED: playwright.config.ts:160-167] |
| Framework (guards) | `node --test --test-reporter=tap` [VERIFIED: ci.yml:393] |
| Config file | `test/example/priv/playwright/playwright.config.ts`; `mix.exs` aliases; no config for `node:test` |
| Quick run command | `node --test scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs` (< 1s) |
| Full suite command | `MIX_ENV=test mix ci` **and** `(cd test/example && MIX_ENV=test mix test --include example_app)` |

### Phase Requirements → Test Map

| Req | SC | Behavior | Test Type | Automated Command | Exists? |
|-----|----|----------|-----------|-------------------|---------|
| GREEN-01 | SC-1 | A RED is captured for `toHaveURL` at `admin-generated.spec.ts:459`, with a trace | manual-repro (unavoidable — reproducing a stochastic flake cannot be a deterministic test) | `npx playwright test … --repeat-each=30 --trace=on` (Path A above) | ❌ Wave 0 — evidence artifact, not a test |
| GREEN-02 | SC-2 | `audit_index_live.ex` has ≥1 `handle_event/3`, the form carries `phx-submit`, and no plain `<a href>` drives a filter transition | unit (ExUnit contract test over the source, the `test/sigra/planning/*.exs` idiom) | `mix test test/sigra/planning/phase_236_audit_url_ownership_test.exs` | ❌ Wave 0 |
| GREEN-02 | SC-2 | Dead render still emits byte-identical `href` strings (no PNG/DOM drift) | unit | `(cd test/example && mix test test/example_web/live/admin_audit_index_live_test.exs)` | ✅ exists, 4 tests [VERIFIED: test/example/test/example_web/live/admin_audit_index_live_test.exs:10,62,98,130] |
| GREEN-02 | SC-2 | Rendered classes/layout unchanged → canary guard green | integration | `bash scripts/ci/snapshot-canary-guard.sh --base origin/main` | ✅ exists [VERIFIED: ci.yml:205] |
| GREEN-02 | SC-2 | Connected LiveView applies the filter and updates the URL without a document navigation | browser | new assertion in `admin-generated.spec.ts` after `waitForLiveViewReady`, e.g. asserting no `page.on('framenavigated')` fires (D-22: must wait for `phx:connected` first) | ❌ Wave 0 (optional — SC-3's repeated green may suffice) |
| GREEN-01/02 | SC-3 | The job passes on every repeat, and the SC-1 repro no longer reproduces | live-external observation | `gh run list --workflow CI --branch <fix-branch> --json databaseId,conclusion` + `gh run view <id> --json jobs`; and a re-run of Path A | ❌ Wave 0 — see Pitfall 5 for the sequencing constraint |
| GREEN-02 | SC-4 | A retry wrapper fails `p17` | node-test, proven RED against a committed fixture | `GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts node --test scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs` → **must exit non-zero**; then unset → **must exit 0** | ❌ Wave 0 |
| GREEN-02 | SC-4 | `PLAYWRIGHT_RETRIES` is gone | unit (grep-backed contract test, not a bare grep — standing constraint 1 rejects count-only) | fold into `phase_236_*_test.exs`: assert `ci.yml` has zero `PLAYWRIGHT_RETRIES` occurrences **and** the `generated_admin_playwright_smoke` block still parses with ≥1 `env:` key (non-vacuity floor) | ❌ Wave 0 |

### How each success criterion is *proved* (the reviewer-facing answer)

**SC-1 — what proves the captured RED.** A `trace.zip` written by a Playwright attempt that *failed* the `:459` assertion, plus the console output showing the `--repeat-each` index and the `Error: expect(page).toHaveURL` message with both expected and received URL. The received URL is the diagnostic payload: it distinguishes D-05's three branches. Record **absolute path + the received URL string verbatim** in the phase EVIDENCE ledger. A trace from a *passing* attempt proves nothing; a trace from a run where the app failed to boot is not a falsification.

**SC-3 — what proves repeated green, and why not `workflow_dispatch`.** [VERIFIED: .github/workflows/ci.yml:78-96] the guard exits non-zero for any `workflow_dispatch` whose `GITHUB_REF` is not `refs/tags/v*` — verbatim:
```yaml
          case "${GITHUB_REF}" in
            refs/tags/v*) ;;
            *)
              echo "Manual CI release-evidence runs must use refs/tags/v*; got ${GITHUB_REF}"
```
The only bypass is a non-empty `recapture_branch` [VERIFIED: ci.yml:85-87], which [VERIFIED: ci.yml:18-20] documents as: *"When set, the two amd64 recapture jobs (admin_design_recapture, admin_checkpoint_recapture) run on this ref and their PRs target it instead of main."* — i.e. it opens the PNG recapture lane forbidden by standing constraint 7. **Both doors are closed.**

Therefore SC-3 evidence = **N sequential pushes to the fix PR**, each allowed to conclude before the next (Pitfall 5), harvested as:
```bash
gh run list --workflow CI --branch <fix-branch> --event pull_request \
  --limit 40 --json databaseId,headSha,conclusion,createdAt
gh run view <run_id> --json jobs \
  --jq '.jobs[] | select(.name=="Generated admin Playwright smoke") | {name,conclusion,startedAt,completedAt}'
```
The artifact is the **run-id list with per-job conclusions**, not a prose claim and not YAML. Phase 240 owns the n≥20 bar; Phase 236's SC-3 needs only "passes every repeat" at whatever n the plan commits to — **state n explicitly in the plan**, because an unstated n is count-only acceptance by another name.

**SC-4 — how `p17` is observed RED.** Two invocations, both recorded:
```bash
# RED half — must exit non-zero, with a NAMED message (not a parse-broke message)
GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts \
  node --test --test-reporter=tap scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs; echo "exit=$?"

# GREEN half — must exit 0 against the real config
node --test --test-reporter=tap scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs; echo "exit=$?"
```
plus `gsd_run check prohibition-enforcement`, which re-runs exactly this pair from the plan's `check_violation_fixture` / `check_clean_fixture` frontmatter. **Paste both exit codes and the RED's failure message** into the evidence ledger — asserting the guard was run does not earn the claim.

**SC-5 — how the quarantine is validated (if it is ever built).** `node --test scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs` must stay green after the row lands, and `bash scripts/ci/ci-demotion-observer.test.sh` + `bash scripts/ci/honest-skip-verdict.test.sh` must stay green. Per C-2 this requires the schema amendment; **validate the amendment by adding the row and running all three before claiming SC-5.**

### Sampling Rate
- **Per task commit:** `node --test scripts/ci/prohibitions/*.test.mjs` (fast, < 1s) + `mix format --check-formatted`
- **Per wave merge:** `MIX_ENV=test mix ci` **and** `(cd test/example && MIX_ENV=test mix test --include example_app)` **and** `bash scripts/ci/snapshot-canary-guard.sh --base origin/main`
- **Phase gate:** full CI green on the PR + the SC-3 run-id list at the final committed HEAD on a clean tree (standing constraint 2)

### Wave 0 Gaps
- [ ] `test/sigra/planning/phase_236_audit_url_ownership_test.exs` — SC-2 source contract (form has `phx-submit`, ≥1 `handle_event/3`, filter anchors are `<.link patch>`, `Export CSV` is still `<a href>`), with a non-vacuity floor on the anchor count
- [ ] `scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs` — SC-4 guard
- [ ] `test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts` — committed known-bad, all three violations in one file (D-26)
- [ ] Phase EVIDENCE ledger with `BEFORE-FLAKE-RED` / `AFTER-FIX-GREEN` slots — `_lib.mjs:254` `SLOT_HEADING_RE` requires `## BEFORE-*` / `## AFTER-*` headings with a `Status:` line and run ids as 8-12 digit tokens (`:282`); `p12-run-id-provenance.test.mjs` reads this format generically across `.planning/phases`
- [ ] (conditional, SC-5 only) `.github/ci-skip-manifest.tsv` schema amendment + `p10` `kind=spec` exemption + `MAINTAINING.md` entry

*Framework install: none needed.*

## Security Domain

Low-surface phase. No auth logic, no crypto, no new input handling beyond one param normalizer.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | untouched |
| V3 Session Management | no | untouched |
| V4 Access Control | **yes** | The two-`live_session` scoping (`:admin_global` / `:admin_organization`) is an authorization boundary. A `push_patch` that crossed it would bypass `Sigra.LiveView.AdminScope`'s `on_mount` — verified prevented by `index_path/1` (C-3). The plan MUST assert this, not assume it. Existing coverage: `admin_audit_index_live_test.exs:62` "organization explorer fails closed outside the resolved organization scope". |
| V5 Input Validation | **yes** | The new `handle_event` receives raw user params. It must **whitelist** keys (D-08.3), not pass them through to `append_query`. Unknown keys reaching the URL is the mechanism behind the already-fixed duplicate-`action_prefix` bug (D-31). |
| V6 Cryptography | no | untouched |

### Known Threat Patterns
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Open redirect via `push_patch(to:)` | Tampering | `validate_local_url!` rejects `//` and absolute URLs [VERIFIED: phoenix_live_view.ex:1180-1187] — but the plan must not defeat it by building the path from user input |
| Cross-scope data exposure via patch | Information Disclosure | `live_link_info!`'s `live_session` match + `index_path/1` scope resolution (C-3) |
| Param injection into the audit query | Tampering | Whitelist in `handle_event`; `handle_params/3` stays the sole loader (D-08.4) |

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| URL state via plain GET form + `<a href>` inside a LiveView | `<.link patch>` + `phx-submit` → `push_patch` → `handle_params` | LiveView 0.16+ (`live_patch` → `<.link patch>` in 0.18) | The repo's three admin index views still use the old shape; `branding_live.ex` already uses the new one (C-1) |
| `trace: 'on-first-retry'` as a diagnosis source | Deliberate manufacture (`--repeat-each` / `--trace=on`) | n/a — this repo hardcodes `retries: 0`, so on-first-retry never fires | D-18; STACK.md:81,195-204 must be corrected (D-29) |

**Deprecated/outdated in `.planning/research/STACK.md`:** the claim that traces already exist. Two locations, both false (C-11/D-29).

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The trace will show branch (a) — no `actor=` key at all, confirming D-01 | Reproduction | If it shows (b) or (c), the fix shape changes entirely. **D-05 already mandates the trace gate**, so this assumption costs nothing if wrong — it is exactly why SC-1 precedes the fix. |
| A2 | `.applied_chip` / `.audit_pagination_nav` anchors live in `lib/sigra/admin/components.ex` and are shared with the two excluded views | Pattern 1 ⚠️ | I did not open `components.ex` this session. If the anchors are local to `audit_index_live.ex` after all, the scope narrowing I recommend is unnecessary. **Planner must open `lib/sigra/admin/components.ex` and check before writing tasks.** |
| A3 | `gh` CLI is authenticated in this environment | Environment Availability | SC-3 is blocked without it; confirm at plan time. Not probed this session. |
| A4 | `append_query/2` at `audit_index_live.ex:298` already drops blank values | Pattern 2 | I read `:298-300` only partially (`cleaned = params |> …`). If it does not drop blanks, D-14's same-URL invariant needs an explicit normalizer. **Verify before relying on it.** |
| A5 | Repeated PR pushes produce one CI run each and the `generated_admin_playwright_smoke` job completes in ~3.7m | Pitfall 5 | Duration is from `ci.yml:1395`'s comment (a recorded measurement, not a live probe). If slower, SC-3's wall-clock budget grows. |
| A6 | `gsd_run check prohibition-enforcement` is available to this repo's GSD runtime | SC-4 validation | If not, the manual two-invocation RED/GREEN pair (shown above) is a complete substitute. |

## Open Questions

1. **What n does Phase 236's SC-3 commit to?**
   - Known: Phase 240/GREEN-04 owns n≥20; Phase 236's SC-3 says only "dispatched repeatedly … passes every repeat".
   - Unclear: whether 236 should carry a lighter n (e.g. 5) and defer the n≥20 to 240, or front-load it.
   - Recommendation: **commit to n=5 sequential PR pushes in Phase 236** (≈25 min of CI per the Pitfall 5 budget) and let Phase 240 do the n≥20 on `main`. State n explicitly; an unstated n is count-only acceptance by another name (standing constraint 1).

2. **Should SC-5's quarantine schema be built or only specified?** (C-2)
   - Known: it is a contingency that only fires if root cause fails; it requires a real schema change to a file Phase 241 depends on.
   - Recommendation: **specify in the plan, build only on the contingency branch.** Speculative construction hands Phase 241 a moving target, which is the exact reason the ROADMAP ordered 236 → 241.

3. **Does the new browser assertion for SC-2 earn its keep?**
   - Known: SC-3's repeated green already proves the flake is gone; the ROADMAP does not require a new spec assertion.
   - Recommendation: **prefer adding `waitForLiveViewReady(page)` after each preset click in `admin-generated.spec.ts:443,449`** (mirroring the `admin-audit.spec.ts` control's sequencing, C-5) over inventing a navigation-counting assertion. It is the smaller, more idiomatic change — but it must land **with** the `lib/` fix, never instead of it, or it is a harness-side mask in disguise.

---

## Sources

### Primary (HIGH confidence) — read at HEAD `09ec1353` this session
- `lib/sigra/admin/live/audit_index_live.ex` (309 lines, read in full for the render + path helpers)
- `lib/sigra/admin/live/branding_live.ex:87,118-165,397-473,595`
- `deps/phoenix_live_view/lib/phoenix_component.ex:3055-3130`
- `deps/phoenix_live_view/lib/phoenix_component/declarative.ex:16-26,127-145`
- `deps/phoenix_live_view/lib/phoenix_live_view.ex:1124-1187`
- `deps/phoenix_live_view/lib/phoenix_live_view/route.ex:20-60`
- `deps/phoenix_live_view/lib/phoenix_live_view/channel.ex:138-153,574-612,925-985`
- `deps/phoenix_live_view/lib/phoenix_live_view/utils.ex:599-619`
- `deps/phoenix_live_view/lib/phoenix_live_view/tag_engine.ex:1538-1540`
- `deps/phoenix_live_view/assets/js/phoenix_live_view/live_socket.js:247-257,1158-1250`
- `deps/phoenix_live_view/assets/js/phoenix_live_view/dom.js:105-123`
- `test/example/priv/playwright/tests/admin-generated.spec.ts:415-470`
- `test/example/priv/playwright/tests/admin-audit.spec.ts:76-161`
- `test/example/priv/playwright/tests/demo-showcase.spec.ts:905-945`
- `test/example/priv/playwright/playwright.config.ts` (read in full, 261 lines)
- `.github/workflows/ci.yml:1-100,195-215,385-400,645-715,1390-1475`
- `.github/ci-skip-manifest.tsv` (read in full)
- `scripts/ci/prohibitions/_lib.mjs` (read in full, 315 lines)
- `scripts/ci/prohibitions/p09-timeouts-not-truncating.test.mjs`, `p10-no-undocumented-demotion.test.mjs`, `p16-no-schedule-lane-leniency.test.mjs`
- `scripts/ci/admin-acceptance-smoke.sh:20-76,250-262,335-412`
- `scripts/ci/ci-demotion-observer.sh:39-90`
- `scripts/ci/snapshot-canary-guard.sh:1-60`
- `priv/templates/sigra.install/admin/router_injection.ex:20-75`
- `test/example/test/example_web/live/admin_audit_index_live_test.exs`
- `mix.exs:12,55,149-169`; `mix.lock:49`
- `.planning/ROADMAP.md` (v1.48 block), `.planning/REQUIREMENTS.md`, `.planning/research/STACK.md:78-86,193-206`
- `.planning/todos/pending/2026-07-30-admin-generated-audit-presets-actor-filter-race.md` (read in full)

### Secondary (MEDIUM confidence)
- `.planning/milestones/v1.47-phases/230-*/230-07-PLAN.md` — the prohibition frontmatter contract

### Tertiary (LOW confidence)
- None. No WebSearch was used; every claim was verified against files in this repo or its `deps/`.

## Metadata

**Confidence breakdown:**
- Stack: HIGH — no new packages; every version read from `mix.lock` / `playwright.config.ts`
- Architecture / fix shape: HIGH — every framework mechanic verified in `deps/` source, with an in-repo precedent found (C-1)
- Corrections C-1..C-10: HIGH — each carries a file:line and a verbatim quote
- Reproduction feasibility: MEDIUM-HIGH — commands derived from verified script internals but **not executed** this session (no DB/archive probe run)
- SC-3 dispatch analysis: HIGH — both gates read verbatim from `ci.yml`
- A1 (which D-05 branch the trace will show): LOW by design — SC-1 exists to settle it

**Research date:** 2026-09-15
**Valid until:** 2026-10-15 (stable; re-verify line numbers if `audit_index_live.ex`, `ci.yml`, or `playwright.config.ts` change — Phases 237/238 run in parallel and 237 touches `lib/` docs, though it is contracted to skip `audit_index_live.ex`)
