defmodule CoviewWeb.RoomLive do
  @moduledoc """
  LiveView for viewing a shared browsing session.
  Followers join here to see the leader's browser view.
  """
  use CoviewWeb, :live_view

  alias Coview.Room

  @impl true
  def mount(%{"room_id" => room_id}, _session, socket) do
    # Ensure room exists
    {:ok, _pid} = Room.get_or_create(room_id)

    socket =
      socket
      |> assign(:room_id, room_id)
      |> assign(:current_dom, nil)
      |> assign(:cursor, nil)
      |> assign(:scroll, nil)
      |> assign(:presences, %{})

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="flex h-[80vh]">
        <%!-- Main viewing area --%>
        <div class="flex-1 relative bg-base-200 rounded-lg">
          <%= if @current_dom do %>
            <iframe
              id="view-frame"
              srcdoc={@current_dom}
              sandbox="allow-same-origin"
              class="w-full h-full border-0 rounded-lg"
            />
          <% else %>
            <div class="flex items-center justify-center h-full text-base-content/60">
              <div class="text-center">
                <.icon name="hero-tv" class="w-16 h-16 mx-auto mb-4 opacity-50" />
                <p class="text-lg">Waiting for leader to share...</p>
                <p class="text-sm mt-2">The shared view will appear here</p>
              </div>
            </div>
          <% end %>

          <%!-- Ghost cursor overlay --%>
          <%= if @cursor do %>
            <div
              id="ghost-cursor"
              class="absolute pointer-events-none z-50 transition-all duration-75"
              style={"left: #{@cursor["x"]}px; top: #{@cursor["y"]}px;"}
            >
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                <path
                  d="M4 4L12 20L14 14L20 12L4 4Z"
                  fill="#3B82F6"
                  stroke="#1E40AF"
                  stroke-width="2"
                />
              </svg>
            </div>
          <% end %>
        </div>

        <%!-- Sidebar --%>
        <div class="w-64 ml-4 border border-base-300 rounded-lg flex flex-col bg-base-100">
          <%!-- Room info --%>
          <div class="p-4 border-b border-base-300">
            <h3 class="font-semibold text-base-content mb-1">Room</h3>
            <p class="text-sm text-base-content/60 font-mono">{@room_id}</p>
          </div>

          <%!-- Presence --%>
          <div class="p-4">
            <h3 class="font-semibold text-sm text-base-content/70 mb-2">
              {map_size(@presences)} viewing
            </h3>
            <div class="flex flex-wrap gap-1">
              <%= for {user_id, %{metas: [meta | _]}} <- @presences do %>
                <span class={[
                  "px-2 py-1 rounded text-xs",
                  if(meta.role == "leader",
                    do: "bg-primary/20 text-primary",
                    else: "bg-base-200 text-base-content/70"
                  )
                ]}>
                  {if meta.role == "leader", do: "Leader", else: String.slice(user_id, 0..4)}
                </span>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
