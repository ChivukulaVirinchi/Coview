defmodule CoviewWeb.UserSocket do
  @moduledoc """
  Socket for real-time communication between browser extension and Phoenix server.
  """
  use Phoenix.Socket

  channel "room:*", CoviewWeb.RoomChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end
