# Phase 53 — Pattern map (PUB-01)

## Primary file

| Role | Path | Analog in ecosystem |
|------|------|---------------------|
| Hex metadata source | `mix.exs` | `ecto/mix.exs`, `oban/mix.exs` — short `description`, small `links` map, `package/0` |

## Excerpts to mirror (structure, not copy prose)

**Sigra today** — `package/0` and `description` live in `Sigra.MixProject` (`mix.exs` lines ~36–41, ~135–143). Optional deps are grouped with comments in `deps/0` (~98–108); `elixirc_options` documents `no_warn_undefined` for optional modules (~55–84).

**Contract:** Any new `description` sentence about optionals must enumerate families consistent with `optional: true` lines in `deps/0`.

## Anti-patterns (from CONTEXT)

- Walls of package names in `description` (Swoosh-style density).
- `.planning/` or internal evidence URLs in `links`.
- GA / audit / waiver language in Hex `description`.

---

## PATTERN MAPPING COMPLETE
