---
phase: 32-generated-installer-admin-surface-parity
reviewed: 2026-04-17T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - priv/templates/sigra.install/admin/impersonation_controller.ex
  - lib/sigra/install/features/admin.ex
  - priv/templates/sigra.install/admin/router_injection.ex
  - test/sigra/install/features/admin_test.exs
  - scripts/ci/admin-acceptance-smoke.sh
findings:
  critical: 0
  warning: 4
  info: 6
  total: 10
status: issues_found
---

# Phase 32: Code Review Report

**Reviewed:** 2026-04-17
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Phase 32 Plan 01 and Plan 02 close INT-01/02/03 by emitting the impersonation
controller and registering the audit export controller from the installer, and
by mounting UsersIndexLive/UserShowLive in both live_session blocks, gated
behind smoke-script runtime probes.

**Security-critical invariants are intact.** The enumeration-prevention
mapping (`{:error, :not_allowed} -> auth_error(:not_found, [])`), the
sudo-fresh gate (300s window), and the `safe_return_to/1` open-redirect
guard (leading `/` with no `//`) are all preserved verbatim from the
proven example controller, and the generator tests grep for each
invariant so regressions fail loudly.

No critical issues. The four warnings cluster around three themes:

1. **A pre-existing enumeration-prevention leak** in the `sudo_fresh?` branch
   that exposes a distinguishable "stale sudo" response on a route that
   is supposed to be un-enumerable by non-admins (inherited from the
   example controller; this phase faithfully copies it, so flagging for
   awareness rather than as a Phase 32 defect).
2. **A stored-XSS vector on flash copy** via the generated error branch's
   `put_flash(:error, ...)` with copy that is safe today but has no
   mechanical guard against future mutation.
3. **Smoke-script robustness**: `set -e` + background process + sticky
   failure flag interaction means the script can exit on the first
   probe failure instead of collecting all failures, and `cleanup`
   only `kill`s (not `kill -9`-on-stuck + no `wait`).
4. **EEx template binding fragility** in `admin.ex injections/1`: a
   future `otp_app` that contains characters legal in Elixir atoms but
   illegal in filesystem paths (e.g. unusual underscore handling on
   Windows) is not validated.

Info items are mostly style / documentation / minor test-robustness
suggestions.

## Warnings

### WR-01: `sudo_fresh?` false branch is enumerable

**File:** `priv/templates/sigra.install/admin/impersonation_controller.ex:63-67`
**Issue:** When sudo is stale, the controller redirects to the sudo page
with a flash message *before* calling `Sigra.Impersonation.start/5` —
which is where `authorize_impersonation_target!/2` and the
`:not_allowed → :not_found` enumeration-prevention map live. A
non-admin who reaches this controller (e.g. a newly demoted user with
a still-valid admin session cookie and stale sudo_at) gets the
`"Please re-enter your password to continue."` flash plus a
302 to `/users/sudo?return_to=...`, which is distinguishable from the
404 that an unknown `user_id` on a fresh-sudo admin would receive.

Note: the `:admin_global` pipeline's `RequireAdminAccess` already
blocks non-admins before the controller runs, so in the nominal path
this is defense-in-depth rather than a primary leak. But an admin
whose scope was revoked between request and controller dispatch
(unlikely but possible with caching), or any future code path that
relaxes the pipeline, would start leaking enumeration signal.

This is inherited verbatim from the example controller, and the
Phase 32 plan explicitly said "copy the example verbatim modulo 5-rule
EEx table." Flagging because the plan's threat model treats
enumeration-prevention as load-bearing, and the sudo-fresh branch is
the only code path in this controller that runs *before* the
library's authorizer.

**Fix:** Check sudo-freshness *after* the library's authorization
result, or make the stale-sudo branch issue the same
`auth_error(:not_found, [])` that the `:not_allowed` branch uses (at
the cost of UX: a legitimately-admin user with stale sudo would get
a 404 instead of a redirect to the sudo prompt). The pragmatic
compromise is to gate the sudo-fresh check with the authorization
check first, then only redirect to sudo if authorization would have
succeeded:

