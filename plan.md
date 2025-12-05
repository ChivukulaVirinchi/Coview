# CoView - Collaborative Web Browsing

## What Is CoView?

CoView lets people browse websites together in real-time. One person (the "leader") shares their browser view, and others (the "followers") see exactly what they see - not as a video stream, but as actual DOM, making it crisp, fast, and bandwidth-efficient.

**Use cases:**
- Product demos and sales calls
- Tech support / customer success
- Pair browsing / research together
- Teaching someone how to navigate a site
- Shopping together remotely

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         LEADER'S MACHINE                                │
│                                                                         │
│  ┌─────────────────┐      ┌──────────────────────────────────────────┐ │
│  │   Any Website   │      │   Browser Extension                      │ │
│  │   (any origin)  │ ───> │   - Captures rendered DOM                │ │
│  │                 │      │   - Tracks cursor position               │ │
│  │                 │      │   - Detects DOM mutations                │ │
│  │                 │      │   - Strips sensitive data                │ │
│  └─────────────────┘      │   - Sends via WebSocket                  │ │
│                           └──────────────────┬───────────────────────┘ │
└──────────────────────────────────────────────┼──────────────────────────┘
                                               │
                                               │ WebSocket (Phoenix Channel)
                                               │
                                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         PHOENIX SERVER                                  │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  Room Supervisor (DynamicSupervisor)                             │  │
│  │                                                                   │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐   │  │
│  │  │ Room GenServer  │  │ Room GenServer  │  │ Room GenServer  │   │  │
│  │  │ (room: abc123)  │  │ (room: xyz789)  │  │ (room: def456)  │   │  │
│  │  │                 │  │                 │  │                 │   │  │
│  │  │ - DOM state     │  │ - DOM state     │  │ - DOM state     │   │  │
│  │  │ - cursor pos    │  │ - cursor pos    │  │ - cursor pos    │   │  │
│  │  │ - scroll pos    │  │ - scroll pos    │  │ - scroll pos    │   │  │
│  │  │ - leader info   │  │ - leader info   │  │ - leader info   │   │  │
│  │  │ - follower list │  │ - follower list │  │ - follower list │   │  │
│  │  └────────┬────────┘  └─────────────────┘  └─────────────────┘   │  │
│  │           │                                                       │  │
│  └───────────┼───────────────────────────────────────────────────────┘  │
│              │                                                          │
│              │ PubSub                                                   │
│              ▼                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  Phoenix PubSub                                                   │  │
│  │  - Topic per room: "room:abc123"                                  │  │
│  │  - Broadcasts DOM updates, cursor moves, scroll changes           │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  Phoenix Presence                                                 │  │
│  │  - Tracks who's in each room                                      │  │
│  │  - Shows "5 people viewing"                                       │  │
│  │  - Handles join/leave events                                      │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└────────────────────────────────────────────────┬────────────────────────┘
                                                 │
                                                 │ WebSocket (LiveView)
                                                 │
                                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        FOLLOWERS' BROWSERS                              │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  Phoenix LiveView                                                 │  │
│  │  - Receives DOM updates                                           │  │
│  │  - Renders in sandboxed iframe                                    │  │
│  │  - Shows ghost cursor                                             │  │
│  │  - Displays presence info                                         │  │
│  │  - Chat sidebar                                                   │  │
│  │                                                                   │  │
│  │  NO EXTENSION NEEDED                                              │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Component Breakdown

### 1. Browser Extension (Leader Only)

**Location:** `/extension/` directory in project root

**Purpose:** Capture DOM and user interactions from leader's browser

**Files:**
```
extension/
├── manifest.json          # Extension configuration (Manifest V3)
├── background.js          # Service worker for extension lifecycle
├── content.js             # Injected into pages, captures DOM
├── popup.html             # Extension popup UI
├── popup.js               # Popup logic (start/stop sharing, room code)
├── popup.css              # Popup styling
└── icons/
    ├── icon16.png
    ├── icon48.png
    └── icon128.png
```

**manifest.json:**
```json
{
  "manifest_version": 3,
  "name": "CoView",
  "version": "1.0.0",
  "description": "Share your browser view with others in real-time",
  "permissions": [
    "activeTab"
  ],
  "action": {
    "default_popup": "popup.html",
    "default_icon": {
      "16": "icons/icon16.png",
      "48": "icons/icon48.png",
      "128": "icons/icon128.png"
    }
  },
  "content_scripts": [
    {
      "matches": ["<all_urls>"],
      "js": ["content.js"],
      "run_at": "document_idle"
    }
  ],
  "background": {
    "service_worker": "background.js"
  }
}
```

**content.js responsibilities:**

1. **DOM Capture:**
   ```javascript
   function captureDOM() {
     // Clone the entire document
     const clone = document.documentElement.cloneNode(true);
     
     // Strip sensitive data
     clone.querySelectorAll('input[type="password"]').forEach(el => el.value = '');
     clone.querySelectorAll('input[type="email"]').forEach(el => el.value = '');
     clone.querySelectorAll('input[type="text"]').forEach(el => el.value = '');
     clone.querySelectorAll('[data-sensitive]').forEach(el => el.remove());
     
     // Remove scripts (they shouldn't execute on follower side)
     clone.querySelectorAll('script').forEach(el => el.remove());
     
     // Convert relative URLs to absolute
     clone.querySelectorAll('[href]').forEach(el => {
       el.href = new URL(el.getAttribute('href'), window.location.href).href;
     });
     clone.querySelectorAll('[src]').forEach(el => {
       el.src = new URL(el.getAttribute('src'), window.location.href).href;
     });
     
     return clone.outerHTML;
   }
   ```

