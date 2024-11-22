defmodule Chat.Screen do
  def setup do
    :shell.start_interactive({:noshell, :raw})
    # Enable alternate screen buffer
    :io.put_chars("\e[?1049h")
    :ok
  end

  def render(state) do
    hide_cursor()
    state = add_dimensions(state)
    write([IO.ANSI.clear(), move(:top, :left, state), "\n"])
    print_messages(state)
    write([move(:top, :left, state)])
    print_top_bar(state)
    write([move(:bottom, :left, state)])
    print_input(state)
    show_cursor()
    :ok
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
      color(state.color),
      user,
      color(:yellow),
      " | " <> state.state,
      user_info(state),
      "\r\n\n",
      IO.ANSI.reset()
    ])
  end

  defp user_info(%{state: "connected"}) do
    case length(Node.list()) do
      0 -> " | 1 user online"
      count -> " | #{count + 1} users online"
    end
  end

  defp user_info(_), do: ""

  # TODO: limit the number of messages printed to only those that fit on the screen.
  defp print_messages(state) do
    state.messages
    |> Enum.reverse()
    |> Enum.each(&print_message/1)
  end

  defp print_message({"SYSTEM", color, text}) do
    write([color(color), text, "\r\n", IO.ANSI.reset()])
  end

  defp print_message({name, color, text}) do
    write([name, ": ", color(color), text, "\r\n", IO.ANSI.reset()])
  end

  defp print_input(state) do
    write([color(state.color), "> " <> state.input, IO.ANSI.reset()])
  end

  # -- Utils --

  defp add_dimensions(state) do
    {:ok, height} = :io.rows()
    {:ok, width} = :io.columns()
    Map.merge(state, %{height: height, width: width})
  end

  defp color(code) when is_integer(code), do: IO.ANSI.color(code)
  defp color(name) when is_atom(name), do: name

  defp hide_cursor, do: :io.put_chars("\e[?25l")
  defp show_cursor, do: :io.put_chars("\e[?25h")

  defp write(ansidata) do
    ansidata
    |> IO.ANSI.format()
    |> IO.write()
  end
end
