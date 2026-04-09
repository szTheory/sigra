# Phase 10: Developer Experience - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-09
**Phase:** 10-developer-experience
**Areas discussed:** DX-01 signature reconciliation, Scenario fixture API shape, Cookie domain config strategy, Documentation structure (DX-02), Audit test helpers, Sigra.Testing module organization, Example Phoenix app

---

## Gray Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| DX-01 signature reconciliation | Requirement names don't match shipped code | ✓ |
| Scenario fixture API shape | 7 states, piecemeal vs dispatcher vs traits | ✓ |
| Cookie domain config strategy | Config location, defaults, auto-detect | ✓ |
| Documentation structure (DX-02) | Layout, guide count, sync strategy | ✓ |

---

## DX-01 Signature Reconciliation

| Option | Description | Selected |
|--------|-------------|----------|
| Honor shipped names; update REQUIREMENTS wording | Keep setup_totp/2, create_api_token/3; update DX-01 text | ✓ |
| Add thin aliases matching DX-01 text | Wrapper functions with DX-01 arities | |
| Rename shipped code to match DX-01 | Breaking change | |
| Introduce scenario/2 as primary API | New API replaces literal DX-01 surface | |

**User's choice:** Honor shipped names (recommended)
**Notes:** Shipped arities reflect real option needs. Phase 7 D-63 standardized "token" over "key".

---

## Scenario Fixture API Shape

### Primary API

| Option | Description | Selected |
|--------|-------------|----------|
| Piecemeal named fns + scenario/2 dispatcher in generated AuthFixtures | Both direct calls and parametric dispatch | ✓ |
| Piecemeal only — one function per scenario | Match phx.gen.auth exactly | |
| factory_bot-style traits | Composable traits | |
| Scenario fixtures in Sigra.Testing (library) | Library-owned instead of generated | |

### Return Shape

| Option | Description | Selected |
|--------|-------------|----------|
| Uniform map with consistent keys (nil-padded) | One destructure pattern | |
| Scenario-specific shapes | Each returns what it needs | ✓ |
| Tagged struct %Sigra.Testing.Scenario{} | Explicit pattern-matchable struct | |

### Anonymous Scenario

| Option | Description | Selected |
|--------|-------------|----------|
| Returns a plain Plug.Conn with no session | anonymous_fixture() → %{conn: build_conn()} | ✓ |
| Returns nil / :anonymous atom | Minimal | |
| Omit anonymous from the set | Explicitly carve out | |

### MFA States (pending vs complete)

| Option | Description | Selected |
|--------|-------------|----------|
| pending = enrolled+challenged; complete = verified this session | Phase 6 session type semantics | ✓ |
| pending = enrollment in progress; complete = enrolled | Different interpretation | |
| You decide — use Phase 6 as source of truth | Delegate to planner | |

### Conn Setup in Fixtures

| Option | Description | Selected |
|--------|-------------|----------|
| Include conn in scenarios that imply HTTP state | authenticated/sudo/mfa_complete include conn | ✓ |
| Never include conn — fixtures are data only | Pure separation | |
| Always include conn when a user exists | Always consistent | |

### Unconfirmed Meaning

| Option | Description | Selected |
|--------|-------------|----------|
| Email unconfirmed: user exists, confirmed_at is nil | phx.gen.auth convention | ✓ |
| MFA unconfirmed: TOTP generated not verified | Reuse for half-enrolled MFA | |
| Both — ship two unconfirmed fixtures | Explicit | |

### Dispatcher Shape

| Option | Description | Selected |
|--------|-------------|----------|
| scenario(name, attrs \\ %{}) with atom name | Standard shape | ✓ |
| scenario/2 with keyword list + :as key | Pipe-friendly | |
| No dispatcher — named fns only | Drop parametric API | |

### Host Schema Extensions

| Option | Description | Selected |
|--------|-------------|----------|
| Fixtures in GENERATED AuthFixtures — host edits directly | Matches D-33 | ✓ |
| Fixtures in library with config callback | Indirection via config | |
| Fixtures in library, attrs always explicit | Brittle | |

---

## Cookie Domain Config Strategy

### Config Key Location

| Option | Description | Selected |
|--------|-------------|----------|
| Top-level :cookie_domain in Sigra config struct | Single source of truth | ✓ |
| Per-cookie: :remember_me_cookie_domain etc. | Fine-grained | |
| Via endpoint configuration passed in | Host-app owned | |

