# Phase 53: Package & Hex metadata — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in `053-CONTEXT.md` — this log preserves alternatives considered.

**Date:** 2026-04-21  
**Phase:** 53 — Package & Hex metadata  
**Areas discussed:** Hex description; package links; optional vs core messaging; maintainers & version / announcement-safe coupling (all four gray areas, research-assisted)

---

## 1. Hex description — content and promises

| Approach | Description | Selected |
|----------|-------------|----------|
| Ultra-short tagline | Minimal surface, low stale risk; weak discoverability | |
| Feature-dense | Good for integration breadth; high drift and “optional reads default” risk | |
| Positioning + pointer to docs (Ecto/Oban-style precision) | Short paragraph, verifiable, routes depth to README/hexdocs | ✓ |

**User's choice:** **Research-synthesized “default”** — integrator-first tone; paragraph shape; no GA/waiver language in Hex; explicit optional contract + pointer.  
**Notes:** Hex spec treats `description` as a paragraph, not a README clone. Cross-ecosystem auth libs favor **scope** over **assurance marketing**.

---

## 2. Links map (`package[:links]`)

| Approach | Description | Selected |
|----------|-------------|----------|
| GitHub + Changelog only | Idiomatic baseline for Elixir OSS | ✓ (baseline) |
| + Documentation / Issues / Sponsor | Add only when they add clear value | ✓ (conditional) |
| Link `.planning/` or internal GA evidence | Transparency without wrong audience / misread warranties | ✗ |

**User's choice:** **GitHub + single Changelog URL**; optional **Documentation**, **Issues**, **Sponsor** per policy in CONTEXT; **never** internal planning URLs. **Changelog:** GitHub `main` blob acceptable short-term; **prefer** hexdocs `changelog.html` long-term when published.  
**Notes:** Peer libs (Phoenix/Ecto/Req) often use HexDocs changelog; Oban/Swoosh often use GitHub blob — both valid; pick one canonical URL.

---

## 3. Optional vs core dependencies — Hex messaging

| Approach | Description | Selected |
|----------|-------------|----------|
| Swoosh-style dense list in Hex only | High drift vs optional deps | ✗ |
| One honest “supported when you add deps” sentence + doc pointer | Matches PUB-01 and code guards | ✓ |
| Split packages (Ueberauth model) | Clear boundaries; different architecture — not this phase | (deferred product/architecture) |

**User's choice:** **Family-level opt-in sentence** in Hex description; detailed table in docs/README in later phases.  
**Notes:** Align with `optional: true`, `Code.ensure_loaded?`, and actionable raises.

---

## 4. Maintainers, version string, announcement-safe

| Approach | Description | Selected |
|----------|-------------|----------|
| Populate deprecated `:maintainers` heavily | Spec deprecated; stale emails | ✗ |
| Omit `:maintainers`; use Hex owners + SECURITY/MAINTAINING | Operational truth for humans | ✓ |
| Conflate roadmap “v1.4” with `mix` semver | User confusion, bad `~>` examples | ✗ (explicit disambiguation) |

**User's choice:** **Omit or minimal legacy `maintainers`**; **disambiguate** milestone labels vs Hex semver; **version bump + tag + source_ref** checklist on actual publish — phase 53 defines policy; release mechanics when cutting Hex.  
**Notes:** Hex publish doc: on `0.x`, breaking-ish changes often **minor** bump per ecosystem guidance.

---

## Claude's Discretion

- Exact final prose for `description` — within locked tone and structure.

## Deferred Ideas

- README/docs GA paragraph, full optional-deps table — phase **55**.  
- Changelog structure — phase **54**.  
- Announcement checklist — phase **56**.
