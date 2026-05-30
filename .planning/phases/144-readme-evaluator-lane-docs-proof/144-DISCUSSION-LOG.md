# Phase 144: README Evaluator Lane & Docs/Proof - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-30
**Phase:** 144-readme-evaluator-lane-docs-proof
**Areas discussed:** README strategy, Guide depth & screenshots, Proof bundle format

---

## README Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Replace entirely | Remove Phoenix scaffold boilerplate; full evaluator-focused content | ✓ |
| Supplement | Add evaluator section on top of existing Phoenix content | |

**User's choice:** Research + one-shot recommendations (all areas)
**Notes:** User requested deep research with subagents across all 3 areas simultaneously,
then a coherent one-shot set of recommendations without requiring the user to pick A/B/C.
Research confirmed that no top auth library retains scaffold boilerplate in example apps;
replace-entirely was the unanimous ecosystem recommendation. Two hexdocs links (top framing
+ bottom "Learn more"), Docker one-liner, credentials table with all 6 personas, explicit
rough-edge trigger instructions for Dave and Frank.

---

## Guide Depth & Screenshots

| Option | Description | Selected |
|--------|-------------|----------|
| All 4 screenshots | Each shows categorically different UI surface (~385KB total) | ✓ |
| Minimum 2 screenshots | Smaller page weight, tighter narrative | |
| Step-by-step tutorial | Numbered steps across the whole guide | |
| Feature-organized sections | Sections by feature area; numbered steps within sections only | ✓ |
| Pure narrative prose | Flowing prose with inline screenshots | |

**User's choice:** Research + one-shot recommendations
**Notes:** All 4 screenshots selected because each covers a distinct UI surface (cheat-sheet,
admin detail, admin list, audit log) — dropping any two would eliminate either the evaluator
entry point or the differentiating audit feature. Feature-organized sections selected because
the guide is a guided tour for evaluators who explore non-linearly, not a recipe for building.
ExDoc assets solution: `:assets` map config in mix.exs + `guides/assets/` directory with
committed PNG copies. Section structure locked: orientation → run → cheat-sheet (screenshot) →
admin (2 screenshots) → audit (screenshot) → rough edges → OAuth → what's next.

---

## Proof Bundle Format

| Option | Description | Selected |
|--------|-------------|----------|
| New VERIFICATION.md | Phase 140/136 pattern; planning-internal; 6 explicit gates | ✓ |
| Append to docs/ga-evidence.md | Publicly shipped via Hexdocs; existing v1.4 router doc | Pointer line only |
| CI-only evidence | No new file; point to CI run URL | |

**User's choice:** Research + one-shot recommendations
**Notes:** Research confirmed no major Elixir OSS lib ships maintainer gate logs to Hexdocs.
VERIFICATION.md is the correct internal proof format (Phase 140 precedent). `ga-evidence.md`
stays a router — gets one new bullet pointer line under "Where to read next", no verbatim
output. 6 gates: full suite, dep-off lane, clean-state mix setup (explicit ecto.drop first),
screenshot file existence, screenshot referenced in guide (separate gate), mix docs --warnings-as-errors.

---

## Claude's Discretion

- Exact prose wording within guide sections (structure locked, sentences are Claude's call)
- Whether Alice gets a named subsection or is handled via orientation paragraph
- Ordering of "What's Next" links in both README and guide
- Minor table/markup formatting choices
- Whether mix.exs docs alias to copy screenshots is added (D-12: committed copies are simpler;
  alias is optional)

## Deferred Ideas

- `mix docs` pre-step alias for screenshot sync — nice-to-have maintainability improvement,
  out of Phase 144 scope
- Mobile/dark screenshot variants — Phase 143 captured chromium desktop only; variants are
  post-milestone polish
- Alice explicit narrative section — acceptable to fold into orientation paragraph if cleaner