### Per-Environment Defaults

| Option | Description | Selected |
|--------|-------------|----------|
| dev/test: nil; prod: nil with warning | Safe defaults, loud | ✓ |
| All envs: nil (no opinion) | Match phx.gen.auth exactly | |
| dev/test: nil; prod: raise on boot if unset | Fail-fast | |

### Auto-Detection Mode

| Option | Description | Selected |
|--------|-------------|----------|
| No — explicit string or nil only | Not an Elixir convention | ✓ |
| Yes — :parent atom extracts parent from endpoint | LiveDashboard precedent | |
| Yes — {:from_endpoint, Module} tuple | Explicit endpoint reference | |

### Cookies Affected

| Option | Description | Selected |
|--------|-------------|----------|
| Remember-me cookie | Subdomain auth | ✓ |
| MFA trust cookie | Subdomain MFA persistence | ✓ |
| Phoenix session cookie | Out of scope (host endpoint.ex) | |

---

## Documentation Structure (DX-02)

### Guides Directory Layout

| Option | Description | Selected |
|--------|-------------|----------|
| Phoenix-style: flat top-level + category folders | ~15 guides across intro/flows/recipes/upgrading | ✓ |
| Flow-first: by user journey | Task-oriented | |
| Single mega-guide + module docs | Minimal | |
| Recipe-only: cookbook style | Direct copy-paste | |

### Getting-Started Target

| Option | Description | Selected |
|--------|-------------|----------|
| Single getting-started.md, <30 min, install→register→login→logout+reset | Concrete bar | ✓ |
| Full-featured covering everything | Includes MFA/OAuth/API | |
| Tiered: quickstart/getting-started/full setup | Three entry points | |

### Example Sync Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Doctests + example Phoenix app under test/example | Dual verification | ✓ |
| Doctests only | Simpler | |
| Generate guides from templates + doctests | Script-driven | |

### Hosting

| Option | Description | Selected |
|--------|-------------|----------|
| HexDocs only via ex_doc extras | Standard Elixir | ✓ |
| HexDocs + dedicated docs site | SEO + custom styling | |
| README as docs, HexDocs links back | Minimal | |

---

## Audit Test Helpers (Phase 9 Carryover)

| Option | Description | Selected |
|--------|-------------|----------|
| Ship audit_event_fixture/1 + assert_audit_event/2 in Sigra.Testing | Full support | ✓ |
| Assertion only — no fixture | Real code paths emit events | |
| Defer to v1.1 | Punt | |

---

## Sigra.Testing Module Organization

| Option | Description | Selected |
|--------|-------------|----------|
| Keep monolithic, add section comment headers | Elixir norm | ✓ |
| Split into Sigra.Testing.{Session,MFA,API,OAuth,…} | Granular imports | |
| Keep flat but extract biggest concerns + re-export | Compromise | |

---

## Example Phoenix App

### Location and Scope

| Option | Description | Selected |
|--------|-------------|----------|
| test/example/ — committed, smoke-tested in CI | Real verification | ✓ |
| examples/basic_app/ at repo root | More discoverable | |
| Generate fresh in CI, nothing committed | Always latest | |
| No example app — doctests only | Simplest | |

### Smoke Flows in CI

| Option | Description | Selected |
|--------|-------------|----------|
| Install + compile | Generator regression | ✓ |
| Register + login + logout | Core happy path | ✓ |
| Password reset email delivery | Phase 3 verification | ✓ |
| MFA, OAuth, API tokens | Full feature coverage | ✓ |

---

## Claude's Discretion

- Exact guide filenames within `guides/flows/` (±2 from D-12 list)
- Doctest density per library module
- Order of `test/example/` smoke jobs in CI
- Whether to parallelize example-app CI into matrix entries
- `getting-started.md` heading structure and code-block count
- Whether `scenario/2` also accepts string names

## Deferred Ideas

- Tiered docs (5min/30min/2h)
- Dedicated docs site beyond hexdocs
- Splitting Sigra.Testing into submodules (unless >2000 LOC)
- Factory_bot-style trait composition
- Cookie domain auto-detection (`:parent` / `:auto`)
- Generated endpoint.ex session-cookie domain patch
- Parallelized example-app CI matrix
- Custom llms.txt tuning
