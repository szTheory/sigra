# Phase 239 API Coverage Declaration

## Detector Result

`detected: false`

Crosswake is an external repository and independently released Hex package, but Phase 239 integrates its `crosswake_sigra` modules as an in-process Elixir library. The SIGRA host does not call a Crosswake HTTP endpoint, authenticate to a Crosswake service, paginate remote resources, process webhooks, or depend on a network service at runtime. The package exposes constructors and a pure evaluator inside the host BEAM.

GitHub and Hex are used only to verify the companion release's provenance before dependency resolution. Those release-supply-chain checks do not create a product API client or application service integration. Therefore an endpoint/capability matrix would fabricate remote capabilities that do not exist.

## Seal-Time Boundary

- External delivery dependency: a backward-compatible `crosswake_sigra` successor must be released from `szTheory/crosswake` and verified before SIGRA consumes it.
- Runtime boundary: raw browser session credential -> SIGRA-owned database resolution -> fact-only in-process Crosswake contract/evaluator.
- Authority boundary: Crosswake receives fresh server-owned facts; callback/return evidence never selects a session or grants access.
- Re-run trigger: if implementation introduces any Crosswake network endpoint, SDK client, webhook, hosted API, or remote authentication, this declaration is invalid and a complete capability matrix is required before seal.

