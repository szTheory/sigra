defmodule Example.Demo.SeedsScriptTest do
  @moduledoc """
  Process-level assertions for the `priv/repo/seeds.exs` environment guard.

  Covers the SEED-05 guard half that cannot be exercised by calling
  `Example.Demo.Seeds.run/0` directly.
  """
  use Example.DataCase, async: false

  alias Example.Accounts.User

  @demo_domain "@demo.sigra.dev"

  test "priv/repo/seeds.exs refuses to run in MIX_ENV=test before seeding demo users" do
    assert demo_user_count() == 0

    {output, status} =
      System.cmd("mix", ["run", "priv/repo/seeds.exs"],
        cd: example_app_root(),
        env: [{"MIX_ENV", "test"}],
        stderr_to_stdout: true
      )

    assert status != 0
    assert output =~ "seeds.exs must not run in MIX_ENV=test"
    assert output =~ "contaminate the sandboxed CI fixture DB"
    assert demo_user_count() == 0
  end

  defp demo_user_count do
    Repo.aggregate(
      from(u in User, where: like(u.email, ^"%#{@demo_domain}")),
      :count
    )
  end

  defp example_app_root do
    Path.expand("../../..", __DIR__)
  end
end
