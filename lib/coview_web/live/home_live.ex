defmodule CoviewWeb.HomeLive do
  @moduledoc """
  Landing page for CoView - a full multi-section page explaining the product.
  """
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
      <%!-- Hero Section --%>
      <section class="hero-gradient relative overflow-hidden">
        <div class="absolute inset-0 grid-pattern opacity-30 dark:opacity-10"></div>
        <div class="relative max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-20 lg:py-32">
          <div class="grid lg:grid-cols-2 gap-12 lg:gap-16 items-center">
            <%!-- Hero Content --%>
            <div class="space-y-8 animate-fade-up">
              <div class="space-y-4">
                <div class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-coview-accent-subtle border border-coview-accent/30 text-sm font-medium text-coview-accent">
                  <span class="w-2 h-2 rounded-full bg-coview-accent animate-live-pulse"></span>
                  Real-time DOM streaming
                </div>
                <h1 class="font-display text-5xl sm:text-6xl lg:text-7xl tracking-tight text-foreground">
                  Watch anyone browse.
                  <em class="text-coview-accent">Live.</em>
                </h1>
                <p class="text-xl text-muted-foreground max-w-lg">
                  CoView streams browser content as DOM updates, not video. Crystal-clear text, 
                  zero lag, minimal bandwidth. See exactly what they see.
                </p>
              </div>

              <%!-- Join Room Form --%>
              <div class="space-y-4">
                <label class="block text-sm font-medium text-muted-foreground">
                  Join a Room
                </label>
                <form phx-submit="join_room" id="join-room-form" class="flex gap-3">
                  <input
                    type="text"
                    name="room_code"
                    placeholder="Enter room code"
                    class="flex-1 px-4 py-3 bg-card border border-border rounded-lg text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-coview-accent/50 focus:border-coview-accent transition font-mono tracking-wider"
                    autocomplete="off"
                    spellcheck="false"
                  />
                  <.button type="submit" variant="primary" class="px-6">
                    Join
                  </.button>
                </form>
                <%= if @error do %>
                  <p class="text-sm text-destructive flex items-center gap-1">
                    <.icon name="hero-exclamation-circle" class="size-4" />
                    {@error}
                  </p>
                <% end %>
              </div>

              <%!-- Extension CTA --%>
              <div class="flex items-center gap-4 pt-4">
                <span class="text-sm text-muted-foreground">Want to share your screen?</span>
                <a
                  href="#extension"
                  id="get-extension-link"
                  class="inline-flex items-center gap-2 px-4 py-2 bg-secondary hover:bg-accent text-secondary-foreground hover:text-accent-foreground rounded-lg transition-all text-sm font-medium"
                >
                  <.icon name="hero-puzzle-piece" class="size-4" />
                  Get Extension
                </a>
              </div>
            </div>

            <%!-- Hero Visual --%>
            <div class="relative animate-fade-up animate-delay-200 hidden lg:block">
              <div class="relative">
                <%!-- Browser mockup --%>
                <div class="bg-card border border-border rounded-xl shadow-2xl overflow-hidden">
                  <%!-- Browser chrome --%>
                  <div class="flex items-center gap-2 px-4 py-3 bg-muted border-b border-border">
                    <div class="flex gap-1.5">
                      <div class="w-3 h-3 rounded-full bg-red-400"></div>
                      <div class="w-3 h-3 rounded-full bg-yellow-400"></div>
                      <div class="w-3 h-3 rounded-full bg-green-400"></div>
                    </div>
                    <div class="flex-1 mx-4">
                      <div class="bg-background rounded px-3 py-1 text-xs text-muted-foreground font-mono">
                        coview.app/room/demo-123
                      </div>
                    </div>
                    <div class="live-indicator">Live</div>
                  </div>
                  <%!-- Content area --%>
                  <div class="p-6 bg-background min-h-[200px] space-y-4">
                    <div class="h-4 bg-muted rounded w-3/4"></div>
                    <div class="h-4 bg-muted rounded w-1/2"></div>
                    <div class="h-4 bg-muted rounded w-5/6"></div>
                    <div class="h-4 bg-muted rounded w-2/3"></div>
                  </div>
                </div>
                <%!-- Floating viewers indicator --%>
                <div class="absolute -bottom-4 -right-4 flex items-center gap-2 px-4 py-2 bg-card border border-border rounded-full shadow-lg">
                  <div class="flex -space-x-2">
                    <div class="viewer-orb connected">A</div>
                    <div class="viewer-orb connected">B</div>
                    <div class="viewer-orb connected">C</div>
                  </div>
                  <span class="text-sm font-medium text-muted-foreground">3 viewers</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- What is CoView Section --%>
      <section class="py-20 lg:py-28">
        <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="max-w-3xl mx-auto text-center space-y-6 animate-fade-up">
            <h2 class="font-display text-4xl sm:text-5xl tracking-tight text-foreground">
              Not screen sharing.<br />
              <span class="text-coview-accent">DOM streaming.</span>
            </h2>
            <p class="text-lg text-muted-foreground leading-relaxed">
              Traditional screen sharing captures pixels as video. CoView captures the actual webpage structure 
              and streams it directly to viewers. The result? Perfect text rendering at any zoom level, 
              instant updates, and bandwidth usage measured in kilobytes, not megabytes.
            </p>
          </div>
        </div>
      </section>

      <div class="section-divider max-w-6xl mx-auto"></div>

      <%!-- How It's Different Section --%>
      <section class="py-20 lg:py-28">
        <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-16 space-y-4">
            <h2 class="font-display text-4xl sm:text-5xl tracking-tight text-foreground">
              The CoView difference
            </h2>
            <p class="text-lg text-muted-foreground max-w-2xl mx-auto">
              See why DOM streaming changes everything about collaborative browsing.
            </p>
          </div>

          <div class="grid md:grid-cols-2 gap-6">
            <%!-- Video Streaming (old way) --%>
            <div class="comparison-card bg-card border border-border rounded-xl p-8 space-y-6">
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-lg bg-muted flex items-center justify-center">
                  <.icon name="hero-video-camera" class="size-5 text-muted-foreground" />
                </div>
                <div>
                  <h3 class="font-semibold text-foreground">Video Streaming</h3>
                  <p class="text-sm text-muted-foreground">The traditional approach</p>
                </div>
              </div>
              <ul class="space-y-3 text-muted-foreground">
                <li class="flex items-start gap-2">
                  <.icon name="hero-x-mark" class="size-5 text-destructive shrink-0 mt-0.5" />
                  <span>Blurry text, compression artifacts</span>
                </li>
                <li class="flex items-start gap-2">
                  <.icon name="hero-x-mark" class="size-5 text-destructive shrink-0 mt-0.5" />
                  <span>High bandwidth usage (2-5+ Mbps)</span>
                </li>
                <li class="flex items-start gap-2">
                  <.icon name="hero-x-mark" class="size-5 text-destructive shrink-0 mt-0.5" />
                  <span>Noticeable latency on actions</span>
                </li>
                <li class="flex items-start gap-2">
                  <.icon name="hero-x-mark" class="size-5 text-destructive shrink-0 mt-0.5" />
                  <span>Heavy CPU/GPU encoding required</span>
                </li>
              </ul>
            </div>

            <%!-- DOM Streaming (CoView) --%>
            <div class="comparison-card bg-card border border-coview-accent/30 rounded-xl p-8 space-y-6 relative overflow-hidden">
              <div class="absolute top-0 left-0 right-0 h-1 bg-coview-accent"></div>
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-lg bg-coview-accent-subtle flex items-center justify-center">
                  <.icon name="hero-code-bracket" class="size-5 text-coview-accent" />
                </div>
                <div>
                  <h3 class="font-semibold text-foreground">DOM Streaming</h3>
                  <p class="text-sm text-coview-accent">The CoView approach</p>
                </div>
              </div>
              <ul class="space-y-3 text-foreground">
                <li class="flex items-start gap-2">
                  <.icon name="hero-check" class="size-5 text-coview-success shrink-0 mt-0.5" />
                  <span>Pixel-perfect text at any zoom</span>
                </li>
                <li class="flex items-start gap-2">
                  <.icon name="hero-check" class="size-5 text-coview-success shrink-0 mt-0.5" />
                  <span>Minimal bandwidth (~50-200 Kbps)</span>
                </li>
                <li class="flex items-start gap-2">
                  <.icon name="hero-check" class="size-5 text-coview-success shrink-0 mt-0.5" />
                  <span>Near-instant updates (&lt;50ms)</span>
                </li>
                <li class="flex items-start gap-2">
                  <.icon name="hero-check" class="size-5 text-coview-success shrink-0 mt-0.5" />
                  <span>Lightweight JSON diffing</span>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      <div class="section-divider max-w-6xl mx-auto"></div>

      <%!-- How It Works Section --%>
      <section class="py-20 lg:py-28">
        <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-16 space-y-4">
            <h2 class="font-display text-4xl sm:text-5xl tracking-tight text-foreground">
              How it works
            </h2>
            <p class="text-lg text-muted-foreground max-w-2xl mx-auto">
              Get started in under a minute. No accounts, no downloads for viewers.
            </p>
          </div>

          <div class="grid md:grid-cols-3 gap-8">
            <%!-- Step 1 --%>
            <div class="relative group">
              <div class="feature-card bg-card border border-border rounded-xl p-8 h-full space-y-4">
                <div class="w-12 h-12 rounded-full bg-coview-accent-subtle border border-coview-accent/30 flex items-center justify-center text-coview-accent font-bold text-lg">
                  1
                </div>
                <h3 class="font-semibold text-lg text-foreground">Install extension</h3>
                <p class="text-muted-foreground">
                  Add the CoView Chrome extension. It sits quietly until you need it.
                </p>
              </div>
              <div class="hidden md:block step-line"></div>
            </div>

            <%!-- Step 2 --%>
            <div class="relative group">
              <div class="feature-card bg-card border border-border rounded-xl p-8 h-full space-y-4">
                <div class="w-12 h-12 rounded-full bg-coview-accent-subtle border border-coview-accent/30 flex items-center justify-center text-coview-accent font-bold text-lg">
                  2
                </div>
                <h3 class="font-semibold text-lg text-foreground">Start sharing</h3>
                <p class="text-muted-foreground">
                  Click the extension icon to create a room. Your browser view starts streaming instantly.
                </p>
              </div>
              <div class="hidden md:block step-line"></div>
            </div>

            <%!-- Step 3 --%>
            <div class="relative group">
              <div class="feature-card bg-card border border-border rounded-xl p-8 h-full space-y-4">
                <div class="w-12 h-12 rounded-full bg-coview-accent-subtle border border-coview-accent/30 flex items-center justify-center text-coview-accent font-bold text-lg">
                  3
                </div>
                <h3 class="font-semibold text-lg text-foreground">Share the link</h3>
                <p class="text-muted-foreground">
                  Send the room code to anyone. They join instantly in their browser—no installs needed.
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <div class="section-divider max-w-6xl mx-auto"></div>

      <%!-- Use Cases Section --%>
      <section class="py-20 lg:py-28 bg-muted/30">
        <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-16 space-y-4">
            <h2 class="font-display text-4xl sm:text-5xl tracking-tight text-foreground">
              Perfect for
            </h2>
          </div>

          <div class="grid sm:grid-cols-2 lg:grid-cols-4 gap-6">
            <div class="bg-card border border-border rounded-xl p-6 space-y-3 hover:border-coview-accent/50 transition-colors">
              <.icon name="hero-lifebuoy" class="size-8 text-coview-accent" />
              <h3 class="font-semibold text-foreground">Customer Support</h3>
              <p class="text-sm text-muted-foreground">Guide customers through web apps with perfect clarity.</p>
            </div>

            <div class="bg-card border border-border rounded-xl p-6 space-y-3 hover:border-coview-accent/50 transition-colors">
              <.icon name="hero-code-bracket-square" class="size-8 text-coview-accent" />
              <h3 class="font-semibold text-foreground">Pair Programming</h3>
              <p class="text-sm text-muted-foreground">Review code together in browser-based IDEs.</p>
            </div>

            <div class="bg-card border border-border rounded-xl p-6 space-y-3 hover:border-coview-accent/50 transition-colors">
              <.icon name="hero-presentation-chart-line" class="size-8 text-coview-accent" />
              <h3 class="font-semibold text-foreground">Product Demos</h3>
              <p class="text-sm text-muted-foreground">Show off web products with crisp, professional quality.</p>
            </div>

            <div class="bg-card border border-border rounded-xl p-6 space-y-3 hover:border-coview-accent/50 transition-colors">
              <.icon name="hero-academic-cap" class="size-8 text-coview-accent" />
              <h3 class="font-semibold text-foreground">Training</h3>
              <p class="text-sm text-muted-foreground">Teach web workflows with readable text at any zoom.</p>
            </div>
          </div>
        </div>
      </section>

      <%!-- Tech Section --%>
      <section class="py-20 lg:py-28">
        <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="grid lg:grid-cols-2 gap-12 items-center">
            <div class="space-y-6">
              <h2 class="font-display text-4xl sm:text-5xl tracking-tight text-foreground">
                Built for <span class="text-coview-accent">real-time</span>
              </h2>
              <p class="text-lg text-muted-foreground leading-relaxed">
                CoView is powered by Phoenix LiveView and WebSockets, the same technology that 
                enables real-time features for millions of users. Updates propagate to all viewers 
                within milliseconds.
              </p>
              <div class="flex flex-wrap gap-3">
                <span class="tech-badge">
                  <.icon name="hero-bolt" class="size-4 text-coview-accent" />
                  Phoenix LiveView
                </span>
                <span class="tech-badge">
                  <.icon name="hero-signal" class="size-4 text-coview-accent" />
                  WebSockets
                </span>
                <span class="tech-badge">
                  <.icon name="hero-cube-transparent" class="size-4 text-coview-accent" />
                  morphdom
                </span>
              </div>
            </div>
            <div class="bg-card border border-border rounded-xl p-6 font-mono text-sm">
              <div class="text-muted-foreground mb-2"># How CoView streams DOM</div>
              <div class="space-y-1">
                <div><span class="text-coview-accent">1.</span> Extension captures page DOM</div>
                <div><span class="text-coview-accent">2.</span> Diffs against previous state</div>
                <div><span class="text-coview-accent">3.</span> Sends minimal JSON patches</div>
                <div><span class="text-coview-accent">4.</span> LiveView broadcasts to viewers</div>
                <div><span class="text-coview-accent">5.</span> morphdom applies changes</div>
                <div class="text-muted-foreground mt-4"># Result: ~50ms end-to-end latency</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <div class="section-divider max-w-6xl mx-auto"></div>

      <%!-- CTA Section --%>
      <section id="extension" class="py-20 lg:py-28">
        <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 text-center space-y-8">
          <h2 class="font-display text-4xl sm:text-5xl tracking-tight text-foreground">
            Ready to try it?
          </h2>
          <p class="text-lg text-muted-foreground">
            Join a room to watch, or install the extension to share your browser.
          </p>
          <div class="flex flex-col sm:flex-row gap-4 justify-center">
            <a
              href="#"
              class="inline-flex items-center justify-center gap-2 px-6 py-3 bg-coview-accent text-white rounded-lg font-medium hover:opacity-90 transition-opacity"
            >
              <.icon name="hero-puzzle-piece" class="size-5" />
              Get Chrome Extension
            </a>
            <a
              href="#"
              onclick="document.querySelector('#join-room-form input').focus(); return false;"
              class="inline-flex items-center justify-center gap-2 px-6 py-3 bg-secondary text-secondary-foreground rounded-lg font-medium hover:bg-accent hover:text-accent-foreground transition-colors"
            >
              Join a Room
            </a>
          </div>
        </div>
      </section>

      <%!-- Footer --%>
      <footer class="py-12 border-t border-border">
        <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex flex-col md:flex-row justify-between items-center gap-6">
            <div class="flex items-center gap-2">
              <img src={~p"/images/logo.svg"} width="24" class="dark:brightness-0 dark:invert" />
              <span class="font-semibold text-foreground">CoView</span>
            </div>
            <div class="flex items-center gap-6 text-sm text-muted-foreground">
              <a href="https://phoenixframework.org" class="hover:text-foreground transition-colors">
                Built with Phoenix
              </a>
              <span class="text-border">·</span>
              <a href="https://github.com/virinchi/coview" class="hover:text-foreground transition-colors">
                Open Source
              </a>
            </div>
          </div>
        </div>
      </footer>
    </Layouts.app>
    """
  end
end
