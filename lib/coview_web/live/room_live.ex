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

        # Get current room state (DOM, cursor, scroll, viewport)
        state = Room.get_state(room_id)

        socket
        |> assign(:user_id, user_id)
        |> assign(:current_dom, state.current_dom)
        |> assign(:viewport_width, state.viewport_width)
        |> assign(:viewport_height, state.viewport_height)
        |> assign(:cursor, state.cursor_position)
        |> assign(:scroll, state.scroll_position)
        |> assign(:presences, presences)
      else
        socket
        |> assign(:user_id, nil)
        |> assign(:current_dom, nil)
        |> assign(:viewport_width, nil)
        |> assign(:viewport_height, nil)
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

  # Handle DOM updates from leader (now includes viewport dimensions and full_page flag)
  # We push to JS hook for incremental morphdom patching instead of replacing srcdoc
  @impl true
  def handle_info(
        {:dom_update, %{html: html, viewport_width: vw, viewport_height: vh} = payload},
        socket
      ) do
    require Logger

    is_full_page = Map.get(payload, :is_full_page, true)

    Logger.info(
      "[RoomLive] Received DOM update, size: #{String.length(html)} bytes, viewport: #{vw}x#{vh}, full_page: #{is_full_page}"
    )

    # Track if this is the first DOM (need full render via srcdoc)
    is_first_dom = is_nil(socket.assigns.current_dom)

    socket =
      socket
      |> assign(:current_dom, html)
      |> assign(:viewport_width, vw)
      |> assign(:viewport_height, vh)

    # Push DOM to JS hook for update
    # - First DOM: triggers full iframe via srcdoc (template render)
    # - Full page navigation: tell JS to replace iframe content completely
    # - Incremental: tell JS to use morphdom for patching
    socket =
      if not is_first_dom do
        push_event(socket, "dom_update", %{html: html, is_full_page: is_full_page})
      else
        socket
      end

    {:noreply, socket}
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
      <div class="flex flex-col h-[90vh]">
        <%!-- Top bar with room info --%>
        <div class="flex items-center justify-between px-4 py-2 bg-base-100 border-b border-base-300 rounded-t-lg">
          <%!-- Left: Room info & status --%>
          <div class="flex items-center gap-4">
            <div class="flex items-center gap-2">
              <span class={[
                "w-2 h-2 rounded-full",
                if(@has_leader, do: "bg-success animate-pulse", else: "bg-base-300")
              ]}>
              </span>
              <span class="text-sm font-medium">
                {if @has_leader, do: "Live", else: "Waiting"}
              </span>
            </div>
            <div class="text-sm text-base-content/60">
              <span class="font-mono">{@room_id}</span>
              <%= if @viewport_width && @viewport_height do %>
                <span class="ml-2 text-xs">({@viewport_width}x{@viewport_height})</span>
              <% end %>
            </div>
          </div>

          <%!-- Right: Viewers & Copy link --%>
          <div class="flex items-center gap-4">
            <%!-- Presence indicators --%>
            <div class="flex items-center gap-2">
              <span class="text-sm text-base-content/60">{map_size(@presences)} viewing</span>
              <div class="flex -space-x-1">
                <%= for {_user_id, %{metas: [meta | _]}} <- Enum.take(@presences, 5) do %>
                  <span class={[
                    "w-6 h-6 rounded-full flex items-center justify-center text-xs border-2 border-base-100",
                    if(meta.role == "leader",
                      do: "bg-primary text-primary-content",
                      else: "bg-base-300 text-base-content/70"
                    )
                  ]}>
                    {if meta.role == "leader", do: "L", else: "V"}
                  </span>
                <% end %>
              </div>
            </div>

            <%!-- Copy link button --%>
            <button
              id="copy-link-btn"
              phx-hook="CopyLink"
              data-url={url(~p"/room/#{@room_id}")}
              class="px-3 py-1.5 text-xs bg-base-200 hover:bg-base-300 rounded transition flex items-center gap-1"
            >
              <.icon name="hero-clipboard-document" class="w-4 h-4" />
              <span>Copy link</span>
            </button>
          </div>
        </div>

        <%!-- Main viewing area - uses JS hook to scale iframe to fit --%>
        <div
          id="view-container"
          class="flex-1 relative bg-base-200 rounded-b-lg overflow-hidden"
          phx-hook="ScaledView"
          data-viewport-width={@viewport_width}
          data-viewport-height={@viewport_height}
        >
          <%= if @current_dom && @viewport_width && @viewport_height do %>
            <%!-- Scaled wrapper - JS will calculate and apply the scale transform --%>
            <div
              id="scaled-wrapper"
              class="origin-top-left absolute"
              style={"width: #{@viewport_width}px; height: #{@viewport_height}px;"}
            >
              <%!-- phx-update="ignore" prevents LiveView from touching iframe after initial render --%>
              <%!-- DOM updates are pushed via push_event and applied with morphdom --%>
              <div id="view-frame-wrapper" phx-update="ignore">
                <iframe
                  id="view-frame"
                  srcdoc={@current_dom}
                  sandbox="allow-same-origin"
                  class="w-full h-full border-0"
                  style={"width: #{@viewport_width}px; height: #{@viewport_height}px;"}
                  phx-hook="ViewFrame"
                />
              </div>

              <%!-- Ghost cursor - positioned with leader's exact pixel coordinates --%>
              <%= if @cursor do %>
                <div
                  id="ghost-cursor"
                  class="absolute pointer-events-none z-50"
                  style={"left: #{@cursor["x"] || @cursor[:x] || 0}px; top: #{@cursor["y"] || @cursor[:y] || 0}px;"}
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
              <div
                id="click-ripples"
                phx-hook="ClickRipple"
                class="absolute inset-0 pointer-events-none"
              >
              </div>
            </div>
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

          <%!-- No leader warning overlay --%>
          <%= if not @has_leader and is_nil(@current_dom) do %>
            <div class="absolute bottom-4 left-1/2 -translate-x-1/2">
              <div class="px-4 py-2 bg-warning/10 border border-warning/30 rounded-lg">
                <p class="text-xs text-warning flex items-center gap-1">
                  <.icon name="hero-exclamation-triangle" class="w-4 h-4" /> No leader connected
                </p>
              </div>
            </div>
          <% end %>
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
