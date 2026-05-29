# Phase 138: `mix sigra.doctor` Operator Diagnostic - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-29
**Phase:** 138-mix-sigra-doctor-operator-diagnostic
**Mode:** assumptions
**Areas analyzed:** Task structure/shell, Core/shell split & testability, Feature→dep matrix & row granularity, State model (four states) + config seam, Boot-wiring checks (reuse vs reimplement), Exit-code mechanics

## Assumptions Presented

### Task structure / shell
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `use Mix.Task` + `@shortdoc`/`@moduledoc`, OptionParser flags, output via `Mix.shell().info/error` with ANSI-IO-data; no table dep | Confident | `sigra.install.ex:35-37`, `sigra.upgrade.ex:50`, `sigra.gen.oauth.ex:157,333`; `mix.exs:95-129` |
| Run `Mix.Task.run("app.start")` first (live load checks + booted config) | Likely | `optional_deps.ex:66-67,79`; `application.ex:34-37,173-176`; `rebless_golden.ex:51-52` |

### Core / shell split & testability
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Pure `Sigra.Doctor` lib returns structured rows; Mix.Task is thin formatter+exit shell | Confident | `sigra.upgrade.ex:42-48`, `sigra.install.ex:28-34`; CLAUDE.md library-first |
| `Sigra.Doctor` accepts injected predicate/config inputs for unit isolation; task tested via CaptureIO | Likely | `encryption_active?/1` & `verify_vault!/1` take config arg; `forwarders.oban_running?/1` override atom; CaptureIO in `purely_additive_test.exs` |

### Feature → dep matrix & row granularity
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Rows keyed by feature; multi-dep features = one conjunction row | Confident | feature-scoped guards `mfa.ex:1059`, `crypto.ex:244`, `plug/rate_limit.ex:85`, `delivery.ex:114`, `forwarders.ex:99`; phase goal "per feature" |
| Consume `OptionalDeps` predicates directly; never re-grep | Confident | `optional_deps.ex:6-9,55-61` (Swoosh/Req added for doctor) |

### State model + config seam
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Config seam = `:sigra :otp_app` → `otp_app :sigra_config` → feature sub-key | Confident | `application.ex:34-37,94-97,173-176`; `config.ex:31-45` |
| Four states: collapse loaded≈available to 3 + wiring sublayer (analyzer default) | Likely | `optional_deps.ex:79-170` (load-only); Oban loaded-vs-supervised the only finer distinction |

### Boot-wiring checks
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Reuse non-raising predicates (`oban_running?/1`, `encryption_active?/1`); never call raising `verify_vault!`/`attach_forwarders` | Confident | `application.ex:196,140-152`; `optional_deps.ex:198-207`; `forwarders.ex:90` |
| Hard-fail = configured-but-broken only (analyzer default) | Likely | boot-path raise-vs-warn conditions `application.ex:139-152,194-205,108-117` |

### Exit-code mechanics
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Print full report then `exit({:shutdown, 1})`; `Mix.raise` only for usage errors; always-on gate, optional `--quiet` | Likely | `rebless_golden.ex:143`; `sigra.install.ex:81,94`, `sigra.gen.oauth.ex:185` |

## Corrections Made

Two contract-relevant forks were escalated to the user (the rest locked as decisive defaults).
Both were **confirmed in favor of the recommended option** — the recommendation refined, not
overturned, the analyzer's baseline:

### State model (four states)
- **Analyzer baseline:** collapse "loaded"≈"available" → report 3 dep states + separate wiring layer.
- **Refined recommendation (presented & confirmed):** **activity-based 4 states** —
  missing / available (present, unconfigured) / loaded-active (present + configured + wired) /
  configured-but-missing. Honors all four DR-01 labels truthfully by mapping "loaded" onto the
  Oban-supervised / in-use tier.
- **User choice:** "Activity-based 4 states (rec)."
- **Reason:** keeps the operator-facing matrix faithful to DR-01's literal four-state vocabulary.

### Hard-fail boundary
- **Analyzer baseline (Likely):** configured-but-broken only, with a noted alternative of also
  failing on configured-but-missing deps.
- **User choice:** "Configured-but-broken only (rec)."
- **Reason:** keeps doctor green on intentional minimal / dep-off CI lanes; red only on genuine
  wiring breakage. Stricter "fail on configured-but-missing dep" deferred (possible future
  `--strict` flag).

## External Research

None performed — analyzer flagged no gaps. This is internal tooling fully determinable from the
codebase (task idiom, SOT, config seam, boot-wiring predicates, `exit({:shutdown,n})` precedent
all present in-repo).
