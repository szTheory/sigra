defmodule Sigra.Templates.InstallerDriftTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Drift guard: every file in `test/example/lib/**` (and `test/example/test/**`)
  that was fixed during phase 10-06 under Rule 1 must stay in sync with the
  corresponding template in `priv/templates/sigra.install/`. Phase 10.1-02
  backported those fixes; this test prevents future silent divergence.

  Strategy: each fixture declares the Rule-1 fix as a pair of regular
  expressions — one for the template and one for the example copy — and
  the test asserts that BOTH files still contain the fix marker. If a
  contributor fixes a bug in only one side, this test fails with a message
  pointing at the diverged file.

  To add a new fixture pair, append to @fixtures. Use marker patterns
  that are specific to the fix (not generic code) so the test catches
  regressions without being brittle to unrelated whitespace changes.
  """

  # Each entry:
  #   :id        — human-readable fix label
  #   :template  — path to priv/templates/sigra.install/*
  #   :example   — path to test/example/lib/** (or test/**)
  #   :must_have — list of {label, regex_template, regex_example} tuples
  #                that must match in BOTH files
  #   :must_not  — optional list of {label, regex_template, regex_example}
  #                that must NOT match in either file
  @fixtures [
    %{
      id: "fix #1 — user_auth uses Gettext",
      template: "priv/templates/sigra.install/user_auth.ex",
      example: "test/example/lib/example_web/user_auth.ex",
      must_have: [
        {"use Gettext backend present",
         ~r/use Gettext, backend: <%= web_module %>\.Gettext/,
         ~r/use Gettext, backend: ExampleWeb\.Gettext/}
      ]
    },
    %{
      id: "fix #2 — Encrypted.Binary passthrough stub",
      template: "priv/templates/sigra.install/encrypted.ex",
      example: "test/example/lib/example/accounts/encrypted.ex",
      must_have: [
        {"use Ecto.Type", ~r/use Ecto\.Type/, ~r/use Ecto\.Type/},
        {"dump/cast/load passthrough",
         ~r/def dump\(value\) when is_binary\(value\), do: \{:ok, value\}/,
         ~r/def dump\(value\) when is_binary\(value\), do: \{:ok, value\}/}
      ]
    },
    %{
      id: "fix #3 — Swoosh Mailer stub wrapper",
      template: "priv/templates/sigra.install/mailer.ex",
      example: "test/example/lib/example/mailer.ex",
      must_have: [
        {"use Swoosh.Mailer", ~r/use Swoosh\.Mailer, otp_app:/,
         ~r/use Swoosh\.Mailer, otp_app: :example/}
      ]
    },
    %{
      id: "fix #4 — UserToken.build_session_token/2 arity",
      template: "priv/templates/sigra.install/user_token.ex",
      example: "test/example/lib/example/accounts/user_token.ex",
      must_have: [
        {"build_session_token accepts opts",
         ~r/def build_session_token\(user, _opts \\\\ \[\]\)/,
         ~r/def build_session_token\(user, _opts \\\\ \[\]\)/}
      ]
    },
    %{
      id: "fix #5 — auth.ex reset_user_password @doc de-duplicated",
      template: "priv/templates/sigra.install/auth.ex",
      example: "test/example/lib/example/accounts.ex",
      must_have: [
        {"legacy reset_user_password has inline comment, not @doc",
         ~r/# Legacy API accepting a user struct/,
         ~r/# Legacy API accepting a user struct/}
      ],
      must_not: [
        {"second @doc block absent",
         ~r/Resets the user password \(legacy API accepting user struct\)/,
         ~r/Resets the user password \(legacy API accepting user struct\)/}
      ]
    },
    %{
      id: "fix #6 — audit_event drops unused import Ecto.Changeset",
      template: "priv/templates/sigra.install/audit_event.ex",
      example: "test/example/lib/example/accounts/audit_event.ex",
      must_not: [
        {"import Ecto.Changeset removed",
         ~r/^\s*import Ecto\.Changeset\s*$/m,
         ~r/^\s*import Ecto\.Changeset\s*$/m}
      ]
    },
    %{
      id: "fix #7 — reset_password_controller drops unused alias",
      template: "priv/templates/sigra.install/reset_password_controller.ex",
      example: "test/example/lib/example_web/controllers/reset_password_controller.ex",
      must_not: [
        {"bare alias <context_module> removed",
         ~r/^\s*alias <%= context_module %>\s*$/m,
         ~r/^\s*alias Example\.Accounts\s*$/m}
      ]
    },
    %{
      id: "fix #8 — reset_password_live drops unused alias",
      template: "priv/templates/sigra.install/reset_password_live.ex",
      example: "test/example/lib/example_web/live/reset_password_live.ex",
      must_not: [
        {"bare alias <context_module> removed",
         ~r/^\s*alias <%= context_module %>\s*$/m,
         ~r/^\s*alias Example\.Accounts\s*$/m}
      ]
    },
    %{
      id: "fix #9 — confirmation_live unused var prefixed _user",
      template: "priv/templates/sigra.install/confirmation_live.ex",
      example: "test/example/lib/example_web/live/confirmation_live.ex",
      must_have: [
        {"handle_params assigns _user",
         ~r/_user = socket\.assigns\.current_scope\.user/,
         ~r/_user = socket\.assigns\.current_scope\.user/}
      ]
    },
    %{
      id: "fix #10 — unreachable :rate_limited clause removed from resend path",
      template: "priv/templates/sigra.install/confirmation_controller.ex",
      example: "test/example/lib/example_web/controllers/confirmation_controller.ex",
      must_not: [
        {"rate_limited clause absent in resend redirect",
         ~r/Please wait a few minutes before requesting another email/,
         ~r/Please wait a few minutes before requesting another email/}
      ]
    },
    %{
      id: "fix #10b — confirmation_live rate_limited clause removed from resend",
      template: "priv/templates/sigra.install/confirmation_live.ex",
      example: "test/example/lib/example_web/live/confirmation_live.ex",
      must_not: [
        {"rate_limited put_flash in resend absent",
         ~r/Please wait a few minutes before requesting another email/,
         ~r/Please wait a few minutes before requesting another email/}
      ]
    },
    %{
      id: "fix #12 — auth_fixtures destructures :secret key from setup_totp",
      template: "priv/templates/sigra.install/auth_fixtures.ex",
      example: "test/example/test/support/fixtures/auth_fixtures.ex",
      must_have: [
        {"%{secret: secret, backup_codes: codes} destructure",
         ~r/%\{secret: secret, backup_codes: codes\} =\s*\n\s*Sigra\.Testing\.setup_totp/,
         ~r/%\{secret: secret, backup_codes: codes\} =\s*\n\s*Sigra\.Testing\.setup_totp/}
      ],
      must_not: [
        {"destructure no longer uses :totp_secret key",
         ~r/%\{totp_secret: secret, backup_codes: codes\} =/,
         ~r/%\{totp_secret: secret, backup_codes: codes\} =/}
      ]
    },
    %{
      id: "fix #13 — auth_fixtures uses context alias (not bare Auth)",
      template: "priv/templates/sigra.install/auth_fixtures.ex",
      example: "test/example/test/support/fixtures/auth_fixtures.ex",
      must_not: [
        {"no bare Auth.sigra_config reference",
         ~r/\bAuth\.sigra_config\(\)/,
         ~r/\bAuth\.sigra_config\(\)/}
      ]
    },
    %{
      id: "fix #14 — auth_fixtures log_in_user import trimmed to arity 2",
      template: "priv/templates/sigra.install/auth_fixtures.ex",
      example: "test/example/test/support/fixtures/auth_fixtures.ex",
      must_have: [
        {"import only log_in_user: 2",
         ~r/only: \[log_in_user: 2\]/,
         ~r/only: \[log_in_user: 2\]/}
      ],
      must_not: [
        {"log_in_user: 3 not imported",
         ~r/log_in_user: 3/,
         ~r/log_in_user: 3/}
      ]
    },
    %{
      id: "fix #15 — conn_case_helpers references <app>.<context>Fixtures",
      template: "priv/templates/sigra.install/conn_case_helpers.ex",
      example: "test/example/test/support/conn_case_helpers.ex",
      must_have: [
        {"fully-qualified Fixtures call",
         ~r/<%= app_module %>\.<%= context_alias %>Fixtures\.user_fixture\(\)/,
         ~r/Example\.AccountsFixtures\.user_fixture\(\)/}
      ],
      must_not: [
        {"no bare Fixtures reference",
         ~r/^\s*user = Fixtures\.user_fixture\(\)/m,
         ~r/^\s*user = Fixtures\.user_fixture\(\)/m}
      ]
    },
    %{
      id: "fix #16 — locked_user_fixture truncates DateTime to :second",
      template: "priv/templates/sigra.install/auth_fixtures.ex",
      example: "test/example/test/support/fixtures/auth_fixtures.ex",
      must_have: [
        {"locked_at uses DateTime.truncate(:second)",
         ~r/locked_at: DateTime\.utc_now\(\) \|> DateTime\.truncate\(:second\)/,
         ~r/locked_at: DateTime\.utc_now\(\) \|> DateTime\.truncate\(:second\)/}
      ]
    },
    %{
      id: "fix #17 — auth.ex passes :user_token_schema at magic link + password reset call sites",
      template: "priv/templates/sigra.install/auth.ex",
      example: "test/example/lib/example/accounts.ex",
      must_have: [
        {"request_magic_link passes user_token_schema",
         ~r/SigraAuth\.request_magic_link\(Repo, email,[\s\S]*?user_token_schema:/,
         ~r/SigraAuth\.request_magic_link\(Repo, email,[\s\S]*?user_token_schema:/},
        {"request_password_reset passes user_token_schema",
         ~r/Sigra\.Auth\.request_password_reset\(Repo, email,[\s\S]*?user_token_schema:/,
         ~r/Sigra\.Auth\.request_password_reset\([\s\S]*?user_token_schema:/}
      ]
    }
  ]

  describe "installer template drift" do
    for fixture <- @fixtures do
      @fixture fixture
      test "#{fixture.id}" do
        template_path = Path.expand(@fixture.template, File.cwd!())
        example_path = Path.expand(@fixture.example, File.cwd!())

        assert File.exists?(template_path),
               "template missing: #{@fixture.template}"

        assert File.exists?(example_path),
               "example missing: #{@fixture.example} — phase 10-06 fixture is gone"

        template_content = File.read!(template_path)
        example_content = File.read!(example_path)

        for {label, tmpl_rx, ex_rx} <- Map.get(@fixture, :must_have, []) do
          assert template_content =~ tmpl_rx, """
          Drift: #{label} — missing in TEMPLATE #{@fixture.template}
          Expected regex (template): #{inspect(tmpl_rx)}
          If you fixed a bug in test/example/ but not in the template,
          backport the fix. If the fix is intentional-template-only, update
          this test's `@fixtures` entry.
          """

          assert example_content =~ ex_rx, """
          Drift: #{label} — missing in EXAMPLE #{@fixture.example}
          Expected regex (example): #{inspect(ex_rx)}
          If you fixed a bug in the template but not in test/example/,
          regenerate the example or apply the fix manually.
          """
        end

        for {label, tmpl_rx, ex_rx} <- Map.get(@fixture, :must_not, []) do
          refute template_content =~ tmpl_rx, """
          Drift: #{label} — STALE code re-introduced in TEMPLATE #{@fixture.template}
          Forbidden regex (template): #{inspect(tmpl_rx)}
          """

          refute example_content =~ ex_rx, """
          Drift: #{label} — STALE code re-introduced in EXAMPLE #{@fixture.example}
          Forbidden regex (example): #{inspect(ex_rx)}
          """
        end
      end
    end
  end
end
