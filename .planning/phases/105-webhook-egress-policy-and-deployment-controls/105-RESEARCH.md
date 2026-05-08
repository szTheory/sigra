# Phase 105: Webhook egress policy and deployment controls - Research

**Researched:** 2026-05-07
**Domain:** Outbound webhook egress policy, SSRF-resistant destination validation, and generated deployment guidance for Sigra webhooks [VERIFIED: codebase] [CITED: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html]
**Confidence:** MEDIUM

<user_constraints>
## User Constraints

### Locked Decisions
- No Phase 105 `CONTEXT.md` exists; derive the planning substrate from roadmap, requirements, and prior webhook phases. [VERIFIED: user prompt]
- Preserve Sigra's existing architecture: outbound-only webhooks, truthful operator state, receiver-owned verification contract, and generated-host guidance instead of bespoke host forks. [VERIFIED: user prompt] [VERIFIED: guides/flows/webhooks.md]
- Phase 105 must satisfy `WH-06`: adopters can enforce outbound webhook endpoint policy, including allowlisting guidance and deployment-specific controls, without forking Sigra internals. [VERIFIED: .planning/REQUIREMENTS.md]
- Success criteria are: block disallowed schemes/hosts/network targets before remote request, generate practical allowlisting/deployment guidance, support tenant/deployment-specific controls without forks, and prove both allowed and blocked paths with truthful operator visibility. [VERIFIED: .planning/ROADMAP.md]

### Claude's Discretion
- Exact config DSL, module names, and policy-hook shape are open so long as the enforcement stays library-owned and host-extensible. [VERIFIED: user prompt] [VERIFIED: codebase]
- Exact admin copy, delivery reason strings, and generated-doc wording are open so long as blocked destinations stay operator-visible and truthful. [VERIFIED: user prompt] [VERIFIED: codebase]

### Deferred Ideas (OUT OF SCOPE)
- Inbound provider webhooks. [VERIFIED: .planning/REQUIREMENTS.md]
- Arbitrary event transformation or scripting before delivery. [VERIFIED: .planning/REQUIREMENTS.md]
- Custom retry-policy tuning per subscription. [VERIFIED: .planning/REQUIREMENTS.md]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WH-06 | Adopter can enforce outbound webhook endpoint policy, including allowlisting guidance and deployment-specific controls, without forking Sigra internals. | Add a library-owned egress-policy preflight that validates scheme, host, and resolved IPs before dispatch; persist blocked sends as explicit local policy failures; expose host-configurable policy hooks in `Sigra.Config`; extend generated host docs/checklists with deployment control points and egress-IP guidance. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: codebase] [CITED: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html] |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- Keep Phoenix `1.8+` and Ecto `3.x` as the blessed path. [VERIFIED: CLAUDE.md]
- Keep security-sensitive behavior in the library and generated host code thin. [VERIFIED: CLAUDE.md]
- Prefer minimal transitive dependencies; if HTTP is needed in library internals, prefer Req or Finch directly rather than Tesla. [VERIFIED: CLAUDE.md]
- Keep LiveView optional overall, but use existing admin/operator surfaces when the requirement is explicitly operator-facing. [VERIFIED: CLAUDE.md]
- Tests should cover happy path, main error cases, and boundary conditions in flat, self-contained AAA style. [VERIFIED: CLAUDE.md]
- Local `mix test` depends on Postgres at `localhost:5432` with `postgres/postgres`. [VERIFIED: CLAUDE.md] [VERIFIED: test/test_helper.exs]

## Summary

Sigra already performs a narrow save-time endpoint check, but it does not yet have a real egress-policy contract. `Sigra.Webhooks.subscription_changeset/3` only enforces `https` except for localhost HTTP, while `Sigra.Workers.WebhookDelivery.default_request/1` still makes the outbound call with `:httpc` and no destination-network preflight. That means Phase 105 is not about polishing an existing knob; it is about adding the first authoritative “do not dial this destination” layer to the webhook pipeline. [VERIFIED: lib/sigra/webhooks.ex] [VERIFIED: lib/sigra/workers/webhook_delivery.ex]

