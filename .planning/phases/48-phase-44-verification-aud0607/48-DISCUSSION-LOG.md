# Phase 48: Phase 44 verification & AUD-06/07 closure — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in `48-CONTEXT.md` — this log preserves alternatives considered.

**Date:** 2026-04-21  
**Phase:** 48 — phase-44-verification-aud0607  
**Areas discussed:** Merge gate vs attestation, REQ reconciliation & PR shape, Validation vs Nyquist, Incomplete implementation posture

**Method:** User selected **all** areas and requested parallel subagent research; maintainer synthesized into **D-48-01..04**.

---

## 1. Merge gate vs release attestation

| Option | Description | Selected |
|--------|-------------|----------|
| Path-scoped gate only | Fast `mix test` paths + compile; lowest CI cost | |
| Full suite as sole gate | Maximum regression signal; high cost/flake risk | |
| Hybrid + alias/tags | Scoped invariants + optional full attestation; drift-resistant | ✓ |
| Pinned CI only | Strong paper trail; weaker local contributor story | |

**User's choice:** Hybrid (scoped merge gate + optional full-suite or pinned CI attestation), expressed as stable **Mix alias** and/or **ExUnit tags** where possible; verbatim commands in `44-VERIFICATION.md`.

**Notes:** Research highlighted path-list **drift** as the main footgun; tags/aliases reduce surprise for Elixir contributors. Coherent with **D-47-03** and Sigra Postgres-backed atomicity tests.

---

## 2. Single verification doc vs split PRs / REQ flips

| Option | Description | Selected |
|--------|-------------|----------|
| One doc + one atomic PR | Both REQs + verification together; simplest traceability | ✓ (default) |
| One doc + split PRs | Per-REQ merges with strict “evidence before checkbox” ordering | ✓ (exception) |
| Split verification files | Separate docs per REQ | |

**User's choice:** **Single `44-VERIFICATION.md`** with **AUD-06** and **AUD-07** subsections. **Default:** one atomic closure PR (like **47**). **Exception:** split merges if batches land separately, never flipping a checkbox before its evidence is on `main`.

**Notes:** Research favored small merges for bisect; **47** already optimized for auditor traceability via single atomic PR — **48** defaults the same, with an escape hatch.

---

## 3. `44-VALIDATION.md` vs Nyquist deferral

| Option | Description | Selected |
|--------|-------------|----------|
| Claim Nyquist in 48 | Flip `nyquist_compliant` early | |
| Defer to phase 50 + honest map | Living validation + snapshot verification | ✓ |
| Partial named slice only | Labeled partial, never substitute for 50 | ✓ (optional) |

**User's choice:** **D-47-01** policy carried forward — **no** full Nyquist claim in **48**; explicit pointer to **phase 50**; optional **labeled partial** only.

---

## 4. Incomplete phase 44 — draft verification vs defer closure

| Option | Description | Selected |
|--------|-------------|----------|
| No doc until green | Clean external signal; transparency gap during build | |
| Draft/blocked doc + no REQ flip | Honest engineering state on `main` | ✓ |
| REQ flip without evidence | — | (rejected) |

**User's choice:** Allow **`44-VERIFICATION.md` in `draft`/`blocked`** with banner + strict semantics; **REQ** flips only on **passed** closure with evidence.

---

## Claude's discretion

- Mix alias naming; tag vs path emphasis for the **44** gate.  
- Minor frontmatter variance vs **43** / **46** templates.

## Deferred ideas

- Full Nyquist **41–44** — **phase 50**.  
- **AUD-08** / C-1 — **phase 49**.
