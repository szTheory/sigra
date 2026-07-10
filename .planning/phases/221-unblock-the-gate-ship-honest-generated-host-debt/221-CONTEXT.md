# Phase 221: Unblock the Gate + Ship-Honest Generated-Host Debt - Context

**Gathered:** 2026-07-10 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Make the code bound for Hex honest and the release gate green **before anything is published**:
resolve the upgrade-smoke `<.button type>` blocker so `ci-gate` is green on push-to-`main`, and
pay down the generated-host debt that ships to every adopter (passkey `scope:` defense-in-depth,
copy/DX nits, the app.css corruption-guard blind spot).

Requirements in scope: **PUB-01, SHIP-01, SHIP-02, SHIP-03**.

**Explicitly out of scope** (do NOT pull in): IN-01 (bounded org-member-list pagination) and
IN-03 (`systemicGroup` doc-comment wording in `fix-queue-build.mjs`) from the 218 re-review — they
are not covered by any requirement. Full currency proof (v1.3.0 publish, adopter `~> 1.0`
resolution proof, PROOF-01) remains **Phase 223**; release-lane hardening remains **Phase 222**.
</domain>

<decisions>
## Implementation Decisions

### PUB-01 — Green the gate by publishing a clean release, NOT by editing candidate source
- **D-01:** The literal PUB-01 instruction ("fix `<.button type="submit">` in lib + installer
  template + example, re-bless golden") is a **no-op** and must NOT be executed as written. Local
  source is already `<.button type=>`-free (stripped 2026-06-18 by quick-fix `260618-fch`), and
  `lib/sigra_web/live/organization_settings_live.ex` does not exist (org settings is a
  template-only surface). No candidate-side edit changes the smoke outcome.
- **D-02:** Root cause: `scripts/ci/upgrade-smoke.sh:117` compiles the **published-posture** install
  (the newest published series-1 release, currently `v1.1.0`) under `--warnings-as-errors`; that
  release's generated `organization_settings_live.ex` still passes `type="submit"` to a host
  `<.button>` that doesn't declare `attr :type`. `mix sigra.upgrade` is own-your-code and never
  rewrites that user-owned LiveView, so the post-upgrade compile at `:152` also fails.
- **D-03:** **Resolution = Option A: publish the already-tagged, `type=`-clean release(s) to Hex**
  so the smoke's newest-published floor is clean and `ci-gate` greens naturally — **no gate
  weakening, no `--warnings-as-errors` relaxation, no `sigra.upgrade` codemod.** Publish via the
  ungated `workflow_dispatch` `hex-publish.yml` (manual recovery; not gated on `ci-gate`), dry-run
  first then real. (Chosen by Jon over re-scope / gate-semantics-fix / codemod alternatives.)
- **D-04:** **Hard dependency — the version the smoke resolves to must be `type=`-clean.**
  `upgrade-smoke.sh:52` selects `versions | sort -V | tail -n1` over series-1. The stray Hex
  **`1.20.0`** (if published as series-1) out-sorts `1.2.0`/`1.3.0`, so publishing `v1.2.0` **alone
  may not green the gate** — the stray `1.20.0` likely must also be retired (pulls PUB-04 forward),
  and/or `v1.3.0` published. The planner/researcher must determine the **minimal** publish/retire
  set that makes `sort -V | tail -1` land on a clean release. See `<canonical_refs>`.
- **D-05:** Scope boundary for 221's publish work: do the **minimum** to green the gate honestly
  (publish `v1.2.0`; retire the stray `1.20.0` if it blocks resolution). Leave the **full currency
  story** — `v1.3.0` publish for adopter currency, clean `~> 1.0` resolution proof, PROOF-01 — to
  Phase 223 unless greening the gate strictly requires `v1.3.0` too (then it's pulled in as a gate
  dependency, and REQUIREMENTS/ROADMAP traceability is updated to reflect the reordering).

### SHIP-01 — Restore installer passkey-rename defense-in-depth (mechanical mirror)
- **D-06:** In `priv/templates/sigra.install/core/mfa_settings_live.ex` (`~:736`, `save_passkey_name`)
  add `scope: socket.assigns.current_scope` to the `Auth.rename_passkey/4` call and add the
  `{:error, :impersonation_forbidden}` case clause, mirroring the example twin
  `test/example/lib/example_web/live/mfa_settings_live.ex:768-787`. Sibling calls (`disable_mfa`,
  `regenerate_codes`) in the same template already pass scope — `rename_passkey` is the lone gap.
  Re-bless the golden fixture.

### SHIP-02 — Copy/DX nits (mechanical)
- **D-07:** In the same template (`~:363`) drop the redundant leading "Delete this passkey?" from
  the delete-passkey confirmation **body** (heading keeps it), mirroring
  `test/example/.../mfa_settings_live.ex:383`. Re-bless the golden fixture.
- **D-08:** Widen the `--help`/`--print-env` window in `scripts/uat/up.sh:745` (`sed -n '2,25p'`)
  so the `--print-env` usage line (`:25`) is not clipped — match the sibling `scripts/db/up.sh`
  window (`2,30p`) or verify the true last-usage line number after any edit. No golden impact.

### SHIP-03 — Fix the app.css corruption-guard false-negative (test-driven)
- **D-09:** In `scripts/ci/app-css-corruption-check.sh` (`:118-127`) reset `last_was_prop=0` on any
  `property:` opener line whose trimmed content already ends in `;` (complete single-line decl),
  and only set `last_was_prop=1` on a genuine multi-line opener. This closes the false-negative
  where an orphan bare value after a `;`-terminated declaration reads as a continuation.
- **D-10:** Add a **committed regression fixture** (a small `.css` with an orphan bare value right
  after a `;`-terminated `:root` declaration) plus a driver that asserts the script exits `1`. The
  script currently has no test harness (invoked only from `.github/workflows/ci.yml`) — the driver
  is net-new. Recommended home: `test/fixtures/css/` + a bash or ExUnit wrapper; final placement is
  the planner's discretion.

### Golden re-bless mechanism
- **D-11:** Re-bless with `MIX_ENV=test mix sigra.fixture.rebless_golden` (drift-check:
  `--check`). Requires live Postgres and the **`phx_new 1.8.8`** archive pinned locally
  (`mix archive.install --force hex phx_new 1.8.8`) to avoid spurious byte-diffs. Only SHIP-01 and
  SHIP-02a change the golden tree; PUB-01 produces **no** golden delta (already clean).

### Claude's Discretion
- Exact widened `up.sh` help window bound (D-08); regression-fixture file location + driver style
  (D-10); the precise minimal publish/retire set for D-04/D-05 once the researcher resolves the
  `1.20.0` version-resolution question.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/todos/pending/2026-07-10-upgrade-smoke-button-type-hex-publish.md` — PUB-01 origin, the failing error, publish deadlock, `hex-publish.yml` dispatch commands
- `.planning/todos/pending/2026-07-09-218-rereview-followups.md` — SHIP-01 (WR-01), SHIP-02a (WR-02), SHIP-02b (IN-02) exact findings + example-twin references
- `.planning/todos/pending/2026-07-02-app-css-corruption-guard-blind-spot.md` — SHIP-03 root cause + suggested fix + fixture guidance
- `.planning/todos/pending/2026-07-03-hex-retire-stray-1-20-0.md` — the stray `1.20.0` (D-04 dependency)
- `scripts/ci/upgrade-smoke.sh` — version resolution (`:41-53`, `sort -V | tail -1`), the two `--warnings-as-errors` compiles (`:117`, `:152`), `SIGRA_UPGRADE_SMOKE_START_VERSION` override (published-only, `:56-77`)
- `.github/workflows/hex-publish.yml` — ungated `workflow_dispatch` publish path (`tag` + `release_version` + `dry_run`)
- `.planning/REQUIREMENTS.md` — PUB-01/SHIP-01/02/03 acceptance text; PUB-02..05 (Phase 223) for the reordering awareness
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Example twin is the source of truth** for SHIP-01/02a mirrors:
  `test/example/lib/example_web/live/mfa_settings_live.ex` (rename-with-scope `:768-787`,
  deduped delete copy `:383`). The `test/example` ↔ `priv/templates/sigra.install` ↔
  golden-fixture parity model is the established mechanism (see `reference_installer_template_drift`).
- **Golden fixtures:** `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/mfa_settings_live.ex`
  (mirrors the buggy `:733` rename + `:358/:360` copy); `.../organization_settings_live.ex` already
  `type=`-clean (no PUB-01 delta). Re-bless task: `lib/mix/tasks/sigra.fixture.rebless_golden.ex`;
  gate test: `test/sigra/install/golden_diff_test.exs` (`:golden`/`:integration`).
- **Sibling `up.sh`:** `scripts/db/up.sh` already uses the wider `2,30p` help window — copy its pattern.

### Established Patterns
- Own-your-code: `mix sigra.upgrade` (`lib/sigra/upgrade.ex`) creates/injects but never overwrites
  user-owned LiveViews — this is *why* PUB-01 can't be fixed candidate-side.
- Published `<.button>` contract: phx.new `CoreComponents.button/1` `attr :rest, :global, include:
  ~w(href navigate patch method download name value disabled)` — `type` is NOT included and
  `:global` does not cover it, so `type=` on `<.button>` is a warnings-as-errors failure. (Phase 213's
  note that "`type` is a built-in LiveView global" is **wrong** — do not rely on it.)

### Integration Points
- `ci-gate` ← `Upgrade smoke (published source → local candidate)` job (push/schedule-only,
  PR-invisible). Greening it depends on the Hex-published floor, not the repo tree.
- `hex-publish.yml` (`workflow_dispatch`) is the ungated escape hatch that breaks the publish
  deadlock; `HEX_API_KEY` is configured and has published before.
</code_context>

<specifics>
## Specific Ideas

- PUB-01 resolution is Option A (publish v1.2.0), explicitly chosen over re-scoping to 223,
  changing gate semantics (222's charter), or a `sigra.upgrade` codemod.
- The stray `1.20.0` `sort -V` interaction is the single most important thing for the researcher to
  resolve first — it determines whether v1.2.0 alone greens the gate or whether the retire/v1.3.0
  must be pulled in.
</specifics>

<deferred>
## Deferred Ideas

- **v1.3.0 publish + full currency proof (PUB-03, PUB-05, PROOF-01)** → Phase 223, unless greening
  the gate strictly requires v1.3.0 as a floor (then pulled in as a gate dependency with
  traceability updated).
- **Making the upgrade-smoke gate un-rot-able / PR-visible** → Phase 222 (HARD-01/02). Do not solve
  it here; Option A deliberately avoids touching gate semantics.
- **IN-01** (org member list >1000 pagination) and **IN-03** (`systemicGroup` doc-comment wording in
  `scripts/ci/fix-queue-build.mjs`) from the 218 re-review — out of scope, no requirement.

### Reviewed Todos (not folded)
- `2026-06-20-mix-sigra-migrate-schema-helper.md`, `2026-06-20-playwright-parallelization-per-shard-db.md`,
  `2026-06-20-runtime-auth-prefix-override.md`, `2026-06-22-white-label-auth-email-theming.md` —
  keyword-matched but unrelated to this phase's scope; left pending.
- `2026-07-03-hex-retire-stray-1-20-0.md` — NOT folded as an independent task, but its subject is a
  D-04 hard dependency for PUB-01; the planner may need to action it here to green the gate.
</deferred>
