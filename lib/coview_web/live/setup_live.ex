defmodule CoviewWeb.SetupLive do
  @moduledoc """
  Setup/installation instructions page for CoView.
  """
  use CoviewWeb, :live_view

  @github_url "https://github.com/ChivukulaVirinchi/Coview"

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :github_url, @github_url)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="max-w-3xl mx-auto px-6 py-16 lg:py-20">
        <a href="/" class="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground transition-colors mb-8">
          <.icon name="hero-arrow-left" class="size-4" />
          Back
        </a>

        <h1 class="text-3xl font-bold text-foreground mb-2">Setup</h1>
        <p class="text-muted-foreground mb-12">Get CoView running locally in under 2 minutes.</p>

        <%!-- Step 1: Clone & Run Server --%>
        <div class="mb-12">
          <div class="flex items-center gap-3 mb-4">
            <div class="w-8 h-8 rounded-full bg-primary text-primary-foreground flex items-center justify-center text-sm font-bold shrink-0">1</div>
            <h2 class="text-lg font-semibold text-foreground">Run the server</h2>
          </div>
          <div class="bg-muted/50 rounded-lg p-4 font-mono text-sm overflow-x-auto">
            <div class="text-muted-foreground"># Clone and start the Phoenix server</div>
            <div class="text-foreground mt-2">git clone <a href={@github_url} class="text-primary hover:underline">{@github_url}</a></div>
            <div class="text-foreground">cd Coview</div>
            <div class="text-foreground">mix setup</div>
            <div class="text-foreground">mix phx.server</div>
          </div>
          <p class="text-sm text-muted-foreground mt-3">
            Server runs at <code class="bg-muted px-1.5 py-0.5 rounded text-xs">http://localhost:4000</code>
          </p>
          <p class="text-sm text-muted-foreground mt-2">
            Requires <a href="https://elixir-lang.org/install.html" class="text-primary hover:underline">Elixir</a> 1.14+ and Erlang 25+.
          </p>
        </div>

        <%!-- Step 2: Load Extension --%>
        <div class="mb-12">
          <div class="flex items-center gap-3 mb-4">
            <div class="w-8 h-8 rounded-full bg-primary text-primary-foreground flex items-center justify-center text-sm font-bold shrink-0">2</div>
            <h2 class="text-lg font-semibold text-foreground">Load the Chrome extension</h2>
          </div>
          <div class="bg-muted/50 rounded-lg p-4 space-y-3">
            <div class="flex gap-3">
              <span class="text-muted-foreground font-mono text-sm shrink-0">a.</span>
              <span class="text-foreground text-sm">Open <code class="bg-muted px-1.5 py-0.5 rounded text-xs">chrome://extensions</code> in Chrome</span>
            </div>
            <div class="flex gap-3">
              <span class="text-muted-foreground font-mono text-sm shrink-0">b.</span>
              <span class="text-foreground text-sm">Enable <strong>Developer mode</strong> (top right toggle)</span>
            </div>
            <div class="flex gap-3">
              <span class="text-muted-foreground font-mono text-sm shrink-0">c.</span>
              <span class="text-foreground text-sm">Click <strong>Load unpacked</strong></span>
            </div>
            <div class="flex gap-3">
              <span class="text-muted-foreground font-mono text-sm shrink-0">d.</span>
              <span class="text-foreground text-sm">Select the <code class="bg-muted px-1.5 py-0.5 rounded text-xs">extension/</code> folder from the cloned repo</span>
            </div>
          </div>
        </div>

        <%!-- Step 3: Share --%>
        <div class="mb-12">
          <div class="flex items-center gap-3 mb-4">
            <div class="w-8 h-8 rounded-full bg-primary text-primary-foreground flex items-center justify-center text-sm font-bold shrink-0">3</div>
            <h2 class="text-lg font-semibold text-foreground">Start sharing</h2>
          </div>
          <div class="bg-muted/50 rounded-lg p-4 space-y-3">
            <div class="flex gap-3">
              <span class="text-muted-foreground font-mono text-sm shrink-0">a.</span>
              <span class="text-foreground text-sm">Click the CoView extension icon in your browser toolbar</span>
            </div>
            <div class="flex gap-3">
              <span class="text-muted-foreground font-mono text-sm shrink-0">b.</span>
              <span class="text-foreground text-sm">Enter a room name and click <strong>Start Sharing</strong></span>
            </div>
            <div class="flex gap-3">
              <span class="text-muted-foreground font-mono text-sm shrink-0">c.</span>
              <span class="text-foreground text-sm">Share the room code—viewers join at <code class="bg-muted px-1.5 py-0.5 rounded text-xs">localhost:4000</code></span>
            </div>
          </div>
        </div>

        <%!-- Done --%>
        <div class="border-t border-border pt-10">
          <p class="text-muted-foreground text-sm">
            That's it. Questions or issues? <a href={"#{@github_url}/issues"} class="text-primary hover:underline">Open an issue</a> on GitHub.
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
