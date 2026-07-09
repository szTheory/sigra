---
phase: 218-elevation-wave-nit-cleanup
reviewed: 2026-07-09T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - guides/reference/admin-award-ledger.json
  - guides/reference/admin-render-sha.json
  - scripts/ci/fix-queue-build.mjs
  - scripts/uat/up.sh
  - test/example/lib/example_web/live/mfa_settings_live.ex
  - test/example/lib/example_web/live/organization_members_live.ex
  - test/example/priv/playwright/lib/eval/probes.ts
  - test/example/priv/playwright/tests/admin-eval.spec.ts
  - test/example/priv/static/assets/css/app.css
findings:
  critical: 1
  warning: 7
  info: 2
  total: 10
status: issues_found
---

# Phase 218: Code Review Report

**Reviewed:** 2026-07-09
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Reviewed the phase-218 harness-hardening changes (`fix-queue-build.mjs`, `probes.ts`,
`admin-eval.spec.ts`), the `up.sh` UAT-DX nits, the two rebranded demo LiveViews
(`mfa_settings_live.ex`, `organization_members_live.ex`), and the `app.css` vt-* restyle.

The most serious finding is a **determinism hole in `fix-queue-build.mjs`**: the builder
whose stated contract is a *committed artifact that must diff cleanly vs merge-base* selects
its systemic-parent representative from an unsorted `readdirSync` walk, so the committed
`fix-queue.json` content/ordering can vary between filesystems (dev macOS/APFS vs CI Linux/ext4).
That can produce spurious CI diffs / gate flakes.

Beyond that, two demo LiveViews carry non-exhaustive `case`/pattern-match crash paths
reachable from DB errors or crafted LiveView events, a member-lookup helper silently caps at
1000 rows, `up.sh`'s stale-stack reaper filters on only one of the two labels its own comment
claims to cover, and the MFA success icon references an undefined CSS custom property.

No hardcoded secrets, injection, or auth-bypass issues were found. Role/email inputs in the
org LiveView are correctly funneled through `safe_role_atom`/`safe_invite_role` allowlists and
scoped library calls.

Note: `@user_organizations` in `organization_members_live.ex` render is supplied by the
router `on_mount {ExampleWeb.UserAuth, :assign_user_organizations}` hook — verified, not a bug.
`var(--sg-color-brand)` refs in `app.css` resolve via the installer-shipped `sigra_admin.css`
(`--sg-color-brand: #c2410c`) — verified, not a bug.

## Critical Issues

### CR-01: fix-queue.json systemic-parent representative is filesystem-order dependent (non-deterministic committed artifact)

**File:** `scripts/ci/fix-queue-build.mjs:121-150, 254-295` (esp. `const rep = entries[0]` at :263)
**Issue:** The module header promises a *deterministic* builder whose output "must diff cleanly
vs merge-base." But `walkFindings` iterates `readdirSync(evalDir)` / `readdirSync(shaDir)` /
`readdirSync(surfDir)` with **no sort** (lines 125, 128, 131). Node's `readdirSync` does not
guarantee sorted order — it is filesystem-dependent. This ingestion order flows into
`builtMap` → `openEntries` → `fixQueueEntries` → the per-`systemic_group` `entries` arrays.
For any systemic group with ≥2 surfaces, the collapse picks `entries[0]` as the representative
(line 263) and emits `rep.finding_id`/`rep.surface`/`rep.lens`/`rep.severity`. Because
`entries[0]` depends on walk order, a systemic parent's `finding_id` (and therefore its content
and its position in the final `finding_id`-keyed sort) can differ between a dev machine (APFS)
and CI (ext4), yielding a different committed `fix-queue.json`. That breaks the "diffs cleanly"
gate non-deterministically. (`open_findings` recomputation is Set-size based and is safe; only
the systemic-parent selection is affected.)
**Fix:** Make the representative selection order-independent — sort the group deterministically
before picking, e.g.:
```js
// inside the allSurfaces.size >= 2 branch, before choosing rep:
const rep = entries
  .slice()
  .sort((a, b) => a.finding_id.localeCompare(b.finding_id))[0];
```
Alternatively (belt and suspenders) sort each `readdirSync(...)` result in `walkFindings`:
```js
for (const sha of readdirSync(evalDir).sort()) { ... }
```

## Warnings

### WR-01: `do_confirm_enrollment/2` non-exhaustive case crashes on `{:error, changeset}` / other error tuples

