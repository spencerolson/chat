defmodule Chat do
  alias Chat.{Clustering, Input, Screen, Server}

  def main(_), do: start()

  def start do
    Clustering.setup()
    Screen.setup()
    Input.process_input(&Server.handle_input/1)
  end
end
