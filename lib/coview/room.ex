defmodule Coview.Room do
  @moduledoc """
  GenServer that manages the state of a collaborative viewing room.

  Each room holds:
  - Current DOM state shared by the leader
  - Cursor position for ghost cursor display
  - Scroll position for viewport sync
  - Leader information
  """
  use GenServer

  # State structure
  defstruct [
    :room_id,
    :leader_id,
    :current_dom,
    :current_url,
    :cursor_position,
    :scroll_position,
    :created_at,
    followers: []
  ]

  # Client API

  @doc """
  Starts a new Room process for the given room_id.
  """
  def start_link(room_id) do
    GenServer.start_link(__MODULE__, room_id, name: via_tuple(room_id))
  end

  @doc """
  Returns the via tuple for Registry lookup.
  """
  def via_tuple(room_id) do
    {:via, Registry, {Coview.RoomRegistry, room_id}}
  end

  @doc """
  Gets an existing room or creates a new one.
  Returns {:ok, pid} on success.
  """
  def get_or_create(room_id) do
    case Registry.lookup(Coview.RoomRegistry, room_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> DynamicSupervisor.start_child(Coview.RoomSupervisor, {__MODULE__, room_id})
    end
  end

  @doc """
  Sets the leader for the room.
  """
  def set_leader(room_id, leader_id) do
    GenServer.call(via_tuple(room_id), {:set_leader, leader_id})
  end

  @doc """
  Updates the DOM state and broadcasts to all subscribers.
  """
  def update_dom(room_id, dom) do
    GenServer.cast(via_tuple(room_id), {:update_dom, dom})
  end

  @doc """
  Updates the cursor position and broadcasts to all subscribers.
  """
  def update_cursor(room_id, position) do
    GenServer.cast(via_tuple(room_id), {:update_cursor, position})
  end

  @doc """
  Updates the scroll position and broadcasts to all subscribers.
  """
  def update_scroll(room_id, position) do
    GenServer.cast(via_tuple(room_id), {:update_scroll, position})
  end

  @doc """
  Gets the current room state.
  """
  def get_state(room_id) do
    GenServer.call(via_tuple(room_id), :get_state)
  end

  @doc """
  Checks if a room exists.
  """
  def exists?(room_id) do
    case Registry.lookup(Coview.RoomRegistry, room_id) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  # Server Callbacks

  @impl true
  def init(room_id) do
    state = %__MODULE__{
      room_id: room_id,
      created_at: DateTime.utc_now()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:set_leader, leader_id}, _from, state) do
    {:reply, :ok, %{state | leader_id: leader_id}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:update_dom, dom}, state) do
    Phoenix.PubSub.broadcast(Coview.PubSub, "room:#{state.room_id}", {:dom_update, dom})
    {:noreply, %{state | current_dom: dom}}
  end

  @impl true
  def handle_cast({:update_cursor, position}, state) do
    Phoenix.PubSub.broadcast(Coview.PubSub, "room:#{state.room_id}", {:cursor_update, position})
    {:noreply, %{state | cursor_position: position}}
  end

  @impl true
  def handle_cast({:update_scroll, position}, state) do
    Phoenix.PubSub.broadcast(Coview.PubSub, "room:#{state.room_id}", {:scroll_update, position})
    {:noreply, %{state | scroll_position: position}}
  end
end
