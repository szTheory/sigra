---
id: SEED-010
status: deferred
planted: 2026-05-08
planted_during: post v1.24 documentation-gap surfacing
trigger_when: Next docs cycle (likely paired with a v1.x release that adds a new feature surface), OR when adopter feedback indicates onboarding friction
scope: Small to Medium
---

# SEED-010: Architecture and design-principles docs

## Why This Matters

The crash-course conversation (2026-05-08) surfaced two pieces of conceptual content that don't yet have a home in the guides:

1. **The lib+generator hybrid architecture** — what lives in the hex package vs what's generated into the host, why the split exists, and what it implies for upgrades. This is THE architectural idea adopters need before anything else clicks. Today it's only described informally in README sections.

2. **The two recurring design obsessions** — *atomicity* (audit + domain writes co-fate in `Ecto.Multi`) and *operator truth* (UIs don't lie about session/delivery/secret state). These are real differentiators vs Devise/allauth-style libs but appear nowhere in the user-facing docs.

Both are durable conceptual content that would help adopters navigate any feature surface, but they're more general than the existing `flows/` and `recipes/` guides cover. They belong in `guides/introduction/` alongside getting-started and the new terminology guide (quick-win A1).

## When to Surface

Trigger this seed when:

- The next docs cycle ships (likely paired with a v1.x release that adds a new feature surface)
- Adopter feedback indicates onboarding friction or "I don't get the architecture"
- A new contributor is joining and would benefit from this orientation

It should stay deferred during pure feature work; docs cycles are the right window.

## Scope Estimate

Small to Medium:

- `guides/introduction/architecture.md` — the lib+generator split, layer 1 vs 2, with diagram. Source content: the crash-course TL;DR section.
- `guides/introduction/design-principles.md` — atomicity, operator truth, optional-deps-truly-optional, Postgres-by-design. Source content: the crash-course "two obsessions" + "five mental-model anchors" sections.
- ASCII diagram suitable for HexDocs rendering (tested with `mix docs`).
- Cross-link from `guides/introduction/getting-started.md` and `guides/introduction/terminology.md`.

Both files together should fit in 800–1200 words each — concise, scannable, with concrete examples.

## Breadcrumbs

- [`/Users/jon/.claude/plans/so-whats-the-current-dreamy-eich.md`](/Users/jon/.claude/plans/so-whats-the-current-dreamy-eich.md) — earlier crash-course content as the source
- [`README.md`](/Users/jon/projects/sigra/README.md) — current architecture description (informal, scattered)
- [`.planning/PROJECT.md`](/Users/jon/projects/sigra/.planning/PROJECT.md) — north stars and JTBD that frame the design
- [`guides/introduction/`](/Users/jon/projects/sigra/guides/introduction/) — sibling guides this lands alongside
- [`mix.exs`](/Users/jon/projects/sigra/mix.exs) — `groups_for_extras` (lines 205–211); new files auto-appear in Introduction group

## Notes

- Don't over-author. These docs are reference, not narrative. Scannable lists + diagrams + 1-2 line examples beat paragraphs.
- The two-obsessions framing (atomicity + operator truth) is novel positioning; lean into it rather than burying it in generic "design philosophy" prose.
- Pair-review with the EMAIL-RAILS or PK-LIFECYCLE owner so the principles align with what the next milestone reinforces.
