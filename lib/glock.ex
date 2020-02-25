defmodule Glock do
  @moduledoc """
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

    defmodule MySocket do
      use Glock.Socket
    end

    iex> {:ok, conn} = MySocket.start_link(host: "localhost", path: "/ws")
    {:ok, #PID<0.260.0>}
    iex> :ok = MySocket.send(conn, "hello socket!")
    :ok

  Implementing the `init_stream/1` callback allows you to create and store
  state for the socket connection which can be accessed from subsequent message
  send or receive events. A simple example might be to count the number of
  messages sent and received from the socket.

  Example:

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

  Implementing the `handle_send/2` callback allows for customization of the
  message frame types and the encoding or serialization performed on messages
  prior to sending. Piggy-backing the prior example, a complex data structure
  could be serialized to JSON and counted before being sent to the remote server.

  Example:

    defmodule MySocket do
    ...

      def handle_send(message, state) do
        frame = {:text, JSON.encode(message)}
        new_state = Map.put(state, "sent", state["sent"] + 1)
        {frame, new_state}
      end
    end

  Finally, implementing the `handle_receive/2` callback allows for custom
  handling of messages beyond simply logging them. All messages received
  by the gun connection pass through the `handle_receive/2` callback, so you
  can decode them, store them, reprocess them or anything else you like.
  This handler also covers receiving `:close` control frames and cleaning up/
  shutting down the glock process appropriately according to the Websocket
  specification.

  Example:

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
  """

  @typedoc """
  The types of frame structures accepted and returned by underlying gun
  client for handling.
  """
  @type frame ::
          :ping
          | :pong
          | :close
          | {:ping | :pong | :text | :binary | :close, binary}
          | {:close, non_neg_integer, binary}

  @typedoc """
  Keyword list of arguments to initialize a glock socket process.
  All keys are optional with default values except for `:host`
  and `:path`.
  """
  @type init_opts :: [
          connect_opts: %{
            connect_timeout: non_neg_integer,
            retry: non_neg_integer,
            retry_timeout: non_neg_integer,
            transport: :tcp | :tls
          },
          handler_init_args: term,
          headers: [binary],
          host: iodata,
          path: iodata,
          port: non_neg_integer,
          ws_opts: %{
            compress: boolean,
            closing_timeout: non_neg_integer,
            keepalive: non_neg_integer
          }
        ]

  @typedoc """
  Options available to the `c:init_stream/1` callback for initializing
  the state of socket implementing the glock behaviour.
  """
  @type stream_init_opts :: [
          conn: Glock.Conn.t(),
          protocols: [binary],
          headers: [{binary, binary}]
        ]

  @doc """
  Initialize the state of the socket implementing the glock
  behaviour. The state is stored within the glock connection
  and passed to the handler callbacks when messages are sent or
  received over the socket.
  """
  @callback init_stream(stream_init_opts()) :: term

  @doc """
  Processes messages sent from the client application to the
  websocket server and optionally tracks state for the connection.
  Messages sent by either the `send/2` or `send_async/2` functions
  are passed through `handle_send/2` for processing.

  The `c:handle_send/2` callback for the module implementing the
  glock behaviour is responsible for packaging messages to be sent
  into an appropriate websocket message frame. Terms must be converted
  or serialized to an appropriate text (string) or raw binary encoding
  and wrapped in a tuple indicating their format, or else a `:close`
  control frame can be sent.
  """
  @callback handle_push(message :: term, state :: term) ::
              {frame,
               {:ok, new_state}
               | {:push, new_state}
               | {:close, new_state}}
            when new_state: term

  @doc """
  Processes messages received by the client application from the
  remote websocket server. Any application-specific operations that
  must be done on received messages are performed by the `c:handle_receive/2`
  callback.

  Based on the frame received and the optionally tracked state available
  to the callback, emits a response frame and triggers the appropriate action.
  If an `{:ok, state}` tuple is produced, there is no expectation that a frame
  should be sent back to the websocket server. If a `{:send, state}` tuple is
  produced, the response frame is sent to the server. If a `{:close, state}`
  tuple is produced, a simple `:close` frame is returned to the server to
  signal the client's acknowledgement the connection is to be terminated and
  the process exits, cleaning up its state.
  """
  @callback handle_receive(frame, state :: term) ::
              {frame,
               {:ok, new_state}
               | {:push, new_state}
               | {:close, new_state}}
            when new_state: term

  defdelegate stream(opts), to: Glock.Stream

  defmacro is_close(frame) do
    quote do
      unquote(frame) == :close or unquote(frame) |> elem(0) == :close
    end
  end

  defmodule ConnError do
    defexception [:message]
  end
end
