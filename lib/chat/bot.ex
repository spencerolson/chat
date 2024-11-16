defmodule Chat.Bot do
  use GenServer

  def start do
    GenServer.start(__MODULE__, nil, name: __MODULE__)
  end

  def ping do
    GenServer.cast(__MODULE__, :ping)
  end

  @impl true
  def init(_) do
    # GenServer.cast(__MODULE__, :print)
    :timer.apply_after(1_000, __MODULE__, :ping, [])
    {:ok, nil}
  end

  @impl true
  def handle_cast(:ping, state) do
    IO.write(Chat.Server, "ping!")
    :timer.apply_after(1_000, __MODULE__, :ping, [])
    {:noreply, state}
  end
end
