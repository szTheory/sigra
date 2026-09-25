---
phase: 237-clean-working-tree-green-pages-clean-lib-docs-surface
reviewed: 2026-09-16T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - lib/sigra/audit.ex
  - lib/sigra/testing.ex
  - lib/mix/tasks/sigra.fixture.rebless_golden.ex
  - mix.exs
  - .gitignore
  - doc/llms.txt
  - guides/introduction/code-walkthrough.md
  - guides/introduction/upgrading-to-v1.10.md
  - guides/introduction/upgrading-to-v1.11.md
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 237: Code Review Report

**Reviewed:** 2026-09-16
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Phase 237 is a docs/repo-hygiene diff (25 insertions, 24 deletions across 9 files): four dead
`.planning/` references stripped from `lib/` documentation attributes, three dead `.planning/`
links removed from two upgrade guides, one Liquid-hostile interpolation rewritten in the
walkthrough, two entries pruned from `skip_undefined_reference_warnings_on`, and two
`.gitignore` adjustments. No executable code changed — every `lib/` edit is inside a
`@moduledoc`/`@doc`/comment, verified line by line against
`git diff 7d7bcf4d^..HEAD`.

**The load-bearing claim verified, with a positive control.** I ran the real gate twice:

- At HEAD: `MIX_ENV=dev mix docs --warnings-as-errors` → **exit 0, 0 warnings**, and `git status`
  stayed clean afterwards (the committed `doc/llms.txt` is byte-identical to regenerated output,
  so the `/doc/*` + `!/doc/llms.txt` re-inclusion does what its new comment claims).
- Positive control: temporarily emptying `skip_undefined_reference_warnings_on` → **exit 1, 10
  warnings**, sourced from exactly these 7 files: `guides/recipes/companion-libs/mailglass.md`,
  `guides/recipes/companion-libs/threadline.md`, `lib/sigra/audit/forwarder.ex`,
  `lib/sigra/audit/forwarders.ex`, `lib/sigra/audit/forwarders/noop.ex`,
  `lib/sigra/audit/forwarders/threadline.ex`, `lib/sigra/workers/audit_forward.ex`.
  `mix.exs` was restored and `git status` re-verified clean.

That is a one-to-one match with the 7 surviving entries: the pruned list is **minimal and
complete** — nothing over-suppressed, nothing now-unsuppressed that breaks the docs build. The
mix.exs change is correct.

**Security:** no security-relevant rationale was dropped. The `testing.ex` rewrite preserves the
full substantive argument (process-dict synthesis of `:audit_schema`, "thin alias", hidden
required options) and only drops the plan-file pointer. `audit.ex` retains the enumeration-
relevant invariants (Multi-not-telemetry, reserved-prefix enforcement). The
`rebless_golden` deletion is pure runbook provenance. No behavior changed anywhere.

What the phase did **not** finish is the dead-`.planning/`-reference sweep itself: the one
surviving reference is the one that escapes into third-party codebases (WR-01).

## Warnings

### WR-01: Dead `.planning/` reference still ships into every adopter's generated app

**File:** `priv/templates/sigra.install/organizations/organizations.ex:59` (mirrored at `test/example/lib/example/organizations.ex:87`)
**Issue:** The phase removed four dead `.planning/` references from `lib/` doc attributes
(`audit.ex`, `testing.ex`, and two in `sigra.fixture.rebless_golden.ex`), leaving `grep -rn
'\.planning/' lib/` empty. But the sweep stopped at `lib/`. One reference survives in
`priv/templates/`, and it is strictly worse than the four that were fixed: `lib/` comments are
read only by Sigra maintainers and hexdocs readers, whereas this one is **copied verbatim into
every host application created by `mix sigra.install --organizations`**:

```elixir
# configured @sigra_org_config. See .planning/phases/16-org-liveviews-switcher/
# 16-CONTEXT.md D-10 / D-11 / D-16 for signatures.
```

An adopter reading their own generated `MyApp.Organizations` is pointed at a path that does not
exist in their repository and never will. This is the exact defect class the phase set out to
eliminate, left in the one location where it reaches strangers. The stale-template hazard is a
known repeat pattern in this project (see the "installer template drift" memory).

**Fix:** apply the same treatment the phase applied to `lib/sigra/testing.ex` — inline the
substance, drop the pointer — in both the template and the hand-maintained example copy:

```elixir
  # `use Sigra.Organizations` above already injects thin delegators for
  # `list_organizations_for_user/1`, `remove_member/2`, and a 3-arg
  # `change_role/3`. The wrappers below route the settings-page and members-list
  # LiveView callers through Sigra.Organizations with the configured
  # @sigra_org_config; see `Sigra.Organizations` for the callee signatures.
```

Verify with `grep -rn '\.planning/' lib/ priv/templates/ test/example/lib/` returning nothing.

### WR-02: v1.10 guide rewrite destroys two pointers and leaves a conditional with no consequent

**File:** `guides/introduction/upgrading-to-v1.10.md:5,9` (same pattern at `upgrading-to-v1.11.md:7`)
**Issue:** Removing the broken relative links was right; replacing them with unnavigable prose was
not, and line 9 is now logically incoherent. Before/after:

- `:5` — "see **[v1.10 adopter scope](../../.planning/v1.10-ADOPTER-SCOPE.md)**" → "see the v1.10
  adopter-scope planning notes." The reader is told a document exists and given no way to reach it.
- `:9` — "If you have not followed **v1.9** audit-atomicity work yet, read the archived roadmap
  **[v1.9 ROADMAP]**" → "If you have not followed **v1.9** audit-atomicity work yet, note that
  **v1.10** builds on that shipped baseline." The imperative was deleted but the conditional clause
  survived, so the sentence now gates a non-action on a precondition: there is nothing for the
  reader who answers "yes, I skipped v1.9" to *do*.

