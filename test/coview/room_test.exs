defmodule Coview.RoomTest do
  use ExUnit.Case, async: true

  alias Coview.Room

  describe "get_or_create/1" do
    test "creates a new room if it doesn't exist" do
      room_id = "test-room-#{System.unique_integer([:positive])}"
      assert {:ok, pid} = Room.get_or_create(room_id)
      assert is_pid(pid)
    end

    test "returns existing room if already created" do
      room_id = "test-room-#{System.unique_integer([:positive])}"
      {:ok, pid1} = Room.get_or_create(room_id)
      {:ok, pid2} = Room.get_or_create(room_id)
      assert pid1 == pid2
    end
  end

  describe "exists?/1" do
    test "returns false for non-existent room" do
      room_id = "non-existent-#{System.unique_integer([:positive])}"
      refute Room.exists?(room_id)
    end

    test "returns true for existing room" do
      room_id = "test-room-#{System.unique_integer([:positive])}"
      {:ok, _pid} = Room.get_or_create(room_id)
      assert Room.exists?(room_id)
    end
  end

  describe "set_leader/2" do
    test "updates leader_id" do
      room_id = "test-room-#{System.unique_integer([:positive])}"
      {:ok, _pid} = Room.get_or_create(room_id)

      assert :ok = Room.set_leader(room_id, "leader-123")
      state = Room.get_state(room_id)
      assert state.leader_id == "leader-123"
    end
  end

  describe "get_state/1" do
    test "returns initial state with room_id and created_at" do
      room_id = "test-room-#{System.unique_integer([:positive])}"
      {:ok, _pid} = Room.get_or_create(room_id)

      state = Room.get_state(room_id)
      assert state.room_id == room_id
      assert %DateTime{} = state.created_at
      assert is_nil(state.leader_id)
      assert is_nil(state.current_dom)
      assert is_nil(state.cursor_position)
      assert is_nil(state.scroll_position)
    end
  end

  describe "update_dom/5" do
    test "stores DOM and broadcasts with viewport dimensions" do
      room_id = "test-room-#{System.unique_integer([:positive])}"
      {:ok, _pid} = Room.get_or_create(room_id)

      Phoenix.PubSub.subscribe(Coview.PubSub, "room:#{room_id}")

      html = "<html><body>Test</body></html>"
      Room.update_dom(room_id, html, 1920, 1080, true)

      assert_receive {:dom_update,
                      %{
                        html: ^html,
                        viewport_width: 1920,
                        viewport_height: 1080,
                        is_full_page: true
                      }}

      # Sync with GenServer to ensure state is updated
      state = Room.get_state(room_id)
      assert state.current_dom == html
      assert state.viewport_width == 1920
      assert state.viewport_height == 1080
    end

    test "stores DOM with nil viewport dimensions" do
      room_id = "test-room-#{System.unique_integer([:positive])}"
      {:ok, _pid} = Room.get_or_create(room_id)

      Phoenix.PubSub.subscribe(Coview.PubSub, "room:#{room_id}")

      html = "<html><body>Test</body></html>"
      Room.update_dom(room_id, html, nil, nil, true)

      assert_receive {:dom_update,
                      %{
                        html: ^html,
                        viewport_width: nil,
                        viewport_height: nil,
                        is_full_page: true
                      }}

      state = Room.get_state(room_id)
      assert state.current_dom == html
    end

    test "broadcasts incremental update with is_full_page false" do
      room_id = "test-room-#{System.unique_integer([:positive])}"
      {:ok, _pid} = Room.get_or_create(room_id)

      Phoenix.PubSub.subscribe(Coview.PubSub, "room:#{room_id}")

      html = "<html><body>Test</body></html>"
      Room.update_dom(room_id, html, 1920, 1080, false)

      assert_receive {:dom_update,
                      %{
                        html: ^html,
                        viewport_width: 1920,
                        viewport_height: 1080,
                        is_full_page: false
                      }}
    end
  end

  describe "update_cursor/2" do
    test "stores position and broadcasts" do
      room_id = "test-room-#{System.unique_integer([:positive])}"
      {:ok, _pid} = Room.get_or_create(room_id)

      Phoenix.PubSub.subscribe(Coview.PubSub, "room:#{room_id}")

      position = %{x: 100, y: 200}
      Room.update_cursor(room_id, position)

      assert_receive {:cursor_update, ^position}

      state = Room.get_state(room_id)
      assert state.cursor_position == position
    end
  end

  describe "update_scroll/2" do
    test "stores position and broadcasts" do
      room_id = "test-room-#{System.unique_integer([:positive])}"
      {:ok, _pid} = Room.get_or_create(room_id)

      Phoenix.PubSub.subscribe(Coview.PubSub, "room:#{room_id}")

      position = %{x: 0, y: 500}
      Room.update_scroll(room_id, position)

      assert_receive {:scroll_update, ^position}

      state = Room.get_state(room_id)
      assert state.scroll_position == position
    end
  end
end
