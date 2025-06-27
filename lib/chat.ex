defmodule Chat do
  alias Chat.{Clustering, Input, Screen, Server}

  def main(_), do: start()

  def start do
    Clustering.setup()
    Screen.setup()
    show_help_menu()
    Input.process_input(&Server.handle_input/1)
  end

  defp show_help_menu do
    Server.handle_input("help")
    Server.handle_input("\r")
  end
end