All three targets are real and tracked in this public repo (`.planning/v1.10-ADOPTER-SCOPE.md`,
`.planning/v1.11-TRIAGE.md`, `.planning/milestones/v1.9-ROADMAP.md`), and the repo already has an
established, ExDoc-safe pattern for exactly this case — absolute GitHub blob URLs — used in
`guides/introduction/intermediate-production-path.md:19` and `upgrading-to-v1.12.md:7-8`. A
lossless fix was available and precedented; the diff chose a lossy one.

**Fix:** restore the pointers using the existing absolute-URL convention, and repair the dangling
conditional:

```markdown
For what "first production" is assumed to include in v1.10, see
[v1.10 adopter scope (source)](https://github.com/sztheory/sigra/blob/main/.planning/v1.10-ADOPTER-SCOPE.md).

## After v1.9 (planning milestone)

If you have not followed **v1.9** audit-atomicity work yet, read the archived
[v1.9 ROADMAP](https://github.com/sztheory/sigra/blob/main/.planning/milestones/v1.9-ROADMAP.md) —
**v1.10** builds on that shipped baseline without replacing **v1.8** / **v1.7** doc narratives.
```

Apply the same to `upgrading-to-v1.11.md:7` for the adopter-scope and `v1.11-TRIAGE.md` pointers.
(This re-introduces no docs warning: extras links to absolute URLs are not autolink references,
which is why `upgrading-to-v1.12.md` needs no suppression entry today.)

### WR-03: Walkthrough excerpt now silently diverges from the template it claims to quote

**File:** `guides/introduction/code-walkthrough.md:170-176` vs `priv/templates/sigra.install/core/session_controller.ex:98`
**Issue:** The section is introduced as "The generated controller owns parameter shape, flash
messages, redirects…" and the block is otherwise a verbatim copy of the shipped template. This
diff changed only the guide:

```elixir
query = %{routing_source: "local_policy"}
...
|> redirect(to: ~p"/organizations/#{slug}/sso?#{query}")
```

while the template still emits the inline form
`~p"/organizations/#{slug}/sso?#{%{routing_source: "local_policy"}}"`. The motivation (commit
e0d98092: `{%{` opens a Liquid tag and crashed the Jekyll Pages build) is legitimate and the
behavior is identical — but the guide now shows adopters code that their generated file does not
contain, in a guide whose whole premise is "this is the code you will read."

Nothing guards the divergence: the `@source_anchors` list in
`test/sigra/architecture_guides_contract_test.exs:28-70` pins seven source↔walkthrough line pairs,
and this redirect is not one of them, so the two can drift arbitrarily from here.

**Fix:** keep the Liquid-safe form (Pages was also repointed at `gh-pages` in D-07, but defense in
depth is fine) and make the divergence honest and enforced — either (a) add a one-line note under
the block, e.g. `> The generated file inlines the query map; it is extracted here only so the
docs site renders it.`, or (b) apply the same extraction to
`priv/templates/sigra.install/core/session_controller.ex:59,98` so guide and template match again,
then add a `@source_anchors` entry pinning the shared line.

## Info

### IN-01: mix.exs suppression comment leads with a rationale that no longer applies to any entry

**File:** `mix.exs:190-192`
**Issue:** The rewritten comment opens with "ExDoc only autolinks extras by basename" and then
describes the real reason ("hidden Application helpers and a behaviour callback"). The
basename clause was the justification for the *two removed* entries; the empty-list probe proves
all 10 surviving warnings are hidden-function or undefined-callback references, none of them
basename-autolink. The first clause is now a leftover that mis-explains the list it heads —
the same "false comment" defect 237-05 set out to correct, one clause short.

**Fix:** drop the lead clause: `# ExDoc cannot resolve these references: hidden Application
helpers and a Sigra.Mailer @callback. Verified minimal — emptying this list produces warnings
from exactly these 7 files.`

### IN-02: `audit.ex` moduledoc now cites decision IDs with no resolvable referent

**File:** `lib/sigra/audit.ex:5-9`
**Issue:** The pointer to the 28-decision record was removed, but the bullets it indexed still
cite `(D-01)`, `(D-02)`, `(D-17..D-18)`. On hexdocs these are now bare identifiers a public reader
cannot resolve to anything. `lib/sigra/testing.ex` handled the identical situation correctly in
this same phase — it dropped `D-31` along with the pointer and inlined the reasoning — so the
inconsistency is within the diff itself.

**Fix:** drop the parenthetical IDs and keep the assertions, matching the `testing.ex` treatment:
`- Direct \`Ecto.Multi\` writes — **not** telemetry subscribers` /
`- Public API enforces reserved prefixes; internal …`.

### IN-03: The phase's own anti-regression check is not wired into CI

**File:** phase artifact `237-security-comment-diff-check.sh` (per commit 93f723bb)
**Issue:** The guard that detects security-rationale deletions in comment diffs is explicitly "not
wired into `scripts/ci/prohibitions/` — the durable ratchet is Phase 241's p18 slot" (D-04). It is
a deliberate, documented deferral, so this is not a defect of the phase — but it does mean the
class of regression this phase exists to prevent (comment/doc deletions that quietly take
rationale with them, WR-01/WR-02 being live examples of the adjacent class) has no standing
enforcement between now and Phase 241.

**Fix:** none required in this phase; confirm the Phase 241 p18 slot is filed so the deferral does
not lapse.

---

_Reviewed: 2026-09-16_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
