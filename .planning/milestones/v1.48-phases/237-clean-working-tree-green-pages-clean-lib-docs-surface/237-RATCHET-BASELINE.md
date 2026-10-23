---
phase: 237-clean-working-tree-green-pages-clean-lib-docs-surface
plan: 06
kind: ratchet-baseline
owner: Phase 241 (p18 docs-surface ratchet, SURF-04)
---

# Docs-attribute bookkeeping ratchet baseline

This file exists so Phase 241's `p18` monotonic-decrease ratchet has a starting number to
decrease from, not a description. Per D-01, this phase (237) fixed only **4** named dead
`.planning/` references out of the wider surface measured here — the residual below is
deliberately NOT this phase's scope.

**Zero is explicitly not the target for this residual.** The roadmap defines `p18` as a
monotonic-decrease ratchet over the wider benign-phase-mention surface, not a
delete-everything sweep — most of the residual hits are legitimate prose describing why a
design decision was made, which is exactly the kind of rationale this milestone protects
(see the separate security-rationale count below).

## Measured at this commit

Re-run the documentation-attribute bookkeeping scan (the same extractor
`237-RESEARCH.md` §E.6 describes: `@moduledoc`/`@doc`/`@shortdoc`/`@typedoc` heredoc ranges
under `lib/`, matched against the token set `.planning/ | Phase NNN | phase-NN | D-NN | SC-N
| REQ-... | Pitfall N | INV-N | *-PLAN.md | *-CONTEXT.md | *-SUMMARY.md | todos/`) at this
phase's final committed HEAD:

```
$ python3 .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-docs-attribute-scan.py lib
total_hits=337
distinct_sites=254
distinct_files=69
top_files:
  25	lib/sigra/organizations.ex
  15	lib/sigra/admin/components.ex
  13	lib/sigra/auth.ex
  13	lib/sigra/oauth.ex
  12	lib/sigra/audit/forwarders/threadline.ex
  11	lib/sigra/mfa.ex
  11	lib/sigra/workers/audit_forward.ex
  10	lib/sigra/audit.ex
  10	lib/sigra/plug/put_active_organization.ex
  9	lib/sigra/config.ex
  9	lib/sigra/plug/require_membership.ex
  8	lib/sigra/account/deletion.ex
  8	lib/sigra/oauth/callback.ex
  8	lib/sigra/organizations/invitations.ex
  7	lib/sigra/account/password_change.ex
```

| Metric | Value |
|---|---|
| Token-occurrence count | **337** |
| Distinct site count (`file:line`) | **254** |
| Distinct file count | **69** |

**Reproducible command** (this exact invocation, from the repository root, against `lib/`):

```bash
python3 .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-docs-attribute-scan.py lib
```

The script is committed at
`.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-docs-attribute-scan.py`
and takes no arguments beyond the directory to scan; Phase 241 can re-run it verbatim against
a later HEAD and diff the numbers.

### Why this is smaller than `237-RESEARCH.md`'s 348/259/71

`237-RESEARCH.md` §E.2 measured **348 hits / 259 sites / 71 files** before this phase ran.
Plan `237-04` then removed exactly the 4 D-01-named dead `.planning/` references from
`lib/sigra/audit.ex`, `lib/sigra/testing.ex`, and
`lib/mix/tasks/sigra.fixture.rebless_golden.ex` (rewriting the surrounding sentence rather
than deleting it outright in two of the three files). The **337/254/69** figures above are
the same extractor re-run at this phase's final HEAD, so the ~11-hit / ~5-site / ~2-file
delta is that one deliberate, individually-verified prune — not drift, not a different
extractor, and not the ~344-hit residual being silently chipped away here.

### This phase deliberately fixed only 4 named references

The 4 D-01-named references (all inside `@moduledoc`, all confirmed rendering on HexDocs):

- `lib/sigra/audit.ex:5`
- `lib/sigra/testing.ex:1274`
- `lib/mix/tasks/rebless_golden.ex:11`
- `lib/mix/tasks/rebless_golden.ex:13`

The remaining count above (337 hits across 254 sites in 69 files) is the residual this
phase hands to Phase 241's `p18` ratchet. It is overwhelmingly benign prose — phase-history
citations, decision-ID citations, and rationale sentences explaining *why* a design choice
was made — not dead links or broken references. A phase that tried to rewrite all of it
would be doing 71-file low-care prose surgery on a shipped auth library's public API docs,
which is explicitly what `237-RESEARCH.md` §E.2 recommended against.

## Security-rationale comment class (separate count, `lib/`)

So a future ratchet run can tell a genuine bookkeeping decrease from a rationale deletion,
this file also records the **separate, non-overlapping** count of security-rationale
comment lines in `lib/` — the class SC-5 (this phase, via plan `237-04`'s
`237-security-comment-diff-check.sh`) protects from collateral deletion:

```bash
$ rg -n -i "^\s*#.*\b(security|CSRF|enumeration|timing|scope|impersonation)\b" lib/ | wc -l
52
```

**Positive control**, same invocation shape, proving the search machinery and the path both
work (a control that returns a known non-empty count against a known file):

```bash
$ rg -c 'defmodule' lib/sigra/audit.ex
1
```

52 matches the count plan `237-04` recorded after its own edits — no security-rationale line
was lost between that plan's close and this ledger.

## What a later phase should do with this

1. Re-run `python3 .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-docs-attribute-scan.py lib` at the later HEAD.
2. Compare `total_hits` / `distinct_sites` / `distinct_files` against **337 / 254 / 69**. A
   monotonic decrease (or equal) in `total_hits` is the ratchet's pass condition; an increase
   is a regression.
3. Separately re-run the security-rationale count
   (`rg -n -i "^\s*#.*\b(security|CSRF|enumeration|timing|scope|impersonation)\b" lib/ | wc -l`)
   and compare against **52**. A decrease here is NOT automatically good — it must be checked
   against `237-security-comment-diff-check.sh`'s class (or its Phase 241 durable successor)
   to confirm it is a genuine deletion of dead bookkeeping and not a lost rationale sentence.
4. Zero is not the target for either count. The ratchet's job is monotonic non-increase, not
   elimination.
