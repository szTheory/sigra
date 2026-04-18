defmodule Sigra.OAuth.OAuthSettingsTemplateContractTest do
  @moduledoc """
  SEED-5 shift-left: generated `OAuthSettingsLive` template must retain D-03
  last-provider / no-password unlink defenses (no Playwright in `test/example`
  until OAuth routes are mounted there).
  """
  use ExUnit.Case, async: true

  @template Application.app_dir(:sigra, "priv/templates/sigra.gen.oauth/oauth_settings_live.ex")

  test "template references last-provider unlink guard and password gate copy" do
    src = File.read!(@template)

    assert src =~ "has_other_auth"
    assert src =~ "last_provider"
    assert src =~ "Set a password first to keep access to your account"
    assert src =~ ~S[title="Set a password first to keep access to your account."]
    assert src =~ "phx-click=\"unlink\""
  end
end
