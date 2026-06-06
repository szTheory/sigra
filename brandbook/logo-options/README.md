# Sigra Logo Direction Options

These are the Phase 167 direction-review records. **Option A: Core Rails** was selected and ratified as the final logo direction; the other options remain comparison history.

## Selection Criteria

Use these criteria when choosing or critiquing:

- Does it clearly belong to Sigra's actual architecture: library-owned sensitive core plus generated host-owned Phoenix code?
- Does it avoid generic auth marks: basic locks, shields, hexagons, blue-purple gradients, or abstract node networks?
- Does it work at favicon size and in monochrome?
- Does it feel credible on GitHub, Hex.pm, HexDocs, docs pages, and conference slides?
- Does it create useful design constraints without making future implementation fragile?

## Options

| Option | File | Best case | Risk |
| --- | --- | --- | --- |
| A. Core Rails | [`option-a-core-rails.svg`](option-a-core-rails.svg) | Selected direction. Strongest continuity with the brandbook and most literal architecture metaphor. | Needs the "visible host code" explanation when seen cold. |
| B. Audit Path | [`option-b-audit-path.svg`](option-b-audit-path.svg) | Best if Sigra wants traceability and audit semantics to lead the identity. | Small nodes can become busy at favicon size. |
| C. Keystone Core | [`option-c-keystone-core.svg`](option-c-keystone-core.svg) | Strong substrate/library metaphor; less generic than a lock. | Keystone shape may need refinement to avoid feeling like construction branding. |
| D. Wordmark Only | [`option-d-wordmark-only.svg`](option-d-wordmark-only.svg) | Lowest abstraction risk and most OSS-maintainer restrained. | Needs a separate favicon mark or very careful rail accent extraction. |
| E. Session Gate | [`option-e-session-gate.svg`](option-e-session-gate.svg) | Most immediately auth-adjacent while still referencing explicit boundaries. | Closest to generic lock/gate territory; use only if recognizability matters more than distinctiveness. |

## Ratified Direction

Option A is the ratified direction. It is specific to Sigra's hybrid model, simple enough for maintainers to edit, and strong at small sizes.

Option D is the conservative fallback if any symbol feels like over-branding for an OSS library.

Option E is the safest recognizable-auth option, but it is also the most likely to blend into the broader auth/devtools category.

## Historical Alternatives

Use the remaining options only as history if future work reopens the logo system. Do not treat them as active variants without a new focused decision.
