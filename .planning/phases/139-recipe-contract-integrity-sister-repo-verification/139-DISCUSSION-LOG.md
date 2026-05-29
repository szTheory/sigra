# Phase 139: Recipe-Contract Integrity & Sister-Repo Verification - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-29
**Phase:** 139-recipe-contract-integrity-sister-repo-verification
**Mode:** assumptions
**Areas analyzed:** RCT-01 fixture, RCV-01 Lockspire contract, RCV-02 Rulestead contract, verification posture & todo disposition

## Analysis note

Sister repos were found resolvable in-tree (`/Users/jon/projects/lockspire` @ v1.2.0 `def616d`,
`/Users/jon/projects/rulestead/rulestead` @ v0.1.3 `0a18360`). Both contracts were therefore
hard-verified directly from primary source during discussion rather than delegated, putting
RCV-01/RCV-02 on the verify path (the "document-the-assumption" fallback is not exercised).

## Assumptions Presented

### RCT-01 — merge-blocking recipe-contract fixture
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| New pure-ExUnit `async: true` test globs `guides/recipes/companion-libs/*.md`, asserts 3 sections + 2 frontmatter markers per recipe | Confident | guides_dx02_test.exs; phase_50_nyquist_docs_contract_test.exs; recipe headers already carry markers |
| Merge-blocking via standard suite (no tag exclusions per CLAUDE.md), no separate CI job | Confident | CLAUDE.md local-prereqs note |

### RCV-01 — Lockspire resolve_account/2 (confirmed real bug)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Contract is `{:ok, account()} \| {:error, :not_found \| term()}` | Confident | account_resolver.ex:17-18; consumers token_exchange.ex:1223, userinfo.ex:147 |
| Recipe's bare user-or-nil at lockspire.md:93 is a real MatchError → fix to tagged tuples | Confident | recipe line 93 vs verified `with {:ok, account} <-` consumers |

### RCV-02 — Rulestead policy @behaviour (todo named wrong module)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Behaviour is `Rulestead.Admin.Policy` (`@callback can?/4 :: boolean()`), NOT `Authorizer` | Confident | policy.ex:121; authorizer.ex:149 only dispatches `policy.can?/4` |
| Recipe should declare `@behaviour Rulestead.Admin.Policy` + `@impl true can?/4` | Confident | recipe rulestead.md:123-145 |

### Verification posture & todo disposition
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Neither contract uses fallback; recipes cite verified version+ref+date | Confident | both repos in-tree |
| `validated_against:` markers already accurate (lockspire ~> 1.2 / rulestead ~> 0.1) | Confident | sister mix.exs 1.2.0 / 0.1.3 |
| IN-01 already resolved — recipes now pin `{:sigra, "~> 0.2"}` (resolves vs hex 0.3.0) | Confident | grep of all six recipes; mix.exs @version 0.3.0 |
| Phase-134 todo folded+closed; Phase-135 & Phase-138 todos reviewed-not-folded | Confident | todo.match-phase scoring + scope read |

## Corrections Made

No corrections — all assumptions confirmed ("Yes, all correct").

One design choice was surfaced (RCT-01 fixture strictness):
- **Choice:** Requirement-exact vs. Strict+drift-tripwires.
- **User selected:** Requirement-exact — assert only the 3 sections + 2 frontmatter markers;
  do NOT assert the sigra version pin or `last_validated:` date-parse. Strict tripwires noted
  as a Deferred Idea.

## External Research

None — codebase + in-tree sister repos provided complete primary-source evidence.
