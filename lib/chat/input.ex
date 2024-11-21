defmodule Chat.Input do
  @max_utf8_character_bytes 4

  def process_input(input \\ "", handler) do
    handler.(input)

    ""
    |> IO.getn(@max_utf8_character_bytes)
    |> process_input(handler)
  end
end