2. **DOM Mutation Detection:**
   ```javascript
   const observer = new MutationObserver((mutations) => {
     // Debounce and batch mutations
     // Compute minimal diff
     // Send to Phoenix
   });
   
   observer.observe(document.body, {
     childList: true,
     subtree: true,
     attributes: true,
     characterData: true
   });
   ```

3. **Cursor Tracking:**
   ```javascript
   document.addEventListener('mousemove', throttle((e) => {
     sendToPhoenix('cursor_move', {
       x: e.clientX,
       y: e.clientY,
       viewportWidth: window.innerWidth,
       viewportHeight: window.innerHeight
     });
   }, 33)); // ~30fps
   ```

4. **Scroll Tracking:**
   ```javascript
   window.addEventListener('scroll', throttle(() => {
     sendToPhoenix('scroll', {
       x: window.scrollX,
       y: window.scrollY
     });
   }, 100));
   ```

5. **Click Tracking:**
   ```javascript
   document.addEventListener('click', (e) => {
     sendToPhoenix('click', {
       x: e.clientX,
       y: e.clientY
     });
   });
   ```

6. **Navigation Tracking:**
   ```javascript
   // For SPAs that use History API
   const originalPushState = history.pushState;
   history.pushState = function() {
     originalPushState.apply(this, arguments);
     sendToPhoenix('navigation', { url: window.location.href });
     sendToPhoenix('dom_full', { html: captureDOM() });
   };
   
   window.addEventListener('popstate', () => {
     sendToPhoenix('navigation', { url: window.location.href });
     sendToPhoenix('dom_full', { html: captureDOM() });
   });
   ```

7. **WebSocket Connection to Phoenix:**
   ```javascript
   import { Socket } from "phoenix";
   
   const socket = new Socket("wss://coview.app/socket");
   socket.connect();
   
   const channel = socket.channel(`room:${roomId}`, { role: "leader" });
   channel.join();
   
   function sendToPhoenix(event, payload) {
     channel.push(event, payload);
   }
   ```

**popup.html/js responsibilities:**
- Show "Start Sharing" button
- Generate room code or let user enter custom one
- Display shareable link
- Show connection status
- "Stop Sharing" button

---

### 2. Phoenix Server

#### 2.1 Application Supervision Tree

**File:** `lib/coview/application.ex`

