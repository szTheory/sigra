if Code.ensure_loaded?(Oban.Worker) do
  defmodule Sigra.Workers.EmailDelivery do
    @moduledoc """
    Oban worker for asynchronous email delivery.

    Reconstructs email from type + args at delivery time. Never stores
    email body content in the jobs table (security: T-3-INFRA-01).

    ## Job Args

    - `"email_type"` - String email type (e.g., "confirmation", "reset_password")
    - `"user_id"` - User ID to look up
    - `"token"` - Optional token for URL construction
    - `"code"` - Optional confirmation code
    - `"url"` - Optional pre-built URL

    ## Runtime Config

    The worker resolves host app modules from application env at runtime (D-22):

    - `:repo` - Ecto repo module
    - `:user_schema` - User schema module
    - `:email_module` - Module with email builder functions
    - `:mailer` - Module implementing `Sigra.Mailer`

    ## Retry

    max_attempts: 3, exponential backoff with jitter (~15s, ~60s).
    Non-retryable failures (user not found, unknown type) use `{:cancel, reason}`.
    Retryable failures (mailer error) use `{:error, reason}` for backoff retry.
    """
    use Oban.Worker,
      queue: :sigra_mailer,
      max_attempts: 3

    alias Oban.{Job, Worker}
    alias Sigra.OptionalDeps
    alias Sigra.Telemetry

    # Phase 95 Plan 02 — async_email optional-dep boundary.
    # Override new/2 so enqueueing hard-fails with MissingDependencyError when
    # the host app has not declared the `:async_email` optional dep. Without
    # this, hosts compiling against Sigra's own Oban dep can produce
    # unrunnable Job structs silently.
    @impl Oban.Worker
    def new(args, opts) when is_map(args) and is_list(opts) do
      OptionalDeps.ensure_available!(:async_email, async_email_context(opts))
      Job.new(args, Worker.merge_opts(__opts__(), Keyword.drop(opts, [:dependency_loaded?])))
    end

    defp async_email_context(opts) do
      [
        delivery_mode: :async,
        dependency_loaded?: Keyword.get(opts, :dependency_loaded?, &dependency_loaded?/1)
      ]
    end

    defp dependency_loaded?(spec) do
      Enum.any?(spec.dependency_modules, &Code.ensure_loaded?/1)
    end

    @impl Oban.Worker
    def perform(%Oban.Job{args: args}) do
      Telemetry.span(
        [:sigra, :email, :deliver],
        %{
          delivery_method: :async,
          email_type: args["email_type"]
        },
        fn ->
          %{repo: repo, user_schema: user_schema, email_module: email_module, mailer: mailer} =
            resolve_config()

          case repo.get(user_schema, args["user_id"]) do
            nil ->
              {:cancel, :user_not_found}

            user ->
              case build_email(email_module, args, user) do
                {:ok, email} ->
                  body = %{html: email.html_body, text: email.text_body}

                  case mailer.deliver(user.email, email.subject, body) do
                    {:ok, _result} -> {:ok, :delivered}
                    {:error, reason} -> {:error, reason}
                  end

                {:cancel, _reason} = cancel ->
                  cancel
              end
          end
        end
      )
    end

    @impl Oban.Worker
    def backoff(%Oban.Job{attempt: attempt}) do
      # Exponential backoff with jitter: ~15s, ~60s (per D-25)
      trunc(:math.pow(attempt, 4) + 15 + :rand.uniform(10) * attempt)
    end

    defp resolve_config do
      %{
        repo: Application.fetch_env!(:sigra, :repo),
        user_schema: Application.fetch_env!(:sigra, :user_schema),
        email_module: Application.fetch_env!(:sigra, :email_module),
        mailer: Application.fetch_env!(:sigra, :mailer)
      }
    end

    defp build_email(email_module, args, user) do
      case args["email_type"] do
        "confirmation" ->
          {:ok, email_module.confirmation_email(user, args["url"], args["code"])}

        "reset_password" ->
          {:ok, email_module.reset_password_email(user, args["url"])}

        "magic_link" ->
          {:ok, email_module.magic_link_email(user, args["url"])}

        unknown ->
          {:cancel, "unknown email type: #{unknown}"}
      end
    end
  end
else
  defmodule Sigra.Workers.EmailDelivery do
    @moduledoc """
    Stub fallback for hosts that compile Sigra without Oban (Phase 95
    `:async_email` optional-dep boundary). See
    `Sigra.Workers.AccountDeletion` for the rationale on the dual-defmodule
    shape — Elixir 1.19 expands `use Oban.Worker` even inside `if false do
    ... end`, so the conditional must wrap the entire `defmodule`.
    """

    alias Sigra.OptionalDeps

    @doc false
    def new(args, opts \\ []) when is_map(args) and is_list(opts) do
      OptionalDeps.ensure_available!(:async_email, async_email_context(opts))
      raise "unreachable"
    end

    defp async_email_context(opts) do
      [
        delivery_mode: :async,
        dependency_loaded?: Keyword.get(opts, :dependency_loaded?, fn _spec -> false end)
      ]
    end
  end
end
