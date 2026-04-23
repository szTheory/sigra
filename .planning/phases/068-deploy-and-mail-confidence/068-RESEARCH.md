# Phase 68 — Technical research: Deploy and mail confidence

**Question:** What do we need to know to plan documentation for ACF-01 and ACF-04 well?

## Summary

Phase 68 is **documentation-only**: extend `guides/recipes/deployment.md` as the single hub, add a scannable **production checklist** (HTTPS, reverse proxy, session cookies, `Endpoint` `url:`, `check_origin`, cookie flags) and a **mail delivery decision tree** (inline default vs Oban recommended for production), then add **five thin inbound links** from README, intro guides, and MAINTAINING. No code or generator behavior changes unless a doc task discovers a bug-level gap (out of scope per CONTEXT).

## Findings

### Phoenix / Plug mechanics (link targets, not inline manuals)

- **`Phoenix.Endpoint`** `url:` host/scheme/port drives URL generation and must match public origin behind TLS terminators.
- **`check_origin`** / WebSocket origins must align with public `https://` host; misalignment causes silent LiveView failures.
- **`Plug.Session`**: `secure`, `same_site`, `domain` must align with `COOKIE_DOMAIN` and Sigra’s generated `UserAuth` cookie behavior (already partially documented).

### OWASP session cookie grounding

- OWASP Session Management cheat sheet supports documenting `Secure`, `SameSite`, and lifecycle expectations without duplicating full nginx/Fly configs in the checklist matrix.

### Oban vs inline Swoosh (Sigra-specific)

- `deployment.md` already states Oban queues (`mailers`, `sigra_auth`, …), cron snippets, and **“Strongly prefer Oban in production.”** Phase work sharpens a **TL;DR decision tree** and names **at-least-once** / double-send on retry with a pointer to idempotency/token patterns (not a full Oban manual — link `https://hexdocs.pm/oban`).

### Install flags (source of truth)

- `lib/mix/tasks/sigra.install.ex` `@moduledoc` lists switches: `--live` / `--no-live`, `--binary-id`, `--api`, `--jwt`, `--admin` / `--no-admin`, `--passkeys` / `--no-passkeys`, `--organizations` implied by negation in feature modules (`--no-organizations` pattern). Executor must run `mix help sigra.install` and align prose with actual output.

### Example app pointer

- **`test/example/`** is CI-backed; plans should cite it as the canonical “what we generate and test” host for Oban wiring when flags enable it.

### ExDoc anchors

- H2 **`## Production checklist (read first)`** yields a stable fragment for cross-links (`deployment.html#production-checklist-read-first` style depending on ExDoc slug algorithm — executor verifies with `mix docs` output if needed).

## Risks / pitfalls

- **Duplicate truths:** MATRIX + full env tables repeated in README would violate CONTEXT D-12–D-13; keep README/intro strips to one sentence + one link.
- **Stale flag list:** If `@switches` in `sigra.install` changes, Installation table must be updated in the same phase or a follow-up.

## Validation Architecture

Phase deliverables are **Markdown + ExDoc**. Automated verification is **grep + `mix docs --warnings-as-errors`** on touched paths; no new test modules required.

| Dimension | Approach |
|-----------|----------|
| Correctness | Required headings and link targets exist; `mix docs` clean |
| Security doc posture | Threat model in plans: no false “guaranteed secure deployment”; checklist is configuration verification, not certification |
| Traceability | Each plan frontmatter lists **ACF-01** and/or **ACF-04** as appropriate |

## RESEARCH COMPLETE