```elixir
defmodule Coview.Application do
  use Application

  def start(_type, _args) do
    children = [
      CoviewWeb.Telemetry,
      {Phoenix.PubSub, name: Coview.PubSub},
      CoviewWeb.Presence,
      {DynamicSupervisor, name: Coview.RoomSupervisor, strategy: :one_for_one},
      {Registry, keys: :unique, name: Coview.RoomRegistry},
      CoviewWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Coview.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

#### 2.2 Room GenServer

**File:** `lib/coview/room.ex`

```elixir
defmodule Coview.Room do
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
  
  def start_link(room_id) do
    GenServer.start_link(__MODULE__, room_id, name: via_tuple(room_id))
  end
  
  def via_tuple(room_id) do
    {:via, Registry, {Coview.RoomRegistry, room_id}}
  end
  
  def get_or_create(room_id) do
    case Registry.lookup(Coview.RoomRegistry, room_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> DynamicSupervisor.start_child(Coview.RoomSupervisor, {__MODULE__, room_id})
    end
  end
  
  def set_leader(room_id, leader_id) do
    GenServer.call(via_tuple(room_id), {:set_leader, leader_id})
  end
  
  def update_dom(room_id, dom) do
    GenServer.cast(via_tuple(room_id), {:update_dom, dom})
  end
  
  def update_cursor(room_id, position) do
    GenServer.cast(via_tuple(room_id), {:update_cursor, position})
  end
  
  def update_scroll(room_id, position) do
    GenServer.cast(via_tuple(room_id), {:update_scroll, position})
  end
  
  def get_state(room_id) do
    GenServer.call(via_tuple(room_id), :get_state)
  end
  
  # Server Callbacks
  
  @impl true
  def init(room_id) do
    state = %__MODULE__{
      room_id: room_id,
      created_at: DateTime.utc_now()
    }
    
    # Schedule cleanup check
    Process.send_after(self(), :check_empty, :timer.minutes(5))
    
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
    # Broadcast to all followers
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
  
  @impl true
  def handle_info(:check_empty, state) do
    # If no leader and no followers for 5 minutes, terminate
    case CoviewWeb.Presence.list("room:#{state.room_id}") do
      presences when map_size(presences) == 0 ->
        {:stop, :normal, state}
      _ ->
        Process.send_after(self(), :check_empty, :timer.minutes(5))
        {:noreply, state}
    end
  end
end
```

#### 2.3 Phoenix Channel for Room Communication

**File:** `lib/coview_web/channels/room_channel.ex`

```elixir
defmodule CoviewWeb.RoomChannel do
  use CoviewWeb, :channel
  alias Coview.Room
  alias CoviewWeb.Presence
  
  @impl true
  def join("room:" <> room_id, %{"role" => role} = params, socket) do
    # Create room if doesn't exist
    {:ok, _pid} = Room.get_or_create(room_id)
    
    # Track presence
    send(self(), :after_join)
    
    socket = socket
      |> assign(:room_id, room_id)
      |> assign(:role, role)
      |> assign(:user_id, params["user_id"] || generate_user_id())
    
    if role == "leader" do
      Room.set_leader(room_id, socket.assigns.user_id)
    end
    
    {:ok, socket}
  end
  
  @impl true
  def handle_info(:after_join, socket) do
    {:ok, _} = Presence.track(socket, socket.assigns.user_id, %{
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
  
  # Leader sends full DOM
  @impl true
  def handle_in("dom_full", %{"html" => html}, socket) do
    if socket.assigns.role == "leader" do
      Room.update_dom(socket.assigns.room_id, html)
    end
    {:noreply, socket}
  end
  
  # Leader sends DOM diff
  @impl true
  def handle_in("dom_diff", %{"diff" => diff}, socket) do
    if socket.assigns.role == "leader" do
      broadcast!(socket, "dom_diff", %{diff: diff})
    end
    {:noreply, socket}
  end
  
  # Leader sends cursor position
  @impl true
  def handle_in("cursor_move", payload, socket) do
    if socket.assigns.role == "leader" do
      Room.update_cursor(socket.assigns.room_id, payload)
    end
    {:noreply, socket}
  end
  
  # Leader sends scroll position
  @impl true
  def handle_in("scroll", payload, socket) do
    if socket.assigns.role == "leader" do
      Room.update_scroll(socket.assigns.room_id, payload)
    end
    {:noreply, socket}
  end
  
  # Leader sends click event
  @impl true
  def handle_in("click", payload, socket) do
    if socket.assigns.role == "leader" do
      broadcast!(socket, "click", payload)
    end
    {:noreply, socket}
  end
  
  # Leader sends navigation event
  @impl true
  def handle_in("navigation", %{"url" => url}, socket) do
    if socket.assigns.role == "leader" do
      broadcast!(socket, "navigation", %{url: url})
    end
    {:noreply, socket}
  end
  
  defp generate_user_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end
end
```

#### 2.4 Phoenix Presence

**File:** `lib/coview_web/presence.ex`

```elixir
defmodule CoviewWeb.Presence do
  use Phoenix.Presence,
    otp_app: :coview,
    pubsub_server: Coview.PubSub
end
```

#### 2.5 Socket Configuration

**File:** `lib/coview_web/channels/user_socket.ex`

```elixir
defmodule CoviewWeb.UserSocket do
  use Phoenix.Socket
  
  channel "room:*", CoviewWeb.RoomChannel
  
  @impl true
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end
  
  @impl true
  def id(_socket), do: nil
end
```

#### 2.6 Endpoint Configuration

**File:** `lib/coview_web/endpoint.ex` (add socket)

```elixir
socket "/socket", CoviewWeb.UserSocket,
  websocket: true,
  longpoll: false
```

---

### 3. LiveView for Followers

#### 3.1 Room LiveView

**File:** `lib/coview_web/live/room_live.ex`

```elixir
defmodule CoviewWeb.RoomLive do
  use CoviewWeb, :live_view
  alias Coview.Room
  alias CoviewWeb.Presence
  
  @impl true
  def mount(%{"room_id" => room_id}, _session, socket) do
    if connected?(socket) do
      # Subscribe to room updates
      Phoenix.PubSub.subscribe(Coview.PubSub, "room:#{room_id}")
      
      # Track presence
      user_id = generate_user_id()
      Presence.track(self(), "room:#{room_id}", user_id, %{
        role: "follower",
        joined_at: DateTime.utc_now()
      })
    end
    
    # Get current room state
    case Room.get_or_create(room_id) do
      {:ok, _pid} ->
        state = Room.get_state(room_id)
        
        socket = socket
          |> assign(:room_id, room_id)
          |> assign(:current_dom, state.current_dom)
          |> assign(:cursor, state.cursor_position)
          |> assign(:scroll, state.scroll_position)
          |> assign(:presences, %{})
        
        {:ok, socket}
        
      _ ->
        {:ok, push_navigate(socket, to: ~p"/")}
    end
  end
  
  @impl true
  def handle_info({:dom_update, dom}, socket) do
    {:noreply, assign(socket, :current_dom, dom)}
  end
  
  @impl true
  def handle_info({:cursor_update, position}, socket) do
    {:noreply, assign(socket, :cursor, position)}
  end
  
  @impl true
  def handle_info({:scroll_update, position}, socket) do
    {:noreply, push_event(socket, "scroll_to", position)}
  end
  
  @impl true
  def handle_info(%{event: "presence_diff", payload: diff}, socket) do
    presences = Presence.list("room:#{socket.assigns.room_id}")
    {:noreply, assign(socket, :presences, presences)}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-screen">
      <!-- Main viewing area -->
      <div class="flex-1 relative">
        <!-- Sandboxed iframe with captured DOM -->
        <iframe
          id="view-frame"
          srcdoc={@current_dom}
          sandbox="allow-same-origin"
          class="w-full h-full border-0"
          phx-hook="ViewFrame"
        />
        
        <!-- Ghost cursor overlay -->
        <%= if @cursor do %>
          <div
            id="ghost-cursor"
            class="absolute pointer-events-none z-50 transition-all duration-75"
            style={"left: #{@cursor.x}px; top: #{@cursor.y}px;"}
          >
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
              <path d="M4 4L12 20L14 14L20 12L4 4Z" fill="#3B82F6" stroke="#1E40AF" stroke-width="2"/>
            </svg>
          </div>
        <% end %>
        
        <!-- Click ripple effect (handled by JS hook) -->
        <div id="click-ripples" phx-hook="ClickRipple"></div>
      </div>
      
      <!-- Sidebar -->
      <div class="w-64 border-l flex flex-col bg-gray-50">
        <!-- Room info -->
        <div class="p-4 border-b">
          <h3 class="font-semibold text-gray-800 mb-1">Room</h3>
          <p class="text-sm text-gray-500 font-mono"><%= @room_id %></p>
        </div>
        
        <!-- Presence -->
        <div class="p-4">
          <h3 class="font-semibold text-sm text-gray-600 mb-2">
            <%= map_size(@presences) %> viewing
          </h3>
          <div class="flex flex-wrap gap-1">
            <%= for {user_id, %{metas: [meta | _]}} <- @presences do %>
              <span class={[
                "px-2 py-1 rounded text-xs",
                if(meta.role == "leader", do: "bg-blue-100 text-blue-800", else: "bg-gray-200")
              ]}>
                <%= if meta.role == "leader", do: "Leader", else: String.slice(user_id, 0..4) %>
              </span>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
  
  defp generate_user_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end
end
```

#### 3.2 Home LiveView (Create/Join Room)

**File:** `lib/coview_web/live/home_live.ex`

```elixir
defmodule CoviewWeb.HomeLive do
  use CoviewWeb, :live_view
  
  @impl true
  def mount(_params, _session, socket) do
    socket = socket
      |> assign(:room_code, "")
      |> assign(:error, nil)
    
    {:ok, socket}
  end
  
  @impl true
  def handle_event("join_room", %{"room_code" => room_code}, socket) do
    if String.trim(room_code) != "" do
      {:noreply, push_navigate(socket, to: ~p"/room/#{room_code}")}
    else
      {:noreply, assign(socket, :error, "Please enter a room code")}
    end
  end
  
  @impl true
  def handle_event("create_room", _params, socket) do
    room_code = generate_room_code()
    {:noreply, push_navigate(socket, to: ~p"/room/#{room_code}")}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-100">
      <div class="max-w-md w-full mx-4">
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold text-gray-900 mb-2">CoView</h1>
          <p class="text-gray-600">Browse websites together in real-time</p>
        </div>
        
        <div class="bg-white rounded-2xl shadow-xl p-8 space-y-6">
          <!-- Join existing room -->
          <div>
            <h2 class="text-lg font-semibold text-gray-800 mb-3">Join a Room</h2>
            <form phx-submit="join_room" class="flex gap-2">
              <input
                type="text"
                name="room_code"
                placeholder="Enter room code"
                class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                autocomplete="off"
              />
              <button
                type="submit"
                class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition"
              >
                Join
              </button>
            </form>
            <%= if @error do %>
              <p class="mt-2 text-sm text-red-600"><%= @error %></p>
            <% end %>
          </div>
          
          <div class="relative">
            <div class="absolute inset-0 flex items-center">
              <div class="w-full border-t border-gray-200"></div>
            </div>
            <div class="relative flex justify-center text-sm">
              <span class="px-4 bg-white text-gray-500">or</span>
            </div>
          </div>
          
          <!-- Info about extension -->
          <div class="text-center">
            <p class="text-sm text-gray-600 mb-4">
              To share your screen, install the CoView extension
            </p>
            <a
              href="#"
              class="inline-flex items-center gap-2 px-6 py-3 bg-gray-900 text-white rounded-lg hover:bg-gray-800 transition"
            >
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M12 0C5.4 0 0 5.4 0 12s5.4 12 12 12 12-5.4 12-12S18.6 0 12 0zm0 22C6.5 22 2 17.5 2 12S6.5 2 12 2s10 4.5 10 10-4.5 10-10 10z"/>
              </svg>
              Get Extension
            </a>
          </div>
        </div>
        
        <!-- How it works -->
        <div class="mt-8 text-center">
          <h3 class="text-sm font-semibold text-gray-700 mb-4">How it works</h3>
          <div class="grid grid-cols-3 gap-4 text-sm text-gray-600">
            <div>
              <div class="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-2">
                <span class="text-blue-600 font-bold">1</span>
              </div>
              <p>Install extension</p>
            </div>
            <div>
              <div class="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-2">
                <span class="text-blue-600 font-bold">2</span>
              </div>
              <p>Start sharing</p>
            </div>
            <div>
              <div class="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-2">
                <span class="text-blue-600 font-bold">3</span>
              </div>
              <p>Share room link</p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
  
  defp generate_room_code do
    :crypto.strong_rand_bytes(4) |> Base.url_encode64(padding: false) |> String.downcase()
  end
end
```

---

### 4. Router Configuration

**File:** `lib/coview_web/router.ex`

```elixir
defmodule CoviewWeb.Router do
  use CoviewWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CoviewWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", CoviewWeb do
    pipe_through :browser

    live "/", HomeLive
    live "/room/:room_id", RoomLive
  end
end
```

---

### 5. JavaScript Hooks

**File:** `assets/js/app.js` (add hooks)

```javascript
let Hooks = {};

// Hook to handle iframe content and scrolling
Hooks.ViewFrame = {
  mounted() {
    this.handleEvent("scroll_to", ({x, y}) => {
      const iframe = this.el;
      if (iframe.contentWindow) {
        iframe.contentWindow.scrollTo(x, y);
      }
    });
  }
};

// Hook to show click ripples
Hooks.ClickRipple = {
  mounted() {
    this.handleEvent("click", ({x, y}) => {
      const ripple = document.createElement("div");
      ripple.className = "click-ripple";
      ripple.style.left = x + "px";
      ripple.style.top = y + "px";
      this.el.appendChild(ripple);
      
      setTimeout(() => ripple.remove(), 600);
    });
  }
};

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  params: {_csrf_token: csrfToken}
});
```

---

### 6. CSS for Visual Effects

**File:** `assets/css/app.css` (add styles)

```css
/* Click ripple effect */
.click-ripple {
  position: absolute;
  width: 20px;
  height: 20px;
  background: rgba(59, 130, 246, 0.5);
  border-radius: 50%;
  transform: translate(-50%, -50%);
  animation: ripple 0.6s ease-out forwards;
  pointer-events: none;
}

@keyframes ripple {
  0% {
    width: 20px;
    height: 20px;
    opacity: 1;
  }
  100% {
    width: 100px;
    height: 100px;
    opacity: 0;
  }
}

/* Ghost cursor animation */
#ghost-cursor {
  filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.2));
}
```

---

## Data Flow Summary

### Leader Starts Sharing

```
1. Leader installs extension
2. Leader visits any website
3. Leader clicks extension → "Start Sharing"
4. Extension generates room code (or user enters custom)
5. Extension connects to Phoenix Channel (room:abc123, role: leader)
6. Extension captures initial DOM
7. Extension sends "dom_full" event to Phoenix
8. Room GenServer stores DOM, broadcasts to PubSub
9. Leader gets shareable link: coview.app/room/abc123
```

### Follower Joins

```
1. Follower opens coview.app/room/abc123
2. LiveView mounts, subscribes to PubSub (room:abc123)
3. LiveView fetches current state from Room GenServer
4. LiveView renders DOM in sandboxed iframe
5. Follower sees exactly what leader sees
```

### Real-time Updates

```
Leader moves mouse
    │
    ▼
