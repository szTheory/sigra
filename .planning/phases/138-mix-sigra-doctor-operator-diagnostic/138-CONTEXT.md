# Phase 138: `mix sigra.doctor` Operator Diagnostic - Context

**Gathered:** 2026-05-29 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Ship `mix sigra.doctor`: a single adopter-facing diagnostic that prints a per-feature
optional-dependency matrix (loaded / available / configured-but-missing / missing) with an
actionable remediation hint per row, validates boot-time wiring for **configured** features
(audit forwarder, async email/audit Oban workers, encryption vault), and exits **non-zero**
when a configured feature is wired wrong — so it doubles as a CI / pre-deploy gate.

In scope: the diagnostic command + its testable core, consuming the Phase 137
`Sigra.OptionalDeps` SOT and the existing non-raising boot-wiring predicates.

Out of scope: any change to `Sigra.OptionalDeps` predicates or to the boot path itself
(Phase 138 is a **read-only consumer** of both); recipe-contract work (Phase 139);
deprecation timelines + milestone proof bundle (Phase 140); auto-remediation / writing to
the host's `mix.exs` or config (doctor reports, it does not fix).
</domain>

<decisions>
## Implementation Decisions

### Task structure & shell
- **D-01:** `Mix.Tasks.Sigra.Doctor` follows the established Sigra task idiom: `use Mix.Task`,
  `@shortdoc` + `@moduledoc`, flag parsing via `OptionParser`, all output through
  `Mix.shell().info/1` and `Mix.shell().error/1` using the `[:green, "...", :reset]`
  ANSI-IO-data form. No raw `IO.puts`, no table/Owl dependency — `Mix.shell()` auto-degrades
  ANSI in non-TTY/CI, so no manual TTY detection.
  - *Evidence:* `lib/mix/tasks/sigra.install.ex:35-37`, `sigra.upgrade.ex:50`,
    `sigra.gen.oauth.ex:157,333`; no table dep in `mix.exs:95-129`.
- **D-02:** Doctor runs `Mix.Task.run("app.start")` before checking deps/config, because
  `OptionalDeps` predicates are live un-memoized `Code.ensure_loaded?` checks and host config
  lives in the booted app env. Without a started app, dep predicates can false-report "missing"
  and config reads come back empty (every feature "not configured" — false negatives).
  - *Evidence:* `optional_deps.ex:66-67,79`; config seam at `application.ex:34-37,173-176`;
    `loadpaths`/`compile` precedent at `sigra.fixture.rebless_golden.ex:51-52`. (No existing
    task uses `app.start` — this is an inference from the live-check requirement, not a copied
    pattern; the planner should confirm `app.start` vs a narrower `compile` during research.)

### Core / shell split & testability
- **D-03:** Diagnostic logic lives in a pure library module **`Sigra.Doctor`** that returns a
  structured result (a list of per-feature row maps/structs carrying `:feature`, `:dep(s)`,
  `:state`, `:hint`, plus a wiring-check result list and an overall ok/fail verdict). The
  Mix.Task is a thin formatter + exit shell over that return.
  - *Rationale:* security/diagnostic logic belongs in the library (ships via `mix deps.update`),
    not the generator/task layer. Mirrors `sigra.upgrade.ex:42-48` → `Sigra.Upgrade.run/1` and
    `sigra.install.ex:28-34` → `Sigra.Install.Runner`. Makes the matrix unit-testable without
    spawning subprocesses.
- **D-04:** `Sigra.Doctor` accepts injected inputs (predicate results and/or host config) so
  matrix and wiring logic are unit-testable independent of the ambient dep tree, since
  `Code.ensure_loaded?` can't be toggled per-test. The Mix.Task is exercised via
  `ExUnit.CaptureIO`; dep-on vs dep-off behavior is asserted against `Sigra.Doctor`'s
  structured return.
  - *Evidence:* `encryption_active?/1` and `verify_vault!/1` already take config as an arg
    (`optional_deps.ex:198`, `application.ex:185`); `forwarders.oban_running?/1` already supports
    an override atom for exactly this test seam (`forwarders.ex:90-99`); CaptureIO precedent in
    `test/sigra/install/purely_additive_test.exs`. Exact injection shape is planner's discretion.

### Feature → dependency matrix & row granularity
- **D-05:** Matrix rows are keyed by **feature**, not by dependency. A feature requiring two
  deps gets one row whose state is the conjunction (async email → Oban + Swoosh; audit
  forwarding → Threadline + Oban). The feature→predicate mapping table lives in `Sigra.Doctor`.
  Feature set: TOTP/MFA (EQRCode), password migration (Bcrypt), OAuth (Assent), rate limiting
  (Hammer), JWT (Joken), async email (Oban + Swoosh), audit forwarding (Threadline + Oban),
  encryption (cloak/vault — config-driven, see D-08), enterprise connections (Req).
  - *Evidence:* guards are feature-scoped — `mfa.ex:1059`, `crypto.ex:244`,
    `oauth/strategies/*.ex`, `plug/rate_limit.ex:85`, `jwt/signer.ex:18`, `delivery.ex:114`,
    `forwarders.ex:99`, `enterprise_connections/validation.ex:91`; phase goal says "per feature."
