defmodule Chat do
  @max_utf8_character_bytes 4

  def start do
    setup_shell()
    process_input("")
  end

  defp setup_shell do
    :shell.start_interactive({:noshell, :raw})
    # Enable alternate screen buffer
    :io.put_chars("\e[?1049h")
  end

  defp process_input(input) do
    Chat.Server.handle_input(input)

    ""
    |> IO.getn(@max_utf8_character_bytes)
    |> process_input()
  end

  # defp teardown do
  #   :io.put_chars("\e[?1049l") # Disable alternate screen buffer
  #   System.halt(0)
  # end
end
