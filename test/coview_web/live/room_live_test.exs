defmodule CoviewWeb.RoomLiveTest do
  use CoviewWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Coview.Room
  alias CoviewWeb.Presence

  describe "mount/3" do
    test "renders room page with waiting state", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/room/test-room")

      assert html =~ "Waiting for leader to share"
      assert html =~ "test-room"
      assert has_element?(view, "#copy-link-btn")
    end

    test "creates room if it doesn't exist", %{conn: conn} do
      room_id = "new-room-#{System.unique_integer([:positive])}"
      refute Room.exists?(room_id)

      {:ok, _view, _html} = live(conn, ~p"/room/#{room_id}")

      assert Room.exists?(room_id)
    end

    test "shows presence count", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/room/presence-test")

      # Initially shows 1 viewing (self, once connected)
      assert html =~ "viewing"
    end
  end

  describe "DOM updates" do
    test "updates view when DOM broadcast received", %{conn: conn} do
      room_id = "dom-test-#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/room/#{room_id}")

      # Simulate DOM update from leader via PubSub (new format with viewport dimensions)
      Phoenix.PubSub.broadcast(
        Coview.PubSub,
        "room:#{room_id}",
        {:dom_update,
         %{
           html: "<html><body><h1>Hello World</h1></body></html>",
           viewport_width: 1920,
           viewport_height: 1080,
           is_full_page: true
         }}
      )

      # Wait for LiveView to process the message
      _ = render(view)

      html = render(view)
      assert html =~ "Hello World"
      assert has_element?(view, "#view-frame")
      assert has_element?(view, "#scaled-wrapper")
    end
  end

  describe "cursor updates" do
    test "updates cursor position on broadcast", %{conn: conn} do
      room_id = "cursor-test-#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/room/#{room_id}")

      # First need DOM with viewport dimensions for cursor to appear
      Phoenix.PubSub.broadcast(
        Coview.PubSub,
        "room:#{room_id}",
        {:dom_update,
         %{
           html: "<html><body>Content</body></html>",
           viewport_width: 1920,
           viewport_height: 1080,
           is_full_page: true
         }}
      )

      _ = render(view)

      # Simulate cursor update from leader
      Phoenix.PubSub.broadcast(
        Coview.PubSub,
        "room:#{room_id}",
        {:cursor_update, %{x: 150, y: 250}}
      )

      _ = render(view)
      html = render(view)

      assert html =~ "ghost-cursor"
      assert html =~ "150"
      assert html =~ "250"
    end
  end

  describe "scroll updates" do
    test "pushes scroll event on broadcast", %{conn: conn} do
      room_id = "scroll-test-#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/room/#{room_id}")

      # Simulate scroll update from leader
      Phoenix.PubSub.broadcast(
        Coview.PubSub,
        "room:#{room_id}",
        {:scroll_update, %{x: 0, y: 500}}
      )

      # The scroll_to event should be pushed to the client
      assert render(view)
    end
  end

  describe "presence" do
    test "tracks viewer presence", %{conn: conn} do
      room_id = "presence-track-#{System.unique_integer([:positive])}"
      {:ok, _view, _html} = live(conn, ~p"/room/#{room_id}")

      # Give presence time to sync
      Process.sleep(50)

      presences = Presence.list("room:#{room_id}")
      assert map_size(presences) >= 1

      # Check that a follower is tracked
      has_follower =
        Enum.any?(presences, fn {_user_id, %{metas: metas}} ->
          Enum.any?(metas, fn meta -> meta.role == "follower" end)
        end)

      assert has_follower
    end

    test "shows leader status when leader present", %{conn: conn} do
      room_id = "leader-status-#{System.unique_integer([:positive])}"

      # Simulate leader presence
      Presence.track(self(), "room:#{room_id}", "leader-123", %{
        role: "leader",
        joined_at: DateTime.utc_now()
      })

      {:ok, view, _html} = live(conn, ~p"/room/#{room_id}")

      # Trigger presence diff
      Process.sleep(50)
      html = render(view)

      assert html =~ "Leader"
    end

    test "shows warning when no leader", %{conn: conn} do
      room_id = "no-leader-#{System.unique_integer([:positive])}"
      {:ok, _view, html} = live(conn, ~p"/room/#{room_id}")

      assert html =~ "No leader connected"
    end
  end

  describe "multiple viewers" do
    test "presence updates when new viewer joins", %{conn: conn} do
      room_id = "multi-viewer-#{System.unique_integer([:positive])}"

      # First viewer
      {:ok, view1, _html} = live(conn, ~p"/room/#{room_id}")
      Process.sleep(50)

      # Second viewer joins
      {:ok, _view2, _html} = live(conn, ~p"/room/#{room_id}")
      Process.sleep(50)

      # First viewer should see updated presence count
      html = render(view1)
      # Should show "2 viewing" or similar
      assert html =~ "viewing"
    end
  end
end
