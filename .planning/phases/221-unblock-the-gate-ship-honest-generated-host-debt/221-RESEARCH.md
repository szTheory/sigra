# Phase 221: Unblock the Gate + Ship-Honest Generated-Host Debt - Research

**Researched:** 2026-07-10
**Domain:** Release ops (Hex publish/retire semantics + CI gate resolution), installer-template↔example↔golden parity, bash/awk CI guards
**Confidence:** HIGH (live Hex + local repro; the one MEDIUM item is the exact gate-config lever, which is a decision not a fact)

## Summary

The headline finding **contradicts a core CONTEXT assumption and is decisive for planning.** The
upgrade-smoke gate does **not** resolve to `v1.1.0` (as D-02 states) — it resolves to the stray
**`1.20.0`** *today*, and **no combination of {publish v1.2.0, publish v1.3.0, retire 1.20.0} greens
the gate** on its own. I verified this end-to-end against live Hex and by reproducing the exact
`upgrade-smoke.sh` resolution pipeline locally. Reasons: (a) `1.20.0` is published and un-retired;
(b) under `sort -V` it out-ranks `1.2.0` **and** `1.3.0` (`1.20.0` > `1.3.0`); (c) `mix hex.retire`
**leaves `1.20.0` visible** in `mix hex.info`'s "Recent releases" list (Hex annotates retired
versions with `(retired)` rather than hiding them, and in non-TTY CI the line is plain text so the
script's `sed` still captures `1.20.0`); and (d) `1.20.0` cannot be unpublished — the ~1-hour Hex
grace window closed on 2026-04-28. Therefore **greening the gate strictly requires making the smoke
stop resolving to `1.20.0`**, which cannot be achieved by publish/retire alone — it needs either a
pin (`SIGRA_UPGRADE_SMOKE_START_VERSION=1.3.0` in the `upgrade_smoke` job env — an *existing,
sanctioned* override) or a resolution-logic change (exclude retired / use `latest_stable_version`).
This pulls PUB-02/PUB-03/PUB-04 (nominally Phase 223) forward and touches gate config, so it must be
surfaced to the operator. **D-05 already authorizes exactly this** ("unless greening the gate
strictly requires v1.3.0 too, then it's pulled in as a gate dependency, and REQUIREMENTS/ROADMAP
traceability is updated").

The SHIP items are low-risk mechanical mirrors from the example twin + one awk fix, all fully
locally verifiable. All re-bless prerequisites are present on this machine (Elixir 1.19.5, phx_new
1.8.8 archive, live Postgres, `gh` authed as `szTheory`). The golden `organization_settings_live.ex`
fixture is already `type=`-clean — PUB-01 produces **no** golden delta, confirming D-01/D-11.

**Primary recommendation:** Treat PUB-01 as a **release-ops** task, not a source edit. Minimal
honest greening set = **publish v1.2.0 → publish v1.3.0 → retire 1.20.0 → pin the smoke floor to
1.3.0** (or filter retired versions). Do the three SHIP fixes as straightforward example-mirrors +
awk reset, re-bless once at the end. Escalate the PUB-02/03/04 pull-forward + the single gate-config
line to the operator before executing (interactive Hex write-auth is operator-gated by design).

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** The literal PUB-01 instruction (fix `<.button type="submit">` in lib + template +
  example, re-bless golden) is a **no-op** and must NOT be executed as written. Local source is
  already `type=`-free; `lib/sigra_web/live/organization_settings_live.ex` does not exist (org
  settings is template-only). No candidate-side edit changes the smoke outcome.
- **D-02:** Root cause: `upgrade-smoke.sh:117` compiles the newest published series-1 release under
  `--warnings-as-errors`; that release's generated `organization_settings_live.ex` passes
  `type="submit"` to a host `<.button>` with no `attr :type`; `mix sigra.upgrade` is own-your-code
  and never rewrites it, so `:152` also fails. *(Researcher correction: the resolved release is
  `1.20.0`, not `v1.1.0` — see Open Questions Q1 and the Summary.)*
- **D-03:** Resolution = **Option A: publish the already-tagged, `type=`-clean release(s)** so the
  smoke's floor is clean — no gate weakening, no `--warnings-as-errors` relaxation, no
  `sigra.upgrade` codemod. Publish via the ungated `workflow_dispatch` `hex-publish.yml`, dry-run
  first then real.
- **D-04:** **Hard dependency — the version the smoke resolves to must be `type=`-clean.** The stray
  `1.20.0` out-sorts `1.2.0`/`1.3.0`, so publishing `v1.2.0` alone may not green the gate; retire
  `1.20.0` and/or publish `v1.3.0`. Researcher must determine the **minimal** publish/retire set.
- **D-05:** Scope = do the **minimum** to green the gate honestly. Leave the full currency story to
  Phase 223 **unless greening the gate strictly requires `v1.3.0` too** (then pull it in as a gate
  dependency and update REQUIREMENTS/ROADMAP traceability).
- **D-06:** In `priv/templates/sigra.install/core/mfa_settings_live.ex` `save_passkey_name` add
  `scope: socket.assigns.current_scope` to `Auth.rename_passkey/4` + the
  `{:error, :impersonation_forbidden}` clause, mirroring the example twin. Re-bless golden.
- **D-07:** In the same template drop the redundant leading "Delete this passkey?" from the delete
  confirmation **body** (heading keeps it), mirroring the example. Re-bless golden.
- **D-08:** Widen the `--help`/`--print-env` window in `scripts/uat/up.sh:745` (`sed -n '2,25p'`) so
  the `--print-env` line is not clipped — match sibling `scripts/db/up.sh` (`2,30p`) or verify the
  true last-usage line number after any edit. No golden impact.
- **D-09:** In `scripts/ci/app-css-corruption-check.sh` reset `last_was_prop=0` on any `property:`
  opener whose trimmed content already ends in `;`, only set `last_was_prop=1` on a genuine
  multi-line opener.
- **D-10:** Add a **committed regression fixture** (orphan bare value after a `;`-terminated `:root`
  declaration) + a driver asserting exit `1`. Net-new harness. Recommended home `test/fixtures/css/`
  + bash or ExUnit wrapper; final placement planner's discretion.
- **D-11:** Re-bless with `MIX_ENV=test mix sigra.fixture.rebless_golden` (`--check` for drift).
  Requires live Postgres + phx_new 1.8.8 archive. Only SHIP-01 + SHIP-02a change the golden tree;
  PUB-01 produces no golden delta.

### Claude's Discretion
- Exact widened `up.sh` help window bound (D-08); regression-fixture file location + driver style
  (D-10); the precise minimal publish/retire set for D-04/D-05 once the `1.20.0` resolution question
  is answered (**this research answers it — see below**).

### Deferred Ideas (OUT OF SCOPE)
- v1.3.0 publish + full currency proof (PUB-03/05, PROOF-01) → Phase 223 **unless greening the gate
  strictly requires v1.3.0** (this research shows it effectively does — see Open Questions Q2).
- Making the upgrade-smoke gate un-rot-able / PR-visible → Phase 222 (HARD-01/02). Do not solve here.
- IN-01 (org member-list pagination) and IN-03 (`systemicGroup` doc comment) — no requirement.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PUB-01 | Upgrade-smoke `<.button type>` WAE resolved; `ci-gate` green on push-to-`main` | Resolution is a **release-ops** action, not a source edit (D-01). Minimal honest set + the mandatory smoke-floor lever documented in "Standard Stack / Architecture Patterns" and Open Questions Q1/Q2. Golden already clean → no PUB-01 golden delta. |
| SHIP-01 | Installer `scope:` omission on `save_passkey_name` fixed + `impersonation_forbidden` clause, mirrored from twin, golden re-blessed | Exact line-level diff pinned: template `:736` vs twin `:768-787`. Sibling calls already scoped. |
| SHIP-02 | Delete-passkey copy dedupe (template↔example) + `up.sh --help` `--print-env` truncation | Template `:363` vs twin `:385`; `up.sh:745` `2,25p` window analyzed (see SHIP-02b note — not currently clipping, but zero-headroom). |
| SHIP-03 | app.css corruption-guard false-negative fixed (reset `last_was_prop`), proven by a regression case | awk logic at `:118-140` analyzed; exact D-09 patch + fixture/driver recommendation provided. |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Green the release gate (PUB-01) | Hex registry (published artifacts) + CI workflow config | — | The gate reads live Hex state, not the repo tree; the fix lives in what's published + one job env, not candidate source. |
| Installer defense-in-depth (SHIP-01) | Generated host code (installer template) | Library (`Auth.rename_passkey` guard) | The guard is library-owned; the template must *opt in* by passing `scope:`. |
| Copy/DX nits (SHIP-02) | Generated host code + operator tooling (`up.sh`) | — | Cosmetic, host-facing. |
| CSS corruption guard (SHIP-03) | CI script (`app-css-corruption-check.sh`) | Test fixture | A merge-blocking guard + its regression proof. |

## Standard Stack

This is an ops/maintenance phase — no new libraries. The "stack" is the existing release toolchain
and its exact invocations.

### Core (existing tooling, verified this session)
| Tool | Version | Purpose | Notes |
|------|---------|---------|-------|
| Hex client | 2.5.0 | publish / retire / `hex.info` | `[VERIFIED: ~/.mix/archives/hex-2.5.0]` — `format_version` annotates retired versions rather than hiding them (decisive; see Pitfall 1). |
| Elixir / OTP | 1.19.5 / 28.5 | build + re-bless | `[VERIFIED: local]` `.tool-versions` = `elixir 1.19.5-otp-28`, `erlang 28.5`. |
| phx_new archive | 1.8.8 | golden re-bless + smoke scaffold | `[VERIFIED: local]` `mix archive` → `phx_new-1.8.8` installed. Matches CI pin. |
| `gh` CLI | authed as `szTheory` | `workflow_dispatch` for `hex-publish.yml` | `[VERIFIED: local]` `gh auth status` OK. |
| Postgres | reachable (`tmp/db.env` present, `:5432 accepting`) | re-bless + local smoke | `[VERIFIED: local]` |

### The exact publish/retire commands
```bash
# 1. Publish v1.2.0 — dry-run FIRST, then real (idempotency-guarded in the workflow)
gh workflow run hex-publish.yml -f tag=v1.2.0 -f release_version=1.2.0 -f dry_run=true
gh workflow run hex-publish.yml -f tag=v1.2.0 -f release_version=1.2.0 -f dry_run=false
# 2. Publish v1.3.0 (real; workflow verifies mix.exs @version + manifest + provenance at the tag)
gh workflow run hex-publish.yml -f tag=v1.3.0 -f release_version=1.3.0 -f dry_run=false
# 3. Retire the stray 1.20.0 — operator-interactive Hex write-auth (agents cannot do this)
mix hex.user key generate --key-name sigra-retire --permission api   # prompts for hex.pm password
mix hex.retire sigra 1.20.0 invalid \
  --message "Published in error during dev cycle; not a real release — use 1.3.0+"
# reversible: mix hex.retire sigra 1.20.0 --unretire
```
`[VERIFIED: .github/workflows/hex-publish.yml]` — the workflow validates inputs, checks out the tag
ref, verifies provenance (`git rev-list` tag == input ref), compiles `--warnings-as-errors`, runs
`mix test`, builds docs WAE, inspects the package (rejects a packaged `.planning/`), skips if the
version already exists, then dry-run or publish, then polls `hex.pm/api/.../releases/<v>`.

### The mandatory smoke-floor lever (the piece publish/retire alone can't cover)
`upgrade-smoke.sh:73` calls `resolve_latest_sigra_source` = `mix hex.info sigra` → `sed` version
extract → `grep -E '^1\.[0-9]+\.[0-9]+$'` → `sort -V | tail -n1`. With `1.20.0` present this is
**always** `1.20.0`. Lever options (planner picks; escalate to operator):
- **Option 4a (minimal, sanctioned, brittle):** set `SIGRA_UPGRADE_SMOKE_START_VERSION=1.3.0` in the
  `upgrade_smoke` job `env:` in `.github/workflows/ci.yml` (the override at `upgrade-smoke.sh:56-77`,
  which validates the version is published + in-series). One line. Hardcodes a version → rot risk
  that HARD-01 (Phase 222) is chartered to fix. `[VERIFIED: upgrade-smoke.sh:74-77]`
- **Option 4b (correct, arguably 222):** change `resolve_latest_sigra_source` to skip retired
  versions — either grep-strip `(retired)` lines, or resolve from the Hex API
  `latest_stable_version` (which *does* honor retirement). Makes `mix hex.retire 1.20.0` the actual
  lever. Touches gate algorithm → closer to 222's charter; flag the boundary.

## Package Legitimacy Audit

No external packages are added in this phase. All tooling (`hex`, `phx_new`, `gh`) is pre-existing
and locally verified. **N/A — no install step.**

## Architecture Patterns

### The gate-resolution data flow (why publish/retire alone fails)
```
push to main
   └─> ci.yml job `upgrade_smoke` (if: github.event_name != 'pull_request')   [PR-invisible]
         └─> scripts/ci/upgrade-smoke.sh
               ├─ resolve_latest_sigra_source():
               │     mix hex.info sigra
               │       → sed '  <maj.min.pat> ...' → grep '^1\.[0-9]+\.[0-9]+$'
               │       → sort -V | tail -n1        ==>  1.20.0   ◀── STRAY WINS
               ├─ scaffold phx.new app, pin {:sigra, "~> 1.20.0"}, mix sigra.install
               ├─ mix compile --warnings-as-errors      ◀── FAILS: generated org_settings
               │                                             passes type="submit" to <.button>
               └─ (never reached) switch to local path, sigra.upgrade, recompile WAE
   └─> ci.yml job `ci-gate` (needs: upgrade_smoke): a lane result of "success" OR "skipped" passes;
        anything else fails.  On push, upgrade_smoke RUNS → its failure fails ci-gate.
```
`[VERIFIED: ci.yml:629-630,1447-1497 + upgrade-smoke.sh:40-53,116-117]`. On PRs `upgrade_smoke` is
`skipped` → counts as pass, which is exactly why this rotted invisibly (the CONTEXT/todo note).

**Observable greening proof:** `upgrade_smoke` job → `success` on a push-to-`main` run, and
`ci-gate` prints `ci-gate passed: all required release lanes succeeded`. This requires an actual
push/dispatch on `main` — it is **not** provable from a PR or purely locally.

### Pattern: example-twin → template → golden mirror (SHIP-01/02a)
The established parity chain (`reference_installer_template_drift`): the example
(`test/example/.../mfa_settings_live.ex`) is the source of truth; the installer template
(`priv/templates/sigra.install/core/mfa_settings_live.ex`) must match its semantics; the golden
fixture (`test/fixtures/install_golden/tree/.../mfa_settings_live.ex`) is the generated+formatted
snapshot re-blessed via `mix sigra.fixture.rebless_golden`.

**SHIP-01 exact edit** — template `save_passkey_name` (`:728-751`). Current:
```elixir
case Auth.rename_passkey(user, credential_id, nickname || "") do
  {:ok, _passkey} -> ...
  {:error, _reason} ->
    {:noreply, put_flash(socket, :error, "Could not save passkey name. Please try again.")}
end
```
Target (mirror twin `:768-787`): add `scope: socket.assigns.current_scope` to the call and insert an
`{:error, :impersonation_forbidden} ->` clause that flashes
`"You can't change account security settings while impersonating."` **before** the `{:error, _reason}`
catch-all. `[VERIFIED: local grep]` Sibling `disable_mfa`/`regenerate_codes` in the same template
already pass `scope:` (template has `impersonation_forbidden` clauses at `:814` and `:874`) —
`rename_passkey` is the lone gap. Match the template's local `put_flash` style; the golden captures
the formatter output regardless.

**SHIP-02a exact edit** — template delete-confirmation body (`:360-364`):
```elixir
<div :if={@deleting_passkey_id == passkey_param_id(passkey)} ...>
  <p class="text-sm font-semibold text-red-800">Delete this passkey?</p>   # heading — KEEP
  <p class="mt-1 text-sm text-red-700">
    Delete this passkey? You'll still need another sign-in method ...       # body — DROP leading "Delete this passkey? "
  </p>
```
Target body (mirror twin `:385`): `You'll still need another sign-in method before removing your last
recovery option.` (heading unchanged). `[VERIFIED: local]` Note the twin uses `vt-*` classes and a
different wrapper; **mirror the copy, not the classes** — the template's own class names stay.

### Pattern: awk state-machine reset (SHIP-03 / D-09)
`app-css-corruption-check.sh` tracks `last_was_prop`. The false-negative: the `--prop` branch
(`:118-121`) and standard-decl branch (`:124-127`) unconditionally `last_was_prop=1; next` — even
when the declaration is a **complete single-line** `prop: value;`. The next line (an orphan) then
hits the `if (last_was_prop)` continuation branch (`:132-140`) and is treated as a legitimate
multi-line continuation → not flagged. `[VERIFIED: local read + the phase-214 verification note in
the todo]`. **D-09 patch** (both branches):
```awk
if (/^[[:space:]]*--[a-zA-Z]/) {              # and likewise for the word: branch
  if (/;[[:space:]]*$/) last_was_prop = 0     # complete single-line decl → NOT an opener
  else                  last_was_prop = 1     # genuine multi-line opener
  next
}
```

### Anti-Patterns to Avoid
- **Publishing a version > 1.20.0 (e.g. 1.21.0) to out-sort the stray.** Breaks the contiguous
  v1.1.0→v1.2.0→v1.3.0 semver plan and the milestone narrative. Rejected — not among the tagged
  releases; not Option A.
- **Assuming `mix hex.retire` fixes the smoke.** It does not (Pitfall 1). This is the trap the
  CONTEXT's D-04 half-anticipated but under-stated.
- **Blindly copying `2,30p` into `uat/up.sh`** (see SHIP-02b): its comment block ends at line 25, so
  `2,30p` would leak `set -euo pipefail` and code lines into `--help`. Verify the true last comment
  line instead (D-08's own escape clause).
- **Reconstructing `--sg-*` tokens in `app.css`** when fixing the guard — they belong in
  `sigra_admin.css` (the guard's own error message says so).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Re-generate golden fixtures | Manual file edits to `test/fixtures/install_golden/tree/` | `MIX_ENV=test mix sigra.fixture.rebless_golden` | It scaffolds a fresh tmp app, normalizes, replaces the tree, and prints a delta report; hand-editing drifts from the generator and fails `golden_diff_test`. `[VERIFIED: lib/mix/tasks/sigra.fixture.rebless_golden.ex]` |
| Verify golden has no unexpected drift | eyeball `git diff` | `mix sigra.fixture.rebless_golden --check` (exit 2 on drift) | Same drift-detector CI runs at `ci.yml:294`. |
| Publish to Hex | local `mix hex.publish` from a dirty tree | `hex-publish.yml` `workflow_dispatch` (dry-run then real) | Verifies provenance, WAE compile, tests, docs, package contents, idempotency, post-publish index poll. |

**Key insight:** Every golden-touching change must round-trip through the re-bless task, and every
publish must round-trip through the dispatch workflow. Both already exist and are battle-tested.

## Runtime State Inventory

> This phase renames nothing and migrates no data, but it **mutates external registry state** (Hex),
> which is the moral equivalent for a release-ops phase. Reproduced here so it isn't lost.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data (registry) | Hex `sigra` published set: `1.20.0` (2026-04-28, **latest_stable**, un-retired), `1.1.0`, `1.0.0`, `0.3.0`, `0.2.5`, `0.2.4`, `0.2.3`, `0.2.2`, `0.2.0`. `retirements: {}`. `[VERIFIED: hex.pm/api/packages/sigra]` | Publish `1.2.0` + `1.3.0`; retire `1.20.0` (operator write-auth). |
| Live service config | `ci.yml` `upgrade_smoke` job `env:` — the pin lever (Option 4a) would live here, in git. | One-line env add (if Option 4a chosen). |
| OS-registered state | None. | None. |
| Secrets/env vars | `HEX_API_KEY` (Actions secret, read-only; has published before). Interactive retire needs a **write** key minted by the operator. `[VERIFIED: hex-publish.yml:180 + retire todo runbook]` | Operator mints write key for retire only. |
| Build artifacts | Local `phx_new-1.8.8` archive + Postgres present → re-bless runs clean locally. `[VERIFIED: local]` | None. |

**Un-revertability:** `1.20.0` is past the Hex ~1-hour unpublish grace window (published 2026-04-28),
so it is on Hex permanently. `[CITED: retire todo + Hex policy]` Retire is the only lever, and it
does **not** change the smoke's sort (Pitfall 1).

## Common Pitfalls

### Pitfall 1: `mix hex.retire` does NOT remove the stray from the smoke's version list
**What goes wrong:** Retiring `1.20.0` to fix adopter resolution does not change what
`upgrade-smoke.sh` selects — the gate stays red.
**Why it happens:** `mix hex.info` (hex 2.5.0) renders retired versions in "Recent releases" via
`format_version`, which appends `(retired)` rather than filtering: for a retired version it emits
`[:yellow, version, date, " (retired)", :reset]`; for a normal one just `[version, date]`. In the
CI job the output is captured in `$(...)` (non-TTY), so ANSI is disabled and the line is plain
`  1.20.0 (2026-04-28) (retired)` — the script's `sed 's/^  \([0-9.]*\).*/\1/p'` still captures
`1.20.0`, `grep '^1\.[0-9]+\.[0-9]+$'` still matches it, and `sort -V | tail -1` still selects it.
`[VERIFIED: hex 2.5.0 source lib/mix/tasks/hex.info.ex format_releases/format_version + local non-TTY
capture showing no ANSI]`
**How to avoid:** Do not rely on retire for the gate. Use the pin (4a) or the retired-filter (4b).
Retire is still worth doing for **adopter honesty** (fixes `latest_stable_version` and `~> 1.0`).
**Warning signs:** `upgrade_smoke` log line `resolved latest published 1.x series as 1.20.0` after a
retire.

### Pitfall 2: `sort -V` orders `1.20.0` above `1.3.0`
**What goes wrong:** Planners read "1.2.0/1.3.0 are newer than 1.1.0" and assume publishing them
raises the floor above the stray.
**Why:** `sort -V` is numeric-by-component: `1.1.0 < 1.2.0 < 1.3.0 < 1.20.0`. `[VERIFIED: local
`printf '1.2.0\n1.3.0\n1.20.0\n1.1.0\n' | sort -V`]`
**How to avoid:** The floor can only be raised above `1.20.0` by publishing `≥1.21.0` (rejected) or
by excluding `1.20.0` from the input.

### Pitfall 3: SHIP-02b — the `--print-env` line is not actually clipped on current HEAD
**What goes wrong:** Implementing "the line is truncated" literally, then confused when `--help`
already shows it.
**Why:** `uat/up.sh:745` `sed -n '2,25p'` prints lines 2–25 inclusive; the usage block currently
ends **exactly** at line 25 (`--print-env`), so it prints — but with **zero headroom** and no
`# `-strip (sibling `db/up.sh:135` uses `2,30p | sed 's/^# \{0,1\}//'`). `[VERIFIED: local `bash
scripts/uat/up.sh --help` tail shows the `--print-env` line]`
**How to avoid:** Frame the fix as **hardening** (add headroom + optional `# `-strip), and verify the
true last comment line (26 is blank, 27 is `set -euo pipefail`). Recommended: `sed -n '2,26p'` (safe,
stays within block) or add a sentinel; do **not** use `2,30p` (leaks code). Note the discrepancy in
the plan so a verifier doesn't fail an "it was truncated" assertion.

### Pitfall 4: re-bless byte-diffs from the wrong phx_new archive
**What goes wrong:** A non-1.8.8 archive yields spurious golden byte-diffs.
**Why:** Golden is generated against phx.new output; CI pins 1.8.8. `[CITED: CLAUDE.md local-dev
prereqs]`
**How to avoid:** `mix archive.install --force hex phx_new 1.8.8` (already installed here). Re-bless
with `MIX_ENV=test`.

## Code Examples

### Reproduce the exact smoke resolution locally (proves the floor)
```bash
# Source: scripts/ci/upgrade-smoke.sh:44-53
info="$(mix hex.info sigra)"
versions="$(printf '%s\n' "$info" | sed -n 's/^  \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' \
            | grep -E '^1\.[0-9]+\.[0-9]+$')"
printf '%s\n' "$versions" | sort -V | tail -n1     # ==> 1.20.0  (today)
```

### Re-bless + drift-check (SHIP-01/02a)
```bash
# Source: lib/mix/tasks/sigra.fixture.rebless_golden.ex + ci.yml:294
MIX_ENV=test mix sigra.fixture.rebless_golden          # regenerates test/fixtures/install_golden/
MIX_ENV=test mix sigra.fixture.rebless_golden --check  # exit 2 if drift remains
MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs
```

### Regression fixture + driver (SHIP-03 / D-10)
```css
/* test/fixtures/css/orphan_after_terminated_decl.css — must make the guard exit 1 */
:root {
  --vt-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
  0 0 0 1px rgba(0, 0, 0, 0.2);   /* ORPHAN bare value after a ;-terminated decl */
}
```
```bash
# driver (bash): assert exit 1 on the corrupt fixture, 0 on a clean one
if bash scripts/ci/app-css-corruption-check.sh test/fixtures/css/orphan_after_terminated_decl.css; then
  echo "FAIL: guard did not catch mid-block orphan"; exit 1
fi
echo "OK: guard caught mid-block orphan"
```
Recommend a bash driver (`scripts/ci/app-css-corruption-check.test.sh`, mirroring the repo's existing
`*.test.sh` self-tests wired at `ci.yml:139-152`) over ExUnit — the target is a bash script, the repo
already has `settled-findings-lint.test.sh` / `stale-render-guard.test.sh` as precedent, and it keeps
the guard's proof next to the guard.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| CONTEXT D-02: smoke floor = `v1.1.0` | Smoke floor = `1.20.0` (stray out-ranks) | Live Hex, 2026-07-10 | Publishing v1.2.0 alone cannot green the gate. |
| "retire 1.20.0 fixes resolution" (D-04 implied) | Retire fixes *adopter* resolution, NOT the smoke's sort | This research | Gate needs a pin/filter in addition to retire. |

**Deprecated/outdated:**
- Phase 213's note that "`type` is a built-in LiveView global" — **wrong**, do not rely on it
  (CONTEXT code_context confirms).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The generated `organization_settings_live.ex` from published `1.20.0` is what fails the WAE compile (vs some other surface) | Summary/D-02 | Low — the CI error text (`<.button type="submit" ... phx-disable-with="Updating...">`) matches the org-settings template exactly; and v1.2.0/v1.3.0/HEAD templates are all `type=`-clean `[VERIFIED: git show]`. If the failing surface were elsewhere, publishing a clean floor still fixes it. |
| A2 | ANSI is disabled for `mix hex.info` inside the CI `$(...)` capture (so retired lines stay `sed`-visible) | Pitfall 1 | Low — local non-TTY capture emitted no ANSI; CI is also non-TTY. If ANSI *were* on, retired lines would gain color codes and `sed` would *drop* them, making retire sufficient — a strictly *better* outcome, so the recommendation (pin/filter) is safe either way. |
| A3 | v1.2.0 and v1.3.0 tags compile WAE + pass `mix test` + `mix docs` WAE at their refs (hex-publish preflight) | Standard Stack | Medium — they were release-please-cut from green `main`, but the dispatch workflow will hard-fail loudly if not; dry-run v1.2.0 first de-risks this. |
| A4 | `1.20.0` is un-revertable (grace window closed) | Runtime State Inventory | Low — Hex ~1h policy + the retire todo both state deletion is disallowed post-window; published 2026-04-28. |

## Open Questions

1. **Which lever removes `1.20.0` from the smoke's resolution — pin (4a) or retired-filter (4b)?**
   - What we know: publish/retire alone cannot; both levers work; 4a is one env line (sanctioned
     override), 4b edits the resolution algorithm.
   - What's unclear: whether editing `resolve_latest_sigra_source` (4b) crosses into Phase 222's
     "gate hardening" charter enough to defer.
   - Recommendation: **Option 4a for 221** (minimal, uses the existing sanctioned override, no
     algorithm change), and file the durable retired-filter (4b) as a HARD-01/Phase-222 input. If
     the operator prefers not to touch `ci.yml` at all in 221, then 221 cannot green the gate and
     PUB-01 must move with the publish work — escalate.

2. **Does greening strictly require `v1.3.0` (pulling PUB-03 forward), or does `v1.2.0` suffice?**
   - `v1.2.0` alone *would* suffice as a clean floor **if** pinned via 4a (`START_VERSION=1.2.0`).
     But publishing `v1.3.0` too (a) makes adopters current, (b) is the natural pin target, and (c)
     is required for Phase 223 regardless. Recommendation: **publish both v1.2.0 and v1.3.0 now**,
     pin the floor to `1.3.0`, retire `1.20.0`; update REQUIREMENTS/ROADMAP traceability to move
     PUB-02/03/04 into 221 as gate dependencies (D-05 authorizes this). Leave PUB-05/PROOF-01
     (full currency *proof* bundle) in 223.

3. **SHIP-02b widened bound (D-08 discretion):** `2,26p` vs `2,25p`+`# `-strip vs restructure. Low
   stakes; recommend `2,26p` (safe headroom, stays in the comment block).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir/OTP | re-bless, local smoke | ✓ | 1.19.5 / 28.5 | — |
| phx_new archive | re-bless, smoke scaffold | ✓ | 1.8.8 | `mix archive.install --force hex phx_new 1.8.8` |
| PostgreSQL | re-bless, local smoke | ✓ | reachable (`tmp/db.env`) | `scripts/db/up.sh` |
| `gh` CLI (authed) | `workflow_dispatch` publish | ✓ | szTheory | web Actions UI |
| Hex **write** key | retire `1.20.0` | ✗ (local key read-only) | — | **Operator mints interactively** — no fallback; agent-blocked by design |
| Live Hex + push-to-`main` | PUB-01 greening proof | n/a (external) | — | none — proof is inherently CI/registry-side |

**Missing dependencies with no fallback:** Hex write-auth for retire (operator-gated, by design);
observing `ci-gate` green requires an actual push/dispatch on `main`.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (library) + bash `*.test.sh` self-tests (CI guards) |
| Config file | `.github/workflows/ci.yml` (job wiring); `test/sigra/install/golden_diff_test.exs` (golden) |
| Quick run command | `MIX_ENV=test mix sigra.fixture.rebless_golden --check` (golden drift, seconds) |
| Full suite command | `MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PUB-01 | Smoke resolves to a `type=`-clean floor + compiles WAE; `ci-gate` green on push-to-`main` | integration (CI/push) | `scripts/ci/upgrade-smoke.sh` locally (proves compile) + observe `upgrade_smoke`→success on a `main` run | ✅ script exists; ❌ green requires publish+pin+push (not local) |
| PUB-01 (floor) | Resolution no longer lands on `1.20.0` | unit (local) | the `sed/grep/sort` snippet above → expect `1.3.0` | ✅ reproducible locally after publish+pin |
| SHIP-01 | Golden `mfa_settings_live.ex` shows `scope: socket.assigns.current_scope` + `{:error, :impersonation_forbidden}` clause | golden | `MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs` + `grep -n 'scope:\|impersonation_forbidden' test/fixtures/install_golden/tree/.../mfa_settings_live.ex` | ✅ locally verifiable |
| SHIP-02a | Golden delete-copy body matches twin (no leading "Delete this passkey?" repeat) | golden | `grep -n 'Delete this passkey' test/fixtures/install_golden/tree/.../mfa_settings_live.ex` → single occurrence (heading only) | ✅ locally verifiable |
| SHIP-02b | `up.sh --help` prints the full `--print-env` usage line | smoke (bash) | `bash scripts/uat/up.sh --help \| grep -q -- '--print-env'` | ✅ locally verifiable |
| SHIP-03 | Guard exits `1` on the committed orphan-after-`;` fixture; `0` on clean | unit (bash) | `bash scripts/ci/app-css-corruption-check.sh test/fixtures/css/orphan_after_terminated_decl.css` (expect exit 1) | ❌ Wave 0: fixture + driver are net-new |

### Sampling Rate
- **Per task commit:** the requirement's own command above (golden `--check`, the grep, the bash
  driver) — all sub-30s and local.
- **Per wave merge:** `mix test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs` + `bash scripts/ci/app-css-corruption-check.sh` + `bash scripts/uat/up.sh --help`.
- **Phase gate:** the publish/retire/pin sequence on `main`, then observe `upgrade_smoke`→success and
  `ci-gate`→green (operator-driven; the only non-local proof).

### Wave 0 Gaps
- [ ] `test/fixtures/css/orphan_after_terminated_decl.css` — regression fixture for SHIP-03 (D-10).
- [ ] `scripts/ci/app-css-corruption-check.test.sh` (or ExUnit equiv) — driver asserting exit 1;
      wire into `ci.yml` alongside the existing `*.test.sh` self-tests (`ci.yml:139-152`).
- [ ] No framework install needed — ExUnit + bash harness already present.

*(Golden re-bless is not "new tests" — the existing `golden_diff_test.exs` + `rebless_golden --check`
cover SHIP-01/02a once the template edits land.)*

## Security Domain

`security_enforcement` is not disabled; this phase has a genuine security-adjacent surface (SHIP-01
restores impersonation defense-in-depth).

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no (no auth-flow change) | — |
| V4 Access Control | **yes** | SHIP-01 restores the library-level impersonation guard (`Auth.rename_passkey` `forbid_sensitive_operation` only fires when `scope:` is passed) in the generated host; without it, generated apps rely solely on the LV `impersonating?` pre-check. |
| V5 Input Validation | no | — |
| V6 Cryptography | no | — |
| V14 Config / Supply chain | **yes** | Retiring the stray `1.20.0` prevents adopters from silently resolving a non-release; `hex-publish.yml` verifies provenance + rejects a packaged `.planning/`. |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Impersonator renames a victim's passkey (defense-in-depth gap) | Elevation of Privilege | Pass `scope:` so the library guard returns `{:error, :impersonation_forbidden}` (SHIP-01). |
| Adopter `mix deps.update` resolves the stray `1.20.0` instead of GA | Tampering / Spoofing (supply chain) | Retire `1.20.0`; publish the real GA series (fixes `latest_stable_version` + `~> 1.0`). |

## Sources

### Primary (HIGH confidence)
- Live Hex API `https://hex.pm/api/packages/sigra` — releases incl. `1.20.0` (latest_stable), `retirements: {}` (2026-07-10).
- `mix hex.info sigra` (local, non-TTY) — display format + no-ANSI confirmation.
- hex 2.5.0 source `lib/mix/tasks/hex.info.ex` (`format_releases`/`format_version`) — retired versions annotated, not filtered.
- Local repro of `upgrade-smoke.sh:44-53` pipeline → resolves `1.20.0`; `sort -V` ordering confirmed.
- `scripts/ci/upgrade-smoke.sh`, `.github/workflows/ci.yml` (`upgrade_smoke` `:629`, `ci-gate` `:1447-1497`), `.github/workflows/hex-publish.yml` — read in full.
- `priv/templates/sigra.install/core/mfa_settings_live.ex`, `test/example/lib/example_web/live/mfa_settings_live.ex`, golden fixture, `scripts/ci/app-css-corruption-check.sh`, `scripts/uat/up.sh`, `lib/mix/tasks/sigra.fixture.rebless_golden.ex` — read directly.
- Local env probe — Elixir 1.19.5/OTP 28.5, phx_new 1.8.8, Postgres reachable, `gh` authed, golden org-settings `type=`-clean.

### Secondary (MEDIUM confidence)
- Hex ~1-hour unpublish grace policy (`2026-07-03-hex-retire-stray-1-20-0.md` runbook + general Hex policy).

### Tertiary (LOW confidence)
- None material.

## Metadata

**Confidence breakdown:**
- Version-resolution / minimal-set answer: HIGH — reproduced against live Hex + hex client source.
- SHIP-01/02/03 mechanics: HIGH — exact lines read in template, twin, golden, and scripts.
- The specific gate-config lever (4a vs 4b): MEDIUM — a scoping decision (221 vs 222), not a fact; escalate.
- Publish preflight passing at v1.2.0/v1.3.0 refs: MEDIUM — cut from green main, but dry-run confirms.

**Research date:** 2026-07-10
**Valid until:** 2026-07-17 (live Hex state can change the instant a publish/retire runs — re-query before executing).
