defmodule Mix.Tasks.Sigra.Email.Snapshot do
  @shortdoc "Prerenders deterministic email HTML for Playwright snapshot tests"

  @moduledoc """
  Prerenders the locked 9-template × frozen-fixture matrix to HTML files
  on disk so `test/example/priv/playwright/tests/email-visual.spec.ts` can
  open them via `file://` URLs without requiring a running Phoenix server.

  Each rendered HTML file has Premailex CSS inlining applied, matching the
  exact bytes that a real email client would receive.

  ## Frozen fixtures (D-86-04)

  All templates use deterministic fixture values so pixel-diff results never
  churn between CI runs:

  - `time`: `~U[2026-04-17 12:00:00Z]`
  - `ip`: `"203.0.113.42"` (RFC 5737 documentation IP)
  - `geo_city`: `"Test City"`
  - `device`: `"Test Browser on Test OS"`
  - `user.email`: `"snapshot-fixture@example.test"`
  - `old_email`: `"old@example.test"` (email-change templates)
  - `new_email`: `"new@example.test"` (email-change templates)
  - `app_name`: `"Example"` (the test/example app name)
  - `scheduled_date`: `~D[2026-12-01]` (deletion_scheduled_email)

  ## Output directory

  By default, HTML files are written to `test/example/priv/email_snapshots/`
  (gitignored — not committed to the repo; Playwright reads them at runtime).

  ## Usage

      # Normal run — render HTML files for Playwright
      MIX_ENV=test mix sigra.email.snapshot

      # Check mode — verify all 9 templates render successfully without
      # writing anything. Exits 0 if all templates render, exits 2 on failure.
      # Safe for CI drift detection.
      MIX_ENV=test mix sigra.email.snapshot --check

  After a normal run, start Playwright against the rendered files:

      cd test/example/priv/playwright
      npx playwright test tests/email-visual.spec.ts

  ## Regenerating baselines

  To update committed Playwright baselines after a template change:

      MIX_ENV=test mix sigra.email.snapshot
      cd test/example/priv/playwright && npm ci
      npx playwright test tests/email-visual.spec.ts --update-snapshots

  Review `git diff` on `__snapshots__/email-visual.spec.ts/` before committing.
  Include a reviewer note explaining what changed and why.
  """

  use Mix.Task

  # Example.Accounts.Emails is compiled only under the example subproject
  # (test/example) which is a separate Mix project. This task invokes a
  # subprocess to render emails so the root-level task can stay canonical.
  # Suppress undefined-function warnings for doc/compile-time passes.
  @compile {:no_warn_undefined, [Example.Accounts.Emails, Premailex]}

  # Locked fixture values per D-86-04
  @frozen_time ~U[2026-04-17 12:00:00Z]
  @frozen_ip "203.0.113.42"
  @frozen_city "Test City"
  @frozen_device "Test Browser on Test OS"
  @frozen_user_email "snapshot-fixture@example.test"
  @frozen_old_email "old@example.test"
  @frozen_new_email "new@example.test"
  @frozen_scheduled_date ~D[2026-12-01]

  # The 9 template slugs in the locked matrix (D-86-03)
  @templates [
    "lockout-notification",
    "suspicious-login",
    "email-change-confirmation",
    "email-change-notification",
    "email-changed",
    "password-changed",
    "deletion-scheduled",
    "deletion-cancelled",
    "deletion-finalized"
  ]

  @example_app_dir "test/example"
  @output_subdir "priv/email_snapshots"

  @impl Mix.Task
  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, strict: [check: :boolean, out: :string])
    check? = Keyword.get(opts, :check, false)
    out_dir = Keyword.get(opts, :out, Path.join(@example_app_dir, @output_subdir))

    Mix.shell().info("==> sigra.email.snapshot: rendering #{length(@templates)}-template matrix")

    if check? do
      run_check!()
    else
      run_render!(out_dir)
    end
  end

  # ---------------------------------------------------------------------------
  # Check mode: render each template via subprocess, verify no errors
  # ---------------------------------------------------------------------------

  defp run_check! do
    Mix.shell().info("Running in --check mode (no files written)")

    results = Enum.map(@templates, fn slug ->
      case render_template_via_subprocess(slug) do
        {:ok, html} when is_binary(html) and byte_size(html) > 0 ->
          Mix.shell().info("  OK #{slug} (#{byte_size(html)} bytes)")
          {:ok, slug}

        {:ok, html} ->
          Mix.shell().error("  EMPTY #{slug} (rendered to #{byte_size(html)} bytes)")
          {:error, slug}

        {:error, reason} ->
          Mix.shell().error("  FAIL #{slug}: #{reason}")
          {:error, slug}
      end
    end)

    failed = Enum.filter(results, &match?({:error, _}, &1))

    if failed == [] do
      Mix.shell().info("")
      Mix.shell().info("OK: all #{length(@templates)} templates rendered successfully (check mode)")
      :ok
    else
      names = Enum.map(failed, fn {:error, n} -> n end) |> Enum.join(", ")
      Mix.shell().error("FAILED: #{length(failed)} template(s) failed to render: #{names}")
      exit({:shutdown, 2})
    end
  end

  # ---------------------------------------------------------------------------
  # Normal mode: write HTML files to out_dir
  # ---------------------------------------------------------------------------

  defp run_render!(out_dir) do
    File.mkdir_p!(out_dir)
    Mix.shell().info("Writing HTML files to #{out_dir}/")

    results = Enum.map(@templates, fn slug ->
      case render_template_via_subprocess(slug) do
        {:ok, html} ->
          path = Path.join(out_dir, "#{slug}.html")
          File.write!(path, html)
          Mix.shell().info("  WROTE #{path} (#{byte_size(html)} bytes)")
          {:ok, slug}

        {:error, reason} ->
          Mix.shell().error("  FAIL #{slug}: #{reason}")
          {:error, slug}
      end
    end)

    failed = Enum.filter(results, &match?({:error, _}, &1))

    if failed == [] do
      Mix.shell().info("")
      Mix.shell().info("Done. #{length(@templates)} HTML files written to #{out_dir}/")
      Mix.shell().info("")
      Mix.shell().info("Next: cd test/example/priv/playwright && npx playwright test tests/email-visual.spec.ts")
      :ok
    else
      names = Enum.map(failed, fn {:error, n} -> n end) |> Enum.join(", ")
      Mix.raise("Failed to render #{length(failed)} template(s): #{names}")
    end
  end

  # ---------------------------------------------------------------------------
  # Render a single template by delegating to the example app subprocess
  # ---------------------------------------------------------------------------

  defp render_template_via_subprocess(slug) do
    script = render_script(slug)

    case System.cmd("mix", ["run", "--no-start", "--eval", script],
           cd: Path.expand(@example_app_dir),
           env: [{"MIX_ENV", "test"}],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        # Output is the raw HTML terminated by a sentinel marker
        case extract_html_from_output(output) do
          {:ok, html} -> {:ok, html}
          :error -> {:error, "could not extract HTML from output:\n#{String.slice(output, 0, 500)}"}
        end

      {output, code} ->
        {:error, "exit #{code}:\n#{String.slice(output, 0, 500)}"}
    end
  end

  # Sentinel used to delimit the HTML in subprocess stdout from Mix compile output
  @html_sentinel_start "<<<EMAIL_HTML_START>>>"
  @html_sentinel_end "<<<EMAIL_HTML_END>>>"

  defp extract_html_from_output(output) do
    with [_, rest] <- String.split(output, @html_sentinel_start, parts: 2),
         [html, _] <- String.split(rest, @html_sentinel_end, parts: 2) do
      {:ok, html}
    else
      _ -> :error
    end
  end

  # Elixir script that renders a single email template using frozen fixtures,
  # applies Premailex CSS inlining, and prints the HTML between sentinels.
  defp render_script(slug) do
    frozen_time = inspect(@frozen_time)
    frozen_date = inspect(@frozen_scheduled_date)

    """
    Application.ensure_all_started(:example)
    alias Example.Accounts.Emails

    user = %{email: "#{@frozen_user_email}"}
    details = %{
      ip: "#{@frozen_ip}",
      geo_city: "#{@frozen_city}",
      geo_country_code: "US",
      device: "#{@frozen_device}",
      time: #{frozen_time}
    }
    url = "https://example.test/users/confirm/TOKEN"
    cancel_url = "https://example.test/users/email/cancel/TOKEN"
    login_url = "https://example.test/users/log-in"

    email =
      case "#{slug}" do
        "lockout-notification" ->
          Emails.lockout_notification_email(user, details)
        "suspicious-login" ->
          Emails.suspicious_login_email(user, details)
        "email-change-confirmation" ->
          Emails.email_change_confirmation_email(%{email: "#{@frozen_old_email}"}, "#{@frozen_new_email}", url)
        "email-change-notification" ->
          Emails.email_change_notification_email(%{email: "#{@frozen_old_email}"}, "#{@frozen_new_email}", cancel_url)
        "email-changed" ->
          Emails.email_changed_email(%{email: "#{@frozen_new_email}"})
        "password-changed" ->
          Emails.password_changed_email(user, details)
        "deletion-scheduled" ->
          Emails.deletion_scheduled_email(user, #{frozen_date}, cancel_url)
        "deletion-cancelled" ->
          Emails.deletion_cancelled_email(user, login_url)
        "deletion-finalized" ->
          Emails.deletion_finalized_email("#{@frozen_user_email}")
      end

    html =
      if Code.ensure_loaded?(Premailex) do
        Premailex.to_inline_css(email.html_body)
      else
        email.html_body
      end

    IO.write("#{@html_sentinel_start}")
    IO.write(html)
    IO.write("#{@html_sentinel_end}")
    """
  end
end
