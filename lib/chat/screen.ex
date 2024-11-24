defmodule Chat.Screen do
  alias Chat.Server

  @prompt "> "
  @start_messages_y 3
  @start_input_x String.length(@prompt) + 1

  def setup do
    :shell.start_interactive({:noshell, :raw})
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

    write([move(:bottom, @start_input_x, state)])
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
      move(:bottom, :left, state),
      IO.ANSI.clear_line(),
      color(state.color),
      @prompt <> state.input,
      IO.ANSI.reset()
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

  defp lines_above_input_to_clear(state) do
    input_length = String.length(@prompt <> state.input)
    div(input_length + 1, state.width)
  end

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
end
