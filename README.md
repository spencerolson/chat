# Chat

To start the application, run

```bash
$ mix run -e Chat.start
```

Once started, type `help` to see all options.

Try running the application in multiple terminal windows, or even on multiple machines within the same network!

![Demo](https://github.com/spencerolson/chat/raw/main/priv/static/images/demo.gif)

## What is this?

A terminal-based chat app that demos the "raw mode" coming to OTP 28. Thanks to @zachallaun for the awesome [writeup](https://elixirforum.com/t/raw-terminal-mode-coming-to-otp-28/67491). He sums it up best:

> If you’re unfamiliar with raw mode, the gist of it is that it allows terminals to read input without waiting for a newline, allowing for much more responsive terminal UIs.

Note that you need to have OTP 28 installed locally, or else "raw mode" won't be available and the app won't work as expected. For the `asdf` version manager, I installed and activated it via:

```bash
$ asdf install erlang ref:master
$ asdf global erlang ref:master
```

## TODO
- Only render the messages that are visible on screen (currently it renders all, and performance can get bad/janky with a lot of messages)
- Ensure epmd is started on app startup (it'll be started if the user has created a node before, but otherwise the app will fail)
- Decide if i should be using multi_call instead of abcast for message broadcast
