defmodule Sigra do
  @moduledoc """
  Comprehensive authentication library for Phoenix 1.8+.

  Sigra provides a hybrid lib+generator architecture for authentication:
  security-critical code lives in this library (updated via `mix deps.update`),
  while customizable application code (schemas, routes, LiveViews) is generated
  into your project via `mix sigra.install`.

  ## Getting Started

  Add Sigra to your dependencies and run the install generator:

      mix sigra.install Accounts User users

  This generates migrations, schemas, a context module, plugs, and optionally
  LiveView pages into your Phoenix application.

  ## Architecture

  Sigra follows the "own your code" philosophy: generated schemas and context
  modules are plain Elixir that you can read and modify. Security-sensitive
  operations (password hashing, token verification, HMAC signing) delegate to
  library functions that receive security patches via dependency updates.

  ## Configuration

  See `Sigra.Config` for all available options. Only `:repo` and `:user_schema`
  are required -- everything else has OWASP-grade defaults.
  """
end
