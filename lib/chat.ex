defmodule Chat do
  alias Chat.{Input, Screen, Server}

  def start do
    Screen.setup_shell()
    Input.process_input(&Server.handle_input/1)
  end
end
