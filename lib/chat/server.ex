defmodule Chat.Server do
  use GenServer

  @backspace "\d"
  @enter "\r"
  @ignored [
    "\t",    # tab
    "\e",    # escape
    "\e[A",  # arrow up
    "\e[B",  # arrow down
    "\e[C",  # arrow right
    "\e[D",  # arrow left
    "\e[F",  # end
    "\e[H",  # home
    "\e[1~", # home
    "\e[3~", # delete
    "\e[4~", # end
    "\e[5~", # page up
    "\e[6~"  # page down
  ]

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def handle_input(input) do
    GenServer.cast(__MODULE__, {:handle_input, input})
  end

  def message_all(msg) do
    GenServer.abcast(__MODULE__, {:add_message, msg})
  end

  @impl true
  def init(_) do
    state = %{state: "logged_out", messages: [], input: "", color: :yellow}
    {:ok, state}
  end

  @impl true
  def handle_cast({:add_message, msg}, state) do
    state = %{state | messages: [msg | state.messages]}
    Chat.Screen.render(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:connected, %{state: "connected"} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast(:connected, state) do
    state = %{state | state: "connected"}
    Chat.Screen.render(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:handle_input, @backspace}, state) do
    state = %{state | input: String.slice(state.input, 0..-2//1)}
    Chat.Screen.render(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:handle_input, @enter}, state) do
    state = handle_enter(state)
    Chat.Screen.render(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:handle_input, input}, state) when input in @ignored do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:handle_input, input}, state) do
    state = %{state | input: state.input <> input}
    Chat.Screen.render(state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:nodeup, node_name}, state) do
    msg = {"SYSTEM", :green, "<< #{node_name} connected to the cluster >>"}
    state = %{state | state: "connected", messages: [msg | state.messages]}
    Chat.Screen.render(state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:nodedown, node_name}, state) do
    if Node.alive?() do
      msg = {"SYSTEM", :green, "<< #{node_name} logged out >>"}
      state = %{state | messages: [msg | state.messages]}
      Chat.Screen.render(state)
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  defp handle_enter(%{input: "help"} = state) do
    help_message = """
    Commands:\r
    help - show this message.\r

    login <name>@<host> - login to the chat with name and host.\r
    login <name> - login to the chat with name. Tries to infer host from `ipconfig getifaddr en0`.\r

    connect <name>@<host> - connect to another user. Connecting to a single user automatically connects to all users in the cluster.\r
    connect <name> - connect to another user with the same host.\r

    users - list connected users.\r

    color <color code> - set the color of your messages. Color code is an integer between 0 and 255, inclusive.\r
    color rand - set the color of your messages to a random color.\r

    logout - logout from the chat.\r
    """

    msg = {"SYSTEM", :white, help_message}
    %{state | input: "", messages: [msg | state.messages]}
  end

  defp handle_enter(%{input: "color rand"} = state) do
    color = Enum.random(0..255)
    msg = {"SYSTEM", color, "<< Color changed to #{color}. >>"}
    %{state | input: "", color: color, messages: [msg | state.messages]}
  end

  defp handle_enter(%{input: "color " <> code_str} = state) do
    case Integer.parse(code_str) do
      {code, ""} when code in 0..255 ->
        msg = {"SYSTEM", code, "<< Color changed to #{code}. >>"}
        %{state | input: "", color: code, messages: [msg | state.messages]}

      _ ->
        msg = {"SYSTEM", :red, "<< Invalid color code. Please enter a number between 0 and 255, inclusive. >>"}
        %{state | input: "", messages: [msg | state.messages]}
    end
  end

  defp handle_enter(%{input: "login " <> login_as} = state) do
    login_as
    |> get_node_name()
    |> start_node(state)
  end

  defp handle_enter(%{input: "logout"} = state) do
    node_name = Node.self()
    case Node.stop() do
      :ok ->
        msg = {"SYSTEM", :green, "<< #{node_name} logged out >>"}
        %{state | input: "", state: "logged_out", messages: [msg | state.messages]}

      {:error, :not_found} ->
        msg = {"SYSTEM", :red, "<< Must login first. Type 'help' for more info >>"}
        %{state | input: "", messages: [msg | state.messages]}

      {:error, _} ->
        msg = {"SYSTEM", :red, "<< Failed logout attempt >>"}
        %{state | input: "", messages: [msg | state.messages]}
    end
  end

  defp handle_enter(%{input: "connect " <> node_name_str} = state) do
    node_name = get_node_name(node_name_str)
    connect_node(node_name, state)
  end

  defp handle_enter(%{input: "users"} = state) do
    text =
      [node() | Node.list()]
      |> Enum.reduce("\r\nConnected Users:\r\n", fn node, acc ->
        line = "- #{node}#{if Node.self() == node, do: " (you)", else: ""}\r\n"
        acc <> line
      end)

    msg = {"SYSTEM", :white, text}
    %{state | input: "", messages: [msg | state.messages]}
  end

  defp handle_enter(state) do
    cond do
      String.trim(state.input) == "" ->
        state

      not Node.alive?() ->
        msg = {"SYSTEM", :red, "<< Must login first. Type 'help' for more info. >>"}
        %{state | input: "", messages: [msg | state.messages]}

      true ->
        message_all({user(), state.color, state.input})
        %{state | input: ""}
    end
  end

  defp start_node({:error, :invalid_name}, state), do: invalid_node_name(state)

  defp start_node(node_name_str, state) do
    node_name = String.to_atom(node_name_str)
    case Node.start(node_name) do
      {:ok, _} ->
        Node.set_cookie(:monster)
        :net_kernel.monitor_nodes(true)
        msg = {"SYSTEM", :green, "<< #{node_name} logged in >>"}
        %{state | input: "", state: "disconnected", messages: [msg | state.messages]}

      {:error, _} ->
        msg = {"SYSTEM", :red, "<< Failed to start node with name #{node_name} >>"}
        %{state | input: "", messages: [msg | state.messages]}
    end
  end

  defp connect_node({:error, :invalid_name}, state), do: invalid_node_name(state)

  defp connect_node(node_name_str, state) do
    node_name = String.to_atom(node_name_str)
    case Node.connect(node_name) do
      true ->
        %{state | input: "", state: "connected"}

      false ->
        msg = {"SYSTEM", :red, "<< #{user()} failed to connect to the cluster >>"}
        %{state | input: "", messages: [msg | state.messages]}

      :ignored ->
        msg = {"SYSTEM", :red, "<< Must login first. Type 'help' for more info >>"}
        %{state | input: "", messages: [msg | state.messages]}
    end
  end

  defp invalid_node_name(state) do
    msg = {"SYSTEM", :red, "<< Invalid node name. Please enter a valid name. >>"}
    %{state | input: "", messages: [msg | state.messages]}
  end

  defp user do
    Node.self() |> Atom.to_string()
  end

  defp get_node_name(str) do
    case String.split(str, "@") do
      [_, _] -> str
      [name] when name != "" -> "#{name}@#{get_host()}"
      _ -> {:error, :invalid_name}
    end
  end

  defp get_host do
    {:ok, interfaces} = :inet.getifaddrs()
    Enum.find_value(interfaces, fn {_, descriptions} ->
      Enum.find_value(descriptions, &ipv4_addr/1)
    end)
  end

  defp ipv4_addr({key, value}) do
    if key == :addr and tuple_size(value) == 4 and value != {127, 0, 0, 1} do
      value |> Tuple.to_list() |> Enum.join(".")
    end
  end
end
