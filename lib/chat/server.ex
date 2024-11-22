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

  def initial_state do
    %{state: "logged_out", messages: [], input: "", color: :yellow}
  end

  @impl true
  def init(_) do
    {:ok, initial_state()}
  end

  @impl true
  def handle_cast({:add_message, msg}, state) do
    state
    |> Map.merge(%{messages: [msg | state.messages]})
    |> Screen.render(state)
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_cast(:connected, %{state: "connected"} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast(:connected, state) do
    state
    |> Map.merge(%{state: "connected"})
    |> Screen.render(state)
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_cast({:handle_input, @enter}, state) do
    state
    |> handle_enter()
    |> Screen.render(state)
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_cast({:handle_input, @backspace}, state) do
    state
    |> Map.merge(%{input: String.slice(state.input, 0..-2//1)})
    |> Screen.render(state)
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_cast({:handle_input, input}, state) when input in @ignored do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:handle_input, input}, state) do
    state
    |> Map.merge(%{input: state.input <> input})
    |> Screen.render(state)
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_info({:nodeup, node_name}, state) do
    messages = [{"SYSTEM", :green, Messaging.connected(node_name)} | state.messages]

    state
    |> Map.merge(%{messages: messages, state: "connected"})
    |> Screen.render(state)
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_info({:nodedown, node_name}, state) do
    if Node.alive?() do
      messages = [{"SYSTEM", :green, Messaging.disconnected(node_name)} | state.messages]

      state
      |> Map.merge(%{messages: messages})
      |> Screen.render(state)
      |> then(&{:noreply, &1})
    else
      {:noreply, state}
    end
  end

  defp handle_enter(%{input: "help"} = state) do
    messages = [{"SYSTEM", :white, Messaging.help_message()} | state.messages]
    %{state | input: "", messages: messages}
  end

  defp handle_enter(%{input: "color rand"} = state) do
    code = Enum.random(0..255)
    messages = [{"SYSTEM", code, Messaging.color_changed(code)} | state.messages]
    %{state | input: "", color: code, messages: messages}
  end

  defp handle_enter(%{input: "color " <> code_str} = state) do
    case Integer.parse(code_str) do
      {code, ""} when code in 0..255 ->
        messages = [{"SYSTEM", code, Messaging.color_changed(code)} | state.messages]
        %{state | input: "", color: code, messages: messages}

      _ ->
        messages = [{"SYSTEM", :red, Messaging.invalid_color()} | state.messages]
        %{state | input: "", messages: messages}
    end
  end

  defp handle_enter(%{input: "login " <> login_as} = state) do
    status =
      login_as
      |> Clustering.get_node_name()
      |> Clustering.start_node()

    case status do
      {:ok, node_name} ->
        messages = [{"SYSTEM", :green, Messaging.logged_in(node_name)} | state.messages]
        %{state | input: "", state: "disconnected", messages: messages}

      {:error, {:invalid_name, node_name}} ->
        messages = [{"SYSTEM", :red, Messaging.invalid_node_name(node_name)} | state.messages]
        %{state | input: "", messages: messages}

      {:error, {:could_not_start, node_name, error}} ->
        messages = [
          {"SYSTEM", :red, Messaging.could_not_start_node(node_name, error)} | state.messages
        ]

        %{state | input: "", messages: messages}
    end
  end

  defp handle_enter(%{input: "quit"} = state), do: handle_enter(%{state | input: "logout"})
  defp handle_enter(%{input: "exit"} = state), do: handle_enter(%{state | input: "logout"})

  defp handle_enter(%{input: "logout"} = state) do
    node_name = Node.self()

    case Node.stop() do
      :ok ->
        messages = [{"SYSTEM", :green, Messaging.logged_out(node_name)} | state.messages]
        %{state | input: "", state: "logged_out", messages: messages}

      {:error, :not_found} ->
        messages = [{"SYSTEM", :red, Messaging.requires_login()} | state.messages]
        %{state | input: "", messages: messages}

      {:error, _} ->
        messages = [{"SYSTEM", :red, Messaging.failed_logout()} | state.messages]
        %{state | input: "", messages: messages}
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
        messages = [{"SYSTEM", :red, Messaging.invalid_node_name(node_name)} | state.messages]
        %{state | input: "", messages: messages}

      {:error, {:could_not_connect, node_name}} ->
        messages = [
          {"SYSTEM", :red, Messaging.could_not_connect_node(node_name)} | state.messages
        ]

        %{state | input: "", messages: messages}

      {:error, {:must_login_first, _}} ->
        messages = [{"SYSTEM", :red, Messaging.requires_login()} | state.messages]
        %{state | input: "", messages: messages}
    end
  end

  defp handle_enter(%{input: "users"} = state) do
    text =
      Clustering.nodes()
      |> Enum.reduce(Messaging.userlist_title(), fn node, acc ->
        acc <> Messaging.userslist_line(node)
      end)

    messages = [{"SYSTEM", :white, text} | state.messages]
    %{state | input: "", messages: messages}
  end

  defp handle_enter(state) do
    cond do
      String.trim(state.input) == "" ->
        state

      not Node.alive?() ->
        messages = [{"SYSTEM", :red, Messaging.requires_login()} | state.messages]
        %{state | input: "", messages: messages}

      true ->
        user = Node.self() |> Atom.to_string()
        message_all({user, state.color, state.input})
        %{state | input: ""}
    end
  end
end
