# Phase 213: Latest-Phoenix Compatibility - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-02
**Phase:** 213-latest-phoenix-compatibility
**Mode:** assumptions
**Areas analyzed:** Button-fix approach, Golden-fixture reconciliation, CI pin removal, Test/verification strategy

## Assumptions Presented

### A. Button-fix approach
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| No template button re-engineering; current templates already 1.8.8-safe (0 `<.button type=>` callsites); verify empirically via install-smoke | Confident (upgraded from Likely after research) | analyzer scan of `priv/templates/sigra.install/` + `test/example/`; research diff of phx installer templates v1.8.5/1.8.7/1.8.8 |
| If a real error surfaces, root cause is Sigra-side; fix via Sigra-owned button in `sigra_auth_components.ex`, never patch host `core_components.ex` | Confident | `core/sigra_auth_components.ex` exists w/ `attr :rest, :global`; philosophy = don't patch host files |

### B. Golden-fixture reconciliation
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Rebless via `mix sigra.fixture.rebless_golden`, commit delta; no hand-editing | Confident | `lib/mix/tasks/sigra.fixture.rebless_golden.ex:59-145` |
| Expected delta limited to config.exs (`root_tag_attribute`, esbuild 4.3.0, NODE_PATH); larger delta = stop & review | Confident | research diff of config.exs.eex v1.8.7 vs v1.8.8; committed fixture has no `root_tag_attribute` today |
| Add `--check` drift-detector CI job | Confident | `rebless_golden.ex:120-145` exits 2 on drift |

### C. CI pin removal
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| 11 pin sites (9 ci.yml, 1 release-please.yml, 1 hex-publish.yml) + CLAUDE.md note | Confident | grep of `phx_new 1.8.7`; CLAUDE.md:210-222 |
| Rebless first, flip pins after, atomically | Confident | unpinning before rebless turns golden jobs red on config byte-diff |

### D. Test/verification strategy
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Three automated gates (golden_diff_test, install-smoke, admin-acceptance-smoke) against ≥1.8.8; zero human UAT | Confident | `install-smoke.sh:~64` (--warnings-as-errors), `admin-acceptance-smoke.sh` boot+Playwright |
| Assert resolved phx.new version in smoke preambles to avoid cached-archive false green | Likely | mitigation for runner archive-cache risk |

## Corrections Made

No corrections — user selected "Yes, proceed" on the assumption set.

## Decisions on Open Forks

### CI pin policy (impactful fork)
- **Original tension:** COMPAT-03 wording ("drop the pin / track current Phoenix") vs CI
  determinism (SEED-004 was caused by an *unpinned* silent upgrade).
- **User decision:** Bump pin to concrete `1.8.8` + add `rebless_golden --check` drift-detector.
  Rejected fully-unpinning. Captured as D-07.

## External Research

- **phx.new button contract (v1.8.5 / 1.8.7 / 1.8.8):** `button/1` is byte-identical across all
  three; `include:` list is `~w(href navigate patch method download name value disabled)` in every
  version; no `attr :type`. `type` is a built-in LiveView global (`@globals` in
  phoenix_component/declarative.ex), present since LV 1.0.0. Conclusion: a stock 1.8.8 button
  accepts `type`, `phx-*`, `data-*`, `name`, `value`, `disabled`, `title`, `id`, `aria-*`, `class`
  — none error. The seed's button-breakage premise is a red herring; any real error would be
  Sigra-side. (Source: raw.githubusercontent.com phoenixframework/phoenix installer templates at
  tags v1.8.5/v1.8.7/v1.8.8; phoenix_live_view declarative.ex @globals history.)
- **config.exs 1.8.7→1.8.8 diff:** 1.8.8 adds `config :phoenix_live_view, root_tag_attribute:
  "phx-r"` block (when `@live`), bumps esbuild `4.1.12`→`4.3.0`, adds esbuild `NODE_PATH` env.
  (Source: phx installer `phx_single/config/config.exs.eex` at v1.8.7 vs v1.8.8.) File template
  also renamed `core_components.ex`→`core_components.ex.eex` starting 1.8.6 (path-only change).
