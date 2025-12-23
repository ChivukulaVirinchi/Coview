defmodule CoviewWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use CoviewWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates("layouts/*")

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr(:flash, :map, required: true, doc: "the map of flash messages")

  attr(:current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"
  )

  slot(:inner_block, required: true)

  def app(assigns) do
    ~H"""
    <header class="sticky top-0 z-40 flex items-center justify-between px-4 sm:px-6 lg:px-8 py-4 border-b border-border bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      <div class="flex-1">
        <a href="/" class="flex w-fit items-center gap-2 group">
          <img src={~p"/images/logo.svg"} width="36" class="dark:brightness-0 dark:invert transition-all" />
          <span class="text-sm font-semibold text-muted-foreground group-hover:text-foreground transition-colors">CoView</span>
        </a>
      </div>
      <div class="flex-none">
        <ul class="flex flex-row px-1 space-x-4 items-center">
          <li>
            <a
              href="https://github.com/virinchi/coview"
              class="text-sm text-muted-foreground hover:text-foreground transition-colors"
            >
              GitHub
            </a>
          </li>
          <li>
            <.theme_switcher id="theme-toggle" variant="ghost" />
          </li>
        </ul>
      </div>
    </header>

    <main>
      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr(:flash, :map, required: true, doc: "the map of flash messages")
  attr(:id, :string, default: "flash-group", doc: "the optional id of flash container")

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite" class="fixed top-4 right-4 z-50 space-y-2">
      <.flash_item :if={Phoenix.Flash.get(@flash, :info)} kind={:info} flash={@flash} />
      <.flash_item :if={Phoenix.Flash.get(@flash, :error)} kind={:error} flash={@flash} />

      <div
        id="client-error"
        class="hidden"
        phx-disconnected={CoviewWeb.CoreComponents.show(".phx-client-error #client-error")}
        phx-connected={CoviewWeb.CoreComponents.hide("#client-error")}
      >
        <.alert variant="destructive">
          <:icon><.icon name="hero-wifi" class="size-4" /></:icon>
          <:title>{gettext("We can't find the internet")}</:title>
          <:description>
            <span class="flex items-center gap-1">
              {gettext("Attempting to reconnect")}
              <.icon name="hero-arrow-path" class="size-3 animate-spin" />
            </span>
          </:description>
        </.alert>
      </div>

      <div
        id="server-error"
        class="hidden"
        phx-disconnected={CoviewWeb.CoreComponents.show(".phx-server-error #server-error")}
        phx-connected={CoviewWeb.CoreComponents.hide("#server-error")}
      >
        <.alert variant="destructive">
          <:icon><.icon name="hero-exclamation-triangle" class="size-4" /></:icon>
          <:title>{gettext("Something went wrong!")}</:title>
          <:description>
            <span class="flex items-center gap-1">
              {gettext("Attempting to reconnect")}
              <.icon name="hero-arrow-path" class="size-3 animate-spin" />
            </span>
          </:description>
        </.alert>
      </div>
    </div>
    """
  end

  attr(:kind, :atom, values: [:info, :error], required: true)
  attr(:flash, :map, required: true)

  defp flash_item(assigns) do
    ~H"""
    <div
      id={"flash-#{@kind}"}
      phx-click={
        JS.push("lv:clear-flash", value: %{key: @kind})
        |> CoviewWeb.CoreComponents.hide("#flash-#{@kind}")
      }
      class="cursor-pointer"
    >
      <.alert variant={if @kind == :error, do: "destructive", else: "default"}>
        <:icon>
          <.icon
            name={if @kind == :error, do: "hero-exclamation-circle", else: "hero-information-circle"}
            class="size-4"
          />
        </:icon>
        <:title>{Phoenix.Flash.get(@flash, @kind)}</:title>
      </.alert>
    </div>
    """
  end
end
