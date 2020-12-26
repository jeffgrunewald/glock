# Glock

Glock is a simple websocket client application based on the Gun
HTTP/HTTP2/Websocket Erlang library.

Glock aims to simplify the specific task of starting and configuring
a websocket client connection to a remote server, providing common
default values for all connection settings provided by Gun while still
allowing for full customization.

Glock also provides a set of callbacks for processing messages sent
to and received from the remote server and tracking state across the
life of the connection in whatever way makes sense to your application.
Default callback implementations let you get up and running immediately
for simply sending messages to a server and logging received responses
by implementing the `__using__/1` macro:

Example:

```elixir
  defmodule MySocket do
    use Glock.Socket
  end

  iex> {:ok, conn} = MySocket.start_link(host: "echo.websocket.org", path: "/")
  {:ok, #PID<0.260.0>}
  iex> :ok = MySocket.push(conn, "hello socket!")
```

Implementing the `init_stream/1` callback allows you to create and store
state for the socket connection which can be accessed from subsequent message
send or receive events. A simple example might be to count the number of
messages sent and received from the socket.

Example:

```elixir
  defmodule MySocket do
    use Glock.Socket

    def init_stream(conn: conn, protocols: _, headers: _) do
      %{
        "connection" => conn.stream,
        "sent" => 0,
        "received" => 0
      }
    end
  end
```

Implementing the `handle_send/2` callback allows for customization of the
message frame types and the encoding or serialization performed on messages
prior to sending. Piggy-backing the prior example, a complex data structure
could be serialized to JSON and counted before being sent to the remote server.

Example:

```elixir
  defmodule MySocket do
  ...

    def handle_send(message, state) do
      frame = {:text, JSON.encode(message)}
      new_state = Map.put(state, "sent", state["sent"] + 1)
      {frame, new_state}
    end
  end
```

Finally, implementing the `handle_receive/2` callback allows for custom
handling of messages beyond simply logging them. All messages received
by the gun connection pass through the `handle_receive/2` callback, so you
can decode them, store them, reprocess them or anything else you like.
This handler also covers receiving `:close` control frames and cleaning up/
shutting down the glock process appropriately according to the Websocket
specification.

Example:

```elixir
  defmodule MySocket do
  ...

    def handle_receive(frame, state) do
      case frame do
        {:text, message} ->
          send_to_internal_queue(message)
          new_state = Map.put(state, "received", state["received"] + 1)
          {:doesnt_matter, {:ok, new_state}}
        :close ->
          JSON.encode(state) |> write_to_log_service()
          {:close, {:close, state}}
        _ ->
          {:doesnt_matter, {:ok, state}}
      end
    end
  end
```

## Installation

The package can be installed by adding `glock` to your list
of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:glock, "~> 0.1.0"}
  ]
end
```

The docs can be found at [https://hexdocs.pm/glock](https://hexdocs.pm/glock).