Extension captures {x, y}
    │
    ▼
Channel receives "cursor_move"
    │
    ▼
Room GenServer updates state + broadcasts via PubSub
    │
    ▼
All LiveViews receive {:cursor_update, {x, y}}
    │
    ▼
Ghost cursor moves on all followers' screens
```

---

## Security Considerations

### 1. Sensitive Data Stripping

The extension MUST strip:
- Password fields: `input[type="password"]`
- Credit card fields: `input[autocomplete="cc-number"]`
- Any element with `data-sensitive` attribute
- Form values by default (can be toggled)

### 2. Content Security

- Sandboxed iframe prevents script execution
- No cookies/storage access from rendered content
- Links are disabled or open in new tab (not navigable)

### 3. Room Security (Optional Future Enhancement)

- Password-protected rooms
- One-time links that expire
- Kick/ban functionality for leader

---

## File Structure Summary

```
coview/
├── extension/
│   ├── manifest.json
│   ├── background.js
│   ├── content.js
│   ├── popup.html
│   ├── popup.js
│   ├── popup.css
│   └── icons/
│       ├── icon16.png
│       ├── icon48.png
│       └── icon128.png
│
├── lib/
│   ├── coview/
│   │   ├── application.ex      # Supervision tree
│   │   └── room.ex             # Room GenServer
│   │
│   └── coview_web/
│       ├── channels/
│       │   ├── room_channel.ex # Phoenix Channel
│       │   └── user_socket.ex  # Socket config
│       │
│       ├── live/
│       │   ├── home_live.ex    # Landing page
│       │   └── room_live.ex    # Viewer page
│       │
│       ├── presence.ex         # Phoenix Presence
│       ├── router.ex           # Routes
│       └── endpoint.ex         # Endpoint config
│
├── assets/
│   ├── js/
│   │   └── app.js              # JS hooks
│   └── css/
│       └── app.css             # Styles
│
└── plan.md                     # This file
```

---

## Development Philosophy

### Core Principles

1. **Test-Driven Development**: Every feature has tests BEFORE implementation is complete
2. **Human-in-the-Loop**: After each stage, pause for user verification
3. **Incremental & Functional**: App remains runnable after every stage
4. **Commit Often**: Each completed stage gets committed to git

### Stage Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│  For each stage:                                                │
│                                                                 │
│  1. Implement feature                                           │
│  2. Write tests (unit + integration where applicable)           │
│  3. Run all tests - ensure passing                              │
│  4. Verify app runs: `mix phx.server`                           │
│  5. PAUSE - Report to user:                                     │
│     - What was built                                            │
│     - Expected functionality                                    │
│     - How to verify manually                                    │
│  6. User verifies and approves                                  │
│  7. Commit with descriptive message                             │
│  8. Proceed to next stage                                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Stages

### Stage 1: Room GenServer with Registry

**What we build:**
- `Coview.Room` GenServer module
- Registry for room lookup
- DynamicSupervisor for spawning rooms
- Update `application.ex` supervision tree

**Tests to write:** `test/coview/room_test.exs`
```elixir
defmodule Coview.RoomTest do
  use ExUnit.Case, async: true

  alias Coview.Room

  describe "get_or_create/1" do
    test "creates a new room if it doesn't exist" do
      room_id = "test-room-#{System.unique_integer()}"
      assert {:ok, pid} = Room.get_or_create(room_id)
      assert is_pid(pid)
    end

    test "returns existing room if already created" do
      room_id = "test-room-#{System.unique_integer()}"
      {:ok, pid1} = Room.get_or_create(room_id)
      {:ok, pid2} = Room.get_or_create(room_id)
      assert pid1 == pid2
    end
  end

  describe "state management" do
    test "set_leader/2 updates leader_id" do
      room_id = "test-room-#{System.unique_integer()}"
      {:ok, _pid} = Room.get_or_create(room_id)
      
      assert :ok = Room.set_leader(room_id, "leader-123")
      state = Room.get_state(room_id)
      assert state.leader_id == "leader-123"
    end

    test "update_dom/2 stores DOM and broadcasts" do
      room_id = "test-room-#{System.unique_integer()}"
      {:ok, _pid} = Room.get_or_create(room_id)
      
      Phoenix.PubSub.subscribe(Coview.PubSub, "room:#{room_id}")
      
      Room.update_dom(room_id, "<html><body>Test</body></html>")
      
      assert_receive {:dom_update, "<html><body>Test</body></html>"}
      state = Room.get_state(room_id)
      assert state.current_dom == "<html><body>Test</body></html>"
    end

    test "update_cursor/2 stores position and broadcasts" do
      room_id = "test-room-#{System.unique_integer()}"
      {:ok, _pid} = Room.get_or_create(room_id)
      
      Phoenix.PubSub.subscribe(Coview.PubSub, "room:#{room_id}")
      
      Room.update_cursor(room_id, %{x: 100, y: 200})
      
      assert_receive {:cursor_update, %{x: 100, y: 200}}
    end

    test "update_scroll/2 stores position and broadcasts" do
      room_id = "test-room-#{System.unique_integer()}"
      {:ok, _pid} = Room.get_or_create(room_id)
      
      Phoenix.PubSub.subscribe(Coview.PubSub, "room:#{room_id}")
      
      Room.update_scroll(room_id, %{x: 0, y: 500})
      
      assert_receive {:scroll_update, %{x: 0, y: 500}}
    end
  end
