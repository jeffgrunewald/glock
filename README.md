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

It is set up to sensible TLS/SSH options out of the box without extra configuration.

If you _want_ no encryption specify the transport as `:tcp`. You probably also want to choose your own port as well as the default is `443`, typical for TLS.

Example:

```elixir
  iex> {:ok, conn} = MySocket.start_link(host: "echo.mypersonalserver.net", path: "/", transport: :tcp, port: 8000)
  {:ok, #PID<0.260.0>}
```

If you want to verify the host (which will also stop printing warnings) specify `verify_host_name`.

Example:

```elixir
  iex> {:ok, conn} = MySocket.start_link(host: "echo.websocket.org", path: "/", verify_host_name: "websocket.org")
  {:ok, #PID<0.260.0>}
```

If you want a custom set up `gun` has _a lot_ of options. You can build it yourself and send it in as a map as `connect_opt` (on open) or `ws_opts` (on upgrade) and override the defaults. For all the connection and websocket options available please see the [gun docs](https://ninenines.eu/docs/en/gun/2.0/manual/gun/).


```elixir
  iex> {:ok, conn} = MySocket.start_link(host: "echo.websocket.org", path: "/", 
              connect_opts: %{connect_timeout: 30000, retry: 5},
              port: 9000,
              ws_opts: %{closing_timeout: 60000, compress: true})
  {:ok, #PID<0.260.0>}
```

Please see the bottom of this page for the sensible defaults chosen with minimal options chosen.

Sadly, `echo.websocket.org` is no longer functioning so you have to set up your own echo server to run these examples. [Instructions on that.](https://www.lob.com/blog/websocket-org-is-down-here-is-an-alternative) If you take the Heroku option in the link it is unencrypted by default so follow the instructions for TCP here and make sure you take steps to encrypt it once you do something beyond testing.

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
    {:glock, "~> 0.1.3"}
  ]
end
```

## Connection Options Chosen for You

No additional args

```elixir

  {:ok, conn} = MySocket.start_link(host: "echo.websocket.org", path: "/")
  
  %Glock.Conn{
    ...
      connect_opts: %{
        connect_timeout: 60_000,
        retry: 10,
        retry_timeout: 300,
        transport: :tls,
        tls_opts: [
          verify: :verify_none,
          # Alternatively something like
          # cacertfile: CAStore.file_path(),
          cacerts: :certifi.cacerts(),
          depth: 99,
          reuse_sessions: false
        ],
        protocols: [:http],
        http_opts: %{version: :"HTTP/1.1"}
      },
      headers: [],
      host: 'echo.websocket.org',
      path: "/",
      port: 443,
      ws_opts: %{
        compress: false,
        closing_timeout: 15_000,
        keepalive: 5_000
      }
    ...
  }

```

No encryption

```elixir

  {:ok, conn} = MySocket.start_link(host: "echo.unencryptedrus.org", path: "/", transport: :tcp, port: 9000)
  
  %Glock.Conn{
    ...
      connect_opts: %{
        connect_timeout: 60_000,
        retry: 10,
        retry_timeout: 300,
        transport: :tcp,
        protocols: [:http],
        http_opts: %{version: :"HTTP/1.1"}
      },
      headers: [],
      host: 'echo.unencryptedrus.org',
      path: "/",
      port: 9000,
      ws_opts: %{
        compress: false,
        closing_timeout: 15_000,
        keepalive: 5_000
      }
    ...
  }

```

Verify host name

If this message is annoying you set `verify_host_name` and it should go away.

```
[warn]  Description: 'Authenticity is not established by certificate path validation'
          Reason: 'Option {verify, verify_peer} and cacertfile/cacerts is missing'
```


```elixir

  {:ok, conn} = MySocket.start_link(host: "echo.websocket.org", path: "/", verify_host_name: "websocket.org")
  
  %Glock.Conn{
    ...
      connect_opts: %{
        connect_timeout: 60_000,
        retry: 10,
        retry_timeout: 300,
        transport: :tls,
        tls_opts: [
          verify: :verify_peer,
          cacerts: :certifi.cacerts(),
          depth: 99,
          server_name_indication: 'websocket.org',
          reuse_sessions: false,
          verify_fun: {&:ssl_verify_hostname.verify_fun/3, [check_hostname: 'websocket.org']}
        ],
        protocols: [:http],
        http_opts: %{version: :"HTTP/1.1"}
      },
      headers: [],
      host: 'echo.websocket.org',
      path: "/",
      port: 443,
      ws_opts: %{
        compress: false,
        closing_timeout: 15_000,
        keepalive: 5_000
      }
    ...
  }

```



The docs can be found at [https://hexdocs.pm/glock](https://hexdocs.pm/glock).

