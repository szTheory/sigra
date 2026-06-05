---
phase: 149
slug: launch-evidence-and-announcement-pack
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-01
---

# Phase 149 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + docs-contract shell checks |
| **Config file** | `mix.exs` + `.github/workflows/ci.yml` |
| **Quick run command** | `mix docs --warnings-as-errors` |
| **Full suite command** | `mix test && mix docs --warnings-as-errors` |
| **Estimated runtime** | ~120 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix docs --warnings-as-errors` or the narrow docs-contract command named by the task.
- **After every plan wave:** Run `mix test && mix docs --warnings-as-errors` plus phase-specific routing and forbidden-claim grep checks.
- **Before `$gsd-verify-work`:** Full suite and all launch-pack contract checks must be green.
- **Max feedback latency:** 180 seconds for local docs-contract checks; CI remains authoritative for final release gates.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 149-01-01 | 01 | 1 | LAUNCH-01 | T-149-01 | Announcement avoids misleading security/compliance claims | docs-contract | `rg -n "non-goals|who should upgrade|who can wait|upgrade|migration|evidence" docs/launch/v1.0/announcement.md` | no, W0 | pending |
| 149-01-02 | 01 | 1 | LAUNCH-02 | T-149-02 | Alternatives page includes boundaries and "when not to choose Sigra" | docs-contract | `rg -n "phx.gen.auth|Pow|Guardian|Ueberauth|hosted auth|when not to choose" docs/launch/v1.0/alternatives.md` | no, W0 | pending |
| 149-02-01 | 02 | 1 | LAUNCH-03 | T-149-03 | Evidence page links proof and states proof boundaries | docs-contract | `rg -n "release-runbook-v1-0|uat-ci-coverage|demo-showcase|limitations|does not prove" docs/launch/v1.0/evidence.md` | no, W0 | pending |
| 149-02-02 | 02 | 2 | LAUNCH-04 | T-149-04 | AI index routes to canonical 1.0 docs without a second policy vocabulary | docs-contract | `rg -n "installation|contract|security|migrating|demo-showcase|launch" doc/llms.txt` | yes | pending |
| 149-03-01 | 03 | 2 | LAUNCH-01, LAUNCH-03, LAUNCH-04 | T-149-05 | Entry points converge on canonical launch docs | docs-contract | `rg -n "docs/launch/v1.0|launch/v1.0" README.md CHANGELOG.md doc/llms.txt mix.exs` | partial | pending |

*Status: pending, green, red, flaky*

---

## Wave 0 Requirements

- [ ] Create `docs/launch/v1.0/announcement.md`, `docs/launch/v1.0/alternatives.md`, and `docs/launch/v1.0/evidence.md`.
- [ ] Add the launch docs to `mix.exs` ExDoc extras/groups after the files exist.
- [ ] Add or document narrow docs-contract checks for required links, required sections, and forbidden overclaim phrases.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Publish-ready announcement tone and audience fit | LAUNCH-01 | Prose quality and launch judgment are not fully machine-verifiable | Read `docs/launch/v1.0/announcement.md` and confirm it is ready to paste or link from the GitHub Release body without editing factual claims. |
| Honest comparison framing | LAUNCH-02 | Boundaries require human judgment against official ecosystem docs | Read `docs/launch/v1.0/alternatives.md` and confirm it does not imply automatic migration, compliance certification, hosted-auth replacement, provider certification, or ecosystem equivalence. |
| Post-publish placeholders remain honest | LAUNCH-03 | Final Hex/GitHub/HexDocs URLs cannot exist before release | Confirm placeholders are clearly labeled and limited to final Hex visibility, final HexDocs page, GitHub Release URL, and release-ref CI run URLs. |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency < 180s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