**File:** `test/example/lib/example_web/live/mfa_settings_live.ex:955-979`
**Issue:** The `case Auth.mfa_confirm_enrollment(...)` handles only `{:ok, %{backup_codes: codes}}`
and `{:error, :invalid_code}`. Although the `Sigra.MFA.confirm_enrollment` `@spec` advertises just
those two, the implementation (`lib/sigra/mfa.ex:277-300`) also returns `{:error, changeset}` and
`{:error, _reason}` on transaction/insert failures (e.g. backup-code or credential write failure).
Any such return raises `CaseClauseError` and crashes the LiveView process. Because this handler is
auto-invoked on every 6-digit keystroke (`validate_enroll` → `do_confirm_enrollment`), a transient
DB error during enrollment takes down the page instead of showing a retry message.
**Fix:** Add a fallthrough clause:
```elixir
{:error, _reason} ->
  {:noreply,
   socket
   |> put_flash(:error, "Could not verify your code. Please try again.")
   |> assign(enroll_form: to_form(%{"code" => ""}, as: "enroll"))}
```

### WR-02: `change_role` / `remove_member` MatchError on out-of-order or crafted LiveView events

**File:** `test/example/lib/example_web/live/organization_members_live.ex:134, 301`
**Issue:** Both handlers hard-destructure `{:role, member} = socket.assigns.pending_action`
(line 134) and `{:remove, member} = socket.assigns.pending_action` (line 301). `pending_action`
defaults to `nil` (line 57) and is reset to `nil` after each action. The confirm forms only render
inside their modals when `match?({:role, _}, ...)` / `match?({:remove, _}, ...)`, but LiveView
events are websocket messages a client can send directly (or race after a `cancel_action`). A
`change_role`/`remove_member` event while `pending_action` is `nil` raises `MatchError` and crashes
the LiveView. Not a security breach (mutations remain scope-checked in the library), but a
client-triggerable crash.
**Fix:** Guard the pattern, e.g.:
```elixir
def handle_event("change_role", %{"role" => role_str}, %{assigns: %{pending_action: {:role, member}}} = socket) do
  ...
end
def handle_event("change_role", _params, socket), do: {:noreply, socket}
```
Apply the same for `remove_member`.

### WR-03: `find_streamed_member/2` silently caps member lookup at 1000 rows

**File:** `test/example/lib/example_web/live/organization_members_live.ex:625-636`
**Issue:** `open_role_modal`/`open_remove_modal` resolve the clicked row via `find_streamed_member`,
which refetches `list_members_with_activity(scope, limit: 1_000, offset: 0)` and `Enum.find`s the id.
The list is paginated at 100 with "Load more", so an org with >1000 members can stream rows beyond
index 1000 into the table, but those rows will never be found here — `find_streamed_member` returns
`nil`, `open_*_modal` returns the socket unchanged, and clicking "Change role"/"Remove" silently does
nothing for those members.
**Fix:** Fetch the single row by id (scoped) instead of scanning a capped list, e.g. a
`Organizations.get_member(scope, id)` that filters by `organization_id` + membership id, or at minimum
raise/flash when the lookup misses so the failure is not silent.

### WR-04: MFA "enabled" success icon references an undefined CSS custom property

**File:** `test/example/lib/example_web/live/mfa_settings_live.ex:250`
**Issue:** `<.icon name="hero-check-circle" ... style="color:var(--vt-color-ok)" />` uses
`--vt-color-ok`, which is not defined anywhere in `app.css` (the vt token set defines
`--vt-color-caution`, `--vt-color-danger`, `--vt-color-primary`, etc., but no `--vt-color-ok`).
The declaration is invalid and drops to inherited `currentColor`, so the success checkmark does not
render in the intended positive/green tone. The positive status pill (`.vt-status-pill--ok`,
app.css:1082) uses `--vt-color-primary` for exactly this purpose.
**Fix:** Use the existing token: `style="color:var(--vt-color-primary)"` (or add a
`--vt-color-ok` token to `:root` in `app.css` and its dark-scheme block).

### WR-05: `up.sh` stale-stack reaper filters only the legacy label, contradicting its own comment

