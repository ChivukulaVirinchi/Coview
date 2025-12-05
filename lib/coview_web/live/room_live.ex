defmodule CoviewWeb.RoomLive do
  @moduledoc """
  LiveView for viewing a shared browsing session.
  Followers join here to see the leader's browser view.
  """
  use CoviewWeb, :live_view

  alias Coview.Room
  alias CoviewWeb.Presence

  @impl true
  def mount(%{"room_id" => room_id}, _session, socket) do
    # Ensure room exists
    {:ok, _pid} = Room.get_or_create(room_id)

    socket =
      if connected?(socket) do
        # Subscribe to room updates via PubSub
        Phoenix.PubSub.subscribe(Coview.PubSub, "room:#{room_id}")

        # Track presence for this viewer
        user_id = generate_user_id()

        {:ok, _} =
          Presence.track(self(), "room:#{room_id}", user_id, %{
            role: "follower",
            joined_at: DateTime.utc_now()
          })

        # Get initial presence list
        presences = Presence.list("room:#{room_id}")

        # Get current room state (DOM, cursor, scroll)
        state = Room.get_state(room_id)

        socket
        |> assign(:user_id, user_id)
        |> assign(:current_dom, state.current_dom)
        |> assign(:cursor, state.cursor_position)
        |> assign(:scroll, state.scroll_position)
        |> assign(:presences, presences)
      else
        socket
        |> assign(:user_id, nil)
        |> assign(:current_dom, nil)
        |> assign(:cursor, nil)
        |> assign(:scroll, nil)
        |> assign(:presences, %{})
      end

    socket =
      socket
      |> assign(:room_id, room_id)
      |> assign(:has_leader, has_leader?(socket.assigns[:presences] || %{}))

    {:ok, socket}
  end

  # Handle DOM updates from leader
  @impl true
  def handle_info({:dom_update, dom}, socket) do
    require Logger
    Logger.info("[RoomLive] Received DOM update, size: #{String.length(dom)} bytes")
    {:noreply, assign(socket, :current_dom, dom)}
  end

  # Handle cursor updates from leader
  @impl true
  def handle_info({:cursor_update, position}, socket) do
    {:noreply, assign(socket, :cursor, position)}
  end

  # Handle scroll updates from leader
  @impl true
  def handle_info({:scroll_update, position}, socket) do
    socket =
      socket
      |> assign(:scroll, position)
      |> push_event("scroll_to", position)

    {:noreply, socket}
  end

  # Handle click events from leader - push to JS hook for ripple effect
  @impl true
  def handle_info({:click, position}, socket) do
    {:noreply, push_event(socket, "click", position)}
  end

  # Handle navigation events from leader
  @impl true
  def handle_info({:navigation, url}, socket) do
    {:noreply, assign(socket, :current_url, url)}
  end

  # Handle presence diff events
  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    presences = Presence.list("room:#{socket.assigns.room_id}")

    socket =
      socket
      |> assign(:presences, presences)
      |> assign(:has_leader, has_leader?(presences))

    {:noreply, socket}
  end

  # Catch-all for other messages
  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="flex h-[80vh]">
        <%!-- Main viewing area --%>
        <div class="flex-1 relative bg-base-200 rounded-lg overflow-hidden">
          <%= if @current_dom do %>
            <iframe
              id="view-frame"
              srcdoc={@current_dom}
              sandbox="allow-same-origin"
              class="w-full h-full border-0 rounded-lg"
              phx-hook="ViewFrame"
            />
          <% else %>
            <div class="flex items-center justify-center h-full text-base-content/60">
              <div class="text-center">
                <.icon name="hero-tv" class="w-16 h-16 mx-auto mb-4 opacity-50" />
                <%= if @has_leader do %>
                  <p class="text-lg">Leader connected</p>
                  <p class="text-sm mt-2">Waiting for content...</p>
                <% else %>
                  <p class="text-lg">Waiting for leader to share...</p>
                  <p class="text-sm mt-2">The shared view will appear here</p>
                <% end %>
              </div>
            </div>
          <% end %>

          <%!-- Ghost cursor overlay --%>
          <%= if @cursor do %>
            <div
              id="ghost-cursor"
              class="absolute pointer-events-none z-50 transition-all duration-75"
              style={"left: #{@cursor["x"] || @cursor[:x]}px; top: #{@cursor["y"] || @cursor[:y]}px;"}
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

          <%!-- Click ripple container --%>
          <div id="click-ripples" phx-hook="ClickRipple" class="absolute inset-0 pointer-events-none">
          </div>
        </div>

        <%!-- Sidebar --%>
        <div class="w-64 ml-4 border border-base-300 rounded-lg flex flex-col bg-base-100">
          <%!-- Room info --%>
          <div class="p-4 border-b border-base-300">
            <h3 class="font-semibold text-base-content mb-1">Room</h3>
            <p class="text-sm text-base-content/60 font-mono break-all">{@room_id}</p>

            <%!-- Copy link button --%>
            <button
              id="copy-link-btn"
              phx-hook="CopyLink"
              data-url={url(~p"/room/#{@room_id}")}
              class="mt-2 w-full px-3 py-1.5 text-xs bg-base-200 hover:bg-base-300 rounded transition flex items-center justify-center gap-1"
            >
              <.icon name="hero-clipboard-document" class="w-4 h-4" />
              <span>Copy link</span>
            </button>
          </div>

          <%!-- Presence --%>
          <div class="p-4 flex-1">
            <h3 class="font-semibold text-sm text-base-content/70 mb-2">
              {map_size(@presences)} viewing
            </h3>
            <div class="flex flex-wrap gap-1">
              <%= for {user_id, %{metas: [meta | _]}} <- @presences do %>
                <span class={[
                  "px-2 py-1 rounded text-xs",
                  if(meta.role == "leader",
                    do: "bg-primary/20 text-primary font-medium",
                    else: "bg-base-200 text-base-content/70"
                  )
                ]}>
                  <%= if meta.role == "leader" do %>
                    Leader
                  <% else %>
                    {String.slice(user_id, 0..4)}
                  <% end %>
                </span>
              <% end %>
            </div>

            <%= if not @has_leader do %>
              <div class="mt-4 p-3 bg-warning/10 border border-warning/30 rounded-lg">
                <p class="text-xs text-warning">
                  <.icon name="hero-exclamation-triangle" class="w-4 h-4 inline mr-1" />
                  No leader connected
                </p>
              </div>
            <% end %>
          </div>

          <%!-- Footer with status --%>
          <div class="p-4 border-t border-base-300">
            <div class="flex items-center gap-2 text-xs text-base-content/60">
              <span class={[
                "w-2 h-2 rounded-full",
                if(@has_leader, do: "bg-success", else: "bg-base-300")
              ]}>
              </span>
              <span>{if @has_leader, do: "Live", else: "Waiting"}</span>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp generate_user_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end

  defp has_leader?(presences) do
    Enum.any?(presences, fn {_user_id, %{metas: metas}} ->
      Enum.any?(metas, fn meta -> meta.role == "leader" end)
    end)
  end
end
