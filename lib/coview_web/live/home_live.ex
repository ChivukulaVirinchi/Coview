defmodule CoviewWeb.HomeLive do
  use CoviewWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:room_code, "")
      |> assign(:error, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("join_room", %{"room_code" => room_code}, socket) do
    room_code = String.trim(room_code)

    if room_code != "" do
      {:noreply, push_navigate(socket, to: ~p"/room/#{room_code}")}
    else
      {:noreply, assign(socket, :error, "Please enter a room code")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-[80vh] flex items-center justify-center">
        <div class="max-w-md w-full mx-4">
          <div class="text-center mb-8">
            <h1 class="text-4xl font-bold text-base-content mb-2">CoView</h1>
            <p class="text-base-content/70">Browse websites together in real-time</p>
          </div>

          <div class="bg-base-200 rounded-2xl shadow-xl p-8 space-y-6">
            <%!-- Join existing room --%>
            <div>
              <h2 class="text-lg font-semibold text-base-content mb-3">Join a Room</h2>
              <form phx-submit="join_room" id="join-room-form" class="flex gap-2">
                <input
                  type="text"
                  name="room_code"
                  placeholder="Enter room code"
                  class="flex-1 px-4 py-2 border border-base-300 rounded-lg bg-base-100 text-base-content placeholder:text-base-content/50 focus:ring-2 focus:ring-primary focus:border-primary"
                  autocomplete="off"
                />
                <button
                  type="submit"
                  class="px-6 py-2 bg-primary text-primary-content rounded-lg hover:bg-primary/90 transition"
                >
                  Join
                </button>
              </form>
              <%= if @error do %>
                <p class="mt-2 text-sm text-error">{@error}</p>
              <% end %>
            </div>

            <div class="relative">
              <div class="absolute inset-0 flex items-center">
                <div class="w-full border-t border-base-300"></div>
              </div>
              <div class="relative flex justify-center text-sm">
                <span class="px-4 bg-base-200 text-base-content/60">or</span>
              </div>
            </div>

            <%!-- Info about extension --%>
            <div class="text-center">
              <p class="text-sm text-base-content/70 mb-4">
                To share your screen, install the CoView extension
              </p>
              <a
                href="#"
                id="get-extension-link"
                class="inline-flex items-center gap-2 px-6 py-3 bg-base-content text-base-100 rounded-lg hover:bg-base-content/90 transition"
              >
                <.icon name="hero-puzzle-piece" class="w-5 h-5" /> Get Extension
              </a>
            </div>
          </div>

          <%!-- How it works --%>
          <div class="mt-8 text-center">
            <h3 class="text-sm font-semibold text-base-content/80 mb-4">How it works</h3>
            <div class="grid grid-cols-3 gap-4 text-sm text-base-content/70">
              <div>
                <div class="w-10 h-10 bg-primary/20 rounded-full flex items-center justify-center mx-auto mb-2">
                  <span class="text-primary font-bold">1</span>
                </div>
                <p>Install extension</p>
              </div>
              <div>
                <div class="w-10 h-10 bg-primary/20 rounded-full flex items-center justify-center mx-auto mb-2">
                  <span class="text-primary font-bold">2</span>
                </div>
                <p>Start sharing</p>
              </div>
              <div>
                <div class="w-10 h-10 bg-primary/20 rounded-full flex items-center justify-center mx-auto mb-2">
                  <span class="text-primary font-bold">3</span>
                </div>
                <p>Share room link</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