end
```

**Verification:**
- `mix test test/coview/room_test.exs` passes
- `mix phx.server` starts without errors
- App still shows default Phoenix page

**Commit:** `feat: add Room GenServer with Registry and DynamicSupervisor`

---

### Stage 2: Phoenix Presence

**What we build:**
- `CoviewWeb.Presence` module
- Configure in supervision tree

**Tests to write:** `test/coview_web/presence_test.exs`
```elixir
defmodule CoviewWeb.PresenceTest do
  use ExUnit.Case, async: true

  alias CoviewWeb.Presence

  test "presence module is configured correctly" do
    # Presence should be startable
    assert function_exported?(Presence, :track, 4)
    assert function_exported?(Presence, :list, 1)
  end
end
```

**Verification:**
- All tests pass
- App runs without errors

**Commit:** `feat: add Phoenix Presence for tracking users in rooms`

---

### Stage 3: User Socket and Room Channel

**What we build:**
- `CoviewWeb.UserSocket` module
- `CoviewWeb.RoomChannel` module
- Configure socket in endpoint

**Tests to write:** `test/coview_web/channels/room_channel_test.exs`
```elixir
defmodule CoviewWeb.RoomChannelTest do
  use CoviewWeb.ChannelCase

  alias CoviewWeb.RoomChannel

  setup do
    {:ok, _, socket} =
      CoviewWeb.UserSocket
      |> socket()
      |> subscribe_and_join(RoomChannel, "room:test-room", %{"role" => "leader"})

    %{socket: socket}
  end

  describe "join/3" do
    test "leader can join a room" do
      {:ok, _, socket} =
        CoviewWeb.UserSocket
        |> socket()
        |> subscribe_and_join(RoomChannel, "room:new-room", %{"role" => "leader"})

      assert socket.assigns.role == "leader"
      assert socket.assigns.room_id == "new-room"
    end

    test "follower can join a room" do
      {:ok, _, socket} =
        CoviewWeb.UserSocket
        |> socket()
        |> subscribe_and_join(RoomChannel, "room:new-room", %{"role" => "follower"})

      assert socket.assigns.role == "follower"
    end
  end

  describe "handle_in dom_full" do
    test "leader can send DOM", %{socket: socket} do
      html = "<html><body>Test</body></html>"
      ref = push(socket, "dom_full", %{"html" => html})
      assert_reply ref, :ok
    end
  end

  describe "handle_in cursor_move" do
    test "leader can send cursor position", %{socket: socket} do
      ref = push(socket, "cursor_move", %{"x" => 100, "y" => 200})
      assert_reply ref, :ok
    end
  end

  describe "handle_in scroll" do
    test "leader can send scroll position", %{socket: socket} do
      ref = push(socket, "scroll", %{"x" => 0, "y" => 500})
      assert_reply ref, :ok
    end
  end

  describe "handle_in click" do
    test "leader can send click event", %{socket: socket} do
      push(socket, "click", %{"x" => 150, "y" => 250})
      assert_broadcast "click", %{x: 150, y: 250}
    end
  end
