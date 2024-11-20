defmodule Chat.Server do
  use GenServer

  alias Chat.{Clustering, Messaging, Screen}

  @backspace "\d"
  @enter "\r"
  @ignored [
    # tab
    "\t",
    # escape
    "\e",
    # arrow up
    "\e[A",
    # arrow down
    "\e[B",
    # arrow right
    "\e[C",
    # arrow left
    "\e[D",
    # end
    "\e[F",
    # home
    "\e[H",
    # home
    "\e[1~",
    # delete
    "\e[3~",
    # end
    "\e[4~",
    # page up
    "\e[5~",
    # page down
    "\e[6~"
  ]

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def handle_input(input) do
    GenServer.cast(__MODULE__, {:handle_input, input})
  end

  def message_all(msg) do
    # TODO: see if i should multi_call instead? do i need back-pressure?
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
    Screen.render(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:connected, %{state: "connected"} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast(:connected, state) do
    state = %{state | state: "connected"}
    Screen.render(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:handle_input, @backspace}, state) do
    state = %{state | input: String.slice(state.input, 0..-2//1)}
    Screen.render(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:handle_input, @enter}, state) do
    state = handle_enter(state)
    Screen.render(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:handle_input, input}, state) when input in @ignored do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:handle_input, input}, state) do
    state = %{state | input: state.input <> input}
    Screen.render(state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:nodeup, node_name}, state) do
    msg = {"SYSTEM", :green, Messaging.connected(node_name)}
    state = %{state | state: "connected", messages: [msg | state.messages]}
    Screen.render(state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:nodedown, node_name}, state) do
    if Node.alive?() do
      msg = {"SYSTEM", :green, Messaging.disconnected(node_name)}
      state = %{state | messages: [msg | state.messages]}
      Screen.render(state)
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  defp handle_enter(%{input: "help"} = state) do
    msg = {"SYSTEM", :white, Messaging.help_message()}
    %{state | input: "", messages: [msg | state.messages]}
  end

  defp handle_enter(%{input: "color rand"} = state) do
    code = Enum.random(0..255)
    msg = {"SYSTEM", code, Messaging.color_changed(code)}
    %{state | input: "", color: code, messages: [msg | state.messages]}
  end

  defp handle_enter(%{input: "color " <> code_str} = state) do
    case Integer.parse(code_str) do
      {code, ""} when code in 0..255 ->
        msg = {"SYSTEM", code, Messaging.color_changed(code)}
        %{state | input: "", color: code, messages: [msg | state.messages]}

      _ ->
        msg = {"SYSTEM", :red, Messaging.invalid_color()}
        %{state | input: "", messages: [msg | state.messages]}
    end
  end

  defp handle_enter(%{input: "login " <> login_as} = state) do
    status =
      login_as
      |> Clustering.get_node_name()
      |> Clustering.start_node()

    case status do
      {:ok, node_name} ->
        msg = {"SYSTEM", :green, Messaging.logged_in(node_name)}
        %{state | input: "", state: "disconnected", messages: [msg | state.messages]}

      {:error, {:invalid_name, node_name}} ->
        msg = {"SYSTEM", :red, Messaging.invalid_node_name(node_name)}
        %{state | input: "", messages: [msg | state.messages]}

      {:error, {:could_not_start, node_name}} ->
        msg = {"SYSTEM", :red, Messaging.could_not_start_node(node_name)}
        %{state | input: "", messages: [msg | state.messages]}
    end
  end

  defp handle_enter(%{input: "logout"} = state) do
    node_name = Node.self()

    case Node.stop() do
      :ok ->
        msg = {"SYSTEM", :green, Messaging.logged_out(node_name)}
        %{state | input: "", state: "logged_out", messages: [msg | state.messages]}

      {:error, :not_found} ->
        msg = {"SYSTEM", :red, Messaging.requires_login()}
        %{state | input: "", messages: [msg | state.messages]}

      {:error, _} ->
        msg = {"SYSTEM", :red, Messaging.failed_logout()}
        %{state | input: "", messages: [msg | state.messages]}
    end
  end

  defp handle_enter(%{input: "connect " <> connect_to} = state) do
    status =
      connect_to
      |> Clustering.get_node_name()
      |> Clustering.connect_node()

    case status do
      {:ok, _} ->
        %{state | input: "", state: "connected"}

      {:error, {:invalid_name, node_name}} ->
        msg = {"SYSTEM", :red, Messaging.invalid_node_name(node_name)}
        %{state | input: "", messages: [msg | state.messages]}

      {:error, {:could_not_connect, node_name}} ->
        msg = {"SYSTEM", :red, Messaging.could_not_connect_node(node_name)}
        %{state | input: "", messages: [msg | state.messages]}

      {:error, {:must_login_first, _}} ->
        msg = {"SYSTEM", :red, Messaging.requires_login()}
        %{state | input: "", messages: [msg | state.messages]}
    end
  end

  defp handle_enter(%{input: "users"} = state) do
    text =
      Clustering.nodes()
      |> Enum.reduce(Messaging.userlist_title(), fn node, acc ->
        acc <> Messaging.userslist_line(node)
      end)

    msg = {"SYSTEM", :white, text}
    %{state | input: "", messages: [msg | state.messages]}
  end

  defp handle_enter(state) do
    cond do
      String.trim(state.input) == "" ->
        state

      not Node.alive?() ->
        msg = {"SYSTEM", :red, Messaging.requires_login()}
        %{state | input: "", messages: [msg | state.messages]}

      true ->
        user = Node.self() |> Atom.to_string()
        message_all({user, state.color, state.input})
        %{state | input: ""}
    end
  end
end
