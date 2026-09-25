# ADR 003: Hex package version must never be derived from arbitrary git tags; no milestone `vX.Y` tags in the `v1.*` namespace

**Status:** Accepted
**Date:** 2026-07-11
**Context:** Phase 223 (v1.45 RELEASE-CURRENCY) — root-causing the stray Hex `1.20.0` release before deferring its retire.

## The footgun (what actually went wrong)

Sigra used **two different meanings for `v1.*` git tags in the same namespace**:

- **Milestone tags** — two-component `vMAJOR.MILESTONE` (e.g. `v1.20`, `v1.21`, … `v1.35`),
  minted by the old `/gsd-complete-milestone` close flow to mark a milestone. These are
  *not* package versions.
- **Hex release tags** — semver `vMAJOR.MINOR.PATCH` (e.g. `v1.0.0`, `v1.1.0`, `v1.3.0`),
  the actual published package versions.

An **early, naive publish pipeline derived the Hex package version from any pushed `v*`
tag** (normalizing `v1.20` → `1.20.0`). When milestone `v1.20` was pushed, that pipeline
published a phantom Hex package **`1.20.0`** (same family as the earlier phantom `1.32.0`).

Because `1.20.0 > 1.3.0` by SemVer, Hex reports `latest_stable_version = 1.20.0`, so a real
adopter's `{:sigra, "~> 1.0"}` resolves to the **phantom**, not the real GA. Hex forbids
deletion after the grace window, so the only lever is `mix hex.retire` (reversible via
`--unretire`) — an interactive, write-authed step that has been repeatedly deferred (see the
retire todo). Low stakes today because there are no real adopters yet.

## Decision — guardrails to preserve (do NOT regress these)

1. **Publishing is Release-Please-driven.** The Hex version comes from Release Please's
   Release PR (conventional commits → `steps.release.outputs.version`), never from an
   arbitrary tag push. See `.github/workflows/release-please.yml`.
2. **No `on: push: tags: 'v*'` publish trigger, ever.** The only other publish path,
   `.github/workflows/hex-publish.yml`, is `workflow_dispatch`-only and requires an
   **explicit `release_version` input** that must match `@version` in `mix.exs` at the ref.
   A tag alone can never cause a publish.
3. **Do not mint milestone `vX.Y` git tags.** ~~Milestone tagging was stopped after `v1.35`
   precisely to eliminate the namespace collision.~~ **Corrected 2026-09-17 — that sentence was
   false when written and is retracted here rather than left standing; see the amendment below.**
   Milestone tagging did not stop: `v1.47` and `v1.48` were both minted *after* this ADR's own
   date. If milestone marking is ever wanted again, use a **distinct namespace** (e.g.
   `milestone/v1.36`), never bare `v1.36` — and that convention is now enforced server-side for
   the `v*` namespace by the `tag-namespace` ruleset, not by this paragraph.

## Status of the residue

The historical footgun is **already structurally closed** (guardrails 1–3 are in place). The
only remaining residue is the already-published phantom `1.20.0` on Hex, whose retire is a
manual operator step **deferred indefinitely** (no adopters; the CI gate is unaffected — the
`SIGRA_UPGRADE_SMOKE_START_VERSION=1.3.0` pin greens it regardless). Tracked in
`.planning/todos/pending/2026-07-03-hex-retire-stray-1-20-0.md`.

## Consequences

- Future releases cannot repeat the phantom-publish even if stray `v*` tags exist.
- Phase 223's PROOF-01 "current on Hex at 1.3.0" bundle cannot be truthfully emitted until
  the phantom is retired; the phase is paused on that deferred operator step rather than
  force-completed.

## Amendment — 2026-09-16 (Phase 238)

Amended in place, dated. **Status stays `Accepted`** — this section corrects and extends the
decision rather than replacing it, and there is no superseding-ADR precedent in
`.planning/decisions/`. The date in this heading is the date the `tag-namespace` ruleset went live;
the deletion it authorised ran the following day.

### Guardrail 3 was factually wrong, and prose is why

Guardrail 3 asserted that milestone tagging "was stopped after `v1.35`". That was already false when
this ADR was written, and it stayed false afterwards. Two more milestone tags were minted **after
this ADR's own date of 2026-07-11**:

- **`v1.47`** — 2026-08-04, local only, never pushed to origin.
- **`v1.48`** — 2026-08-12, which reached origin.

The strikethrough above retracts the claim at its source; this section records why it was wrong. The
lesson is not that someone misbehaved. It is that guardrail 3 was **prose with no enforcement**, and
prose does not stop a close flow that mints tags automatically. An ADR that states a false fact about
the very recurrence it exists to prevent is worse than no ADR: it reads as a closed problem while the
problem keeps happening. Phase 238 replaced the prose with a server-side rule, which is the only part
of this ADR that can actually refuse a tag.

### What was deleted, and where the record lives

On **2026-09-17**, 39 non-SemVer tags were deleted — all of them locally, 21 of them also from
origin. The local tag namespace went from 52 refs to 13 and origin from 33 to 12, each side asserted
set-equal to a keep-set derived from a regex at compare time.

