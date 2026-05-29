defmodule Sigra.OptionalDeps do
  @moduledoc """
  Single source of truth for optional-dependency availability predicates.

  Sigra guards several runtime features behind optional dependencies. This
  module centralises those availability checks so a maintainer can answer
  "is this optional dep available?" for every guarded dep by reading one
  module, and so `mix sigra.doctor` (Phase 138) has a stable, predictable
  surface to query.

  ## Scope — runtime call-site guards only

  These predicates are for **runtime** call-site guards only — the
  `if/unless` checks that decide whether to invoke an optional dep at
  call time. Two categories of guard are explicitly **out of scope** and
  remain literal `Code.ensure_loaded?/1` calls:

  - **Compile-time `defmodule` wrappers** (`lib/sigra/workers/*.ex`,
    `lib/sigra/audit/forwarders/threadline.ex`) run before this module
    may be compiled and therefore do **not** delegate here (D-04). Routing
    a compile-time guard through this SOT risks compile-ordering
    circularity; those wrappers stay literal.

  - **Dynamic module atoms** (host schema variables, internal
    conditionally-compiled workers) are not named optional deps and are
    also out of scope.

  The one known non-delegated runtime check is `lib/sigra/application.ex:77`
  (`Code.ensure_loaded?(Oban)` boot-warning `cond`), left literal by
  deliberate decision (Open Question 1 default — minimal phase).

  ## Encryption posture — config-driven, not load-driven

  `encryption_active?/1` answers "is the host configured with a real vault
  (not the plaintext stub)?" by mirroring the `__sigra_encryption_mode__/0`
  config check in `Sigra.Application.verify_vault!/1`. It does **not** call
  `Code.ensure_loaded?(Cloak)` — a load check would return `true` even when
  the host app is still on the plaintext stub, which is a silent at-rest
  encryption regression (ASVS V6, D-07).

  ## Covered optional dependencies

  | Predicate              | Module      | Optional dep      |
  |------------------------|-------------|-------------------|
  | `oban_available?/0`    | `Oban`      | `{:oban, ...}`    |
  | `bcrypt_available?/0`  | `Bcrypt`    | `{:bcrypt_elixir, ...}` |
  | `eqrcode_available?/0` | `EQRCode`   | `{:eqrcode, ...}` |
  | `threadline_available?/0` | `Threadline` | `{:threadline, ...}` |
  | `assent_available?/0`  | `Assent`    | `{:assent, ...}`  |
  | `swoosh_available?/0`  | `Swoosh`    | `{:swoosh, ...}`  |
  | `joken_available?/0`   | `Joken`     | `{:joken, ...}`   |
  | `hammer_available?/0`  | `Hammer`    | `{:hammer, ...}`  |
  | `req_available?/0`     | `Req`       | `{:req, ...}`     |

  `swoosh_available?/0` and `req_available?/0` are present for SOT
  completeness and Phase 138 consumption. In the current codebase, Swoosh's
  only `lib/` guard is in the out-of-scope test-helper `testing.ex:98`, and
  Req is a transitive dep guarded only at the compound check in
  `enterprise_connections/validation.ex:91` (whose load-half is delegated by
  plan 03). The absence of further delegation sites for these two predicates
  is intentional, not a missing-delegation gap.
  """

  # ---------------------------------------------------------------------------
  # Availability predicates (nine flat zero-arity wrappers — D-01, D-03)
  # Un-memoized by design: each call is a live Code.ensure_loaded? check.
  # NO caching, NO ETS, NO persistent_term.
  # ---------------------------------------------------------------------------

  @doc """
  Returns `true` when Oban is available as a loaded module.

  Used to gate Oban job-queue features (background email delivery, token
  cleanup, audit forwarding). When `false`, Sigra falls back to inline
  behaviour.
  """
  @doc since: "0.1.0"
  @spec oban_available?() :: boolean()
  def oban_available?, do: Code.ensure_loaded?(Oban)

  @doc """
  Returns `true` when Bcrypt is available as a loaded module.

  Used to gate the bcrypt transparent-migration path in
  `Sigra.Crypto` and `Sigra.Hashers.Bcrypt`. When `false`, bcrypt
  hash verification falls back to a constant-time no-op that prevents
  timing side-channels.
  """
  @doc since: "0.1.0"
  @spec bcrypt_available?() :: boolean()
  def bcrypt_available?, do: Code.ensure_loaded?(Bcrypt)

  @doc """
  Returns `true` when EQRCode is available as a loaded module.

  Used to gate QR code SVG generation in `Sigra.MFA`. When `false`,
  `generate_qr_svg/1` returns `nil`.
  """
  @doc since: "0.1.0"
  @spec eqrcode_available?() :: boolean()
  def eqrcode_available?, do: Code.ensure_loaded?(EQRCode)

  @doc """
  Returns `true` when Threadline is available as a loaded module.

  Used to gate the Threadline audit-forwarding path in
  `Sigra.Audit.Forwarders.Threadline`. When `false`, the Noop forwarder
  is used.
  """
  @doc since: "0.1.0"
  @spec threadline_available?() :: boolean()
  def threadline_available?, do: Code.ensure_loaded?(Threadline)

  @doc """
  Returns `true` when Assent is available as a loaded module.

  Used to gate OAuth / OIDC strategy execution. When `false`, calling any
  OAuth strategy raises with an actionable message asking the adopter to
  add `{:assent, \"~> 0.3\"}` to `mix.exs`.
  """
  @doc since: "0.1.0"
  @spec assent_available?() :: boolean()
  def assent_available?, do: Code.ensure_loaded?(Assent)

  @doc """
  Returns `true` when Swoosh is available as a loaded module.

  Included for SOT completeness and `mix sigra.doctor` consumption.
  The only `lib/` guard for Swoosh in the current codebase is the
  test-helper `Sigra.Testing` module (out of runtime scope).
  """
  @doc since: "0.1.0"
  @spec swoosh_available?() :: boolean()
  def swoosh_available?, do: Code.ensure_loaded?(Swoosh)

  @doc """
  Returns `true` when Joken is available as a loaded module.

  Used to gate JWT signing/verification in `Sigra.JWT.Signer`. When
  `false`, calling Joken-dependent functions raises with an actionable
  message.
  """
  @doc since: "0.1.0"
  @spec joken_available?() :: boolean()
  def joken_available?, do: Code.ensure_loaded?(Joken)

  @doc """
  Returns `true` when Hammer is available as a loaded module.

  Used to gate rate-limiter resolution in `Sigra.Plug.RateLimit`. When
  `false`, `Sigra.RateLimiters.Noop` is used as a fail-open fallback with
  a logged warning.
  """
  @doc since: "0.1.0"
  @spec hammer_available?() :: boolean()
  def hammer_available?, do: Code.ensure_loaded?(Hammer)

  @doc """
  Returns `true` when Req is available as a loaded module.

  Included for SOT completeness and `mix sigra.doctor` consumption. Req
  is a transitive dep; the runtime guard in
  `enterprise_connections/validation.ex:91` checks both availability and a
  specific function export (`function_exported?(Req, :get, 1)`) — the
  load-half delegates here, the function-export half stays at the call site
  (D-06).
  """
  @doc since: "0.1.0"
  @spec req_available?() :: boolean()
  def req_available?, do: Code.ensure_loaded?(Req)

  # ---------------------------------------------------------------------------
  # Encryption-posture predicate (D-07 — config-driven mirror, not load check)
  # ---------------------------------------------------------------------------

  @doc """
  Returns `true` when the host app's encryption module is configured with a
  real vault (not the plaintext stub).

  Derives the host's `*.Encrypted.Binary` module from the `:user_schema`
  key in `host_sigra` (same derivation as `Sigra.Application.verify_vault!/1`
  and `encrypted_binary_module/1`), then checks whether that module exports
  `__sigra_encryption_mode__/0` and returns a non-`:stub` value.

  Returns `false` in any of these cases:

  - `:user_schema` is absent or not an atom.
  - The derived `*.Encrypted.Binary` module does not export
    `__sigra_encryption_mode__/0`.
  - `__sigra_encryption_mode__/0` returns `:stub` (plaintext passthrough active).

  **Does not call `Code.ensure_loaded?(Cloak)`** — a load check would return
  `true` even while the app is still on the plaintext stub, silently
  misreporting encryption posture (D-07, ASVS V6).
  """
  @doc since: "0.1.0"
  @spec encryption_active?(keyword()) :: boolean()
  def encryption_active?(host_sigra) when is_list(host_sigra) do
    case encrypted_binary_module(host_sigra) do
      nil ->
        false

      module ->
        function_exported?(module, :__sigra_encryption_mode__, 0) and
          module.__sigra_encryption_mode__() != :stub
    end
  end

  # Mirrors Sigra.Application.encrypted_binary_module/1 (application.ex:218-230).
  # Derives *.Encrypted.Binary from the :user_schema atom by dropping the last
  # module segment and appending ["Encrypted", "Binary"].
  defp encrypted_binary_module(host_sigra) do
    case Keyword.get(host_sigra, :user_schema) do
      module when is_atom(module) and not is_nil(module) ->
        module
        |> Module.split()
        |> Enum.drop(-1)
        |> Kernel.++(["Encrypted", "Binary"])
        |> Module.concat()

      _ ->
        nil
    end
  end
end
