# Phase 236 Differential Diagnosis: `Generated admin Playwright smoke` flake

**Named cause: product race.**

This is a genuine race condition in `lib/sigra/admin/live/audit_index_live.ex`'s interaction
with LiveView's own JavaScript client — not a test-harness timing artifact and not a database
row-visibility collision. The other two candidates are ruled out below with cited observations,
in the order of weight the plan specifies.

## 1. The captured received URL string (the decider, D-05)

Both the real, unprompted CI failure (run `35004420339`, job `104500542292`, `push` to `main`,
2026-09-15T18:01:41Z) and the local reproduction under genuine CPU contention (`test-results/
phase236-repro-contended`, attempt 3 of 50, trace at
`.gsd/scratch/phase236-evidence/trace.zip`) produced the **identical** received URL:

```text
http://localhost:4017/admin/audit?action_prefix=admin.impersonation&order_by=inserted_at&order_direction=desc&outcome=failure
```

against the expected pattern `/(?:\?|&)actor=00000000-0000-0000-0000-000000000001(?:&|$)/`. The
`actor=` key is **completely absent** — not present with an empty value. Two independent
captures (one from the real CI topology, one from a from-scratch local generated host) agreeing
on the exact same URL shape is strong corroboration that this is a structural, reproducible race
rather than a one-off harness hiccup or a flaky assertion on incidental data.

## 2. Mechanism: LiveView's `unload()` one-way latch (`live_socket.js`)

`Sigra.Admin.Live.AuditIndexLive`'s filter form (`audit_index_live.ex:76`) is a plain
`<form method="get">` with **no `phx-submit` and no `phx-change`** binding. LiveView's client
still installs a single delegated `submit` listener for every form on the page
(`deps/phoenix_live_view/assets/js/phoenix_live_view/live_socket.js:1181-1198`, blank line 1181
immediately preceding the listener registration at 1182):

```js
this.on("submit", (e) => {
  const phxEvent = e.target.getAttribute(this.binding("submit"));
  if (!phxEvent) {
    if (DOM.isUnloadableFormSubmit(e)) {
      this.unload();
    }
    return;
  }
  ...
});
```

For a form with no `phx-submit` attribute, `phxEvent` is `null`, so the branch falls into
`DOM.isUnloadableFormSubmit(e)` (`deps/phoenix_live_view/assets/js/phoenix_live_view/dom.js:105-116`),
which returns `true` whenever the submit was not already prevented and is not a `<dialog>` close
or a new-tab modifier-click — exactly our case (a plain Enter-triggered GET submit). That calls
`this.unload()`.

`unload()` (`live_socket.js:247-260`) is a **one-way latch**:

```js
unload() {
  if (this.unloaded) {
    return;
  }
  ...
  this.unloaded = true;
  this.destroyAllViews();
  this.disconnect();
}
```

`destroyAllViews()` (`live_socket.js:572-578`) synchronously calls `.destroy()` on every mounted
LiveView root, tearing down hooks and the socket connection state in anticipation of the native
browser navigation that pressing Enter is about to trigger. Crucially, `unload()` does **not**
call `e.preventDefault()` on this branch, so the browser's own default GET-submission is still
scheduled to run once every `submit` listener returns — but the LiveView JS state (and, in a
freshly-rejoined page, potentially the DOM subtree hosting the form itself) is torn down in the
*same* synchronous tick, immediately before that default action fires.