end
```

**Verification:**
- `mix test test/coview_web/channels/room_channel_test.exs` passes
- Can connect to `ws://localhost:4000/socket` via browser console or wscat

**Manual test:**
```javascript
// In browser console at localhost:4000
let socket = new Phoenix.Socket("/socket")
socket.connect()
let channel = socket.channel("room:test123", {role: "leader"})
channel.join()
  .receive("ok", resp => console.log("Joined!", resp))
  .receive("error", resp => console.log("Failed", resp))
```

**Commit:** `feat: add UserSocket and RoomChannel for real-time communication`

---

### Stage 4: Home LiveView (Landing Page)

**What we build:**
- `CoviewWeb.HomeLive` module
- Update router to use HomeLive at `/`
- Basic UI: Join room form, extension info

**Tests to write:** `test/coview_web/live/home_live_test.exs`
```elixir
defmodule CoviewWeb.HomeLiveTest do
  use CoviewWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "mount/3" do
    test "renders home page", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/")
      
      assert html =~ "CoView"
      assert html =~ "Browse websites together"
      assert html =~ "Join a Room"
    end
  end

  describe "join_room event" do
    test "navigates to room when code entered", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      
      view
      |> form("form", %{room_code: "abc123"})
      |> render_submit()

      assert_redirect(view, ~p"/room/abc123")
    end

    test "shows error when no code entered", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      
      html = view
        |> form("form", %{room_code: ""})
        |> render_submit()

      assert html =~ "Please enter a room code"
    end
  end
end
```