The strongest planning shape is dual enforcement. Keep the current create/update validation as the fast operator-facing linter, but make send-time preflight authoritative: parse the URL strictly, resolve hostnames at dispatch time, evaluate every literal or resolved IP against the configured policy, and persist a truthful terminal local failure when blocked before any socket connect happens. OWASP’s SSRF guidance is explicit that allowlists are preferred, redirects should not bypass validation, and domain-only checks are insufficient when DNS can resolve to internal or special-use ranges. [CITED: https://hexdocs.pm/elixir/URI.html] [CITED: https://www.erlang.org/doc/apps/kernel/inet.html] [CITED: https://www.erlang.org/docs/26/man/inet_res] [CITED: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html]

The second half of the requirement is operational, not just technical. Sigra runs inside the adopter’s app, so Sigra cannot truthfully publish a universal outbound IP list. The practical contract is: Sigra enforces what it can in-process, generated hosts get explicit documentation about where deployment teams must pin egress in their own infrastructure, and blocked destinations surface in admin history as first-class local policy failures instead of generic transport noise. `docs/webhook_receiver_setup.md` is already the right generated host seam to extend. [VERIFIED: guides/flows/webhooks.md] [VERIFIED: priv/templates/sigra.install/admin/webhook_receiver_setup.md] [ASSUMED]

**Primary recommendation:** Plan Phase 105 around a new library-owned `Sigra.Webhooks.EgressPolicy` preflight that runs at send time, uses strict URL parsing plus DNS/IP evaluation, fails closed with explicit persisted reasons, and extends the generated host webhook setup docs with deployment-class egress guidance. [VERIFIED: codebase] [CITED: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| URL syntax and scheme validation on create/update | API / Backend | Frontend Server (SSR) | Subscription edits already flow through `Sigra.Webhooks.subscription_changeset/3`; the UI should consume those errors, not reimplement them. [VERIFIED: lib/sigra/webhooks.ex] |
| Authoritative destination-policy enforcement before connect | API / Backend | Database / Storage | The worker owns the remote send boundary, so the final block/allow decision must happen there before any request attempt. [VERIFIED: lib/sigra/workers/webhook_delivery.ex] |
| DNS and IP-range evaluation | API / Backend | — | This is runtime network logic, not generated-host UI logic. [CITED: https://www.erlang.org/doc/apps/kernel/inet.html] [CITED: https://www.erlang.org/docs/26/man/inet_res] |
| Truthful blocked-delivery persistence and operator reasoning | Database / Storage | API / Backend | Existing delivery summary plus attempt-ledger tables already carry the operator truth model; blocked sends should extend that model instead of inventing a second one. [VERIFIED: guides/flows/webhooks.md] [VERIFIED: lib/sigra/webhooks.ex] |
| Deployment allowlisting guidance | Generated Host / Docs | API / Backend | Sigra can generate host-owned instructions and examples, but the adopter’s runtime and network perimeter own actual egress IP pinning. [VERIFIED: priv/templates/sigra.install/admin/webhook_receiver_setup.md] [ASSUMED] |
| Admin visibility for blocked destinations | Frontend Server (SSR) | API / Backend | Existing webhook detail/failures pages are already the operator surface for truthful delivery status and should display policy-blocked failures. [VERIFIED: lib/sigra/admin/live/webhook_delivery_show_live.ex] [VERIFIED: lib/sigra/admin/live/webhook_delivery_failures_live.ex] |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir `URI` | `1.19.5` in local environment; docs current for `URI.new/1` on 2026-05-07 | Strict URL parsing and canonical host/scheme extraction | `URI.parse/1` parses without validation, while `URI.new/1`/`new!/1` provide the stricter boundary this phase needs before policy evaluation. [VERIFIED: local toolchain] [CITED: https://hexdocs.pm/elixir/URI.html] |
| Erlang `:inet` / `:inet_res` | OTP docs current on 2026-05-07; local runtime OTP `28` | Strict literal-IP parsing plus A/AAAA hostname resolution | OTP already provides the primitives needed to parse IPs and resolve hostnames at dispatch time. [VERIFIED: local toolchain] [CITED: https://www.erlang.org/doc/apps/kernel/inet.html] [CITED: https://www.erlang.org/docs/26/man/inet_res] |
| `inet_cidr` | `1.0.9`, published 2025-12-12 | IPv4/IPv6 CIDR parsing and containment checks | Zero transitive dependencies, compatible with Erlang `:inet` tuples, and covers both IPv4 and IPv6 without custom bit math. [VERIFIED: hex.pm registry] [CITED: https://hexdocs.pm/inet_cidr/cheatsheet.html] |
| Ecto / Ecto SQL | repo lock `3.13.5`; latest `3.13.6` published 2026-05-05 | Persist blocked-delivery summary and attempt rows transactionally | Phase 105 should reuse the existing “summary row + attempt row in one transaction” pattern for policy blocks. [VERIFIED: mix.lock] [VERIFIED: hex.pm registry] [VERIFIED: lib/sigra/webhooks.ex] |
| Oban | repo lock `2.21.1`; latest `2.22.1` published 2026-04-30 | Existing async worker execution boundary | The phase does not need a new queue system; it needs policy enforcement before the existing worker dials the network. [VERIFIED: mix.lock] [VERIFIED: hex.pm registry] [VERIFIED: lib/sigra/workers/webhook_delivery.ex] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Phoenix LiveView | repo lock `1.1.28`; latest package line for project remains `1.1.x` | Show blocked destinations and truthful failure reasons in existing admin views | Use for operator visibility only; the policy engine stays library-owned. [VERIFIED: mix.lock] [VERIFIED: codebase] |
| `Req` | `0.5.17`, published 2026-01-05 | Optional follow-on transport cleanup if the phase also extracts the webhook sender away from raw `:httpc` | Req’s request-step architecture fits egress instrumentation well, but the policy engine should not depend on a same-phase transport rewrite. [VERIFIED: hex.pm registry] [CITED: https://hexdocs.pm/req/Req.Request.html] [CITED: https://hexdocs.pm/req/changelog.html] |
| Generated host `docs/webhook_receiver_setup.md` | current repo template | Delivery-operator setup checklist and deployment guidance landing zone | Extend this template instead of inventing a second generated webhook-ops document. [VERIFIED: priv/templates/sigra.install/admin/webhook_receiver_setup.md] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `inet_cidr` | Hand-rolled CIDR parsing/matching | Rejected: IPv4/IPv6 prefix math and special-range handling are easy to get wrong; `inet_cidr` is zero-dependency and already matches OTP tuple formats. [VERIFIED: hex.pm registry] [CITED: https://hexdocs.pm/inet_cidr/cheatsheet.html] |
| Dispatch-time resolver/IP policy | Hostname string allowlist only | Rejected: OWASP explicitly warns that domain validation without runtime DNS/IP checks is vulnerable to DNS rebinding/pinning-style bypasses. [CITED: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html] |
| Transport-agnostic preflight over current worker | Same-phase full transport rewrite to Req | A Req migration could be valuable, but it is not required to satisfy WH-06 and would enlarge the phase surface. [VERIFIED: lib/sigra/workers/webhook_delivery.ex] [CITED: https://hexdocs.pm/req/Req.Request.html] |

**Installation:**
```elixir
# mix.exs
{:inet_cidr, "~> 1.0"}
```

```bash
mix deps.get
```

**Version verification:** `inet_cidr` `1.0.9` (2025-12-12), `Req` `0.5.17` (2026-01-05), `Oban` `2.22.1` upstream (2026-04-30), `Phoenix` `1.8.7` upstream (2026-05-06), and `Ecto` `3.13.6` upstream (2026-05-05) were verified against Hex’s package API; the repo currently locks `Oban 2.21.1`, `Phoenix 1.8.5`, and `Ecto 3.13.5`. [VERIFIED: hex.pm registry] [VERIFIED: mix.lock]

## Architecture Patterns

### System Architecture Diagram

```text
Admin or generated host saves subscription
  -> Sigra.Webhooks.subscription_changeset/3
    -> strict scheme/host validation
    -> stored webhook_subscriptions row

Sigra mutation emits webhook event
  -> Dispatcher persists webhook_events + webhook_deliveries
    -> Oban worker loads delivery + subscription + event
      -> EgressPolicy.preflight(endpoint_url, scope/config)
        -> strict URI parse
        -> literal-IP or hostname path
        -> resolve A/AAAA answers
        -> CIDR / host / scheme / local-target policy decision
          -> allowed: existing HTTP transport sends request
          -> blocked: persist local policy failure, no socket connect
            -> admin failures/detail views show truthful blocked reason

Install/admin generator
  -> docs/webhook_receiver_setup.md
    -> deployment-class guidance (host firewall / NAT / Kubernetes / cloud egress control point)
```

### Recommended Project Structure
```text
lib/
├── sigra/webhooks/egress_policy.ex      # authoritative preflight evaluation
├── sigra/webhooks/resolver.ex           # DNS lookup abstraction for tests and host override
├── sigra/webhooks/policy_result.ex      # normalized allow/block reason contract
├── sigra/workers/webhook_delivery.ex    # call preflight before request execution
└── sigra/config.ex                      # webhooks.egress_* NimbleOptions surface

priv/templates/sigra.install/admin/
└── webhook_receiver_setup.md            # generated deployment + allowlisting guidance
```

### Pattern 1: Dual Enforcement
**What:** Validate obvious problems at subscription save time, but make send-time policy authoritative because DNS and deployment policy can change between create and dispatch. [VERIFIED: lib/sigra/webhooks.ex] [CITED: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html]
**When to use:** Always for webhook destinations. [VERIFIED: .planning/ROADMAP.md]
**Example:**
```elixir
# Source: https://hexdocs.pm/elixir/URI.html
with {:ok, uri} <- URI.new(endpoint_url),
     :ok <- Sigra.Webhooks.EgressPolicy.check(uri, config, scope) do
  :allowed
else
  {:error, reason} -> {:blocked, reason}
end
```

### Pattern 2: Evaluate Resolved IPs, Not Just Host Strings
**What:** If the endpoint host is a name rather than a literal IP, resolve its A and AAAA records at dispatch time and check every answer against the allow/deny policy. [CITED: https://www.erlang.org/docs/26/man/inet_res] [CITED: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html]
**When to use:** Every send-time preflight for hostname endpoints. [CITED: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html]
**Example:**
```elixir
# Source: https://www.erlang.org/docs/26/man/inet_res
case :inet_res.gethostbyname(String.to_charlist(host), :inet, 5_000) do
  {:ok, hostent} -> hostent
  {:error, reason} -> {:error, reason}
end
```

### Pattern 3: Persist Policy Blocks as First-Class Local Failures
**What:** A blocked destination is not a transport timeout and not a silent cancel; it is a local policy decision that should produce a durable summary/attempt record and operator-readable reason. [VERIFIED: guides/flows/webhooks.md] [VERIFIED: lib/sigra/webhooks.ex]
**When to use:** Whenever the preflight rejects scheme, host, or network target. [VERIFIED: .planning/ROADMAP.md]
**Example:**
```elixir
# Source: local persisted-outcome pattern in lib/sigra/webhooks.ex
Sigra.Webhooks.persist_delivery_outcome(config, delivery, %{
  attempt_number: next_attempt_number,
  attempted_at: attempted_at,
  finished_at: attempted_at,
  retryable: false,
  error_category: "local_policy_error",
  error_detail: "egress policy blocked resolved target",
  terminal_reason: "egress_policy_blocked",
  endpoint_url: delivery.endpoint_url
})
```

### Anti-Patterns to Avoid
- **`URI.parse/1` as the only validator:** it parses without validating the URI string, which is too weak for the dispatch boundary. [CITED: https://hexdocs.pm/elixir/URI.html]
- **Hostname allowlists without resolved-IP checks:** this leaves DNS rebinding/pinning gaps. [CITED: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html]
- **Treating policy blocks as hidden `{:cancel, reason}` paths:** operators need durable, queryable failure truth. [VERIFIED: guides/flows/webhooks.md]
- **Publishing “Sigra egress IPs” as if Sigra were a hosted sender:** Sigra runs inside the adopter’s deployment, so only adopter-controlled NAT/gateway/firewall IPs are truthful. [VERIFIED: guides/flows/webhooks.md] [ASSUMED]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CIDR parsing and containment | Custom bitstring math for IPv4/IPv6 ranges | `inet_cidr` | Zero deps, OTP-compatible tuples, and both IPv4/IPv6 support out of the box. [VERIFIED: hex.pm registry] [CITED: https://hexdocs.pm/inet_cidr/cheatsheet.html] |
| Strict URL validation | `URI.parse/1` plus ad hoc conditionals | `URI.new/1` or `URI.new!/1` | `URI.parse/1` does not validate the input string; `URI.new` gives a stricter contract. [CITED: https://hexdocs.pm/elixir/URI.html] |
| DNS safety logic | String-only host allowlists | Runtime A/AAAA resolution plus IP-range evaluation | OWASP explicitly calls out domain-only validation as insufficient when DNS can point at internal or special-use targets. [CITED: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html] |
| Deployment allowlisting story | Hard-coded vendor IP list in Sigra docs | Generated guidance telling adopters where to pin their own egress IPs/control points | Sigra is a library in the adopter’s runtime, not a hosted webhook service with stable sender IPs. [VERIFIED: guides/flows/webhooks.md] [ASSUMED] |

**Key insight:** the difficult part of WH-06 is not string validation; it is turning a user-supplied webhook URL into a stable, truthful runtime policy decision that survives DNS drift, IPv6, and operator troubleshooting. [CITED: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html] [VERIFIED: codebase]

## Common Pitfalls

### Pitfall 1: Save-time validation only
**What goes wrong:** A subscription that looked safe when saved later resolves to a blocked address and the worker still dials it. [CITED: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html]
**Why it happens:** The current code validates only `endpoint_url` scheme/host shape at create/update time. [VERIFIED: lib/sigra/webhooks.ex]
**How to avoid:** Treat send-time preflight as authoritative. [VERIFIED: codebase]
**Warning signs:** The implementation never resolves or re-checks the destination in `WebhookDelivery.perform/1`. [VERIFIED: lib/sigra/workers/webhook_delivery.ex]

### Pitfall 2: Checking only one DNS answer
**What goes wrong:** The code allows a hostname because the first answer is public while another A/AAAA answer points to a blocked target. [CITED: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html]
**Why it happens:** Many quick implementations test one resolved IP and stop. [ASSUMED]
**How to avoid:** Resolve both A and AAAA and require every candidate used for connect to pass policy. [CITED: https://www.erlang.org/docs/26/man/inet_res] [CITED: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html]
**Warning signs:** Tests cover IPv4 only or never mention AAAA answers. [VERIFIED: current test surface]

### Pitfall 3: Logging a blocked destination as a transport failure
**What goes wrong:** Operators see `transport_error` or generic dead-letter copy and cannot distinguish policy from receiver outage. [VERIFIED: guides/flows/webhooks.md]
**Why it happens:** The worker already has transport/local failure buckets, so planners may try to squeeze policy blocks into an existing bucket. [VERIFIED: lib/sigra/workers/webhook_delivery.ex]
**How to avoid:** Introduce an explicit local policy error category and terminal reason. [VERIFIED: codebase]
**Warning signs:** The proposed plan never changes `terminal_reason` or `last_error_category`. [VERIFIED: lib/sigra/webhooks.ex]

### Pitfall 4: Generated guidance that stops at a config knob
**What goes wrong:** WH-06 ships a policy API but adopters still do not know where to pin outbound IPs or enforce egress in production. [VERIFIED: .planning/ROADMAP.md]
**Why it happens:** Library authors often document the code path and skip the infrastructure handoff. [ASSUMED]
**How to avoid:** Extend the generated webhook setup doc with explicit deployment control points and the “Sigra has no fixed sender IPs” rule. [VERIFIED: priv/templates/sigra.install/admin/webhook_receiver_setup.md] [ASSUMED]
**Warning signs:** The docs mention only `config.webhooks` keys and never mention firewall/NAT/egress gateway/network policy ownership. [VERIFIED: current generated template]

## Code Examples

Verified patterns from official sources:

### Strict URL parsing
```elixir
# Source: https://hexdocs.pm/elixir/URI.html
{:ok, uri} = URI.new("https://elixir-lang.org/")
```

### Parse CIDR and test membership
```elixir
# Source: https://hexdocs.pm/inet_cidr/cheatsheet.html
cidr = InetCidr.parse_cidr!("192.168.0.0/16")
ip = InetCidr.parse_address!("192.168.15.20")
InetCidr.contains?(cidr, ip)
```

### Append a request step in Req
```elixir
# Source: https://hexdocs.pm/req/Req.Request.html
req =
  Req.new(base_url: "https://api.github.com")
  |> Req.Request.append_request_steps(
    debug_url: fn request ->
      IO.inspect(URI.to_string(request.url))
      request
    end
  )
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Save-time URL check only | Save-time lint plus authoritative send-time preflight | Current OWASP SSRF guidance | Closes DNS drift and runtime target gaps. [CITED: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html] |
| Hostname string matching | Resolved A/AAAA IP evaluation against CIDR/host rules | Current OWASP SSRF guidance | Prevents domain-only bypasses. [CITED: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html] |
| Generic transport/local failure buckets | Explicit `local_policy_error` / `egress_policy_blocked` operator truth | Sigra webhook phases 98-104 established truthful state as the product contract | Keeps blocked destinations understandable to operators. [VERIFIED: guides/flows/webhooks.md] [VERIFIED: .planning/phases/101-operator-delivery-state-truth/101-CONTEXT.md] |
| Hard-coded provider sender IP docs | Generated deployment-control guidance for adopter-owned infrastructure | Phase 105 requirement surface | Makes allowlisting actionable without pretending Sigra is a hosted sender. [VERIFIED: .planning/ROADMAP.md] [ASSUMED] |

**Deprecated/outdated:**
- Using `URI.parse/1` as the trust boundary for outbound webhook destinations is too weak for this phase. [CITED: https://hexdocs.pm/elixir/URI.html]
- The current direct `:httpc.request/4` call in `Sigra.Workers.WebhookDelivery` is a workable baseline but not a policy seam. [VERIFIED: lib/sigra/workers/webhook_delivery.ex]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Generated deployment guidance should cover the main deployment classes adopters are likely to use rather than a single infrastructure recipe. | Summary / Common Pitfalls | Planner may under-scope docs work or choose the wrong examples. |
| A2 | Tenant-specific controls are satisfied in this phase by a host callback seam that can inspect tenant-aware host state; Phase 105 does not add a Sigra-owned tenant policy UI or persisted policy tables. | Resolved Decisions | If future roadmap work wants tenant-managed policy as a product surface, that is follow-on scope, not WH-06 minimum scope. |
| A3 | Sigra should document adopter-owned egress IP pinning instead of publishing a fixed sender-IP list because Sigra runs inside the adopter runtime. | Summary / Don't Hand-Roll | If the project later adds a hosted relay mode, the guidance model would change materially. |

## Resolved Questions

1. **WH-06 is satisfied in Phase 105 by a host-config callback seam, not a persisted tenant policy model.**
   - What we know: the requirement asks for tenant- or deployment-specific controls without forking, and the current webhook data model has no tenant-specific policy tables. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: codebase]
   - Resolution: Phase 105 will ship `Sigra.Config` + generated-host callback wiring so host apps can make tenant-aware allow/deny decisions from their own state. Sigra admin does not gain a new tenant-policy management product surface in this phase. [VERIFIED: roadmap + research synthesis]
   - Scope effect: no new policy tables, tenant-policy forms, or same-phase schema/UI expansion are required for WH-06.

2. **Transport modernization is out of scope unless implementation pressure forces a narrow extraction seam.**
   - What we know: current worker delivery uses `:httpc.request/4`, and policy logic can be added before that call. [VERIFIED: lib/sigra/workers/webhook_delivery.ex]
   - Resolution: Phase 105 is a policy-and-proof slice, not a general HTTP-client migration. The executor may introduce a small extraction seam to make pre-send enforcement testable, but should not broaden the phase into a Req migration unless blocked by the existing structure. [VERIFIED: roadmap success criteria + research synthesis]
   - Scope effect: `WH-06` can pass without replacing the transport implementation.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Library tests and implementation | ✓ | `1.19.5` | — |
| Mix | Library tasks and tests | ✓ | `1.19.5` | — |
| PostgreSQL server | Root `mix test` lane | ✓ | `localhost:5432 accepting` | Docker is available if the local server needs to be replaced. [VERIFIED: local environment] |
| Node / npm | Existing Playwright/generated-host proof lane | ✓ | `22.14.0` / `11.1.0` | Skip browser proof and rely on ExUnit only if Phase 105 stays docs/library-only. [VERIFIED: local environment] |
| Docker | Local Postgres fallback | ✓ | `29.4.1` | — |

**Missing dependencies with no fallback:**
- None found. [VERIFIED: local environment]

**Missing dependencies with fallback:**
- None found. [VERIFIED: local environment]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit at the repo root; Playwright in `test/example/priv/playwright` for generated-host/browser proof. [VERIFIED: test/test_helper.exs] [VERIFIED: test/example/priv/playwright/package.json] |
| Config file | `test/test_helper.exs`; `test/example/priv/playwright/playwright.config.ts`. [VERIFIED: codebase] |
| Quick run command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/webhooks_test.exs test/sigra/workers/webhook_delivery_test.exs -x` |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WH-06 | Allowed endpoints still deliver successfully under the new policy seam | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/webhooks_integration_test.exs -x` | ✅ |
| WH-06 | Disallowed scheme/host/network targets are blocked before request and persisted truthfully | unit + worker | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/workers/webhook_delivery_test.exs -x` | ✅ |
| WH-06 | Operator sees clear blocked reasons in existing admin surfaces | example LiveView | `cd test/example && mix test test/example_web/live/admin_webhook_delivery_show_live_test.exs -x` | ✅ |
| WH-06 | Generated docs / deployment guidance are present and actionable | docs + browser/manual | `cd test/example/priv/playwright && npm test -- admin-generated.spec.ts` | ✅ but Phase 105 assertions need to be added |

### Sampling Rate
- **Per task commit:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/webhooks_test.exs test/sigra/workers/webhook_delivery_test.exs -x`
- **Per wave merge:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/webhooks_integration_test.exs test/sigra/workers/webhook_delivery_test.exs`
- **Phase gate:** full root `mix test`, plus targeted example-host test or Playwright proof if docs/UI/operator surfaces change

### Wave 0 Gaps
- [ ] `test/sigra/webhooks_egress_policy_test.exs` — dedicated matrix for CIDR rules, IPv6, metadata/loopback/private ranges, literal-IP vs hostname resolution paths. [VERIFIED: codebase]
- [ ] Extend `test/sigra/workers/webhook_delivery_test.exs` so blocked endpoints prove “no request attempted” and explicit `terminal_reason` / `error_category`. [VERIFIED: codebase]
- [ ] Extend `test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs` or failures-page tests with operator-visible blocked-destination copy. [VERIFIED: codebase]
- [ ] Extend generated docs/browser proof only if Phase 105 modifies admin text or generated host docs; current Playwright lane has webhook proof seams but no WH-06 assertions. [VERIFIED: test/example/priv/playwright/tests/admin-generated.spec.ts]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | yes | Keep replay/admin/operator mutations behind existing global-admin authorization; tenant-specific policy should be a host-owned decision seam, not a fork. [VERIFIED: lib/sigra/admin/webhooks/actions.ex] [ASSUMED] |
| V5 Input Validation | yes | Strict URL parsing, scheme validation, literal-IP parsing, DNS resolution, and CIDR/range checks before outbound connect. [CITED: https://hexdocs.pm/elixir/URI.html] [CITED: https://www.erlang.org/doc/apps/kernel/inet.html] [CITED: https://hexdocs.pm/inet_cidr/cheatsheet.html] |
| V6 Cryptography | yes | Keep current HMAC signing/verification contract unchanged; never hand-roll new secret-selection semantics just for egress policy. [VERIFIED: lib/sigra/webhooks/signature.ex] |

### Known Threat Patterns for Sigra's webhook stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| SSRF to metadata or private-network targets | Information Disclosure / Tampering | Dispatch-time allowlist or special-range block on resolved IPs plus adopter-owned network egress controls. [CITED: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html] |
| DNS rebinding / DNS pinning | Tampering | Re-resolve hostnames at dispatch time and evaluate all A/AAAA answers against policy. [CITED: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html] |
| Scheme abuse (`file://`, `gopher://`, etc.) | Tampering | Restrict protocols to `https` and explicit localhost `http` exceptions only if the policy permits them. [VERIFIED: lib/sigra/webhooks.ex] [CITED: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html] |
| Silent operator ambiguity after a policy block | Repudiation / Availability | Persist explicit `local_policy_error` and `egress_policy_blocked` reasons in delivery state and attempt history. [VERIFIED: guides/flows/webhooks.md] [VERIFIED: lib/sigra/webhooks.ex] |

## Sources

### Primary (HIGH confidence)
- `lib/sigra/webhooks.ex` — current subscription validation, persistence patterns, and webhook config surface. [VERIFIED: codebase]
- `lib/sigra/workers/webhook_delivery.ex` — current dispatch boundary and direct `:httpc` send path. [VERIFIED: codebase]
- `lib/sigra/config.ex` — current `webhooks` options exposed through `Sigra.Config`. [VERIFIED: codebase]
- `guides/flows/webhooks.md` — published webhook contract, current endpoint policy wording, and operator truth model. [VERIFIED: codebase]
- `guides/recipes/webhook-verification.md` — current receiver-owned verification contract. [VERIFIED: codebase]
- `priv/templates/sigra.install/admin/webhook_receiver_setup.md` — generated host webhook checklist seam. [VERIFIED: codebase]
- `https://hexdocs.pm/elixir/URI.html` — strict vs loose URI parsing behavior. [CITED: https://hexdocs.pm/elixir/URI.html]
- `https://www.erlang.org/doc/apps/kernel/inet.html` — IP parsing helpers. [CITED: https://www.erlang.org/doc/apps/kernel/inet.html]
- `https://www.erlang.org/docs/26/man/inet_res` — hostname resolution behavior. [CITED: https://www.erlang.org/docs/26/man/inet_res]
- `https://hexdocs.pm/inet_cidr/cheatsheet.html` and `https://hex.pm/packages/inet_cidr` — CIDR parsing and package currency. [CITED: https://hexdocs.pm/inet_cidr/cheatsheet.html] [VERIFIED: hex.pm registry]
- `https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html` — SSRF defensive guidance for custom webhook/callback URLs. [CITED: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html]

### Secondary (MEDIUM confidence)
- `https://hexdocs.pm/req/Req.Request.html` and `https://hexdocs.pm/req/changelog.html` — request-step architecture and current `connect_options` support if a later transport cleanup is folded into the phase. [CITED: https://hexdocs.pm/req/Req.Request.html] [CITED: https://hexdocs.pm/req/changelog.html]
- Hex package API lookups for `req`, `phoenix`, `ecto`, `oban`, and `inet_cidr` — current version and publish-date verification. [VERIFIED: hex.pm registry]

### Tertiary (LOW confidence)
- None; low-confidence ecosystem claims were avoided, and no unresolved research blockers remain for planning. [VERIFIED: research process]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - core primitives come from current code, OTP/Elixir docs, and verified package registry data.
- Architecture: MEDIUM - the policy seam and generated deployment-guidance split are strongly supported by the codebase and OWASP, but tenant-policy product shape still needs a deliberate plan decision.
- Pitfalls: HIGH - the main failure modes are directly evidenced by the current code and official SSRF guidance.

**Research date:** 2026-05-07
**Valid until:** 2026-06-06
