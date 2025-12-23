defmodule CoviewWeb.HomeLive do
  @moduledoc """
  Landing page for CoView.
  """
  use CoviewWeb, :live_view

  @github_url "https://github.com/ChivukulaVirinchi/Coview"

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:room_code, "")
      |> assign(:error, nil)
      |> assign(:github_url, @github_url)

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
      <%!-- Hero --%>
      <section class="relative">
        <div class="max-w-5xl mx-auto px-6 py-20 lg:py-28">
          <div class="grid lg:grid-cols-2 gap-12 lg:gap-16 items-center">
            <%!-- Left: Content --%>
            <div class="space-y-6">
              <div class="inline-flex items-center gap-2 text-sm text-muted-foreground">
                <span class="w-2 h-2 rounded-full bg-green-500 animate-pulse"></span>
                DOM streaming, not video
              </div>
              
              <h1 class="text-4xl sm:text-5xl font-bold tracking-tight text-foreground leading-[1.15]">
                Watch anyone browse.<br/>
                <span class="text-muted-foreground">In real time.</span>
              </h1>
              
              <p class="text-lg text-muted-foreground">
                Sharp text. Instant updates. Tiny bandwidth.
              </p>

              <%!-- Join form --%>
              <div class="pt-2">
                <label class="block text-sm font-medium text-foreground mb-2">
                  Join a Room
                </label>
                <form phx-submit="join_room" id="join-room-form" class="flex gap-2 max-w-sm items-stretch">
                  <input
                    type="text"
                    name="room_code"
                    placeholder="room-code"
                    class="flex-1 px-4 py-2.5 bg-background border border-input rounded-lg text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring font-mono tracking-wide"
                    autocomplete="off"
                    spellcheck="false"
                  />
                  <.button type="submit" class="h-auto px-6 rounded-lg">Join</.button>
                </form>
                <%= if @error do %>
                  <p class="mt-2 text-sm text-destructive">{@error}</p>
                <% end %>
              </div>

              <div class="pt-2">
                <a
                  href="/setup"
                  id="get-extension-link"
                  class="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground transition-colors"
                >
                  <.icon name="hero-arrow-right" class="size-4" />
                  Setup instructions
                </a>
              </div>
            </div>

            <%!-- Right: Browser mockup --%>
            <div class="hidden lg:block">
              <div class="bg-card border border-border rounded-xl overflow-hidden shadow-lg">
                <%!-- Browser chrome --%>
                <div class="flex items-center gap-3 px-4 py-3 bg-muted/50 border-b border-border">
                  <div class="flex gap-1.5">
                    <div class="w-3 h-3 rounded-full bg-muted-foreground/20"></div>
                    <div class="w-3 h-3 rounded-full bg-muted-foreground/20"></div>
                    <div class="w-3 h-3 rounded-full bg-muted-foreground/20"></div>
                  </div>
                  <div class="flex-1">
                    <div class="bg-background border border-border rounded-md px-3 py-1.5 text-xs text-muted-foreground font-mono">
                      coview.app/room/demo
                    </div>
                  </div>
                  <div class="flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-green-500/10 text-green-600 dark:text-green-400 text-xs font-semibold tracking-wide">
                    <span class="w-1.5 h-1.5 rounded-full bg-current animate-pulse"></span>
                    LIVE
                  </div>
                </div>
                <%!-- Fake content --%>
                <div class="p-6 bg-background space-y-3 min-h-[160px]">
                  <div class="h-3 bg-muted rounded w-4/5"></div>
                  <div class="h-3 bg-muted rounded w-3/5"></div>
                  <div class="h-3 bg-muted rounded w-full"></div>
                  <div class="h-3 bg-muted rounded w-2/3"></div>
                </div>
              </div>
              <%!-- Viewers --%>
              <div class="flex items-center gap-3 mt-4 ml-2">
                <div class="flex -space-x-2">
                  <div class="w-7 h-7 rounded-full bg-primary/10 border-2 border-background flex items-center justify-center text-xs font-medium text-primary">A</div>
                  <div class="w-7 h-7 rounded-full bg-primary/10 border-2 border-background flex items-center justify-center text-xs font-medium text-primary">B</div>
                  <div class="w-7 h-7 rounded-full bg-primary/10 border-2 border-background flex items-center justify-center text-xs font-medium text-primary">C</div>
                </div>
                <span class="text-sm text-muted-foreground">3 viewers</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- Comparison --%>
      <section class="border-y border-border bg-muted/30">
        <div class="max-w-5xl mx-auto px-6 py-12">
          <div class="grid sm:grid-cols-2 gap-8 sm:gap-12">
            <div>
              <div class="text-sm font-semibold text-destructive mb-2">Video streaming</div>
              <p class="text-muted-foreground text-sm">Blurry text, high bandwidth, laggy.</p>
            </div>
            <div>
              <div class="text-sm font-semibold text-green-600 dark:text-green-400 mb-2">DOM streaming</div>
              <p class="text-foreground text-sm">Crisp text, ~100KB/s, &lt;50ms latency.</p>
            </div>
          </div>
        </div>
      </section>

      <%!-- How it works --%>
      <section class="py-16 lg:py-20">
        <div class="max-w-5xl mx-auto px-6">
          <div class="grid lg:grid-cols-2 gap-10 items-start">
            <div>
              <h2 class="text-xl font-bold text-foreground mb-3">How it works</h2>
              <p class="text-muted-foreground text-sm">
                The extension captures your page's DOM and streams changes over WebSockets. 
                Viewers receive the DOM and render it locally—no video encoding, no compression artifacts.
              </p>
            </div>
            <div class="bg-muted/50 rounded-lg p-4 font-mono text-sm space-y-1">
              <div class="flex justify-between"><span class="text-foreground">Elixir + Phoenix</span><span class="text-muted-foreground">server</span></div>
              <div class="flex justify-between"><span class="text-foreground">Channels</span><span class="text-muted-foreground">websockets</span></div>
              <div class="flex justify-between"><span class="text-foreground">morphdom</span><span class="text-muted-foreground">DOM diff</span></div>
              <div class="flex justify-between"><span class="text-foreground">Chrome Extension</span><span class="text-muted-foreground">capture</span></div>
            </div>
          </div>
        </div>
      </section>

      <%!-- CTA --%>
      <section class="border-t border-border py-16 lg:py-20">
        <div class="max-w-5xl mx-auto px-6">
          <div class="flex flex-col sm:flex-row gap-6 items-start sm:items-center justify-between">
            <div>
              <h2 class="text-xl font-bold text-foreground mb-1">Open source</h2>
              <p class="text-sm text-muted-foreground">MIT licensed. Star, fork, contribute.</p>
            </div>
            <a href={@github_url}>
              <.button>
                <svg class="size-4" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>
                View on GitHub
              </.button>
            </a>
          </div>
        </div>
      </section>

      <%!-- Footer --%>
      <footer class="border-t border-border py-6">
        <div class="max-w-5xl mx-auto px-6 flex flex-col sm:flex-row justify-between items-center gap-4 text-sm text-muted-foreground">
          <span>CoView</span>
          <a href={@github_url} class="hover:text-foreground transition-colors">GitHub</a>
        </div>
      </footer>
    </Layouts.app>
    """
  end
end
