defmodule CoviewWeb.RoomChannelTest do
  use CoviewWeb.ChannelCase

  alias CoviewWeb.RoomChannel
  alias Coview.Room

  setup do
    room_id = "test-room-#{System.unique_integer([:positive])}"

    {:ok, _, socket} =
      CoviewWeb.UserSocket
      |> socket()
      |> subscribe_and_join(RoomChannel, "room:#{room_id}", %{"role" => "leader"})

    %{socket: socket, room_id: room_id}
  end

  describe "join/3" do
    test "leader can join a room" do
      room_id = "new-room-#{System.unique_integer([:positive])}"

      {:ok, _, socket} =
        CoviewWeb.UserSocket
        |> socket()
        |> subscribe_and_join(RoomChannel, "room:#{room_id}", %{"role" => "leader"})

      assert socket.assigns.role == "leader"
      assert socket.assigns.room_id == room_id
    end

    test "follower can join a room" do
      room_id = "new-room-#{System.unique_integer([:positive])}"

      {:ok, _, socket} =
        CoviewWeb.UserSocket
        |> socket()
        |> subscribe_and_join(RoomChannel, "room:#{room_id}", %{"role" => "follower"})

      assert socket.assigns.role == "follower"
    end

    test "creates room if it doesn't exist" do
      room_id = "brand-new-room-#{System.unique_integer([:positive])}"

      refute Room.exists?(room_id)

      {:ok, _, _socket} =
        CoviewWeb.UserSocket
        |> socket()
        |> subscribe_and_join(RoomChannel, "room:#{room_id}", %{"role" => "leader"})

      assert Room.exists?(room_id)
    end

    test "sets leader when role is leader" do
      room_id = "leader-room-#{System.unique_integer([:positive])}"

      {:ok, _, socket} =
        CoviewWeb.UserSocket
        |> socket()
        |> subscribe_and_join(RoomChannel, "room:#{room_id}", %{
          "role" => "leader",
          "user_id" => "leader-123"
        })

      state = Room.get_state(room_id)
      assert state.leader_id == "leader-123"
      assert socket.assigns.user_id == "leader-123"
    end
  end

  describe "handle_in dom_full" do
    test "leader can send DOM", %{socket: socket, room_id: room_id} do
      html = "<html><body>Test</body></html>"
      ref = push(socket, "dom_full", %{"html" => html})
      assert_reply ref, :ok

      # Verify state was updated
      state = Room.get_state(room_id)
      assert state.current_dom == html
    end

    test "follower cannot update DOM" do
      room_id = "follower-room-#{System.unique_integer([:positive])}"

      {:ok, _, socket} =
        CoviewWeb.UserSocket
        |> socket()
        |> subscribe_and_join(RoomChannel, "room:#{room_id}", %{"role" => "follower"})

      ref = push(socket, "dom_full", %{"html" => "<p>test</p>"})
      assert_reply ref, :ok

      # DOM should not be set
      state = Room.get_state(room_id)
      assert is_nil(state.current_dom)
    end
  end

  describe "handle_in cursor_move" do
    test "leader can send cursor position", %{socket: socket, room_id: room_id} do
      ref = push(socket, "cursor_move", %{"x" => 100, "y" => 200})
      assert_reply ref, :ok

      state = Room.get_state(room_id)
      assert state.cursor_position == %{"x" => 100, "y" => 200}
    end
  end

  describe "handle_in scroll" do
    test "leader can send scroll position", %{socket: socket, room_id: room_id} do
      ref = push(socket, "scroll", %{"x" => 0, "y" => 500})
      assert_reply ref, :ok

      state = Room.get_state(room_id)
      assert state.scroll_position == %{"x" => 0, "y" => 500}
    end
  end

  describe "handle_in click" do
    test "leader can send click event", %{socket: socket, room_id: room_id} do
      # Subscribe to the PubSub topic to receive the click event
      Phoenix.PubSub.subscribe(Coview.PubSub, "room:#{room_id}")

      ref = push(socket, "click", %{"x" => 150, "y" => 250})
      assert_reply ref, :ok

      # Click events are broadcast via PubSub
      assert_receive {:click, %{"x" => 150, "y" => 250}}
    end
  end

  describe "handle_in navigation" do
    test "leader can send navigation event", %{socket: socket, room_id: room_id} do
      # Subscribe to the PubSub topic to receive the navigation event
      Phoenix.PubSub.subscribe(Coview.PubSub, "room:#{room_id}")

      ref = push(socket, "navigation", %{"url" => "https://example.com/page"})
      assert_reply ref, :ok

      # Navigation events are broadcast via PubSub
      assert_receive {:navigation, "https://example.com/page"}
    end
  end

  describe "follower receives current state on join" do
    test "follower receives DOM if available" do
      room_id = "state-room-#{System.unique_integer([:positive])}"

      # Leader joins and sets DOM
      {:ok, _, leader_socket} =
        CoviewWeb.UserSocket
        |> socket()
        |> subscribe_and_join(RoomChannel, "room:#{room_id}", %{"role" => "leader"})

      push(leader_socket, "dom_full", %{"html" => "<p>Hello</p>"})

      # Give time for the state to be updated
      _ = Room.get_state(room_id)

      # Follower joins
      {:ok, _, _follower_socket} =
        CoviewWeb.UserSocket
        |> socket()
        |> subscribe_and_join(RoomChannel, "room:#{room_id}", %{"role" => "follower"})

      # Follower should receive the current DOM
      assert_push "dom_full", %{html: "<p>Hello</p>"}
    end
  end
end
