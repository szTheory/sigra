# Sigra Logo Direction Options

These are draft directions for Phase 167. None of them is final. The existing committed logo files remain draft collateral until a direction is selected and ratified.

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
| A. Core Rails | [`option-a-core-rails.svg`](option-a-core-rails.svg) | Strongest continuity with the draft brandbook and most literal architecture metaphor. | May read a little abstract unless paired with the "visible host code" explanation. |
| B. Audit Path | [`option-b-audit-path.svg`](option-b-audit-path.svg) | Best if Sigra wants traceability and audit semantics to lead the identity. | Small nodes can become busy at favicon size. |
| C. Keystone Core | [`option-c-keystone-core.svg`](option-c-keystone-core.svg) | Strong substrate/library metaphor; less generic than a lock. | Keystone shape may need refinement to avoid feeling like construction branding. |
| D. Wordmark Only | [`option-d-wordmark-only.svg`](option-d-wordmark-only.svg) | Lowest abstraction risk and most OSS-maintainer restrained. | Needs a separate favicon mark or very careful rail accent extraction. |
| E. Session Gate | [`option-e-session-gate.svg`](option-e-session-gate.svg) | Most immediately auth-adjacent while still referencing explicit boundaries. | Closest to generic lock/gate territory; use only if recognizability matters more than distinctiveness. |

## Initial Recommendation

Option A is still the best default unless you want the identity to emphasize audit trails over architecture. It is specific to Sigra's hybrid model, simple enough for maintainers to edit, and strong at small sizes.

Option D is the conservative fallback if any symbol feels like over-branding for an OSS library.

Option E is the safest recognizable-auth option, but it is also the most likely to blend into the broader auth/devtools category.

## Next Step

Pick one direction, or give critique like:

- "A, but less abstract"
- "B, but remove nodes"
- "D, but make the favicon from the rails"
- "None; explore a more Elixir/Phoenix-adjacent direction"
