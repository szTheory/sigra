# Phase 132: Threadline Recipe + Mailglass Cross-Link Recipe - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-27
**Phase:** 132-threadline-recipe-mailglass-cross-link-recipe
**Mode:** assumptions (calibration: `minimal_decisive`)
**Areas analyzed:** Recipe content scope & shape, Frontmatter format, Threadline recipe content boundary, Mailglass recipe wiring pattern, mix.exs ExDoc registration, Failure modes & non-goals content, Sequencing within phase

## Assumptions Presented

### Recipe content scope & shape
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Both recipes follow `companion-oauth-provider.md` template + four contract sections; section order banner → role table → prerequisites → mix.exs snippet → Sigra-side config/mailer → Failure modes → Non-goals → See also. Threadline ~150–220 lines, Mailglass ~80–120 lines. | Confident | `guides/recipes/companion-oauth-provider.md:1-52`; ARCHITECTURE.md:188-196; ROADMAP.md:93; STACK.md:186 |

### Frontmatter format
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Ship `validated_against:` + `last_validated:` as HTML-comment block + human-visible "Validated against: …" line under H1. NOT YAML `---` frontmatter. | Likely | Zero existing guides in `guides/` use YAML frontmatter (grep-verified); ex_doc 0.40.1 (`mix.lock:21`) uses Earmark, which does NOT strip YAML cleanly. |

### Threadline recipe — what's shown on Threadline side
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Show Sigra-side `forwarders:` block + cite `mix threadline.install` and `mix ecto.migrate` as prerequisites. Do NOT include `Threadline.record_action/2` examples, `Threadline.Plug` wiring, or trigger generation — Sigra's forwarder owns those internally. Pin contract via prose: "Sigra invokes `Threadline.record_action/2` per `lib/sigra/audit/forwarders/threadline.ex:290-307`." | Confident | ROADMAP.md:92 ("NO library code edits beyond Phase 131"); Phase 131's `threadline.ex` already wraps `record_action/2`; STACK.md:122 Non-Goal |

### Mailglass recipe — wiring pattern shown
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Host implements `Sigra.Mailer` (`lib/sigra/mailer.ex:1-31`) by delegating into a `MyApp.SigraAuthMailer` that `use Mailglass.Mailable, stream: :transactional` and pipes to `Mailglass.deliver/2`. Explicit that Mailglass sits ABOVE Swoosh, not as a Swoosh adapter. `:transactional` stream required (privacy/security guard). | Confident | `lib/sigra/mailer.ex:1-31`; `deps/mailglass/lib/mailglass.ex:7-11`; `deps/mailglass/lib/mailglass/mailable.ex:30-33`; STACK.md:30 |

### mix.exs ExDoc registration
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Three-block edit to `mix.exs:169-214`: (1) append two `extras:` entries; (2) tighten `Recipes:` regex to `~r{guides/recipes/[^/]+\.md$}`; (3) add `"Companion Libraries": ~r{guides/recipes/companion-libs/.?}` to `groups_for_extras:` before tightened `Recipes:`. | Confident | `mix.exs:213` confirmed greedy-match; ARCHITECTURE.md:179-182; ExDoc `groups_for_extras` first-regex-match-wins semantics |

### Failure modes & non-goals content
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Threadline Failure Modes: (1) dep missing→one-shot warning; (2) `:async`+no-Oban→boot raise; (3) changeset error→`:schema_mismatch`; (4) transient→Oban retries; (5) handler-never-raise operator note. Threadline Non-Goals: not primary audit DB; no `--with-threadline`; no Threadline queries/dashboards in recipe; no forwarder SLA. Mailglass Failure Modes: wrong stream→compile error; adapter unconfigured→`{:error,_}` (not silent); backpressure→queue. Mailglass Non-Goals: no library-resident adapter; no `--with-mailglass`; no Sigra-owned mailable templates. | Confident | Phase 131 CONTEXT.md (D-16, D-20, D-21, D-26); STATE.md scope; STACK.md:14-23, 114-123; deps/mailglass NoTrackingOnAuthStream |

### Sequencing within phase
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Single sequential plan, three internal steps: Threadline.md → Mailglass.md → mix.exs edit + `mix docs --warnings-as-errors` gate. Do NOT parallelize (mix.exs is one edit touching both recipes; parallel plans would race). | Confident | Phase 135 pins against Threadline recipe (canary-first); `mix docs --warnings-as-errors` gate from ARCHITECTURE.md:274 only meaningful once both files exist + registered |

## Corrections Made

No corrections — all assumptions confirmed by user via single "Yes, proceed" response.

## External Research

Not required. Threadline 0.5.0 `record_action/2` surface verified in
`deps/threadline/lib/threadline.ex:13-62` (already exercised by Phase 131's shipped
`lib/sigra/audit/forwarders/threadline.ex:299`). Mailglass 1.0.x `Mailable` + `deliver/2`
surface verified in `deps/mailglass/lib/mailglass.ex:1-120` +
`deps/mailglass/lib/mailglass/mailable.ex:1-80`. hex.pm version pins verified
2026-05-27 in `.planning/research/STACK.md`.
