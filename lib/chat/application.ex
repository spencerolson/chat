defmodule Chat.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Chat.Server
    ]

    opts = [strategy: :one_for_one, name: Chat.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
