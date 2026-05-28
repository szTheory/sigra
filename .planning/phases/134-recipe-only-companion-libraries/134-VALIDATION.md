---
phase: 134
slug: recipe-only-companion-libraries
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-28
---

# Phase 134 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> This is a DOCS-ONLY phase — the validation surface is deterministic shell checks
> (`mix docs --warnings-as-errors`, banned-phrase grep, structural-heading grep), not an
> ExUnit suite. The deferred recipe-contract ExUnit fixture is OUT OF SCOPE (Phase 136 may add it).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Shell assertions (`mix docs`, `mix compile`, `rg`/`grep`) — no ExUnit test for docs |
| **Config file** | `mix.exs` `docs/0` (`extras:` + `skip_undefined_reference_warnings_on:` lists) |
| **Quick run command** | `rg -i "seamlessly\|just works\|production-ready out of the box\|the recommended way" guides/recipes/companion-libs/{accrue,lockspire,relyra,rulestead}.md` (MUST return zero matches) |
| **Full suite command** | `mix docs --warnings-as-errors` (MUST exit 0) |
| **Estimated runtime** | ~10-30 seconds |

---

## Sampling Rate

- **After each recipe drafted (per task):** per-file structural-heading check + D-20 banned-phrase grep scoped to that file
- **After the `mix.exs` edit:** `mix compile` clean (catches trailing-comma breakage)
- **Phase gate (pre-commit):** `mix docs --warnings-as-errors` exit 0 + D-20 grep across all four files zero matches
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 134-01-01 | 01 | 1 | RC-03 | — | N/A (docs) | smoke + docs | `test -f guides/recipes/companion-libs/accrue.md && grep -q "^## Failure modes" guides/recipes/companion-libs/accrue.md` | ❌ W0 | ⬜ pending |
| 134-01-02 | 01 | 1 | RC-04 | — | N/A (docs) | smoke + docs | `test -f guides/recipes/companion-libs/lockspire.md && grep -q "companion-oauth-provider" guides/recipes/companion-libs/lockspire.md` | ❌ W0 | ⬜ pending |
| 134-01-03 | 01 | 1 | RC-05 | — | N/A (docs) | smoke + docs | `test -f guides/recipes/companion-libs/relyra.md && grep -q "Sigra.Auth.create_session/4" guides/recipes/companion-libs/relyra.md` | ❌ W0 | ⬜ pending |
| 134-01-04 | 01 | 1 | RC-06 | — | N/A (docs) | smoke + docs | `test -f guides/recipes/companion-libs/rulestead.md && grep -q "RulesteadPolicy" guides/recipes/companion-libs/rulestead.md` | ❌ W0 | ⬜ pending |
| 134-01-05 | 01 | 1 | D-16 | — | N/A (docs) | smoke | `mix compile` (clean — catches comma breakage from the two-block edit) | ❌ W0 | ⬜ pending |
| 134-01-06 | 01 | 1 | RC-03..06 | — | N/A (docs) | grep + docs gate | D-20 banned-phrase grep zero matches AND `mix docs --warnings-as-errors` exit 0 | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `guides/recipes/companion-libs/accrue.md` — covers RC-03 (does not yet exist)
- [ ] `guides/recipes/companion-libs/lockspire.md` — covers RC-04 (does not yet exist)
- [ ] `guides/recipes/companion-libs/relyra.md` — covers RC-05 (does not yet exist)
- [ ] `guides/recipes/companion-libs/rulestead.md` — covers RC-06 (does not yet exist)
- [ ] `mix.exs` two-block edit (D-16) — not yet applied
- No new test-framework install needed (docs-only; shell-check validation).

Per-file structural-heading check (run per recipe):
```bash
for f in accrue lockspire relyra rulestead; do
  p="guides/recipes/companion-libs/$f.md"
  grep -q "^## Failure modes" "$p" && grep -q "^## Non-goals" "$p" \
    && grep -q "^> \*\*Sigra works fully standalone\.\*\*" "$p" \
    && grep -q "validated_against:" "$p" || echo "FAIL: $f missing required section"
done
```

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Prose accuracy / adopter readability | RC-03..06 | Subjective quality of explanation cannot be shell-asserted | Read each recipe end-to-end; confirm the wiring walkthrough is followable and the pinned contract matches the cited line ranges |

*Structural and gate checks are fully automated; only prose-quality review is manual.*

---

## Validation Sign-Off

- [ ] All tasks have an automated shell verify or Wave 0 dependency
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (the four recipe files + mix.exs edit)
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
