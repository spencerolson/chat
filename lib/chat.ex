defmodule Chat do
  def start do
    setup_shell()
    Chat.Getch.run()
  end

  defp setup_shell do
    :shell.start_interactive({:noshell, :raw})
    :io.put_chars("\e[?1049h") # Enable alternate screen buffer
  end
end
