defmodule Coview.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CoviewWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:coview, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Coview.PubSub},
      # Presence for tracking users in rooms
      CoviewWeb.Presence,
      # Registry for room lookup by room_id
      {Registry, keys: :unique, name: Coview.RoomRegistry},
      # DynamicSupervisor for spawning room processes
      {DynamicSupervisor, name: Coview.RoomSupervisor, strategy: :one_for_one},
      # Start to serve requests, typically the last entry
      CoviewWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Coview.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CoviewWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