```elixir
def create(conn, %{"id" => user_id} = params) do
  admin_scope = conn.assigns.admin_scope
  admin_session = conn.private[:sigra_session]
  admin_token = get_session(conn, :user_token)
  target_user = impersonation_target(user_id)

  # Authorize first so :not_allowed -> 404 beats the sudo prompt.
  case Sigra.Impersonation.authorize(impersonation_config(), admin_scope, target_user) do
    :ok ->
      if sudo_fresh?(admin_session), do: start_impersonation(conn, ...),
                                     else: redirect_to_sudo(conn, params)
    {:error, :not_allowed} ->
      conn |> AuthErrorHandler.auth_error(:not_found, []) |> halt()
  end
end
```

This requires a new `Sigra.Impersonation.authorize/3` public function
or a refactor of `start/5` to separate authorization from session
creation. Scoping to a follow-up phase is acceptable given (a) the
pipeline guards are the primary defense, (b) the example controller
carries the same shape, and (c) the plan explicitly preserves the
example shape verbatim. Recommend filing an issue referencing
T-IMPR-ESCALATION so this doesn't get lost.

### WR-02: `put_flash(:error, reason_string)` branches with no escape-safety contract

**File:** `priv/templates/sigra.install/admin/impersonation_controller.ex:55, 60, 95`
**Issue:** Three branches use `put_flash(:error, ...)` with hardcoded
copy that is safe today. None of these interpolate user input, so
there is no current XSS risk. But there is no mechanical guard — a
future maintainer adding a helpful `"Target #{target_user.email} is
not impersonable."` message would introduce stored-XSS via the
`flash_group` renderer (which interpolates flash values into the HTML
via `~H`'s auto-escaping — safe if the Phoenix default renderer is
used, unsafe if a host overrides it with `raw/1`).

**Fix:** Either add a comment above each `put_flash(:error, ...)`
branch documenting "never interpolate user-controlled data into flash
copy — the generated `flash_group` escapes via HEEx but hosts can
override," or extract the flash strings into module attributes so
review of the sensitive surface is colocated:

```elixir
@impersonation_blocked_flash "End the current impersonation session before starting another one."
@impersonation_start_failed_flash "We couldn't start impersonation."
@impersonation_not_active_flash "No impersonation session is active."
@stale_sudo_flash "Please re-enter your password to continue."
```

This is Info-borderline; raising to Warning because the file is a
generator template (every host copy inherits the pattern) and future
maintainers will copy-modify the nearby branches without reading the
full threat model.

### WR-03: `scripts/ci/admin-acceptance-smoke.sh` `set -e` swallows the first probe failure and exits before GEN_PARITY_FAIL summary

**File:** `scripts/ci/admin-acceptance-smoke.sh:13,244,312-317`
**Issue:** The script declares `set -euo pipefail` at line 13, then
uses a sticky failure flag `GEN_PARITY_FAIL=0` at line 244 with the
intent of "run all probes, then fail at the end with a summary" (per
the block at 312-317). This works only because every probe uses
`$(curl ...)` in a subshell with the status captured, and the final
`if` branch at 312 never exits non-zero before all probes run.

However, the `mix compile --warnings-as-errors` call at line 146,
`mix ecto.create` at 150, `mix ecto.migrate` at 151, and `mix run
"${SEED_FILE}"` at 206 all fail-hard under `set -e`. A seed-script
crash (e.g. a pre-existing user with the seed email) aborts the
script *before* any probes run, leaving a half-booted Phoenix server
process orphaned (the `trap cleanup EXIT` fires, but `cleanup` only
runs `kill "${SERVER_PID}" 2>/dev/null || true` without `wait`, so
port :4017 can remain bound briefly, causing the next local run to
fail). Additionally, `mix ecto.drop || true` at line 149 was correct,
but `mix ecto.create` is not similarly guarded — if the postgres
container is slow to start, this throws `eaddrinuse`-class errors.

**Fix:** Tighten the cleanup trap and add a readiness check for
postgres before `mix ecto.create`:

