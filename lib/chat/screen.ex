defmodule Chat.Screen do
  def render(state) do
    hide_cursor()

    state = add_dimensions(state)
    clear_and_move_to_top(state)
    print_top_bar(state)
    print_messages(state)
    move_to_bottom(state)
    print_input(state)

    show_cursor()
  end

  # -- Movement --

  defp clear_and_move_to_top(state) do
    write([IO.ANSI.clear(), move(:top, :left, state)])
  end

  defp move_to_bottom(state) do
    write([move(:bottom, :left, state)])
  end

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

  defp user_info(%{state: "connected"}), do: " | #{length(Node.list()) + 1} users online"
  defp user_info(_), do: ""

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

  defp move(:top, x, state), do: move(0, x, state)
  defp move(:bottom, x, state), do: move(state.height, x, state)
  defp move(y, :left, state), do: move(y, 0, state)
  defp move(y, :right, state), do: move(y, state.width, state)
  defp move(y, x, _) when is_integer(y) and is_integer(x), do: IO.ANSI.cursor(y, x)

  defp write(ansidata) do
    ansidata
    |> IO.ANSI.format()
    |> IO.write()
  end
end
