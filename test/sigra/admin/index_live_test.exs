defmodule Sigra.Admin.IndexLiveTest do
  use ExUnit.Case, async: true

  alias Sigra.Admin.Live.IndexLive

  test "hides week and month detail lines when the counts match" do
    html =
      render_index(%{
        growth: %{new_this_week: 4, new_this_month: 4},
        activity: %{available?: true, active_this_week: 3, active_this_month: 3},
        posture: posture(total: 10, mfa_enabled: 2, passkey_users: 2)
      })

    assert html =~ "4"
    assert html =~ "new this week"
    assert html =~ "3"
    assert html =~ "active this week"
    refute html =~ ~s(<dd class="sg-metric__subvalue">4 this month</dd>)
    refute html =~ ~s(<dd class="sg-metric__subvalue">3 this month</dd>)
    assert html =~ ~s(<dd class="sg-metric__subvalue">20% passkey coverage</dd>)
  end

  test "renders month detail lines when they add different information" do
    html =
      render_index(%{
        growth: %{new_this_week: 2, new_this_month: 5},
        activity: %{available?: true, active_this_week: 1, active_this_month: 4},
        posture: posture(total: 10, mfa_enabled: 3, passkey_users: 1)
      })

    assert html =~ ~s(<dd class="sg-metric__subvalue">5 this month</dd>)
    assert html =~ ~s(<dd class="sg-metric__subvalue">4 this month</dd>)
    assert html =~ ~s(<dd class="sg-metric__subvalue">10% passkey coverage</dd>)
  end

  defp render_index(summary_stats) do
    %{
      __changed__: %{},
      loading: false,
      page_title: "Global overview",
      summary_stats: summary_stats
    }
    |> IndexLive.render()
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp posture(overrides) do
    Map.merge(
      %{
        total: 0,
        confirmed: 0,
        mfa_enabled: 0,
        passkey_users: 0,
        locked_out: 0,
        deletion_scheduled: 0
      },
      Map.new(overrides)
    )
  end
end
