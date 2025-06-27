# Chat

To start the application, run

```bash
cd chat/
mix run -e Chat.start
```

Alernatively, the project can be installed and run as an [escript](https://hexdocs.pm/mix/main/Mix.Tasks.Escript.Build.html):

```bash
mix escript.install github spencerolson/chat
chat
```

Once started, type `help` to see all options.

Try running the application in multiple terminal windows, or even on multiple machines within the same network!

![Demo](https://github.com/spencerolson/chat/raw/main/priv/static/images/demo.gif)

## What is this?

A terminal-based chat app that demos the newly-introduced "raw mode" in OTP 28. Thanks to @zachallaun for the awesome [writeup](https://elixirforum.com/t/raw-terminal-mode-coming-to-otp-28/67491). He sums it up best:

> If you’re unfamiliar with raw mode, the gist of it is that it allows terminals to read input without waiting for a newline, allowing for much more responsive terminal UIs.

Note that you need to have OTP 28 installed locally, or else "raw mode" won't be available and the app won't work as expected. For the `asdf` version manager, I installed and activated it via:

```bash
asdf install erlang 28.0.1
asdf install elixir 1.18.4-otp-28
cd chat/
asdf set erlang 28.0.1
asdf set elixir 1.18.4-otp-28
```

## TODO

- Decide if i should be using multi_call instead of abcast for message broadcast
