defmodule ResourceManager.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, args) do
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: ResourceManager.Worker.start_link(arg)
      %{
        :id => :resource_pool,
        :start => {ResourceManager.Worker, :start_link, [Application.get_env(:resource_manager, :pool)]}
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ResourceManager.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
