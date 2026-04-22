# Requirements — Sigra v1.5 Public release narrative & community readiness

**Defined:** 2026-04-22  
**Core value (from PROJECT.md):** Authentication that works out of the box with great DX on the happy path **and** on the rough edges — including a **credible public story** aligned with shipped GA and audit evidence.

This milestone **does not** expand core auth product scope. It prepares **Hex/README/changelog/docs** and a **maintainer announcement checklist** so external readers see the same story the v1.4 planning archive tells.

**Seeds:** **SEED-001** (pre-public-announcement human UAT) is partially satisfied by v1.4’s matrix + CI substitutes; v1.5 focuses on **where to link** that evidence from public-facing docs — not re-running the full human matrix unless maintainers add explicit phases later.

---

## Package & Hex (PUB)

- [ ] **PUB-01**: **`mix.exs`** package description, links, and maintainers metadata accurately reflect **shipped** capabilities through **v1.4** (no dead claims; optional deps called out honestly).
- [ ] **PUB-02**: **`CHANGELOG.md`** includes readable **milestone anchors** for **v1.3**, **v1.4**, and prior major lines (or explicit “see git tags / MILESTONES” pointer if changelog stays minimal — must be a deliberate maintainer choice, not drift).

---

## Docs & entry paths (DOC)

- [ ] **DOC-01**: **Top-level `README.md`** (or agreed primary entry) includes a short **“production / GA posture”** paragraph with links to **v1.4** evidence (e.g. `.planning/milestones/v1.4-REQUIREMENTS.md`, `.planning/v1.4-GA-UAT.md`, `docs/uat-ci-coverage.md`) so OSS readers understand **Executed vs Waived** language.
- [ ] **DOC-02**: **ExDoc landing** — `mix docs` output has a clear path from the default landing page to **maintainer-facing** GA/audit narrative (extra page, section in `README.md` surfaced in docs, or `guides/` index cross-link — pick one approach and document it in the phase plan).

---

## Maintainer process (MAINT)

- [ ] **MAINT-01**: **`MAINTAINING.md`** gains a concise **“First public announcement”** checklist (owners, order: tag → Hex → post → monitor), referencing **`install_golden_contract`** / **`v1.4-GA-UAT.md`** where relevant — checklist may mark human rows as **optional** if v1.4 waivers still apply.

---

## Out of scope (v1.5)

- Net-new auth features, new providers, SAML, IdP mode.
- Re-running full human GA matrix (Gmail/Outlook/Apple + live Google OAuth) unless promoted as a **separate optional phase** with its own REQ-IDs.
- Further **`log_safe/3` → `Ecto.Multi`** conversion (**SEED-002**) — defer until compliance trigger or dedicated hardening milestone.

---

## Future (post-v1.5)

- Optional **OAuth ceremony audit smoke** (v1.4 “Future”).
- **Nyquist elevation** for phases **41–44** if policy changes.
- Broader **marketing** (video, paid ads) — not required for these REQ IDs.

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PUB-01 | 53 | Pending |
| PUB-02 | 54 | Pending |
| DOC-01 | 55 | Pending |
| DOC-02 | 55 | Pending |
| MAINT-01 | 56 | Pending |

**Coverage:**

- v1.5 requirements: **5** total  
- Mapped to phases: **5**  
- Unmapped: **0**

---

*Requirements defined: 2026-04-22 after `/gsd-new-milestone` (SEED-001 narrative alignment; no `--reset-phase-numbers`; phases continue from **53**).*
