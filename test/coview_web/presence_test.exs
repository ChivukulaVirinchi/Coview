defmodule CoviewWeb.PresenceTest do
  use ExUnit.Case, async: true

  alias CoviewWeb.Presence

  describe "module configuration" do
    test "presence module exports track/4" do
      assert function_exported?(Presence, :track, 4)
    end

    test "presence module exports list/1" do
      assert function_exported?(Presence, :list, 1)
    end

    test "presence module exports get_by_key/2" do
      assert function_exported?(Presence, :get_by_key, 2)
    end
  end

  describe "tracking" do
    test "can track a user in a topic" do
      topic = "room:presence-test-#{System.unique_integer([:positive])}"

      # Track requires a pid - use self()
      {:ok, _ref} =
        Presence.track(self(), topic, "user-123", %{
          role: "leader",
          joined_at: DateTime.utc_now()
        })

      # List should show the tracked user
      presences = Presence.list(topic)
      assert Map.has_key?(presences, "user-123")

      [meta | _] = presences["user-123"].metas
      assert meta.role == "leader"
    end
  end
end
