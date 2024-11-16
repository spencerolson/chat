defmodule Chat.Getch do
  def run do
    # new incantation to switch the terminal to raw mode in OTP 28
    :shell.start_interactive({:noshell, :raw})
    :io.put_chars("\e[?1049h") # Enable alternate screen buffer
    # :io.put_chars("\e[?25l") # Hide the cursor
    loop(nil)
  end

  def loop("q") do
    IO.write(Chat.Server, "Done!")
    # :io.put_chars("\e[?25h") # Show the cursor
    :io.put_chars("\e[?1049l") # Disable alternate screen buffer
    System.halt(0)
  end

  def loop(last) do
    if last, do: print(last)
    loop(IO.getn("", 1))
  end

  def print(last) do
    # IO.write(Chat.Server, IO.ANSI.format(["\r", "Got: ", :green, inspect(last), "\r\n"]))
    Chat.Server.handle_input(last)
    # IO.write(last)
  end
end
