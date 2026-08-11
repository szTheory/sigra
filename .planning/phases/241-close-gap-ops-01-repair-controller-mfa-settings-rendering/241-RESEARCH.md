# Phase 241: OPS-01 Controller MFA Settings Rendering - Research

**Researched:** 2026-08-11
**Domain:** Phoenix controller rendering and deterministic generated-host route proof
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Keep the existing generated `<WebModule>.MFASettingsHTML` module and make `SettingsController.mfa/2` render explicitly through it. Do not rename the emitted module to `SettingsHTML` or broaden the generated-file/module contract to accommodate Phoenix's inferred controller view.
- **D-02:** Preserve the existing `:mfa_settings` template function and assign contract; the defect is the controller-to-HTML-module connection, not the MFA settings presentation or data model.
- **D-03:** Close the gap with a disposable generated `--no-live` host route test that establishes an authenticated, fresh-sudo session, requests `GET /users/settings/mfa`, and asserts successful rendered output. Template/source assertions, warning-free compilation, root readiness, or an unauthenticated redirect are insufficient proof.
- **D-04:** Integrate the route proof into the established deterministic generated-host harness rather than creating a parallel browser suite or relying on manual UAT. Keep it bounded, readiness-driven, credential-free, and free of fixed sleeps.
- **D-05:** Mark the exact persisted session token used by the logged-in test connection as sudo-fresh before issuing the route request. Do not rely on `sudo_fixture/1` alone because it creates a separate session from the one placed in the request connection.
- **D-06:** Assert that the request reaches and renders the protected controller action, so a redirect to the sudo gate cannot masquerade as route success.
- **D-07:** Stop after successful MFA settings GET rendering and deterministic generated-host evidence. Leave mutation behavior unchanged, including existing `unavailable/1` handling.
- **D-08:** Do not modify the canonical LiveView route/runtime lane, add passkey behavior, change public APIs, add dependencies, or claim broader MFA management support.

### the agent's Discretion

- Choose the smallest idiomatic Phoenix mechanism for selecting `MFASettingsHTML`.
- Choose the generated-host test location/setup/stable rendered assertion.
- Choose the narrowest harness/contract updates that retain the single lifecycle.

### Deferred Ideas (OUT OF SCOPE)

- Controller MFA mutations, passkey-enabled controller registration, malformed registration fallback, general MFA, and admin UI work.
</user_constraints>

## Project Constraints (from AGENTS.md)

- Preserve the `sg-*` cascade-layer/BEM, Rail Accent assets, and Light/Dark/System modes for admin UI work; this phase has no admin UI change. [VERIFIED: AGENTS.md]
- Use deterministic automation rather than UAT and never waive missing evidence. [VERIFIED: AGENTS.md]
- UI automation forbids sleeps; this proof uses ExUnit controller dispatch and adds no sleep. [VERIFIED: AGENTS.md]

## Summary

