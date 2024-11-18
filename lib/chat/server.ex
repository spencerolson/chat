defmodule Chat.Server do
  use GenServer

  @refresh_interval 60

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def print do
    GenServer.cast(__MODULE__, :print)
  end

  def handle_input(input) do
    GenServer.cast(__MODULE__, {:handle_input, input})
  end

  @impl true
  def init(_) do
    :timer.apply_after(@refresh_interval, __MODULE__, :print, [])
    {:ok, %{messages: [], input: ""}}
  end

  @impl true
  def handle_info({:io_request, from, reply_as, {:put_chars, :unicode, msg}}, state) do
    msgs = [{user(), msg} | state.messages]
    send(from, {:io_reply, reply_as, :ok})
    {:noreply, %{ state | messages: msgs}}
  end

  defp user do
    Node.self() |> Atom.to_string()
  end

  @impl true
  def handle_cast({:add_message, msg}, state) do
    {:noreply, %{state | messages: [msg | state.messages]}}
  end

  @impl true
  def handle_cast(:print, state) do
    # {:ok, width} = :io.columns()
    {:ok, height} = :io.rows()

    IO.write(IO.ANSI.format([IO.ANSI.clear(), "\e[5;0H"]))
    state.messages
    |> Enum.reverse()
    |> Enum.each(fn {tstamp, color, msg} ->
      IO.write(IO.ANSI.format([tstamp, ": ", color, msg, "\r\n"]))
    end)

    IO.write(IO.ANSI.format([
      IO.ANSI.cursor_down(height - Enum.count(state.messages)),
      :green,
      state.input
    ]))
    :timer.apply_after(@refresh_interval, __MODULE__, :print, [])
    {:noreply, state}
  end

  @impl true
  def handle_cast({:handle_input, input}, state) do
    case input do
      "\d" ->
        {:noreply, %{state | input: String.slice(state.input, 0..-2//1)}}
      "\r" ->
        process_input(state)
        {:noreply, %{state | input: ""}}
      _ ->
        {:noreply, %{state | input: state.input <> input}}
    end
  end

  defp process_input(%{input: "login"}), do: process_input(%{input: "login "})

  defp process_input(%{input: "login " <> login_as}) do
    node_name = get_node_name(login_as)
    case Node.start(String.to_atom(node_name)) do
      {:ok, _} ->
        Node.set_cookie(:monster)
        msg = {"SYSTEM", :green, "'#{node_name}' logged in"}
        GenServer.abcast(__MODULE__, {:add_message, msg})
      {:error, _} ->
        msg = {"SYSTEM", :red, "Failed to start node with name '#{node_name}'"}
        GenServer.abcast(__MODULE__, {:add_message, msg})
    end
  end

  defp process_input(%{input: "logout"}) do
    username = user()
    case Node.stop() do
      :ok ->
        msg = {"SYSTEM", :green, "#{username} disconnected"}
        GenServer.abcast(__MODULE__, {:add_message, msg})
      _ ->
        msg = {"SYSTEM", :red, "#{username} failed to disconnect"}
        GenServer.abcast(__MODULE__, {:add_message, msg})
    end
  end

  defp process_input(%{input: "connect " <> node_name}) do
    case Node.connect(String.to_atom(node_name)) do
      true ->
        msg = {"SYSTEM", :green, "'#{user()}' connected to '#{node_name}'"}
        GenServer.abcast(__MODULE__, {:add_message, msg})
      false ->
        msg = {"SYSTEM", :red, "'#{user()}' failed to connect to '#{node_name}'"}
        GenServer.abcast(__MODULE__, {:add_message, msg})
      :ignored ->
        msg = {"SYSTEM", :red, "Must login first"}
        GenServer.abcast(__MODULE__, {:add_message, msg})
    end
  end

  defp process_input(state) do
    case Node.alive?() do
      true ->
        msg = {user(), :blue, state.input}
        GenServer.abcast(__MODULE__, {:add_message, msg})
      false ->
        msg = {"SYSTEM", :red, "Must login first"}
        GenServer.abcast(__MODULE__, {:add_message, msg})
    end
  end

  defp get_node_name(login_as) do
    case String.split(login_as, "@") do
      [_, _] -> login_as
      [""] -> "noname@#{get_host()}"
      [name] -> "#{name}@#{get_host()}"
      _ -> "noname@#{get_host()}"
    end
  end

  defp get_host do
    case System.cmd("ipconfig", ["getifaddr", "en0"]) do
      {host, 0} -> String.trim(host)
      _ -> "localhost"
    end
  end
end
