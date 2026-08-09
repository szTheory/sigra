defmodule Example.Accounts.CrosswakeSessionAdapterTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures

  alias Crosswake.Companions.Sigra.Contracts
  alias Crosswake.Manifest.Types
  alias Example.Accounts.CrosswakeSessionAdapter

  @tag :crosswake_tracer
  test "freshly resolves a personal session and evaluates it without leaking credentials" do
    user = user_fixture()
    inserted_at = iso8601!("2026-08-09T12:00:00.123456Z")
    as_of = iso8601!("2026-08-09T12:01:00Z")
    raw_token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    raw_bytes = Base.url_decode64!(raw_token, padding: false)

    session =
      session_fixture(user, %{
        hashed_token: Sigra.Token.hash_token(raw_bytes),
        inserted_at: inserted_at,
        last_active_at: inserted_at
      })

    assert {:ok, binding} = CrosswakeSessionAdapter.expected_binding(raw_token)

    assert {:allow, result} =
             CrosswakeSessionAdapter.evaluate(
               raw_token,
               as_of,
               protected_route(),
               binding
             )

    assert result.org_id == nil
    assert result.session_ref == binding.session_ref
    assert result.subject_ref == binding.subject_ref
    assert result.session_version == binding.session_version
    assert result.session_ref != session.id
    assert result.subject_ref != user.id
    assert result.session_ref != raw_token
    assert result.subject_ref != raw_token
    assert result.session_ref != session.hashed_token
    assert result.subject_ref != session.hashed_token

    rendered = inspect(result)
    refute rendered =~ raw_token
    refute rendered =~ Base.encode16(session.hashed_token)
    refute rendered =~ session.id
    refute rendered =~ user.id
    refute Map.has_key?(result, :active_organization_id)
    refute Map.has_key?(result, :provider_payload)
    refute Map.has_key?(result, :oauth_credential)
  end

  @tag :crosswake_tracer
  test "released contract accepts a personal or nonblank organization scope and rejects blank scope" do
    attrs = lane_attrs()

    assert {:ok, personal_lane} =
             Contracts.new_session_authority_lane(Map.put(attrs, :org_id, nil))

    assert {:ok, personal_context} =
             Contracts.new_auth_context(%{session_authority_lane: personal_lane})

    assert personal_context.org_id == nil

    assert {:ok, organization_lane} =
             Contracts.new_session_authority_lane(Map.put(attrs, :org_id, "org_123"))

    assert {:error, errors} =
             Contracts.new_session_authority_lane(Map.put(attrs, :org_id, "   "))

    assert {:org_id, :invalid_optional_string} in errors
    assert organization_lane.org_id == "org_123"
  end

  defp protected_route do
    Types.new_route_entry(
      id: "crosswake-tracer",
      path: "/crosswake-tracer",
      runtime: :phoenix,
      auth_min_level: :password,
      requires_recent_auth: 600,
      auth_posture: :strict_recent
    )
  end

  defp lane_attrs do
    %{
      session_ref: "session_ref",
      subject_ref: "subject_ref",
      state: :active,
      assurance_level: :password,
      authn_methods: [:password],
      authenticated_at: "2026-08-09T12:00:00Z",
      last_seen_at: "2026-08-09T12:00:00Z",
      idle_expires_at: "2026-08-09T12:30:00Z",
      absolute_expires_at: "2026-08-10T12:00:00Z",
      session_version: 1,
      as_of: "2026-08-09T12:01:00Z"
    }
  end

  defp iso8601!(value) do
    {:ok, datetime, 0} = DateTime.from_iso8601(value)
    datetime
  end
end
