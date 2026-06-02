# Research Summary: Sigra Post-1.0 Maintenance and Strategic Bets

**Domain:** Open Source Authentication Library Maintenance (Post-1.0)
**Researched:** 2026-06-01
**Overall confidence:** HIGH

## Executive Summary

After the successful release of `v1.32.0 RELEASE-ADOPTION`, Sigra transitions from a phase of active feature construction into a phase of **stewardship and stability**. The ecosystem standard for post-1.0 libraries (like Ecto, Phoenix, and mature auth tools) dictates that maintenance, operator trust, and security supersede greenfield feature development. The primary goal is managing the long-term viability of the hybrid lib+generator architecture without succumbing to feature creep or violating the established "Diminishing Returns Wall".

Future strategic bets (e.g., SCIM directory sync, IdP glue packages) must now be driven strictly by documented adopter demand or a compelling thesis, rather than a default assumption of continued expansion. This research codifies the tools, features, and architectural principles required to sustain Sigra in a post-1.0 environment.

## Key Findings

**Stack:** GitHub Actions, Release Please, Dependabot, and Playwright (for demo-showcase UAT) form the primary stewardship stack.
**Architecture:** Strict adherence to the Hybrid Lib+Generator pattern and adapter-based seams (for email, audit, and OAuth IdP).
**Critical pitfall:** Feature creep—specifically, building "nice-to-have" capabilities (like opinionated RBAC or generic admin UI) that violate the Diminishing Returns Wall without concrete adopter demand.

## Implications for Roadmap

Based on research, suggested phase structure for the next operational cycle (v1.33 Post-1.0 Maintenance):

1. **Phase 150: Issue Triage & Bugfix Cadence** - Establish a repeatable process for monitoring adopter feedback, diagnosing friction, and patching bugs. 
   - Addresses: Immediate operator trust and stability.
   - Avoids: Accumulating technical debt from unaddressed community reports.

2. **Phase 151: Ecosystem Sync & Hex Dependency Management** - Routine dependency bumps (Dependabot), Elixir/Phoenix version compatibility verification, and ensuring zero deprecation warnings on the latest OTP.
   - Addresses: Supply-chain security and framework alignment.
   - Avoids: The "stale project" perception and broken CI pipelines.

3. **Phase 152: Strategic Bet Evaluation Gate** - A formal checkpoint to evaluate if accumulated adopter demand warrants beginning work on `SCIM`, `sigra_lockspire`, or `Threadline` correlation. 
   - Addresses: Validating feature requests against the Diminishing Returns Wall.
   - Avoids: Unnecessary feature creep and bloated API surface.

**Phase ordering rationale:**
- Triage and maintenance (150 & 151) must always precede new features (152) in a post-1.0 posture. The baseline must be stable before expanding the surface area.

**Research flags for phases:**
- Phase 152: Likely needs deeper research into `ex_scim` vs custom implementations if an enterprise adopter requests directory sync.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | The current CI/CD stack is proven and aligned with Elixir best practices. |
| Features | HIGH | Clear boundaries (Diminishing Returns Wall) exist and are documented. |
| Architecture | HIGH | Hybrid architecture is settled and validated through the 1.0 release. |
| Pitfalls | HIGH | Historical data and open-source best practices strongly point to feature creep as the primary risk. |

## Gaps to Address

- At what threshold of adopter demand does a "Strategic Bet" (like SCIM) override the maintenance-first default?
- How to efficiently communicate generated-host template updates to adopters who have already run `mix sigra.install` prior to minor/patch bumps.