```bash
cleanup() {
  if [[ -n "${SERVER_PID:-}" ]]; then
    kill "${SERVER_PID}" 2>/dev/null || true
    # Wait briefly for graceful shutdown, then force-kill
    for _ in 1 2 3 4 5; do
      kill -0 "${SERVER_PID}" 2>/dev/null || break
      sleep 0.5
    done
    kill -9 "${SERVER_PID}" 2>/dev/null || true
    wait "${SERVER_PID}" 2>/dev/null || true
  fi
}
```

For postgres readiness, the existing app-boot probe at 217-230 is a
reasonable proxy (it runs after ecto.migrate), so the seed/migrate
gap is small. If a pg_isready precheck is infeasible (adds a
dependency), skip — this is a minor CI robustness improvement.

### WR-04: `otp_app` binding is accepted as-is without validating filesystem safety

**File:** `lib/sigra/install/features/admin.ex:27,43`
**Issue:** Both `files/1` and `injections/1` do
`Keyword.fetch!(binding, :otp_app) |> to_string()` and interpolate
that directly into `Path.join/1` calls and string templates (e.g.
`"#{otp_app}_web"`). For any well-formed Phoenix app name this is
fine — `mix phx.new` enforces snake_case, alphanumerics, and an
initial letter. But `mix sigra.install` templates are user-reachable:
a host with an unusual `:otp_app` in `mix.exs` (say,
`:"weird-name"` — technically a valid atom) would produce paths like
`lib/weird-name/sigra_admin_policy.ex` and module names that won't
compile (module/filename drift). No guard exists in `admin.ex`
itself; if upstream validation exists elsewhere (`Mix.Tasks.Sigra.Install`),
the coupling is implicit.

**Fix:** Add a defensive assertion at the top of `files/1` (and any
other sibling feature), or document that callers are responsible:

```elixir
otp_app = Keyword.fetch!(binding, :otp_app) |> to_string()

unless otp_app =~ ~r/\A[a-z][a-z0-9_]*\z/ do
  raise ArgumentError,
        "otp_app #{inspect(otp_app)} is not a valid snake_case atom name; " <>
        "sigra.install templates assume standard Phoenix project naming."
end
```

This is cheap defense-in-depth. Sibling features
(`lib/sigra/install/features/core.ex`, `passkeys.ex`) have the same
exposure, so the fix belongs in a shared helper
(`Sigra.Install.Binding.validate!/1`) rather than per-feature.
Defer to a lint-tightening phase if batching makes sense.

## Info

### IN-01: `@sudo_window 300` is a magic number

**File:** `priv/templates/sigra.install/admin/impersonation_controller.ex:22`
**Issue:** The 300-second sudo window is hardcoded as a module
attribute with no reference to the library's canonical value.
`Sigra.Session.sudo_at` semantics are owned by the library; if the
library's default window ever changes (e.g. OWASP guidance shifts to
10 minutes), the generated controller silently drifts.

**Fix:** Source the value from `Accounts.sigra_config()` (same path
the controller already uses for `scope_module`) or expose
`Sigra.Session.sudo_window_seconds/0` and reference it:

```elixir
defp sudo_fresh?(%Sigra.Session{sudo_at: %DateTime{} = sudo_at}) do
  window = Accounts.sigra_config().sudo_window_seconds || 300
  DateTime.diff(DateTime.utc_now(), sudo_at, :second) <= window
end
```

Scope: out-of-phase if the library doesn't yet expose the value as
config; info-level note to track.

### IN-02: `client_ip/1` returns a charlist-formatted string for IPv6, no proxy header handling

**File:** `priv/templates/sigra.install/admin/impersonation_controller.ex:126-128`
**Issue:** `to_string(:inet.ntoa(conn.remote_ip))` works for both
IPv4 (`"127.0.0.1"`) and IPv6 (`"::1"`), but `conn.remote_ip` is the
Plug-layer socket peer, not the forwarded-for header. Behind a
reverse proxy (Cloudflare, AWS ALB), every impersonation audit row
gets the proxy's IP, not the admin's real IP, weakening the audit
trail. Most Phoenix apps run `RemoteIp` or `Plug.RemoteIp` in the
endpoint to rewrite `remote_ip`, but this controller does not
validate that the host app has done so.