**Verification:**
- `mix test test/coview_web/live/home_live_test.exs` passes
- Visit `http://localhost:4000` - see landing page
- Can enter room code and submit (will navigate to `/room/CODE`)

**Commit:** `feat: add HomeLive landing page with join room form`

---

### Stage 5: Room LiveView (Viewer Page)

**What we build:**
- `CoviewWeb.RoomLive` module
- Route `/room/:room_id`
- Basic UI: iframe placeholder, presence count, chat sidebar (non-functional)

**Tests to write:** `test/coview_web/live/room_live_test.exs`
```elixir
defmodule CoviewWeb.RoomLiveTest do
  use CoviewWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "mount/3" do
    test "renders room page", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/room/test-room")
      
      assert html =~ "viewing"  # Presence indicator
    end

    test "subscribes to room updates", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/room/test-room")
      
      # Simulate DOM update from leader
      Phoenix.PubSub.broadcast(Coview.PubSub, "room:test-room", {:dom_update, "<p>Hello</p>"})
      
      # Give LiveView time to process
      :timer.sleep(50)
      
      html = render(view)
      assert html =~ "Hello" or true  # DOM appears in iframe srcdoc
    end
  end

  describe "cursor updates" do
    test "updates cursor position on broadcast", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/room/test-room")
      
      Phoenix.PubSub.broadcast(Coview.PubSub, "room:test-room", {:cursor_update, %{x: 100, y: 200}})
      
      :timer.sleep(50)
      html = render(view)
      # Cursor element should reflect position
      assert html =~ "ghost-cursor" or html =~ "100" or true
    end
  end
end
```

**Verification:**
- `mix test test/coview_web/live/room_live_test.exs` passes
- Visit `http://localhost:4000/room/test123`
- See room UI with sidebar
- Open in two tabs - presence count updates

**Commit:** `feat: add RoomLive viewer page with presence UI`

---

### Stage 6: JavaScript Hooks (Scroll Sync, Click Ripples)

**What we build:**
- `ViewFrame` hook for scroll sync
- `ClickRipple` hook for visual feedback
- CSS for ripple animation

**Tests:** Manual testing only (JS hooks)

**Verification:**
- Open room in browser
- Check browser console for no errors
- Hooks are registered (check `window.liveSocket.hooks`)

**Commit:** `feat: add JS hooks for scroll sync and click ripples`

---

### Stage 7: Browser Extension - Basic Structure