- **D-06:** Doctor **consumes `Sigra.OptionalDeps` predicates directly** and must NOT call
  `Code.ensure_loaded?` or re-grep guard sites itself — preserving the single source of truth
  Phase 137 established. (`swoosh_available?/0` and `req_available?/0` were added to the SOT
  specifically for doctor's consumption — `optional_deps.ex:55-61`.)

### State model (DR-01 four states)
- **D-07:** The four DR-01 states are given **activity-based** meanings so each is real and
  distinct (rather than collapsing loaded≈available, which `Code.ensure_loaded?` alone would
  force):
  - **missing** — dep absent AND feature not configured.
  - **available** — dep present but the feature is not configured (you *could* use it).
  - **loaded / active** — dep present AND feature configured AND wiring good (actually in use).
    For Oban-backed features this is the *supervised* tier (`Process.whereis(Oban) != nil` /
    `oban_running?/1`), distinct from merely compiled-in.
  - **configured-but-missing** — feature configured but its dep is absent. This is the
    actionable error state and carries the strongest remediation hint.
  - *Rationale:* `OptionalDeps` only does load checks, so the only genuine finer distinction in
    the codebase is Oban *loaded* vs *supervised* (`delivery.ex:114`, `forwarders.ex:99`). The
    activity model maps DR-01's "loaded" onto that supervised/in-use tier, honoring all four
    named states truthfully instead of inventing an unobservable load-vs-available split.
    (User-confirmed, 2026-05-29.)

### Boot-wiring validation (DR-02)
- **D-08:** Wiring validation **reuses existing non-raising predicates** and must NOT call the
  raising boot guards: use `Sigra.Audit.Forwarders.oban_running?/1` (`forwarders.ex:90`), the
  `delivery` Oban-supervision check (`delivery.ex:103-114`), and
  `Sigra.OptionalDeps.encryption_active?/1` (`optional_deps.ex:198`) — the explicit non-raising
  mirror of `verify_vault!/1`. Doctor must NOT invoke `Sigra.Application.verify_vault!/1`
  (raises, would abort the report before the full matrix prints) nor `attach_forwarders`
  (raises ArgumentError on async-without-Oban).
  - *Evidence:* `application.ex:196` (`verify_vault!` raises), `application.ex:140-152`
    (async-forwarder raise), vs `encryption_active?/1` built as the non-raising mirror.
- **D-09 (HARD-FAIL BOUNDARY):** Non-zero exit fires **only for configured-but-broken**
  features — never for a merely-absent dep on an unconfigured feature. The hard-fail set:
  1. audit forwarder configured `dispatch: :async` but Oban not supervised;
  2. async email (`email[:delivery_mode] == :async`) but Oban not supervised;
  3. a feature requiring real encryption is enabled but `__sigra_encryption_mode__ == :stub`
     (mirrors `application.ex:194-205` / `encryption_active?/1`);
  4. a configured forwarder module that is not loaded (mirrors `application.ex:108-117`).
  A configured-but-missing **dep** (e.g. OAuth providers set but Assent absent) is reported as
  an actionable row but is NOT itself a hard-fail in v1 — this keeps doctor green on
  intentional dep-off CI lanes. (User-confirmed "configured-but-broken only," 2026-05-29.)
  - *Rationale:* these are exactly the conditions the boot path treats as raise-vs-warn; failing
    on merely-absent-but-unconfigured deps would make doctor exit non-zero on every minimal
    install, defeating its CI-gate purpose.

### Exit-code mechanics
- **D-10:** On detected misconfiguration, doctor prints the **full** report via
  `Mix.shell().error/1`, then `exit({:shutdown, 1})` (non-zero, no stack trace). `Mix.raise/1`
  is reserved for usage errors (bad flags/args), not app misconfiguration. Non-zero-on-misconfig
  is **always-on**; an optional `--quiet` flag tunes output verbosity, NOT the gate. Do not use
  `System.halt/1` (kills the VM, bypasses `on_exit`, breaks CaptureIO testing).
  - *Evidence:* `sigra.fixture.rebless_golden.ex:143` uses `exit({:shutdown, 2})` for the exact
    "drift detected, fail CI cleanly while still printing" case; `Mix.raise` used strictly for
    usage/refusal errors at `sigra.install.ex:81,94`, `sigra.gen.oauth.ex:185`. (Whether the
    optional flag is `--quiet` vs `--verbose` default, and the exact exit code value, are
    planner's discretion.)

### Claude's Discretion
- Exact output layout of the matrix (column order, grouping, summary footer), remediation-hint
  wording per row, the `Sigra.Doctor` return-struct field names, the injection seam shape for
  testing (D-04), `app.start` vs narrower load (D-02, pending research confirmation), flag
  naming and default verbosity (D-10), and test-file layout — all internal-structure choices
  below the escalation bar (per METHODOLOGY Decisive Defaulting).

### Folded Todos
None.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/REQUIREMENTS.md` — DR-01, DR-02 (the exact four-state vocabulary and the
  "exits non-zero when a configured feature is misconfigured" gate requirement)
- `.planning/phases/137-optional-dependency-source-of-truth/137-CONTEXT.md` — the SOT contract
  doctor consumes (D-01..D-10 there; especially D-06 compound-guard split and D-07 encryption-
  is-config-not-load)
- `.planning/METHODOLOGY.md` — Decisive Defaulting + Escalation Threshold lenses applied here
- `lib/sigra/optional_deps.ex` — the 9 `*_available?/0` predicates + `encryption_active?/1`
  (lines 198-207); the SOT doctor MUST consume
- `lib/sigra/application.ex` — boot-wiring patterns doctor MIRRORS (read-only): forwarder-dep
  warn (93-120), async-forwarder raise (135-169), `verify_vault!` (171-210), config seam (34-37)
- `lib/sigra/audit/forwarders.ex:90-99` — `oban_running?/1` reusable supervision predicate
- `lib/sigra/delivery.ex:103-114` — `oban_running?` async-email supervision check + `delivery_mode` seam
- `lib/sigra/config.ex:31-45,938,1036` — feature sub-key schema, `new!/1`, `oauth_enabled?/1`
- `lib/mix/tasks/sigra.upgrade.ex:42-93` — thin-task-delegates-to-lib idiom
- `lib/mix/tasks/sigra.fixture.rebless_golden.ex:51-52,130-145` — `Mix.Task.run` load +
  `exit({:shutdown, n})` CI-gate precedent
- `test/sigra/upgrade_test.exs:130,245` — task-test patterns (`assert_raise Mix.Error`/RuntimeError)

No external specs — requirements fully captured in decisions above. No external research needed
(internal tooling; analyzer flagged none).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sigra.OptionalDeps` (Phase 137) — 9 `*_available?/0` load predicates + `encryption_active?/1`
  config-driven, non-raising encryption check. Doctor's primary data source.
- `Sigra.Audit.Forwarders.oban_running?/1` — clean boolean supervision predicate with a
  test-override atom; reuse verbatim for audit-forwarder wiring checks.
- `Sigra.Delivery` Oban-supervision check + `delivery_mode` config accessor — reuse for async-
  email wiring checks.
- `Sigra.Config.new!/1` + feature accessors (`oauth_enabled?/1`, etc.) — normalize/read host config.
- Existing `mix sigra.*` tasks — idiom for shell output, ANSI-IO-data, flag parsing, lib delegation.

### Established Patterns
- **Thin task → library logic.** Every Sigra mix task delegates substantive work to a `Sigra.*`
  module; doctor follows suit with `Sigra.Doctor`.
- **Non-raising mirrors of raising boot guards.** `encryption_active?/1` exists precisely so a
  diagnostic can ask the vault question without aborting — doctor leans on this rather than
  re-running `verify_vault!`.
- **Two-hop config read** (`:sigra :otp_app` → `otp_app :sigra_config`) repeated across the boot path.
- **`exit({:shutdown, n})` for clean CI-gate failure** (rebless_golden task) — the model for D-10.

### Integration Points
- New: `lib/mix/tasks/sigra.doctor.ex` (thin shell) + `lib/sigra/doctor.ex` (logic) + tests.
- Reads (does not modify): `Sigra.OptionalDeps`, `Sigra.Audit.Forwarders`, `Sigra.Delivery`,
  `Sigra.Config`, host app env.
- Phase 140 will exercise `mix sigra.doctor` against `test/example/` as part of the proof bundle.
</code_context>

<specifics>
## Specific Ideas

- DR-01's four state labels are a **contract**: the matrix must visibly carry all four
  (missing / available / loaded-active / configured-but-missing) per the activity model in D-07,
  not a reduced three-state set.
- The CI-gate value proposition (DR-02) hinges on doctor being **green on minimal/dep-off
  installs** and red only on configured-but-broken wiring (D-09) — so it can run unconditionally
  in CI without false alarms.
</specifics>

<deferred>
## Deferred Ideas

- **Auto-remediation** (doctor writing fixes into `mix.exs`/config) — out of scope; doctor
  reports, it does not fix. Future consideration if adopter demand surfaces.
- **Failing on configured-but-missing dep** (the stricter hard-fail set, e.g. OAuth configured
  but Assent absent) — explicitly deferred from the v1 gate (D-09) to keep dep-off lanes green;
  could be revisited behind a `--strict` flag in a later milestone if operators want it.

### Reviewed Todos (not folded)
- `2026-05-28-phase-135-review-deferred-findings.md` (score 0.6) — Threadline demo polish +
  upstream note; belongs to the v1.29 demo/recipe surface, not the doctor command. Not folded.
- `2026-05-28-phase-134-recipe-residual-findings.md` (score 0.4) — companion-lib recipe
  sister-repo/version-pin residue; squarely Phase 139 (recipe-contract) territory. Not folded.
</deferred>