**Fix:** Document in the moduledoc that audit IP accuracy depends on
the host configuring a `RemoteIp`-style plug in the endpoint, or
read a standard forwarded header as a fallback. Do not silently
prefer `X-Forwarded-For` — that's spoofable without endpoint-level
allowlisting. Info-level because the audit record at the library
tier is authoritative for security review and the IP is supplementary.

### IN-03: Test uses `async: true` but reads templates from disk

**File:** `test/sigra/install/features/admin_test.exs:2,137,184,189-193`
**Issue:** `use ExUnit.Case, async: true` is declared, but the tests
do `File.read!` on template files in the repo. In practice this is
safe (tests are read-only with respect to the template files) and
the coverage_test.exs pattern is the same. Flagging for awareness:
if any future test adds `File.write!` or mutates template fixtures
in-place, `async: true` will produce nondeterministic cross-test
pollution.

**Fix:** Add an `@moduletag :template_read_only` or a comment
documenting the read-only contract. No action required.

### IN-04: `render_impersonation_controller_template/0` and `render_router_template/0` are duplicated render helpers

**File:** `test/sigra/install/features/admin_test.exs:134-138,180-184`
**Issue:** Two near-identical private helpers (`File.read!` +
`EEx.eval_string` with a `@binding` attribute). Not a bug — the
bindings differ slightly. Future Phase 33+ admin templates will
likely repeat this pattern.

**Fix:** Optional — extract to a shared helper in `test/support/`:

```elixir
defmodule Sigra.Test.TemplateRender do
  def render_admin_template(relative_path, binding) do
    Path.join("priv/templates/sigra.install", relative_path)
    |> File.read!()
    |> EEx.eval_string(binding)
  end
end
```

Defer until the third template-render helper appears.

### IN-05: Smoke script `rm -rf "${TMP_APP_DIR}"` uses a default that escapes via env var

**File:** `scripts/ci/admin-acceptance-smoke.sh:17,74`
**Issue:** `TMP_APP_DIR="${TMP_APP_DIR:-/tmp/sigra_admin_smoke}"` then
`rm -rf "${TMP_APP_DIR}"`. If a caller sets
`TMP_APP_DIR=/` or `TMP_APP_DIR=""` (empty-string via `export
TMP_APP_DIR=`), the shell expands the former to `rm -rf /` or the
latter to `rm -rf ""` (which is a no-op — bash `rm -rf ""` errors
with "cannot remove '': No such file or directory" in GNU coreutils,
and macOS similarly).

Under `set -u`, an unset `TMP_APP_DIR` is caught by the `:-` default.
But a caller who does `export TMP_APP_DIR=/tmp` (without the
`sigra_admin_smoke` suffix) would remove `/tmp` — unlikely but
possible.

**Fix:** Guard the value:

```bash
case "${TMP_APP_DIR}" in
  /tmp/*|/var/tmp/*|"${HOME}"/tmp/*)
    : # allowed
    ;;
  *)
    echo "TMP_APP_DIR (${TMP_APP_DIR}) must be under /tmp, /var/tmp, or \$HOME/tmp" >&2
    exit 1
    ;;
esac
rm -rf "${TMP_APP_DIR}"
```

Low priority — this is a CI script run in ephemeral environments, and
the failure mode requires a misconfigured caller.

### IN-06: Router injection template adds scopes before the pipelines in physical file order

**File:** `priv/templates/sigra.install/admin/router_injection.ex:1-16,17-78`
**Issue:** Lines 1-14 declare `pipeline :admin_global` and
`pipeline :admin_organization`, then line 16 carries the `# Sigra
admin` marker, then scopes start. Phoenix routers allow pipelines
and scopes in any order inside `Router` module, so this compiles —
but stylistically, most Phoenix projects group pipelines at the top
of the router and scopes after. The `:before_last_end` injection
anchor produces a self-contained block that reads naturally in
isolation; inside the host router, the injected pipelines interleave
with host-defined pipelines and scopes, which can look disorganized
on merge conflict resolution.

**Fix:** Consider a two-pass injection pattern: one `:browser_pipeline`-
anchored inject for the pipelines (groups with existing pipelines),
and one `:before_last_end`-anchored inject for the scopes. Out of
scope for Phase 32; note for a router-refactor cleanup phase.

---

_Reviewed: 2026-04-17_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
