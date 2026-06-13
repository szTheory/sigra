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
      template: "priv/templates/sigra.install/core/user_auth.ex",
      example: "test/example/lib/example_web/user_auth.ex",
      must_have: [
        {"use Gettext backend present", ~r/use Gettext, backend: <%= web_module %>\.Gettext/,
         ~r/use Gettext, backend: ExampleWeb\.Gettext/}
      ]
    },
    %{
      id: "fix #2 — Encrypted.Binary passthrough stub",
      template: "priv/templates/sigra.install/core/encrypted.ex",
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
      template: "priv/templates/sigra.install/core/mailer.ex",
      example: "test/example/lib/example/mailer.ex",
      must_have: [
        {"use Swoosh.Mailer", ~r/use Swoosh\.Mailer, otp_app:/,
         ~r/use Swoosh\.Mailer, otp_app: :example/}
      ]
    },
    %{
      # Plan 10.1.1-03 (B6): session token helpers were REMOVED from both
      # the template and the example. Sessions now live in Sigra's canonical
      # `user_sessions` store via `Sigra.Auth.create_session/4`. The old
      # `build_session_token/2` / `verify_session_token_query/1` helpers
      # must NOT reappear in either file.
      id: "fix #4 — UserToken session helpers removed (B6 unification)",
      template: "priv/templates/sigra.install/core/user_token.ex",
      example: "test/example/lib/example/accounts/user_token.ex",
      must_not: [
        {"build_session_token helper absent", ~r/def build_session_token\(/,
         ~r/def build_session_token\(/},
        {"verify_session_token_query helper absent", ~r/def verify_session_token_query\(/,
         ~r/def verify_session_token_query\(/}
      ]
    },
    %{
      # Plan 10.1.1-03 (B6): mirror of the auth.ex session helper rewrite.
      # generate_user_session_token must delegate to Sigra.Auth.create_session
      # in both the template and the example, and the legacy
      # UserToken.build_session_token call site must NOT reappear.
      id: "fix #4b — auth.ex session helpers delegate to Sigra canonical store",
      template: "priv/templates/sigra.install/core/auth.ex",
      example: "test/example/lib/example/accounts.ex",
      must_have: [
        {"generate_user_session_token calls Sigra.Auth.create_session",
         ~r/Sigra\.Auth\.create_session\(sigra_config\(\)/,
         ~r/Sigra\.Auth\.create_session\(sigra_config\(\)/}
      ],
      must_not: [
        {"legacy UserToken.build_session_token call absent", ~r/UserToken\.build_session_token/,
         ~r/UserToken\.build_session_token/}
      ]
    },
    %{
      # Plan 10.1.1-03 (B6): log_in_user must capture IP + user-agent from
      # conn and pass them into generate_user_session_token so the session
      # row has connection metadata.
      id: "fix #4c — user_auth.ex log_in_user captures IP + user-agent",
      template: "priv/templates/sigra.install/core/user_auth.ex",
      example: "test/example/lib/example_web/user_auth.ex",
      must_have: [
        {"ip extracted from conn.remote_ip via :inet.ntoa", ~r/:inet\.ntoa\(conn\.remote_ip\)/,
         ~r/:inet\.ntoa\(conn\.remote_ip\)/},
        {"user_agent extracted via get_req_header", ~r/get_req_header\(\s*"user-agent"\s*\)/,
         ~r/get_req_header\(\s*"user-agent"\s*\)/}
      ]
    },
    %{
      id: "fix #5 — auth.ex reset_user_password @doc de-duplicated",
      template: "priv/templates/sigra.install/core/auth.ex",
      example: "test/example/lib/example/accounts.ex",
      must_have: [
        {"legacy reset_user_password has inline comment, not @doc",
         ~r/# Legacy API accepting a user struct/, ~r/# Legacy API accepting a user struct/}
      ],
      must_not: [
        {"second @doc block absent",
         ~r/Resets the user password \(legacy API accepting user struct\)/,
         ~r/Resets the user password \(legacy API accepting user struct\)/}
      ]
    },
    %{
      id: "fix #6 — audit_event drops unused import Ecto.Changeset",
      template: "priv/templates/sigra.install/core/audit_event.ex",
      example: "test/example/lib/example/accounts/audit_event.ex",
      must_not: [
        {"import Ecto.Changeset removed", ~r/^\s*import Ecto\.Changeset\s*$/m,
         ~r/^\s*import Ecto\.Changeset\s*$/m}
      ]
    },
    %{
      id: "fix #7 — reset_password_controller drops unused alias",
      template: "priv/templates/sigra.install/core/reset_password_controller.ex",
      example: "test/example/lib/example_web/controllers/reset_password_controller.ex",
      must_not: [
        {"bare alias <context_module> removed", ~r/^\s*alias <%= context_module %>\s*$/m,
         ~r/^\s*alias Example\.Accounts\s*$/m}
      ]
    },
    %{
      id: "fix #8 — reset_password_live drops unused alias",
      template: "priv/templates/sigra.install/core/reset_password_live.ex",
      example: "test/example/lib/example_web/live/reset_password_live.ex",
      must_not: [
        {"bare alias <context_module> removed", ~r/^\s*alias <%= context_module %>\s*$/m,
         ~r/^\s*alias Example\.Accounts\s*$/m}
      ]
    },
    %{
      id: "fix #9 — confirmation_live unused var prefixed _user",
      template: "priv/templates/sigra.install/core/confirmation_live.ex",
      example: "test/example/lib/example_web/live/confirmation_live.ex",
      must_have: [
        {"handle_params assigns _user", ~r/_user = socket\.assigns\.current_scope\.user/,
         ~r/_user = socket\.assigns\.current_scope\.user/}
      ]
    },
    %{
      id: "fix #10 — unreachable :rate_limited clause removed from resend path",
      template: "priv/templates/sigra.install/core/confirmation_controller.ex",
      example: "test/example/lib/example_web/controllers/confirmation_controller.ex",
      must_not: [
        {"rate_limited clause absent in resend redirect",
         ~r/Please wait a few minutes before requesting another email/,
         ~r/Please wait a few minutes before requesting another email/}
      ]
    },
    %{
      id: "fix #10b — confirmation_live rate_limited clause removed from resend",
      template: "priv/templates/sigra.install/core/confirmation_live.ex",
      example: "test/example/lib/example_web/live/confirmation_live.ex",
      must_not: [
        {"rate_limited put_flash in resend absent",
         ~r/Please wait a few minutes before requesting another email/,
         ~r/Please wait a few minutes before requesting another email/}
      ]
    },
    %{
      id: "fix #12 — auth_fixtures destructures :secret key from setup_totp",
      template: "priv/templates/sigra.install/core/auth_fixtures.ex",
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
      template: "priv/templates/sigra.install/core/auth_fixtures.ex",
      example: "test/example/test/support/fixtures/auth_fixtures.ex",
      must_not: [
        {"no bare Auth.sigra_config reference", ~r/\bAuth\.sigra_config\(\)/,
         ~r/\bAuth\.sigra_config\(\)/}
      ]
    },
    %{
      id: "fix #14 — auth_fixtures log_in_user import trimmed to arity 2",
      template: "priv/templates/sigra.install/core/auth_fixtures.ex",
      example: "test/example/test/support/fixtures/auth_fixtures.ex",
      must_have: [
        {"import only log_in_user: 2", ~r/only: \[log_in_user: 2\]/, ~r/only: \[log_in_user: 2\]/}
      ],
      must_not: [
        {"log_in_user: 3 not imported", ~r/log_in_user: 3/, ~r/log_in_user: 3/}
      ]
    },
    %{
      id: "fix #15 — conn_case_helpers references <app>.<context>Fixtures",
      template: "priv/templates/sigra.install/core/conn_case_helpers.ex",
      example: "test/example/test/support/conn_case_helpers.ex",
      must_have: [
        {"fully-qualified Fixtures call",
         ~r/<%= app_module %>\.<%= context_alias %>Fixtures\.user_fixture\(\)/,
         ~r/Example\.AccountsFixtures\.user_fixture\(\)/}
      ],
      must_not: [
        {"no bare Fixtures reference", ~r/^\s*user = Fixtures\.user_fixture\(\)/m,
         ~r/^\s*user = Fixtures\.user_fixture\(\)/m}
      ]
    },
    %{
      id: "fix #16 — locked_user_fixture truncates DateTime to :second",
      template: "priv/templates/sigra.install/core/auth_fixtures.ex",
      example: "test/example/test/support/fixtures/auth_fixtures.ex",
      must_have: [
        {"locked_at uses DateTime.truncate(:second)",
         ~r/locked_at: DateTime\.utc_now\(\) \|> DateTime\.truncate\(:second\)/,
         ~r/locked_at: DateTime\.utc_now\(\) \|> DateTime\.truncate\(:second\)/}
      ]
    },
    %{
      id: "fix #17 — auth.ex passes :user_token_schema at magic link + password reset call sites",
      template: "priv/templates/sigra.install/core/auth.ex",
      example: "test/example/lib/example/accounts.ex",
      must_have: [
        {"request_magic_link passes user_token_schema",
         ~r/SigraAuth\.request_magic_link\(Repo, email,[\s\S]*?user_token_schema:/,
         ~r/SigraAuth\.request_magic_link\(Repo, email,[\s\S]*?user_token_schema:/},
        {"request_password_reset passes user_token_schema",
         ~r/Sigra\.Auth\.request_password_reset\(Repo, email,[\s\S]*?user_token_schema:/,
         ~r/Sigra\.Auth\.request_password_reset\([\s\S]*?user_token_schema:/}
      ]
    },
    %{
      # Phase 33 — INT-04 fix + guard: the generator's admin shell template must
      # expose a live Users link (desktop sidebar + top-bar + mobile bottom-nav)
      # matching the example-app shell. Catches the "dead <span>Users</span>"
      # class of navigation drift (WCAG SC 1.3.1).
      id: "fix #18 — admin_shell users nav + mobile bottom-nav",
      template: "priv/templates/sigra.install/admin/components/admin_shell.ex",
      example: "test/example/lib/example_web/components/admin_shell.ex",
      must_have: [
        {"users_link/1 helper defined", ~r/defp users_link\(/, ~r/defp users_link\(/},
        {"at least one href={users_link(@admin_scope)} usage",
         ~r/href=\{users_link\(@admin_scope\)\}/, ~r/href=\{users_link\(@admin_scope\)\}/},
        {"mobile bottom-nav Users label present (live sg-bottom-nav link)",
         ~r/<nav aria-label="Admin bottom nav"[\s\S]*?<\.admin_link[\s\S]*?href=\{users_link\(@admin_scope\)\}[\s\S]*?class=\{\["sg-bottom-nav__item"[\s\S]*?<span>Users<\/span>/,
         ~r/<nav aria-label="Admin bottom nav"[\s\S]*?<\.admin_link[\s\S]*?href=\{users_link\(@admin_scope\)\}[\s\S]*?class=\{\["sg-bottom-nav__item"[\s\S]*?<span>Users<\/span>/}
      ],
      must_not: [
        {"dead <span>Users</span> navigation item absent",
         ~r/<li>\s*<span[^>]*>Users<\/span>\s*<\/li>/,
         ~r/<li>\s*<span[^>]*>Users<\/span>\s*<\/li>/}
      ]
    },
    %{
      # Phase 35 — INT-04 generalization: same dead `<li><span>Label</span></li>`
      # anti-pattern as fix #18, but for the other desktop sidebar / nav labels so
      # regressions cannot reintroduce inert span-only rows for Organization, Global,
      # or Audit (WCAG 1.3.1). Users remains covered by fix #18.
      id: "fix #19 — admin_shell no inert span nav labels (generalized INT-04)",
      template: "priv/templates/sigra.install/admin/components/admin_shell.ex",
      example: "test/example/lib/example_web/components/admin_shell.ex",
      must_not:
        for label <- ["Organization", "Global", "Audit"], into: [] do
          escaped = Regex.escape(label)

          {
            "dead <span>#{label}</span> inert sidebar nav row absent",
            Regex.compile!("<li>\\s*<span[^>]*>#{escaped}</span>\\s*</li>"),
            Regex.compile!("<li>\\s*<span[^>]*>#{escaped}</span>\\s*</li>")
          }
        end
    },
    %{
      # Phase 37 — admin route navigation gets a Sigra-owned loading rail
      # installed from the same plain-JS seam in the example app and installer.
      id: "fix #20 — admin_hooks page loading indicator mirrored",
      template: "priv/templates/sigra.install/admin/admin_hooks.js",
      example: "test/example/assets/js/admin_hooks.js",
      must_have: [
        {"page loading installer present", ~r/function installPageLoadingIndicator\(/,
         ~r/function installPageLoadingIndicator\(/},
        {"LiveView page loading start listener present", ~r/phx:page-loading-start/,
         ~r/phx:page-loading-start/},
        {"LiveView page loading stop listener present", ~r/phx:page-loading-stop/,
         ~r/phx:page-loading-stop/},
        {"page loading failsafe present", ~r/PAGE_LOADING_MAX_ACTIVE_MS/,
         ~r/PAGE_LOADING_MAX_ACTIVE_MS/},
        {"page loading error reset present", ~r/pageLoadingKind\(event\) === "error"/,
         ~r/pageLoadingKind\(event\) === "error"/},
        {"admin page loading data attribute present", ~r/data-sg-admin-page-loading/,
         ~r/data-sg-admin-page-loading/},
        {"admin shell busy state present", ~r/aria-busy/, ~r/aria-busy/}
      ],
      must_not: [
        {"NProgress dependency absent", ~r/NProgress/, ~r/NProgress/},
        {"topbar package import absent", ~r/from ["']topbar["']|require\(["']topbar["']\)/,
         ~r/from ["']topbar["']|require\(["']topbar["']\)/}
      ]
    },
    %{
      # Admin form field help stays delegated and mirrored between the example
      # app and installer template so generated apps get the same touch/keyboard
      # affordance as Sigra's reference admin.
      id: "fix #21 — admin_hooks field help mirrored",
      template: "priv/templates/sigra.install/admin/admin_hooks.js",
      example: "test/example/assets/js/admin_hooks.js",
      must_have: [
        {"field help installer present", ~r/function installFieldHelp\(/,
         ~r/function installFieldHelp\(/},
        {"field help root selector present", ~r/data-sg-field-help-root/,
         ~r/data-sg-field-help-root/},
        {"field help trigger selector present", ~r/data-sg-field-help-trigger/,
         ~r/data-sg-field-help-trigger/},
        {"field help aria expanded state present", ~r/aria-expanded/, ~r/aria-expanded/},
        {"field help installed at boot", ~r/installFieldHelp\(\)/, ~r/installFieldHelp\(\)/}
      ]
    },
    %{
      # Auth-branding color previews use a small optimistic hook so color-picker
      # drags update CSS tokens immediately while LiveView keeps validation and
      # persistence authoritative.
      id: "fix #22 — admin_hooks auth branding preview mirrored",
      template: "priv/templates/sigra.install/admin/admin_hooks.js",
      example: "test/example/assets/js/admin_hooks.js",
      must_have: [
        {"auth branding preview hook present", ~r/var AuthBrandingPreview = \{/,
         ~r/var AuthBrandingPreview = \{/},
        {"color token map present", ~r/AUTH_BRANDING_COLOR_TOKENS/,
         ~r/AUTH_BRANDING_COLOR_TOKENS/},
        {"color input selector present", ~r/data-sg-auth-branding-color/,
         ~r/data-sg-auth-branding-color/},
        {"preview selector present", ~r/data-sg-auth-branding-preview/,
         ~r/data-sg-auth-branding-preview/},
        {"drag-time input propagation is stopped", ~r/event\.stopPropagation\(\)/,
         ~r/event\.stopPropagation\(\)/},
        {"hook exported in admin hooks map", ~r/AuthBrandingPreview: AuthBrandingPreview/,
         ~r/AuthBrandingPreview: AuthBrandingPreview/}
      ]
    }
  ]

  # Anchor fixture paths to the repo root resolved from __DIR__ rather than
  # File.cwd!/0. When `mix test` is invoked from a subdirectory (e.g. inside
  # an umbrella app or test/example/), File.cwd!/0 returns the caller's cwd,
  # not the sigra repo root, and the fixture paths fail to resolve.
  # Reviewed in 10.1 IN-04.
  @repo_root Path.expand("../../..", __DIR__)

  describe "installer template drift" do
    for fixture <- @fixtures do
      @fixture fixture
      test "#{fixture.id}" do
        template_path = Path.expand(@fixture.template, @repo_root)
        example_path = Path.expand(@fixture.example, @repo_root)

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
