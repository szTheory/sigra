# Phase 221: Unblock the Gate + Ship-Honest Generated-Host Debt - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-10
**Phase:** 221-unblock-the-gate-ship-honest-generated-host-debt
**Mode:** assumptions
**Areas analyzed:** PUB-01 (upgrade-smoke button-type blocker), SHIP-01 (passkey scope), SHIP-02 (copy + up.sh help), SHIP-03 (app.css corruption guard), golden re-bless mechanism

## Assumptions Presented

### PUB-01 — upgrade-smoke `<.button type>` blocker
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Literal fix is a no-op; local source already `type=`-free | Confident | Multiline grep 0 matches across lib/priv/templates/example/golden; `lib/sigra_web/live/organization_settings_live.ex` does not exist; quick-fix `260618-fch` |
| Failure originates in published v1.1.0 install output; `sigra.upgrade` never rewrites the user-owned LiveView | Confident | `upgrade-smoke.sh:117` (published-posture `--warnings-as-errors`), `:152` (post-upgrade compile), own-your-code `lib/sigra/upgrade.ex` |
| Gate can green only by publishing a clean floor OR changing gate semantics | Confident | `upgrade-smoke.sh:52` `sort -V \| tail -1`; override validated published-only `:56-77`; `hex-publish.yml` ungated `workflow_dispatch` |
| Stray `1.20.0` out-sorts `1.2.0`/`1.3.0` → publishing v1.2.0 alone may not green the gate | Likely | `series_regex` `^1\.[0-9]+\.[0-9]+$` matches `1.20.0`; `sort -V` ranks it highest |

### SHIP-01 — installer passkey `scope:`
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Mechanical mirror of example twin (add `scope:` + `{:error, :impersonation_forbidden}`), re-bless golden | Confident | template `mfa_settings_live.ex:736` gap; example `:768-787` has both; siblings `disable_mfa`/`regenerate_codes` already pass scope; golden `:733` mirrors bug |

### SHIP-02 — copy + up.sh help
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Drop duplicated "Delete this passkey?" body copy (template `:363`), mirror example `:383`, re-bless | Confident | template repeats heading+body; example deduped; golden `:358/:360` mirrors dup |
| Widen `up.sh` help window `2,25p` → match `db/up.sh` `2,30p` | Likely | `scripts/uat/up.sh:745` window clips `--print-env` line at `:25`; sibling uses `2,30p` |

### SHIP-03 — app.css corruption guard
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Reset `last_was_prop=0` on `;`-terminated single-line decls; add committed regression fixture asserting exit 1 | Confident | `app-css-corruption-check.sh:118-127` unconditional `last_was_prop=1`; continuation branch `:132-137` skips orphan; no existing test harness |

### Golden re-bless
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `MIX_ENV=test mix sigra.fixture.rebless_golden` (`--check` drift); needs `phx_new 1.8.8` pin | Confident | `lib/mix/tasks/sigra.fixture.rebless_golden.ex:17-20`; `golden_diff_test.exs:41`; CLAUDE.md pin note |

## Corrections Made

No corrections to SHIP-01/02/03 or the re-bless mechanism — all confirmed as Confident mechanical
mirrors.

### PUB-01 — escalated strategic fork (above escalation threshold)
- **Finding surfaced:** PUB-01 as literally worded is a no-op; the gate can only be greened by
  publishing a clean release or changing gate semantics — a milestone-ordering + gate-truth decision.
- **Options presented:** (A) publish v1.2.0 now via ungated `hex-publish.yml`; (B) re-scope PUB-01
  to Phase 223; (C) gate-semantics fix in `upgrade-smoke.sh` (222's charter); (D) `sigra.upgrade`
  codemod.
- **User decision:** **Option A — publish v1.2.0 now.** Green the gate honestly with no gate
  weakening, accepting that it pulls Phase 223's publish action (and the stray-`1.20.0` entanglement)
  forward into 221.
- **Reason:** Ship-honest — greens the gate by making the published floor clean rather than
  suppressing the signal or shipping heavy upgrade logic.

## Auto-Resolved

Not applicable (interactive run).

## External Research

None performed — codebase + planning docs answered every question. The published phx.new
`<.button>` `:global` include list (no `type`) was confirmed locally in
`test/example/deps/phoenix/installer/templates/phx_web/components/core_components.ex`.
