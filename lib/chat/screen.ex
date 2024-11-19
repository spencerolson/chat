defmodule Chat.Screen do
  def render(state) do
    clear_and_move_to_top()
    print_messages(state)
    move_to_bottom(state)
    print_input(state)
  end

  # -- Movement --

  defp clear_and_move_to_top() do
    write([IO.ANSI.clear(), "\e[5;0H", IO.ANSI.reset()])
  end

  defp move_to_bottom(state) do
    {:ok, height} = :io.rows()
    lines_down = height - Enum.count(state.messages)
    lines_down
    |> IO.ANSI.cursor_down()
    |> IO.write()
  end

  # -- Printing --

  defp print_input(state) do
    write([color(state.color), "> " <> state.input, IO.ANSI.reset()])
  end

  defp print_messages(state) do
    state.messages
    |> Enum.reverse()
    |> Enum.each(&print_message/1)
  end

  defp print_message({name, color, text}) do
    write([name, ": ", color(color), text, "\r\n", IO.ANSI.reset()])
  end

  # -- Utils --

  defp color(code) when is_integer(code), do: IO.ANSI.color(code)
  defp color(name) when is_atom(name), do: name

  defp write(ansidata) do
    ansidata
    |> IO.ANSI.format()
    |> IO.write()
  end
end
