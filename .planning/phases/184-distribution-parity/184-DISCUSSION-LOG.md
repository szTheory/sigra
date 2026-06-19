# Phase 184: Distribution & Parity - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-13
**Phase:** 184-distribution-parity
**Mode:** assumptions
**Areas analyzed:** Extraction boundary (sg-* vs vt-*), Example consumption mechanism (DIST-04),
DIST-05 parity + DIST-06 styled-host proof wiring

## Pre-work: Roadmap Repair

`init.phase-op 184` returned `phase_found: false` because the v1.39 milestone open wrote the
summary checklist + REQUIREMENTS.md but not the per-phase `### Phase N:` detail sections that
`roadmap.cjs` requires (it emits `malformed_roadmap` when a checklist phase lacks a detail
section). Authored detail sections for all nine v1.39 phases (184–192) from REQUIREMENTS.md and
committed as `docs(roadmap): add Phase 184-192 detail sections for v1.39 DS-COHERENCE` (bf33d711).
After that, `init.phase-op 184` returned `phase_found: true`, slug `distribution-parity`.

## Assumptions Presented

### Extraction boundary (sg-* out, vt-* stays)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `sigra_admin.css` is a selector/token-aware re-section (not line-range cut): carry @layer decl + all `--sg-*` :root tokens + all `@layer sg-*{}` blocks + header comment; drop all `--vt-*` tokens and `.vt-*` rules incl. the "VAULTR HOST APP" block inside `@layer sg-components` | Confident | `app.css` interleaves them: `:root` has `--sg-*`@22 then `--vt-*`@157; `.vt-*` alternates with `.sg-*` ~352–3792 |
| Audit each extracted `sg-*` rule depends only on `var(--sg-*)` — no residual `--vt-*`/daisyUI dependency | Likely (planner must verify) | hosts ship neither vt-* nor daisyUI default.css |

### Example consumption (DIST-04) — stronger-than-auth parity
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Example links `/assets/sigra_admin.css` from a checked-in `test/example/.../sigra_admin.css` byte-guarded ≡ template (checked-in copy, not symlink); `app.css` reduced to vt-*-only | Likely | auth uses checked-in copy + test-guard, body-level `<link>` per `sigra_auth_components.ex:27` |
| This is STRONGER than auth precedent (auth example copy is stale: 12,281 B vs template 19,379 B; only fixture byte-guarded) | Confident | `cmp` of example vs template sigra_auth.css |

### DIST-05 parity + DIST-06 styled proof
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| DIST-05 = new merge-blocking ExUnit byte-compare (template ≡ example) + add to install-golden fixture/manifest so `golden_diff_test.exs` byte-checks host copy | Confident | `core_test.exs:155/:293`, `templates_layout_test.exs:54` analogs |
| DIST-06 = extend existing `generated_admin_playwright_smoke` (`ci.yml:952` / `admin-acceptance-smoke.sh`) + `admin-generated.spec.ts` with a *styled* assertion; not a new lane | Confident | host today ships no admin css (`admin.ex files/1` none; `admin/1` links none) → currently unstyled |
| DIST-02 wiring `{:eex, "admin/sigra_admin.css", "priv/static/assets/sigra_admin.css"}` in `admin.ex files/1`; DIST-03 body-level `<link>` in `def admin/1` | Confident | exact `core.ex` / `sigra_auth_components.ex` analogs |

## Corrections Made

No corrections — user selected "Yes, proceed"; all assumptions confirmed as locked decisions.

## Methodology

**Decisive Defaulting** lens (`.planning/METHODOLOGY.md`) applied: all implementation forks
resolved to a recommended winner from repo evidence, no option menus preserved. The one item
above the escalation threshold — the example≡template byte-parity that changes the generated-host
contract and the honesty of the "no divergent copy" claim (Assumption #2) — was surfaced
explicitly in the confirmation gate rather than auto-defaulted silently.

## External Research

None performed — `needs_research` was empty. The v1.37 auth-CSS distribution precedent plus the
existing smoke job and canary harness provide complete in-repo evidence for every fork.
