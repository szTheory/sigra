# Phase 53 — Technical research: Package & Hex metadata

**Status:** Research complete  
**Question answered:** What do we need to know to plan PUB-01 well?

---

## Current `mix.exs` surface (audit)

| Field | Current value | Gap vs PUB-01 / CONTEXT |
|-------|----------------|-------------------------|
| `@version` | `0.2.0` | ROADMAP language references **v1.0–v1.4** as narrative horizon; shipped Hex version is **0.x**. Metadata must describe **what exists in this repo at publish time**, not future semver. **D-13:** never imply `~> 1.4` until a real **1.4.x** exists on Hex. |
| `description` | Single line: *Comprehensive authentication library for Phoenix 1.8+* | Too thin for integrator-first positioning; no **optional-dep honesty** sentence (**D-09**); risks sounding like everything is default-on (**D-04**, **D-10**). |
| `package[:links]` | `GitHub`, `Changelog` → `blob/main/CHANGELOG.md` | Matches short-term strategy **D-06**; acceptable until hexdocs changelog exists (phase **54**). **D-08:** no `.planning/` URLs (already clean). |
| `:maintainers` | Absent | Aligns with **D-12** (deprecated field — prefer omit). |
| `docs/0` `source_ref` | `"v#{@version}"` → `v0.2.0` | **D-14:** At Hex publish, git tag **`v0.2.0`** must exist or “View source” on hexdocs 404s. Document as release checklist item, not automatic bump in this phase. |

## Optional dependencies (must match description)

Declared **`optional: true`** in `deps/0`: `bcrypt_elixir`, `hammer`, `swoosh`, `oban`, `assent`, `joken`, `eqrcode`.  
**Always present (not optional in mix):** `nimble_totp`, `cloak_ecto`, `wax_` — copy must not call TOTP/WebAuthn “add a dep” if they are non-optional (verify wording: “MFA primitives” vs “QR in emails” — `eqrcode` is optional).

## Hex & ExDoc norms (verified references)

- **Hex publish:** https://hex.pm/docs/publish — `description`, `package` keys propagate to the package page.
- **Package metadata spec:** https://github.com/hexpm/specifications/blob/master/package_metadata.md — `description` length is practical paragraph, not README; `maintainers` deprecated.

## Ecosystem tone reference (non-binding)

Libraries like **Ecto**, **Oban**, **Comeonin** use restrained, mechanism-oriented one-paragraph descriptions. **Swoosh**-style dense adapter lists are called out in CONTEXT as a risk — avoid duplicating that in Sigra’s Hex string.

---

## Planning implications

1. **Single edit locus:** `mix.exs` — `project/0` `description`, `package/0` (and optionally `homepage_url` / `source_url` consistency), plus a **brief** code comment near `source_ref` if it helps executors remember the tag rule (**D-14**).
2. **No README/CHANGELOG edits** for PUB-01 acceptance (explicitly other phases) except cross-links already in `package[:links]` must stay valid.
3. **Maintainer sign-off** (REQ PUB-01 item 3) is **manual** — plan should end with a checklist task or verification note.

---

## Validation Architecture

**Dimension 8 (Nyquist):** This phase changes only Mix project metadata. Automated feedback is **compile cleanliness** plus **grep contracts** on final strings. No new ExUnit file is strictly required if acceptance criteria are grep-based on `mix.exs`.

| Dimension | Approach |
|-----------|----------|
| Correctness | `mix compile --warnings-as-errors` after edits |
| Honesty / security messaging | Manual maintainer read + grep for forbidden substrings (`.planning`, `SOC`, `pen-test`, `waiver`) |
| Link integrity | `grep` for URLs in `mix.exs`; optional `curl -I` against GitHub raw/blob if network available in CI |

---

## RESEARCH COMPLETE
