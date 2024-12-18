defmodule Chat.Screen do
  alias Chat.Server

  @cursor_length 1
  @prompt "> "
  @start_messages_y 3
  @start_input_x String.length(@prompt) + 1

  def setup do
    case Integer.parse(System.otp_release()) do
      {version, _} when version < 28 ->
        msg = """
        This application relies on "raw mode" which is only supported in Erlang/OTP 28 or later.

        << You are running Erlang/OTP version #{System.otp_release()} >>

        See the README for more info.
        """
        IO.puts(msg)
        System.halt(1)
      _ ->
        :shell.start_interactive({:noshell, :raw})
    end
    # Enable alternate screen buffer
    :io.put_chars("\e[?1049h")
    render(Server.initial_state(), %{})
  end

  def render(state, old_state) do
    changes = Map.filter(state, fn {k, v} -> v != old_state[k] end)

    state
    |> add_dimensions()
    |> hide_cursor()
    |> maybe_print_messages(changes)
    |> print_top_bar()
    |> print_input()
    |> show_cursor()

    state
  end

  # -- Movement --

  defp move(:top, x, state), do: move(0, x, state)
  defp move(:bottom, x, state), do: move(state.height, x, state)
  defp move(y, :left, state), do: move(y, 0, state)
  defp move(y, x, _) when is_integer(y) and is_integer(x), do: IO.ANSI.cursor(y, x)

  # -- Printing --

  defp print_top_bar(state) do
    user = Node.self() |> Atom.to_string()

    write([
      move(:top, :left, state),
      IO.ANSI.clear_line(),
      color(state.color),
      user,
      color(:yellow),
      " | " <> state.state,
      user_info(state),
      IO.ANSI.cursor_down(1),
      IO.ANSI.clear_line(),
      move(:bottom, @start_input_x, state),
      IO.ANSI.reset()
    ])

    state
  end

  defp user_info(%{state: "connected"}) do
    case length(Node.list()) do
      0 -> " | 1 user online"
      count -> " | #{count + 1} users online"
    end
  end

  defp user_info(_), do: ""

  defp maybe_print_messages(state, %{messages: _}), do: print_messages(state)
  defp maybe_print_messages(state, _), do: state

  # TODO: limit the number of messages printed to only those that fit on the screen.
  defp print_messages(state) do
    write([move(@start_messages_y, :left, state)])

    message_count = max_visible_messages(state)

    state.messages
    |> Enum.take(message_count)
    |> Enum.reverse()
    |> Enum.each(&print_message/1)

    write(["\r\n", move(:bottom, @start_input_x, state)])
    state
  end

  defp print_message({"SYSTEM", color, text}) do
    write([
      IO.ANSI.clear_line(),
      color(color),
      text,
      "\r\n",
      IO.ANSI.reset()
    ])
  end

  defp print_message({name, color, text}) do
    write([
      IO.ANSI.clear_line(),
      name,
      ": ",
      color(color),
      text,
      "\r\n",
      IO.ANSI.reset()
    ])
  end

  defp print_input(state) do
    write([
      move(state.height - 1, :left, state),
      IO.ANSI.clear_line(),
      IO.ANSI.cursor_down(1),
      IO.ANSI.clear_line(),
      color(state.color),
      @prompt <> visible_input(state),
      IO.ANSI.reset(),
    ])

    state
  end

  # -- Utils --

  defp add_dimensions(state) do
    {:ok, height} = :io.rows()
    {:ok, width} = :io.columns()
    Map.merge(state, %{height: height, width: width})
  end

  defp color(code) when is_integer(code), do: IO.ANSI.color(code)
  defp color(name) when is_atom(name), do: name

  defp max_visible_messages(state), do: state.height - @start_messages_y - 1

  defp hide_cursor(state) do
    :io.put_chars("\e[?25l")
    state
  end

  defp show_cursor(state) do
    :io.put_chars("\e[?25h")
    state
  end

  defp write(ansidata) do
    ansidata
    |> IO.ANSI.format()
    |> IO.write()
  end

  defp max_input_length(state), do: max(state.width - String.length(@prompt) - @cursor_length, 0)

  defp visible_input(state) do
    max = max_input_length(state)

    if String.length(state.input) <= max do
      state.input
    else
      start = String.length(state.input) - max
      String.slice(state.input, start, max)
    end
  end
end
