defmodule Chat.Server do
  use GenServer

  @backspace "\d"
  @enter "\r"

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def handle_input(input) do
    GenServer.cast(__MODULE__, {:handle_input, input})
  end

  def message_all(msg) do
    GenServer.abcast(__MODULE__, {:add_message, msg})
  end

  def message_me(msg) do
    GenServer.cast(__MODULE__, {:add_message, msg})
  end

  @impl true
  def init(_) do
    state = %{messages: [], input: "", color: :yellow}
    {:ok, state, {:continue, :render}}
  end

  @impl true
  def handle_continue(:render, state) do
    Chat.Screen.render(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:add_message, msg}, state) do
    state = %{state | messages: [msg | state.messages]}
    Chat.Screen.render(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:set_color, color}, state) do
    message_me({"SYSTEM", color, "Color changed to #{color}.\n"})
    {:noreply, %{state | color: color}}
  end

  @impl true
  def handle_cast({:handle_input, @backspace}, state) do
    state = %{state | input: String.slice(state.input, 0..-2//1)}
    Chat.Screen.render(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:handle_input, @enter}, state) do
    handle_enter(state)
    {:noreply, %{state | input: ""}}
  end

  @impl true
  def handle_cast({:handle_input, input}, state) do
    state = %{state | input: state.input <> input}
    Chat.Screen.render(state)
    {:noreply, state}
  end

  defp handle_enter(%{input: "help"}) do
    help_message = """
    Commands:\r
    help - show this message.\r

    login <name>@<host> - login to the chat with name and host.\r
    login <name> - login to the chat with name. Tries to infer host from `ipconfig getifaddr en0`.\r
    login - login to the chat with name 'noname'. Tries to infer host from `ipconfig getifaddr en0`.\r

    connect <name>@<host> - connect to another user. Connecting to a single user automatically connects to all users in the cluster.\r

    users - list connected users.\r

    color <color code> - set the color of your messages. Color code is an integer between 0 and 255, inclusive.\r

    logout - logout from the chat.\r
    """

    message_me({"SYSTEM", :green, help_message})
    :ok
  end

  defp handle_enter(%{input: "color " <> code_str}) do
    case Integer.parse(code_str) do
      {code, ""} when code in 0..255 ->
        GenServer.cast(__MODULE__, {:set_color, code})
        _ -> message_me({"SYSTEM", :red, "Invalid color code. Please enter a number between 0 and 255, inclusive.\n"})
    end
    :ok
  end

  defp handle_enter(%{input: "login" <> login_as}) do
    node_name = login_as |> String.trim() |> get_node_name() |> String.to_atom()
    case Node.start(node_name) do
      {:ok, _} ->
        Node.set_cookie(:monster)
        message_me({"SYSTEM", :green, "'#{node_name}' logged in\n"})
      {:error, _} ->
        message_me({"SYSTEM", :red, "Failed to start node with name '#{node_name}'\n"})
    end
    :ok
  end

  defp handle_enter(%{input: "logout"}) do
    message_all({"SYSTEM", :green, "#{user()} disconnected\n"}) # TODO: send this after the node is stopped.
    Node.stop()
    :ok
  end

  defp handle_enter(%{input: "connect " <> node_name}) do
    case Node.connect(String.to_atom(node_name)) do
      true -> message_all({"SYSTEM", :green, "'#{user()}' connected to the cluster\n"})
      false -> message_me({"SYSTEM", :red, "'#{user()}' failed to connect to the cluster\n"})
      :ignored -> message_me({"SYSTEM", :red, "Must login first. Type 'help' for more info.\n"})
    end
    :ok
  end

  defp handle_enter(%{input: "users"}) do
    text =
      [node() | Node.list()]
      |> Enum.reduce("Connected Users:\r\n", fn node, acc ->
        line = "- #{node}#{if Node.self() == node, do: " (you)", else: ""}\r\n"
        acc <> line
      end)

    message_me({"SYSTEM", :green, text})
    :ok
  end

  defp handle_enter(state) do
    if Node.alive?() do
      message_all({user(), state.color, state.input})
    else
      message_me({"SYSTEM", :red, "Must login first. Type 'help' for more info.\n"})
    end
    :ok
  end

  defp user do
    Node.self() |> Atom.to_string()
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
