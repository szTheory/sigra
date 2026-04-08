defmodule Sigra.LockoutTest do
  use ExUnit.Case, async: true

  alias Sigra.Lockout

  # Embedded schema to simulate a user with lockout fields (Ecto.Changeset requires this)
  defmodule FakeUser do
    use Ecto.Schema

    embedded_schema do
      field :email, :string
      field :hashed_password, :string
      field :confirmed_at, :utc_datetime
      field :failed_login_attempts, :integer, default: 0
      field :locked_at, :utc_datetime
    end
  end

  # Fake repo that tracks update! calls
  defmodule FakeRepo do
    def update!(changeset) do
      Ecto.Changeset.apply_changes(changeset)
    end
  end

  describe "check/2" do
    test "returns :ok when user is nil (nonexistent user)" do
      assert :ok = Lockout.check(nil)
    end

    test "returns :ok when failed_login_attempts < threshold" do
      user = %FakeUser{failed_login_attempts: 3}
      assert :ok = Lockout.check(user)
    end

    test "returns :ok when locked_at is nil (never locked)" do
      user = %FakeUser{failed_login_attempts: 10, locked_at: nil}
      assert :ok = Lockout.check(user)
    end

    test "returns :ok when lockout has expired" do
      # Locked 20 minutes ago, duration is 15 minutes
      locked_at = DateTime.add(DateTime.utc_now(), -1200, :second)
      user = %FakeUser{failed_login_attempts: 5, locked_at: locked_at}
      assert :ok = Lockout.check(user, duration: 900)
    end

    test "returns {:error, :account_locked, remaining_seconds} when locked and within duration" do
      # Locked 5 minutes ago, duration is 15 minutes
      locked_at = DateTime.add(DateTime.utc_now(), -300, :second)
      user = %FakeUser{failed_login_attempts: 5, locked_at: locked_at}
      assert {:error, :account_locked, remaining} = Lockout.check(user, duration: 900)
      # Should be approximately 600 seconds remaining (900 - 300)
      assert remaining >= 595 and remaining <= 605
    end

    test "respects custom threshold" do
      user = %FakeUser{failed_login_attempts: 3, locked_at: DateTime.utc_now()}
      assert {:error, :account_locked, _remaining} = Lockout.check(user, threshold: 3)
    end

    test "uses default threshold of 5" do
      user = %FakeUser{failed_login_attempts: 4, locked_at: DateTime.utc_now()}
      assert :ok = Lockout.check(user)
    end
  end

  describe "increment!/3" do
    test "increments failed_login_attempts" do
      user = %FakeUser{id: 1, failed_login_attempts: 2}
      updated = Lockout.increment!(FakeRepo, user)
      assert updated.failed_login_attempts == 3
    end

    test "sets locked_at when threshold reached" do
      user = %FakeUser{id: 1, failed_login_attempts: 4}
      updated = Lockout.increment!(FakeRepo, user)
      assert updated.failed_login_attempts == 5
      assert %DateTime{} = updated.locked_at
    end

    test "does not set locked_at before threshold" do
      user = %FakeUser{id: 1, failed_login_attempts: 2}
      updated = Lockout.increment!(FakeRepo, user)
      assert updated.failed_login_attempts == 3
      assert is_nil(updated.locked_at)
    end

    test "respects custom threshold" do
      user = %FakeUser{id: 1, failed_login_attempts: 2}
      updated = Lockout.increment!(FakeRepo, user, threshold: 3)
      assert updated.failed_login_attempts == 3
      assert %DateTime{} = updated.locked_at
    end
  end

  describe "reset!/2" do
    test "sets failed_login_attempts to 0 and locked_at to nil" do
      user = %FakeUser{id: 1, failed_login_attempts: 5, locked_at: DateTime.utc_now()}
      updated = Lockout.reset!(FakeRepo, user)
      assert updated.failed_login_attempts == 0
      assert is_nil(updated.locked_at)
    end
  end

  describe "locked?/2" do
    test "returns false when user is nil" do
      refute Lockout.locked?(nil)
    end

    test "returns true when within lockout window" do
      user = %FakeUser{failed_login_attempts: 5, locked_at: DateTime.utc_now()}
      assert Lockout.locked?(user)
    end

    test "returns false when lockout expired" do
      locked_at = DateTime.add(DateTime.utc_now(), -1200, :second)
      user = %FakeUser{failed_login_attempts: 5, locked_at: locked_at}
      refute Lockout.locked?(user, duration: 900)
    end

    test "returns false when below threshold" do
      user = %FakeUser{failed_login_attempts: 3}
      refute Lockout.locked?(user)
    end
  end

  describe "lock_status/2" do
    test "returns :unlocked when user is nil" do
      assert :unlocked = Lockout.lock_status(nil)
    end

    test "returns {:locked, remaining_seconds} when locked" do
      locked_at = DateTime.add(DateTime.utc_now(), -300, :second)
      user = %FakeUser{failed_login_attempts: 5, locked_at: locked_at}
      assert {:locked, remaining} = Lockout.lock_status(user, duration: 900)
      assert remaining >= 595 and remaining <= 605
    end

    test "returns :unlocked when not locked" do
      user = %FakeUser{failed_login_attempts: 2}
      assert :unlocked = Lockout.lock_status(user)
    end
  end
end
