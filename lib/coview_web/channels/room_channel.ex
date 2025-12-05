defmodule CoviewWeb.RoomChannel do
  @moduledoc """
  Channel for real-time room communication.

  Handles:
  - Leader joining and sending DOM updates
  - Follower joining and receiving updates
  - Cursor, scroll, and click event broadcasting
  """
  use CoviewWeb, :channel

  alias Coview.Room
  alias CoviewWeb.Presence

  @impl true
  def join("room:" <> room_id, params, socket) do
    role = Map.get(params, "role", "follower")
    user_id = Map.get(params, "user_id") || generate_user_id()

    # Create room if doesn't exist
    {:ok, _pid} = Room.get_or_create(room_id)

    # Track presence after join
    send(self(), :after_join)

    socket =
      socket
      |> assign(:room_id, room_id)
      |> assign(:role, role)
      |> assign(:user_id, user_id)

    if role == "leader" do
      Room.set_leader(room_id, user_id)
    end

    {:ok, socket}
  end

  @impl true
  def handle_info(:after_join, socket) do
    {:ok, _} =
      Presence.track(socket, socket.assigns.user_id, %{
        role: socket.assigns.role,
        joined_at: DateTime.utc_now()
      })

    # Send current state to newly joined follower
    if socket.assigns.role == "follower" do
      state = Room.get_state(socket.assigns.room_id)

      if state.current_dom do
        push(socket, "dom_full", %{html: state.current_dom})
      end

      if state.cursor_position do
        push(socket, "cursor_move", state.cursor_position)
      end

      if state.scroll_position do
        push(socket, "scroll", state.scroll_position)
      end
    end

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  # Ignore PubSub broadcasts that come back to the channel
  # (these are for LiveView subscribers, not channel subscribers)
  @impl true
  def handle_info({:dom_update, _}, socket), do: {:noreply, socket}
  def handle_info({:cursor_update, _}, socket), do: {:noreply, socket}
  def handle_info({:scroll_update, _}, socket), do: {:noreply, socket}
  def handle_info({:click, _}, socket), do: {:noreply, socket}
  def handle_info({:navigation, _}, socket), do: {:noreply, socket}

  # Leader sends full DOM
  @impl true
  def handle_in("dom_full", %{"html" => html}, socket) do
    require Logger

    Logger.info(
      "[RoomChannel] Received dom_full from #{socket.assigns.role}, room: #{socket.assigns.room_id}, size: #{String.length(html)} bytes"
    )

    if socket.assigns.role == "leader" do
      Room.update_dom(socket.assigns.room_id, html)
      Logger.info("[RoomChannel] DOM update sent to Room GenServer")
    else
      Logger.warning("[RoomChannel] Non-leader tried to send DOM")
    end

    {:reply, :ok, socket}
  end

  # Leader sends DOM diff
  @impl true
  def handle_in("dom_diff", %{"diff" => diff}, socket) do
    if socket.assigns.role == "leader" do
      broadcast!(socket, "dom_diff", %{diff: diff})
    end

    {:reply, :ok, socket}
  end

  # Leader sends cursor position
  @impl true
  def handle_in("cursor_move", payload, socket) do
    if socket.assigns.role == "leader" do
      Room.update_cursor(socket.assigns.room_id, payload)
    end

    {:reply, :ok, socket}
  end

  # Leader sends scroll position
  @impl true
  def handle_in("scroll", payload, socket) do
    if socket.assigns.role == "leader" do
      Room.update_scroll(socket.assigns.room_id, payload)
    end

    {:reply, :ok, socket}
  end

  # Leader sends click event
  @impl true
  def handle_in("click", payload, socket) do
    if socket.assigns.role == "leader" do
      Room.broadcast_click(socket.assigns.room_id, payload)
    end

    {:reply, :ok, socket}
  end

  # Leader sends navigation event
  @impl true
  def handle_in("navigation", %{"url" => url}, socket) do
    if socket.assigns.role == "leader" do
      Room.broadcast_navigation(socket.assigns.room_id, url)
    end

    {:reply, :ok, socket}
  end

  defp generate_user_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end
end
