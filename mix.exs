defmodule Chat.MixProject do
  use Mix.Project

  def project do
    [
      app: :chat,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: [],
      escript: escript()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Chat.Application, []}
    ]
  end

  defp escript do
    [main_module: Chat, strip_beams: true, embed_elixir: true]
  end
end
