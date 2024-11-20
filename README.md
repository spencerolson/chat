# Chat

To start the application, run

```bash
$ mix run -e Chat.start
```

Once started, type `help` to see all options.

[![asciicast](https://asciinema.org/a/QzghEIZNT526uU5gZNpB1wFdU.svg)](https://asciinema.org/a/QzghEIZNT526uU5gZNpB1wFdU)

## What is this?

A terminal-based chat app that demos the "raw mode" coming to OTP 28. Thanks to @zachallaun for the awesome [writeup](https://elixirforum.com/t/raw-terminal-mode-coming-to-otp-28/67491). He sums it up best:

> If you’re unfamiliar with raw mode, the gist of it is that it allows terminals to read input without waiting for a newline, allowing for much more responsive terminal UIs.

Note that you need to have OTP 28 installed locally, or else "raw mode" won't be available and the app won't work as expected. For the `asdf` version manager, I installed and activated it via:

```bash
$ asdf install erlang ref:master
$ asdf global erlang ref:master
```
