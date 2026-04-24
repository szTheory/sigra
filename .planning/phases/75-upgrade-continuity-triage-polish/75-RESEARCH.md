# Phase 75 — Technical research

**Question:** What do we need to know to plan **upgrade continuity + triage polish** well?

**Sources:** `75-CONTEXT.md`, `ROADMAP.md` row for phase 75, `mix.exs` `docs/0`, `guides/introduction/upgrading-to-v1.11.md`, phase **74** closure artifacts.

---

## 1. ExDoc extras and `.planning/` on HexDocs

- **`package/0` `files`** in `mix.exs` lists `~w(lib priv docs ...)` — **`.planning/` is not shipped** on Hex. Relative markdown links from extras into `.planning/...` **404 on hexdocs.pm**.
- **`skip_undefined_reference_warnings_on`** silences ExDoc “undefined reference” warnings **per entire file** (coarse footgun). Prefer **https `blob` URLs** for planning artifacts so ExDoc does not treat them as missing extras paths (**D-75-16**, **D-75-17**).
- **v1.10 / v1.11** guides still use relative `.planning/` links and sit on the skip list; **v1.12** net-new guide should default to **blob URLs** for `.planning/` targets so the new file is **not** added to the skip list solely for planning links.
- **Autolink / extras resolution** (repo `deps/ex_doc`): relative `*.md` links without a host are resolved in the extras graph by **basename**. **`https://...` links** bypass that mechanism — correct for GitHub-only artifacts.

## 2. Structural template for `upgrading-to-v1.12.md`

- Mirror **`upgrading-to-v1.11.md`**: title pattern **“Upgrading notes — toward v1.12”**, opening paragraph separating **planning milestone v1.12** vs **Hex SemVer**, pointer to **`CHANGELOG.md`** → *Planning milestones vs Hex releases*, **prerequisite chain** (“after v1.11” → `upgrading-to-v1.11.html`), **three-step library checklist**, **See also** with stable cross-links.
- **Do not duplicate** the eight-row SEED outcome table; state canonical index is **only** in **`.planning/v1.12-UAT-EVIDENCE.md`** (**D-75-02**).
- **Trust bundle** in one tight paragraph: bounded **SEED-002** audit batch (see **09-03** narrative), **UAT evidence index**, alignment with **`docs/uat-ci-coverage.md`** (**v1.12 launch evidence** subsection) — pointers only, not essay length (**D-75-06**).

## 3. TRN-02 touch surfaces

- **`guides/introduction/getting-started.md`**: **Faster path** line already lists v1.7, v1.8, v1.10, v1.11 — append **`[Upgrading notes — v1.12](upgrading-to-v1.12.html)`** after v1.11 (**D-75-07**). Default: **no** extra v1.12 prose on **Reading map** / **first-hour** beyond optional single generic clause.
- **`MAINTAINING.md`**: Insert a **short** block (e.g. **“v1.12 trust bundle (audit + UAT evidence)”**) after early cadence context or adjacent to existing trust/Nyquist material — canonical URLs + **release ritual** one-liner (**D-75-08**).
- **`CHANGELOG.md` `[Unreleased]`**: Add **one** documentation bullet for **v1.12** trust bundle with same three surfaces (upgrade page, `docs/uat-ci-coverage.md`, evidence blob) — **no** eight-row table (**D-75-09**).
- **`README.md`**: **No** change (**D-75-10**).

## 4. TRN-03 triage accountability

- Append **`## v1.12 reconciliation (Phase 75)`** to **`.planning/v1.11-TRIAGE.md`**: ISO date, scope line, bullets = **concrete outcomes** from this phase **or** explicit **“no triage deltas”** with rationale + pointers (**D-75-14**).
- **`75-VERIFICATION.md`**: one-line echo pointing at that subsection (**D-75-15**); triage file remains primary.
- **Issues:** only if a real open item exists (**D-75-20**); otherwise document **no open issues** path in reconciliation (triage file already notes empty issue list).

## 5. `mix.exs` registration

- Add **`"guides/introduction/upgrading-to-v1.12.md"`** to **`extras`** **immediately after** **`upgrading-to-v1.11.md`** (ROADMAP success criterion).
- **`skip_undefined_reference_warnings_on`**: extend **only** if `mix docs --warnings-as-errors` still fails after blob-first links (**D-75-17**); re-audit if added (**D-75-18**).

## 6. Verification commands (CI parity)

- **`.github/workflows/ci.yml`** runs **`mix docs --warnings-as-errors`** — primary automated gate for this phase.
- **`MIX_ENV=test mix compile --warnings-as-errors`** remains a cheap sanity check after markdown-only edits (no behavior change expected).

---

## Validation Architecture

**Nyquist / Dimension 8 — doc-only phase**

| Dimension | Strategy |
|-----------|----------|
| **Automated** | `mix docs --warnings-as-errors` after every task that touches ExDoc inputs (`mix.exs` extras/skip list, any `guides/`, `docs/`, `MAINTAINING.md`, `CHANGELOG.md`). |
| **Sampling** | After each plan wave: same docs command; optional `mix compile --warnings-as-errors` for hygiene. |
| **Manual** | Spot-check rendered HTML locally (`doc/index.html`) for **Faster path** link to **v1.12** upgrade page and that **blob** links open on GitHub. |
| **Evidence** | CI log or local exit **0** from `mix docs --warnings-as-errors`; triage subsection present under exact heading **`## v1.12 reconciliation (Phase 75)`** (or equivalent agreed in execution). |

**Sign-off:** Set `nyquist_compliant: true` on **75-VALIDATION.md** frontmatter when all per-task rows are green.

---

## RESEARCH COMPLETE

Planning can proceed with **TRN-01** (stub + `mix.exs`), **TRN-02** (intro/maintainer/CHANGELOG), **TRN-03** (triage append + verification echo).