**File:** `scripts/uat/up.sh:638-643`
**Issue:** The comment states the reaper lists "projects that carry a sigra UAT label (either the
vendor-neutral `dev.local.proxy-host` or the legacy `dev.sigra.proxy-host`)", but the `docker ps -a`
call filters only `--filter 'label=dev.sigra.proxy-host'`. A leaked stack labeled *only* with the
vendor-neutral `dev.local.proxy-host` (the etiquette the rest of the script is migrating toward, see
`proxy_host_claimants`) will never be reaped, so it leaks until manual `down.sh`.
**Fix:** Query both labels and dedupe (mirroring `proxy_host_claimants`), or drop the "vendor-neutral"
claim from the comment. Preferred:
```bash
stale_projects="$( {
  docker ps -a --filter 'label=com.docker.compose.project' --filter 'label=dev.sigra.proxy-host'  --format '{{.Label "com.docker.compose.project"}}'
  docker ps -a --filter 'label=com.docker.compose.project' --filter 'label=dev.local.proxy-host' --format '{{.Label "com.docker.compose.project"}}'
} | sort -u )"
```

### WR-06: `adminEvalEmail` can collide across parallel Playwright workers (flaky duplicate-email registrations)

**File:** `test/example/priv/playwright/tests/admin-eval.spec.ts:169-180`
**Issue:** The generated admin email is
`platform-admin+ev-<ms base36>-<project 8ch>-<sequence base36>-<retry>@example.test`. `registrationSequence`
is module-level state that resets to `1` in every worker process, and `project` is identical for all
tests in a project. Two workers running tests of the same project can produce identical
`timestamp + project + sequence + retry` (same millisecond, both at sequence `1`, retry `0`), yielding
a duplicate email. The second `registerUser` then fails the "Account created successfully!" assertion —
a non-deterministic flake under parallelism.
**Fix:** Add worker-unique entropy, e.g. include `process.env.TEST_WORKER_INDEX` (or
`testInfo.workerIndex`) and/or a random suffix in the local part.

### WR-07: `.vt-modal__backdrop` is `display:none`, so the backdrop-click close form is dead

**File:** `test/example/priv/static/assets/css/app.css:2841-2843` (used in
`organization_members_live.ex:506, 536, 567, 595`)
**Issue:** Each `<dialog class="vt-modal">` includes
`<form method="dialog" class="vt-modal__backdrop"><button>close</button></form>`, and the CSS comment
says it "covers the backdrop area." But `.vt-modal__backdrop { display: none; }` removes it from layout
entirely, so it covers nothing and can never be clicked — the intended click-outside-to-close affordance
does not exist (native `<dialog>::backdrop` clicks also do not close by default). Closing relies solely on
the Cancel buttons / Escape. Either the comment or the implementation is wrong.
**Fix:** If click-outside close is intended, implement it (e.g. handle a backdrop click in the
`DialogModal` hook, or absolutely-position a real overlay element) and drop the dead form; if not intended,
remove the vestigial `<form class="vt-modal__backdrop">` and correct the comment.

## Info

### IN-01: Probe #5 control-height check reads `min-height` first, making the `height` fallback effectively dead

**File:** `test/example/priv/playwright/lib/eval/probes.ts:493`
**Issue:** `const h = parseFloat(cs.minHeight || cs.height);` — under `getComputedStyle`, `min-height`
resolves to `"0px"` for controls without an explicit `min-height` (initial value 0), which is a truthy
string, so `cs.height` is never consulted. Controls sized purely via `height` (no `min-height`) would be
skipped by the off-scale-control gate. The sg design-system controls set `min-height`, so this rarely
bites in practice, but the fallback is misleading.
**Fix:** Prefer an explicit numeric guard, e.g. compute both and use `min-height` only when `> 0`:
```js
const mh = parseFloat(cs.minHeight);
const h = mh > 0 ? mh : parseFloat(cs.height);
```

### IN-02: Probe #2 doc comment describes "1-6px" misalignment but the code flags any fractional offset

**File:** `test/example/priv/playwright/lib/eval/probes.ts:196-198` vs logic at `:222-227`
**Issue:** The docstring says the probe flags "1-6px sub-pixel misalignment," but the implementation
computes `rect.left % 1` / `rect.top % 1` and flags any fractional component in `(0.05, 0.95)` —
i.e. sub-pixel fractional offset regardless of the integer magnitude. The comment overstates a bounded
range that the code does not enforce.
**Fix:** Align the comment with the actual fractional-offset heuristic (or implement the documented
1-6px window if that was the intent).

---

_Reviewed: 2026-07-09_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
