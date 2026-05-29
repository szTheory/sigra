# Phase 137: Optional-Dependency Source of Truth - Context

**Gathered:** 2026-05-29 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Create one canonical module — `Sigra.OptionalDeps` — that answers "is this optional
dependency available?" for every optional dep Sigra guards today, and route every
**runtime** call-site guard through it **without changing runtime behavior** (proven by
the existing dep-off CI lanes staying green).

In scope: the named optional-dep set (Oban, Bcrypt, EQRCode, Threadline, Assent, Swoosh,
Joken, Hammer, Req) and an encryption predicate that mirrors the existing config-driven
stub-vs-real check.

Out of scope: any runtime behavior change in optional-dep handling (REQUIREMENTS.md
Out-of-Scope row); `mix sigra.doctor` (Phase 138, which *consumes* this SOT); compile-time
`defmodule`-wrapping guards (kept literal — see D-04).

**Reality check (HIGH confidence, verified):** `Sigra.OptionalDeps` does NOT exist today.
The v1.21 HARD-02 milestone narrative claimed it shipped; `grep -r "Sigra.OptionalDeps" lib/`
returns zero hits. This phase is a **fresh creation**, not "building on precedent."
(`.planning/research/SUMMARY.md`, Surfaced Inconsistency #2.)
</domain>

<decisions>
## Implementation Decisions

### Module API shape
- **D-01:** `Sigra.OptionalDeps` exposes one **zero-arity predicate per guarded dependency**
  (`oban_available?/0`, `bcrypt_available?/0`, `eqrcode_available?/0`, `threadline_available?/0`,
  `assent_available?/0`, `swoosh_available?/0`, `joken_available?/0`, `hammer_available?/0`,
  `req_available?/0`), each a thin wrapper over `Code.ensure_loaded?(TheModule)`. **Not** a single
  `available?(dep_atom)` dispatcher. OD-01's "or equivalent" is satisfied by the per-dep form.
  - *Rationale:* OD-01 literally enumerates "per-dependency `available?/0`"; every existing guard
    is per-module zero-arity (`crypto.ex:244`, `mfa.ex:1059`, `jwt/signer.ex:18`, `plug/rate_limit.ex:85`,
    the five `oauth/strategies/*.ex` Assent guards). A dispatcher would invent a name→module mapping
    (its own drift surface) and fail silently (`false`) on a typo'd atom instead of at compile time.
- **D-02:** Module lives at `lib/sigra/optional_deps.ex`, top-level under `Sigra.`, sibling to
  `lib/sigra/rate_limiter.ex`.
- **D-03:** Predicates are pure, side-effect-free, **un-memoized** thin wrappers — preserving the exact
  semantics of the inline `Code.ensure_loaded?` checks one-to-one (this one-to-one mapping is what makes
  OD-02's "no runtime behavior change" provable). No caching: a dep may be loaded later in dev/test.

### Compile-time vs runtime guard treatment
- **D-04:** The `defmodule`-wrapping guards stay **literal `Code.ensure_loaded?`** and do NOT delegate:
  `lib/sigra/workers/{account_deletion,audit_cleanup,audit_forward,cleanup_expired_invitations,email_delivery,token_cleanup}.ex:1`
  (`if Code.ensure_loaded?(Oban.Worker) do`) and `lib/sigra/audit/forwarders/threadline.ex:1`
  (`if Code.ensure_loaded?(Threadline) do`). Only **in-function-body / runtime** guards delegate to the SOT.
  - *Rationale:* these execute at module-compile time, when `Sigra.OptionalDeps` may not yet be compiled —
    a compile-ordering hazard (and near-circular, since the SOT references the very modules they gate).
    `audit/forwarders.ex:133-137` already uses `apply/3` + `no_warn_undefined` specifically to avoid
    compile-time coupling (cites D-18). Routing a `defmodule` guard through a function call buys nothing
    and risks a non-deterministic `mix compile` skip — a runtime-behavior change, the opposite of OD-02.
- **D-05:** SC#2's "all guards delegate" is **scoped to runtime call-site guards**. The compile-time
  wrappers are documented as out-of-scope-for-delegation in the phase notes and the `Sigra.OptionalDeps`
  `@moduledoc`, so the scope narrowing is legible to future maintainers and to the Phase 140 verifier.

### Scope boundary & compound guards
- **D-06:** Compound guards delegate **only the load half**; the liveness/arity half stays at the call site:
  - `lib/sigra/delivery.ex:114` and `lib/sigra/audit/forwarders.ex:99`
    → `Sigra.OptionalDeps.oban_available?() and Process.whereis(Oban) != nil`
  - `lib/sigra/enterprise_connections/validation.ex:91`
    → `Sigra.OptionalDeps.req_available?() and function_exported?(Req, :get, 1)`
  - `lib/sigra/account/deletion.ex:307-308` — delegate each `Code.ensure_loaded?` leg of its `with`.
  - *Rationale:* `delivery.ex:110-115` and `forwarders.ex:80-101` carry explicit comments that the
    liveness check is a *separate* concern. If the SOT swallowed the whole expression, an app that adds
    `:oban` to mix.exs but never supervises it would flip `:sync`→`:async` and crash on insert — the exact
    regression those comments exist to prevent.
- **D-07:** **Encryption gets no `cloak_available?/0` load predicate.** Encryption is gated by the
  config-driven `__sigra_encryption_mode__/0` stub-vs-real check (`application.ex:185-206` `verify_vault!`),
  NOT `Code.ensure_loaded?(Cloak)`. Any encryption predicate the SOT exposes for OD-01's "cloak/encryption"
  must **mirror the stub-mode check** (e.g. an `encryption_active?/1` that takes host config), not invent a
  load check.
  - *Rationale:* a `cloak_available?/0` load check would report "available" while an app is still on the
    plaintext stub — a silent security-posture regression.
- **D-08:** Out of scope (NOT delegated): the dynamic-module guards on variables
  (`Code.ensure_loaded?(schema|repo_module|module)` in `admin/audit/export.ex`, `admin/users/*.ex`,
  `install.ex`, `application.ex`, `audit_forward.ex`), the 2 Credo-check wrappers, and the 2 test-helper
  guards (`fixture.rebless_golden.ex:86`, `testing.ex` Swoosh). These guard dynamic modules or tooling,
  not the named optional-dep set.
- **D-09:** In-scope genuine optional-dep guard count is **≈14 sites** (across crypto, mfa, jwt, plug, the
  5 oauth strategies, delivery, forwarders, deletion, validation) — NOT the ~29/44 a naive
  `grep "Code.ensure_loaded?"` returns. Planning should enumerate the exact set, not anchor on the grep total.
- **D-10:** The `mix.exs` `no_warn_undefined` whitelist (~lines 65-91) is **unchanged**. `Code.ensure_loaded?/1`
  inside `Sigra.OptionalDeps` takes a module atom, not a direct call, so it generates no compile warnings and
  adds no new whitelist entries. (Verified by the analyzer.)

### Claude's Discretion
- Exact wording of the `@moduledoc` scope note (D-05), test-file layout for the SOT unit tests, and whether
  the encryption predicate (D-07) is named `encryption_active?/1` or similar — all left to the planner,
  consistent with the repo METHODOLOGY's decisive-defaulting + escalation-threshold lenses (these are
  internal-structure choices below the escalation bar).

### Folded Todos
None — the 2 pending todos (`2026-05-28-phase-134-*`, `2026-05-28-phase-135-*`) are recipe/Threadline-demo
scoped, unrelated to optional-dep consolidation.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/REQUIREMENTS.md` — OD-01, OD-02, and the Out-of-Scope row "Any runtime behavior change in optional-dep handling"
- `.planning/research/SUMMARY.md` — Surfaced Inconsistency #2 (`Sigra.OptionalDeps` does NOT exist; HIGH confidence)
- `.planning/METHODOLOGY.md` — Decisive Defaulting + Escalation Threshold lenses (applied below)
- `lib/sigra/rate_limiter.ex` + `lib/sigra/rate_limiters/{hammer,noop}.ex` — behaviour+impl+Noop triad precedent for module shape/location
- `lib/sigra/application.ex:68-88` (boot-warning pattern) and `:172-206` (`verify_vault!` encryption gating, D-07)
- `lib/sigra/audit/forwarders.ex:80-101,133-137` — compound-guard split + `apply/3`+`no_warn_undefined` compile-coupling-avoidance precedent (D-04)
- `mix.exs:65-91` — `no_warn_undefined` whitelist (D-10, unchanged)

No external specs — requirements fully captured in decisions above.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Behaviour+impl+Noop triad** (`rate_limiter.ex` + `rate_limiters/{hammer,noop}.ex`) — pattern + location
  precedent for the new top-level `Sigra.OptionalDeps` module.
- **Boot-warning precedent** (`application.ex:68-88`, e.g. `maybe_warn_audit_cleanup_fallback/0`) — the
  established way Sigra surfaces optional-dep state at boot; the SOT predicates can feed these.
- **Compile-coupling-avoidance precedent** (`audit/forwarders.ex:133-137`: `apply/3` + `@worker_module` +
  `no_warn_undefined`) — confirms the repo already treats compile-time module references as a distinct,
  carefully-handled category (grounds D-04).

### Established Patterns
- All current optional-dep guards are **per-module, zero-arity `Code.ensure_loaded?(Mod)`** checks (grounds D-01).
- Two distinct guard categories already exist in the code and must be preserved: **compile-time `defmodule`
  wrappers** (workers, threadline forwarder) vs **runtime in-body guards** (crypto/mfa/jwt/plug/oauth).
- Compound guards deliberately split **load-check** from **liveness/arity-check**, with inline comments
  documenting the liveness half as a separate concern (grounds D-06).
- Encryption is gated by **host config** (`__sigra_encryption_mode__/0` stub-vs-real), not module load (grounds D-07).

### Integration Points
- Runtime guard call sites that will delegate: `crypto.ex:244` (Bcrypt), `mfa.ex:1059` (EQRCode),
  `jwt/signer.ex:18` (Joken), `plug/rate_limit.ex:85` (Hammer), `oauth/strategies/{generic,google,facebook,github,apple}.ex` (Assent),
  `delivery.ex:114` + `audit/forwarders.ex:99` + `account/deletion.ex:307-308` (Oban, load-half only),
  `enterprise_connections/validation.ex:91` (Req, load-half only).
- Phase 138 (`mix sigra.doctor`) is the downstream **consumer** of this SOT (per ROADMAP dependency).
- Proof surface: the existing **dep-off CI lanes** must stay green — that is the OD-02 no-behavior-change proof.
</code_context>

<specifics>
## Specific Ideas

No specific requirements beyond the decisions above — the phase is a tightly-scoped internal refactor.
All decisions were confirmed as-presented (no corrections), consistent with the repo's decisive-defaulting methodology.
</specifics>

<deferred>
## Deferred Ideas

- **`mix sigra.doctor`** — Phase 138 (consumes this SOT). Not in 137.
- **Memoizing/caching availability** — explicitly rejected (D-03) to preserve exact semantics; revisit only
  if a measured hot-path cost ever appears (none expected).
- **A single `available?(dep_atom)` dispatcher** — rejected (D-01); could be reconsidered only if the dep set
  grows large enough to warrant a registry, which is not the case today.

### Reviewed Todos (not folded)
- `2026-05-28-phase-134-recipe-residual-findings.md` — recipe/sister-repo scope, unrelated to optional deps.
- `2026-05-28-phase-135-review-deferred-findings.md` — Threadline demo polish, unrelated to optional deps.
</deferred>