`SettingsController.mfa/2` invokes `render(conn, :mfa_settings, ...)`. Phoenix infers an HTML module from controller naming, so this resolves `SettingsHTML`; the generator emits `MFASettingsHTML.mfa_settings/1`. The actual authenticated/sudo request therefore raises while compilation and root readiness still pass. [VERIFIED: settings controller/template, v1.48 audit] Phoenix documents `put_view(conn, html: Module)` as the explicit view-selection API. [CITED: https://phoenix.hexdocs.pm/Phoenix.Controller.html]

Repair only the controller handoff: put the existing `MFASettingsHTML` into the connection before the existing `render(:mfa_settings, ...)`, preserving the function and every assign. Add a disposable `sigra_b2c_controller` ExUnit probe to the existing four-leg smoke after migration. Log in, resolve the connection's `:user_token` to its persisted session, update that session's `sudo_at`, request the real GET, and require 200 HTML with stable existing MFA copy. [VERIFIED: passkey settings test, sudo plug, controller smoke; CITED: https://phoenix.hexdocs.pm/Phoenix.ConnTest.html]

**Primary recommendation:** Use action-local `put_view(html: MFASettingsHTML)`, then prove the protected rendered GET once through the controller-mode generated-host lane.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Select emitted HTML module | API / Backend | — | Controller owns action-to-renderer handoff. [VERIFIED: template/controller] |
| Render settings | API / Backend | Browser / Client | Backend enforces auth/sudo and returns HTML. [VERIFIED: generated route/template] |
| Prove sudo authorization | API / Backend | Database / Storage | The plug reads persisted session state. [VERIFIED: sudo plug] |
| Host lifecycle | API / Backend | Database / Storage | Existing script generates, migrates, and tests isolated hosts. [VERIFIED: smoke script] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---|---:|---|---|
| Phoenix | 1.8.9 docs current | Explicit controller view selection | Existing framework; official API specifies `put_view/2`. [CITED: https://phoenix.hexdocs.pm/Phoenix.Controller.html] |
| Phoenix.ConnTest | 1.8.7 docs current | Dispatch real route and assert HTML 200 | Proves router/pipeline/controller/template behavior deterministically. [CITED: https://phoenix.hexdocs.pm/Phoenix.ConnTest.html] |
| Ecto / generated Repo | project-locked | Persist exact request session's `sudo_at` | Required by the real sudo plug. [VERIFIED: require_sudo.ex] |

### Supporting

| Library | Version | Purpose | When to Use |
|---|---:|---|---|
| Generated auth fixtures | project-owned | User and connection setup | Only in disposable generated probe. [VERIFIED: auth fixtures] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| Action-local explicit view | Rename module to `SettingsHTML` | Rejected by D-01: expands generated customization contract. [VERIFIED: CONTEXT.md] |
| Routed generated-host probe | Source assertion, compile, root curl | Rejected by D-03/D-06: cannot prove action execution. [VERIFIED: CONTEXT.md] |
| Update connection-token session | `sudo_fixture/1` | Rejected by D-05: fixture creates another session. [VERIFIED: CONTEXT.md] |

**Installation:** None; do not add dependencies. [VERIFIED: D-08]

## Architecture Patterns

### System Architecture Diagram

```text
Generated no-live ExUnit probe
  -> log_in_user(conn, user)
  -> request user token -> resolve exact persisted session -> set sudo_at
  -> GET /users/settings/mfa
  -> authenticated + sudo router pipelines
  -> SettingsController.mfa/2
  -> put_view(html: MFASettingsHTML) -> render(:mfa_settings, existing assigns)
  -> 200 rendered MFA HTML
```

The generator places this route inside authenticated and sudo pipelines. `RequireSudo` checks the session loaded into the connection. [VERIFIED: core route injection, sudo plug]

### Recommended Project Structure

```text
priv/templates/sigra.install/core/settings_controller.ex  # minimal render handoff repair
priv/templates/sigra.install/core/mfa_settings_html.ex    # unchanged renderer/assign API
scripts/ci/passkeys-opt-out-smoke.sh                       # inject/run probe in existing controller leg
test/sigra/install/generated_rate_limit_contract_test.exs  # narrow topology contract extension if needed
```

### Pattern 1: Explicit non-conventional HTML owner

```elixir
# Source: https://phoenix.hexdocs.pm/Phoenix.Controller.html
conn
|> put_view(html: <%= web_module %>.MFASettingsHTML)
|> render(:mfa_settings, mfa_enabled: status.enabled, backup_remaining: status.backup_codes_remaining,
  enrollment_step: nil, svg: nil, base32_secret: nil, backup_codes: [], show_disable: false)
```

### Pattern 2: Freshen the actual request session

```elixir
conn = log_in_user(conn, user)
token = Plug.Conn.get_session(conn, :user_token)
{^user, session} = Accounts.get_user_and_session_by_token(token)
session |> Ecto.Changeset.change(sudo_at: DateTime.utc_now()) |> Repo.update!()
html = conn |> get(~p"/users/settings/mfa") |> html_response(200)
assert html =~ "Two-Factor Authentication"
```

This mirrors existing passkey tests; `sudo_fixture/1` creates an independent session. [VERIFIED: passkey settings test, auth fixtures]

### Anti-Patterns to Avoid

- Rename `MFASettingsHTML`, which violates D-01.
- Accept compile/root/redirect as proof, which violates D-03/D-06.
- Update a fixture session rather than the request-token session.
- Add a browser lane, sleep, dependency, mutation repair, or LiveView change.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Controller-to-template dispatch | Manual renderer/new abstraction | Phoenix `put_view/2` + `render/3` | Framework owns format/view selection. [CITED: https://phoenix.hexdocs.pm/Phoenix.Controller.html] |
| HTTP verification | Custom server client/polling | Generated ConnCase + `html_response/2` | Real pipelines without timing. [CITED: https://phoenix.hexdocs.pm/Phoenix.ConnTest.html] |
| Sudo simulation | Fake assigns/private values | Exact persisted session update | Plug reads persisted session. [VERIFIED: require_sudo.ex] |

## Common Pitfalls

### Pitfall 1: Compiling does not validate controller view inference

**What goes wrong:** Missing inferred view resolves only at render time. [VERIFIED: audit]

**How to avoid:** Explicitly select `MFASettingsHTML` and dispatch protected GET. [CITED: https://phoenix.hexdocs.pm/Phoenix.Controller.html]

### Pitfall 2: Test proves redirect rather than rendering

**How to avoid:** Assert `html_response(conn, 200)` plus stable template copy. [CITED: https://phoenix.hexdocs.pm/Phoenix.ConnTest.html]

### Pitfall 3: Fresh sudo state is on a different session

**How to avoid:** Derive session from `Plug.Conn.get_session(conn, :user_token)`, then update it. [VERIFIED: established passkey test]

### Pitfall 4: Scope expands into mutations

**How to avoid:** Leave `unavailable/1` endpoints and LiveView/passkey behavior untouched. [VERIFIED: D-07/D-08]

## Code Examples

### Generated-host protected route proof

```elixir
test "renders MFA settings after authentication and fresh sudo", %{conn: conn} do
  user = user_fixture()
  conn = log_in_user(conn, user)
  token = Plug.Conn.get_session(conn, :user_token)
  {^user, session} = Accounts.get_user_and_session_by_token(token)
  session |> Ecto.Changeset.change(sudo_at: DateTime.utc_now()) |> Repo.update!()

  html = conn |> get(~p"/users/settings/mfa") |> html_response(200)
  assert html =~ "Two-Factor Authentication"
end
```

Adapt aliases/module names to the generated controller host. [VERIFIED: smoke script]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| Compile/boot/root proof only | Authenticated + exact-sudo routed render proof | Phase 241 | Catches this runtime-only mismatch. [VERIFIED: 240.2 verification, audit] |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | Injected probe filename will be `generated_mfa_settings_route_probe_test.exs` | Validation | Filename can differ; behavior/command must remain bound. |

## Open Questions

None blocking. Planner selects exact injected test filename/function while retaining the single controller-leg lifecycle. [VERIFIED: CONTEXT.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| Elixir / Mix | Generate/run probe | ✓ | 1.19.5 | — |
| PostgreSQL client | Migration/session persistence | ✓ | 14.17 | Existing configured smoke endpoint |
| Default local PostgreSQL | Immediate smoke execution | ✗ | — | Existing PGHOST/PGPORT inputs. [VERIFIED: smoke script] |

**Missing dependencies with no fallback:** None for planning; executing a fresh host needs reachable PostgreSQL.

**Missing dependencies with fallback:** Local default Postgres is unavailable; reuse configured endpoint.

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit with generated Phoenix ConnCase/ConnTest. [VERIFIED: mix.exs, generated tests] |
| Config file | Generated host test helper. [VERIFIED: smoke script] |
| Quick run command | `MIX_ENV=test mix test test/generated_mfa_settings_route_probe_test.exs` [ASSUMED] |
| Full suite command | `scripts/ci/passkeys-opt-out-smoke.sh` [VERIFIED: smoke script] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| OPS-01 closure | no-live host authenticates, freshens exact session, GETs MFA route, receives rendered HTML | generated-host integration | focused injected ExUnit probe | ❌ Wave 0 |
| OPS-01 closure | explicit view/probe wiring preserves canonical LiveView lane | source contract | focused install contracts | ✅ extend existing |

### Sampling Rate

- **Per task commit:** source contracts plus focused generated-host route probe.
- **Per wave merge:** four-leg smoke.
- **Phase gate:** source contracts and full smoke green; no manual substitute. [VERIFIED: AGENTS.md]

### Wave 0 Gaps

- [ ] Inject a controller-host MFA route probe testing real auth, fresh sudo, and 200 HTML. [ASSUMED]
- [ ] Add narrow contract marker checks only if needed for probe wiring/lane preservation. [VERIFIED: existing contracts]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | yes | Existing authenticated pipeline/real login. [VERIFIED: core route injection] |
| V3 Session Management | yes | Exact persisted token session receives fresh `sudo_at`. [VERIFIED: user auth/sudo plug] |
| V4 Access Control | yes | Existing sudo pipeline; proof needs 200 only after fresh sudo. [VERIFIED: core route injection] |
| V5 Input Validation | no new input | GET has no parameters; mutations excluded. [VERIFIED: controller, D-07] |
| V6 Cryptography | no new cryptography | Reuse existing session/token paths. [VERIFIED: D-08] |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Redirect accepted as success | Elevation of Privilege | Require 200 page content after real auth/sudo. [VERIFIED: D-03–D-06] |
| Test bypasses session gate | Tampering | Update connection-token persisted session only. [VERIFIED: sudo plug] |
| Render mismatch omitted by static proof | Denial of Service | Execute protected generated route. [VERIFIED: audit] |

## Sources

### Primary (HIGH confidence)

- Direct settings controller/template, core routes, auth/session/sudo sources, existing passkey test, controller smoke, 240.2 artifacts, and v1.48 audit.

### Secondary (MEDIUM confidence)

- [Phoenix.Controller v1.8.9](https://phoenix.hexdocs.pm/Phoenix.Controller.html) — inference, `put_view/2`, render.
- [Phoenix.ConnTest v1.8.7](https://phoenix.hexdocs.pm/Phoenix.ConnTest.html) — test dispatch and HTML assertions.

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — project sources and official Phoenix docs agree.
- Architecture: HIGH — direct route-to-controller-to-template trace.
- Pitfalls: HIGH — exact problem documented by audit/review and reproducible from source.

**Research date:** 2026-08-11
**Valid until:** 2026-09-10
