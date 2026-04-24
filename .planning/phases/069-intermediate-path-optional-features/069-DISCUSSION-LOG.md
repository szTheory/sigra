# Phase 69: Intermediate path + optional features - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in `069-CONTEXT.md`.

**Date:** 2026-04-23  
**Phase:** 69 — Intermediate path + optional features  
**Areas discussed:** (1) Doc home & shape, (2) Canonical install line & defaults, (3) Optional-feature index placement, (4) Cross-link UX, (5) Sensitive flow exemplar  
**Mode:** User selected **all** areas + requested parallel **subagent research** and a **one-shot synthesized** recommendation set.

---

## Research method

Five `generalPurpose` subagents ran in parallel. Each returned: ecosystem comparison, Elixir/Phoenix/lib-doc idioms, other-framework lessons, footguns, and a draft recommendation. The maintainer agent **merged** outputs into a single coherent architecture (see `069-CONTEXT.md` **Coherence note**).

---

## Area 1: Intermediate path — doc home & shape

| Approach | Description | Selected |
|----------|-------------|----------|
| New Introduction extra | Narrative spine only; links to hubs | ✓ |
| Inflate `first-hour.md` | Single long doc | ✗ (breaks time contract) |
| Checklist + narrative split | Two URLs without clear ownership | ✗ (discovery + drift risk) |

**User's choice:** Synthesized — **new `guides/introduction/intermediate-production-path.md`** + keep `first-hour` bounded.  
**Notes:** Aligns with Phoenix/Ecto pattern of separating deployment how-to from intro tutorials; avoids duplicate prod tables.

---

## Area 2: Assumed `mix sigra.install` line

| Approach | Description | Selected |
|----------|-------------|----------|
| Full canonical command | Every positive flag explicit | ✗ |
| Minimal + prose bundle + matrix elsewhere | SSOT in code; intent in guides | ✓ |

**User's choice:** Synthesized — **minimal three-arg command + v1.10 default bundle prose + link to `mix help`**.  
**Notes:** Subagent flagged moduledoc/switch drift risk — **locked** as implementation gate (align `@moduledoc` with `@switches`).

---

## Area 3: Optional-feature index

| Approach | Description | Selected |
|----------|-------------|----------|
| Dedicated `guides/reference/generator-options.md` | Single canonical URL + matrix + prose | ✓ |
| Only inside `installation.md` | No stable deep link | ✗ (as primary home) |
| Fragment across README/deployment/API | High drift | ✗ |

**User's choice:** Synthesized — **new reference extra + new ExDoc group + thin installation bridge**.

---

## Area 4: Cross-links — getting-started vs first-hour

| Approach | Description | Selected |
|----------|-------------|----------|
| Role split | first-hour = spine; getting-started = narrative + end links | ✓ |
| Layout parity | Same above-fold strips in both | ✗ |

**User's choice:** Synthesized — **coverage parity, not layout parity**; no second above-fold strip on getting-started.

---

## Area 5: Sensitive flow exemplar

| Approach | Description | Selected |
|----------|-------------|----------|
| TOTP enrollment (canonical) | Matches v1.10 ADOPTER-SCOPE; differentiator | ✓ |
| Password change only | Faster pedagogy but weaker Sigra story | ✗ (as sole hero) |
| Two equal heroes | Scope creep / half-stories | ✗ |

**User's choice:** Synthesized — **TOTP enrollment primary**; **password change** short sidebar for session invalidation semantics.

---

## Claude's discretion

File **titles** (exact H1 strings) and minor wording in new guides — semantic contracts in CONTEXT are binding.

## Deferred ideas

- Optional CI check: `@moduledoc` vs `@switches` parity automation.