The delete set is **not restated here**. It is the committed allowlist at
**`.planning/decisions/003-tag-delete-list.tsv`** — one row per tag, with a `remote` flag, a class,
a reason, and a `pre_delete_sha` column holding a single value: the dereferenced commit each tag
pointed at (the tag-object names are preserved in that file's comment header). That path sits beside
this ADR rather than under a phase directory precisely because phase directories move at milestone
close and this ADR outlives the phase. The allowlist is the single oracle for the set; every prose
reference, including this one, is a renderer of it.

No tag backing a published GitHub Release or a HexDocs `source_ref` was touched: the release surface
read 12 published releases and 0 drafts both before and after, and the two captures diff empty.

### Prescribed namespaces for future non-release tags

The `v*` namespace means exactly one thing — a published release version. Everything else gets its
own namespace:

- **`milestone/`** — milestone markers (this extends guardrail 3's existing `milestone/v1.36`
  suggestion into a rule).
- **`proof/`** — phase proof tags. This second namespace exists because Phase 238 had to delete
  eleven `phase-238-*` proof tags left behind by an earlier, differently-scoped phase whose number
  collided with this one. Bare `phase-NNN-*` names are ambiguous across milestones; a namespace
  prefix is not.

### What the guard covers — and, plainly, what it does not

The live ruleset is `tag-namespace` (`target: "tag"`, `enforcement: active`, empty `bypass_actors`).
Its committed snapshot is `.github/rulesets/tag-namespace.json`. Its scope is
`conditions.ref_name.include: ["refs/tags/v*"]` minus
`conditions.ref_name.exclude: ["refs/tags/v*.*.*"]`, and its single rule is `creation`.

It **does not cover** anything outside that scope, and the boundary is narrower than it first reads:

- The include pattern is fnmatch with `FNM_PATHNAME`, so `*` does not cross `/`. The `archive/`,
  `milestone/` and `proof/` namespaces are outside the rule entirely. **This ruleset does not prevent
  a future `phase-NNN-*` junk tag.** It guarantees only that the release namespace means one thing.
  Widening it to cover all tags would require a `~ALL` condition, which would put release automation
  and every other tag in scope; that was considered and rejected.
- Within its scope it is a **shape guard, not a version validator**. The exclusion subtracts any name
  carrying two dots, so `v1.2.3.4`, `v1.a.b`, `v1..` and `v...` are all admitted. It **does not
  guarantee** that every `v*` tag on this repository is valid SemVer. What it does block is the
  recurrence class: two-component `vX.Y` names — the shape behind 28 of the 39 deleted tags and both
  post-ADR regressions above.

### Guardrail 2 is unchanged

Nothing in Phase 238 adds a tag-triggered publish path. `hex-publish.yml` remains
`workflow_dispatch`-only with an explicit `release_version` input, and no `on: push: tags:` publish
trigger was introduced. The new ruleset *restricts* tag creation; it does not consume tags. A future
reader should not misread a tag-scoped ruleset as a regression of guardrail 2.

### Dated supersession — a `creation` rule landed where two locked artifacts said otherwise

Recorded 2026-09-17. The rule type is read from the committed snapshot, not from an expectation:
`.github/rulesets/tag-namespace.json` carries exactly one rule, of type `creation`. Two locked source
artifacts specified something else, and both clauses are **superseded** here, explicitly and with a
date, because keeping this rule is defensible but keeping it quietly is not.

**1. Phase 238 CONTEXT D-04 — superseded in its first clause.** D-04's text is absolute: the ruleset
contains *no `creation` rule and no `deletion` rule, ever*. A `creation` rule is exactly what landed.

- *What was built instead of D-04's shape:* `tag_name_pattern` (the Tier-1 mechanism D-04 assumed
  would be available) was rejected by the live API with `HTTP 422 — Invalid rule 'tag_name_pattern'`;
  it is enterprise-gated on this Free-tier repository. The fallback that landed is a `creation` rule
  narrowed by `ref_name.exclude`.
- *Why D-04's objection dissolves under this shape:* D-04 forbade a `creation` rule because one
  scoped to `refs/tags/v*` would block release automation's own `v1.5.1` push. The exclude list
  subtracts every three-segment release name from the ruleset's **scope**, so no rule evaluates a
  release tag at all. That exclusion was proven live, not assumed: a two-component scratch tag push
  was rejected and a three-component one accepted against the active ruleset.
- *What the departure costs:* the rule constrains *creation of names in scope* rather than validating
  a version string, so it admits the four-segment and non-numeric shapes enumerated above.
- *D-04's second clause is untouched.* No `deletion` rule was built. The live ruleset contains no
  rule of type `deletion`, and deleting an in-scope tag was observed to succeed — so the
  delete-deadlock D-06 exists to avoid is still avoided.

**2. ROADMAP Phase 238 SC-1 — its named mechanism is superseded; its observable outcome is not.**
SC-1 names the mechanism literally as an RE2 `tag_name_pattern` rule. Under what landed, that clause
is false as written and is superseded. SC-1's *observable outcome* still holds and was observed: a
two-component scratch name carries one dot, so the three-dot-segment exclusion does not cover it, it
stays in scope, and its creation is refused; a three-component release name is excluded and accepted.
Mechanism and outcome are different claims, and this amendment records them separately rather than
letting the satisfied one launder the superseded one.

The requirements-file half of this supersession — against REL-01, naming the same two artifacts —
lands in the same commit range. The two halves are one record, not alternatives.