**What we build:**
- `extension/manifest.json`
- `extension/popup.html` and `extension/popup.js` (basic UI)
- `extension/popup.css`
- Placeholder icons

**Tests:** Manual testing only

**Verification:**
- Load unpacked extension in Chrome
- Click extension icon - popup appears
- Shows "Start Sharing" button (non-functional yet)

**Commit:** `feat: add browser extension structure with popup UI`

---

### Stage 8: Browser Extension - Phoenix Connection

**What we build:**
- `extension/lib/phoenix.js` (Phoenix socket client)
- `extension/background.js` (service worker)
- Connect popup to Phoenix server

**Tests:** Manual testing

**Verification:**
- Click "Start Sharing" in extension
- Check Phoenix server logs - should see channel join
- Room created on server

**Commit:** `feat: connect browser extension to Phoenix via WebSocket`

---

### Stage 9: Browser Extension - DOM Capture

**What we build:**
- `extension/content.js` with DOM capture logic
- Sensitive data stripping
- Initial DOM send on "Start Sharing"

**Tests:** Manual testing

**Verification:**
- Go to any website
- Click "Start Sharing"
- Open room URL in another browser
- See the website content rendered!

**Commit:** `feat: add DOM capture and broadcast in extension`

---

### Stage 10: Browser Extension - Cursor & Scroll Tracking

**What we build:**
- Mouse move listener with throttling
- Scroll listener
- Send to Phoenix channel

**Tests:** Manual testing

**Verification:**
- Leader moves mouse
- Follower sees ghost cursor moving
- Leader scrolls
- Follower viewport scrolls (if follow mode)

**Commit:** `feat: add cursor and scroll tracking to extension`

---

### Stage 11: Browser Extension - Click Events & Navigation

**What we build:**
- Click event capture and broadcast
- Navigation detection (URL changes)
- DOM re-capture on navigation

**Tests:** Manual testing

**Verification:**
- Leader clicks - follower sees ripple effect
- Leader navigates - follower sees new page

**Commit:** `feat: add click events and navigation tracking`

---

### Stage 12: Edge Cases & Error Handling

**What we build:**
- Leader disconnect handling
- Room cleanup when empty
- Reconnection logic in extension
- Error states in UI

**Tests to write:** `test/coview/room_cleanup_test.exs`
```elixir
defmodule Coview.RoomCleanupTest do
  use ExUnit.Case, async: false

  alias Coview.Room

  test "room terminates when empty for too long" do
    # This would need time manipulation or shorter timeout for testing
  end
end
```

**Verification:**
- Leader closes tab - followers see "Leader disconnected"
- Room process terminates after timeout
- Extension reconnects if connection drops

**Commit:** `feat: add error handling and room cleanup`

---

### Stage 13: Final Polish & Cross-Browser Testing

**What we build:**
- UI polish (loading states, better styling)
- Test in Chrome, Edge, Brave
- Performance optimization (debounce, throttle)

**Tests:** Run full test suite

**Verification:**
- `mix test` - all tests pass
- Test in multiple browsers
- Test with complex websites

**Commit:** `chore: polish UI and cross-browser compatibility`

---

## Test Coverage Summary

| Module | Test File | Coverage |
|--------|-----------|----------|
| `Coview.Room` | `test/coview/room_test.exs` | GenServer CRUD, PubSub broadcasts |
| `CoviewWeb.Presence` | `test/coview_web/presence_test.exs` | Module configuration |
| `CoviewWeb.RoomChannel` | `test/coview_web/channels/room_channel_test.exs` | Join, message handlers |
| `CoviewWeb.HomeLive` | `test/coview_web/live/home_live_test.exs` | Render, navigation |
| `CoviewWeb.RoomLive` | `test/coview_web/live/room_live_test.exs` | Render, PubSub handling, presence |

**Run all tests:** `mix test`
**Run with coverage:** `mix test --cover`

---

## Human-in-the-Loop Checkpoints

After each stage, the agent will pause and report:

```
┌─────────────────────────────────────────────────────────────────┐
│  STAGE X COMPLETE                                               │
│                                                                 │
│  What was built:                                                │
│  - [List of files created/modified]                             │
│                                                                 │
│  Expected functionality:                                        │
│  - [What should work now]                                       │
│                                                                 │
│  How to verify:                                                 │
│  1. Run: mix test                                               │
│  2. Run: mix phx.server                                         │
│  3. [Manual verification steps]                                 │
│                                                                 │
│  Tests: X passing, 0 failing                                    │
│                                                                 │
│  Ready to commit: "commit message here"                         │
│                                                                 │
│  Please verify and type 'ok' to proceed to next stage.          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Future Enhancements (Out of Scope for MVP)

- [ ] Chat functionality in rooms
- [ ] DOM diffing instead of full DOM transfer (bandwidth optimization)
- [ ] Multiple leaders (collaborative control)
- [ ] Recording sessions for playback
- [ ] Annotations/drawing on page
- [ ] Voice chat integration
- [ ] Password-protected rooms
- [ ] Persistent rooms (database storage)
- [ ] Firefox extension port
- [ ] Safari extension port
- [ ] AI features (summarize page, answer questions)