Under normal, unloaded local conditions this teardown/native-submit ordering resolves cleanly
(60-80 local repeats at normal and CDP-throttled network/CPU conditions all passed — see
`236-EVIDENCE.md`'s "Discarded attempts" section). Under genuine host CPU contention — which is
what a shared CI runner or a locally CPU-saturated machine reproduces, and is exactly what turned
0/80 failures into 41/50 failures in this phase's local reproduction — the browser's own
scheduling of the pending default navigation loses the race against the DOM teardown from
`destroyAllViews()`, and the native GET submission is silently dropped: no new document loads, no
new query string, and the page is left exactly where the prior (`Impersonation` preset)
navigation put it. That is precisely the observed symptom: the URL is frozen at
`...&action_prefix=admin.impersonation&...&outcome=failure` with no `actor=` key at all, because
no navigation for the Enter-press ever happened.

## 3. Harness race ruled out

A pure test-harness race (Playwright's own action/navigation sequencing, independent of the
application) would be expected to reproduce at similar rates regardless of the *server or
browser process's* CPU scheduling, since it would be a property of Playwright's internal
wait/auto-retry logic rather than of `unload()`/`destroyAllViews()`
(`live_socket.js:247-260`, cited above). That is not what was observed: 60-80 repeats at normal
load and under CDP-level network/CPU throttling (`context.newCDPSession` +
`Emulation.setCPUThrottlingRate`, up to 12x, plus up to 400ms simulated network latency — CDP
throttling degrades the *browser tab's* apparent performance, not the host OS scheduler) produced
**zero** failures, while introducing genuine host-OS CPU contention (17 concurrent `yes >
/dev/null` processes contending for the same physical cores the server and browser process run
on) produced 41/50 failures with the identical received-URL signature (`236-EVIDENCE.md`,
"Corroborating evidence" and "Discarded attempts" sections). This dependency on the *host's*
scheduling of two OS-level processes (the `mix phx.server` BEAM VM and the headless Chromium
browser process) — not on Playwright's own internal action timing — is inconsistent with a pure
harness artifact and consistent with the `unload()`/native-submit race described in Section 2,
which is a real race between two separate OS processes' execution order, not a property of the
Playwright driver itself. The identical received-URL signature independently observed on the
real GitHub Actions runner (run `35004420339`, a shared, commonly CPU-contended CI host) is
further, independent corroboration that this is a genuine scheduling-sensitive product race
rather than a Playwright-harness-specific artifact.

## 4. DB collision ruled out

The failing assertion (`:459`, `toHaveURL`) is URL-only; it asserts nothing about rendered audit
rows. The preceding chip assertion (`:451`, `Action: admin.impersonation`) renders from the
**current URL params**, not from any row lookup
(`audit_index_live.ex:handle_params/3` builds `current_params` from the request, and the chip
components read from that same assign) — so no seeded or concurrent audit-event row can make this
assertion pass or fail. There is no shared-fixture contention here: the failure is 100%
attributable to client/browser-side navigation timing, never to what rows exist in the database
at assertion time.

## 5. Value-wipe (connect-patch) ruled out by the received URL itself

A morphdom connect-patch that wiped the typed `actor` value would still leave the **key** present
in a native GET submission — the browser serializes every named `<input>` in the form regardless
of its value, so a wiped-but-submitted form would produce `...&actor=&...`, not a total absence
of the key. Both captures show `actor=` is **not present at all**, which rules out "value wiped,
then submitted" and is consistent only with "the submission never reached the browser's native
default action" — i.e. the `unload()` race above, not a value-ownership bug.

## Two honesty constraints (per plan; verified against current source)

- **`admin-audit.spec.ts` is not a working "identical" control for this form.** It drives a
  *different* LiveView entirely — `audit_user_live.ex`, the per-user/organization-scoped audit
  view that Phase 236 explicitly excludes (D-30) — and it interacts with its filter form by
  filling a textbox, clicking an `Apply filters` **button** by role, and then calling
  `waitForLiveViewReady(page)` immediately after
  (`test/example/priv/playwright/tests/admin-audit.spec.ts:141-143`). It never presses Enter and
  never omits the readiness wait. No spec anywhere in this repository drives
  `audit_index_live.ex`'s filter form except the failing test itself — verified: grepping the
  Playwright suite for filter interactions against `/admin/audit` (the global, non-organization
  route) finds only `admin-generated.spec.ts:428-461`. That is the honest finding, not "a working
  control exists and this one deviates from it."
- **`<.link patch>` / `push_patch` do not both have no matches in `lib/sigra/admin/`.** Verified:
  `grep -rn 'push_patch' lib/` returns **zero** matches — that narrow claim is true. But
  `lib/sigra/admin/live/branding_live.ex:128,136,144` ships three `<.link ... patch={panel_path(...)}>`
  tabs (client-side patch navigation is already used there). The accurate, narrow statement is:
  server-side `push_patch/2` has zero hits in `lib/`; `<.link patch>` itself does not.

## D-05 branch call

**Branch (a):** `actor=` is absent from the URL entirely — no navigation occurred for the
Enter-press at all. This is settled by the received-URL string quoted in Section 1
(`http://localhost:4017/admin/audit?action_prefix=admin.impersonation&order_by=inserted_at&order_direction=desc&outcome=failure`,
observed identically in both the CI run and the local reproduction), which shows total absence of
the `actor=` key rather than a present-but-empty value. This confirms D-01 and authorizes plan
236-02 to proceed exactly as written: convert the preset/chip/sort/pagination/Clear anchors to
`<.link patch>`, add `phx-submit="apply_filters"` to the filter form, and add one new
`handle_event/3` clause that normalizes params and calls `push_patch/2` — eliminating the full
document navigation (and therefore the `unload()` race) from the filter interaction entirely.
