defmodule Glock.Socket do
  @moduledoc """
  Defines the genserver that starts and manages the underlying gun
  process. The glock socket is configured to trap exits and monitor
  the gun connection to the remote server. In the event of failure,
  glock establishes a new http connection to the server if possible
  immediately attempts to re-upgrade to a websocket connection.

  The `__using__/1` macro provides default implementations of the
  three glock callback functions: `c:init_stream/1`, `c:handle_send/2`,
  and `c:handle_receive/2`, and marks them as overridable to allow
  for customization.

  Provides functions for sending messages to the glock process for
  handling and relaying to the remote websocket server both synchronously
  and asynchronously.
  """

  defmacro __using__(_opts) do
    quote location: :keep do
      require Logger
      use GenServer
      alias Glock.Conn
      @behaviour Glock

      @doc """
      Synchronously send a message to the remote server via the glock process.
      """
      @spec push(GenServer.server(), term) :: :ok | :close
      def push(conn, message), do: GenServer.call(conn, {:push, message})

      @doc """
      Asynchronously send a message to the remote server via the glock process.
      """
      @spec push_async(GenServer.server(), term) :: :ok
      def push_async(conn, message), do: GenServer.cast(conn, {:push, message})

      @impl Glock
      def init_stream(_opts), do: %{}

      @impl Glock
      def handle_push(msg, state) when is_binary(msg) do
        {:push, {:text, msg}, state}
      end

      @impl Glock
      def handle_receive(frame, state), do: {:ok, frame, state}

      @doc """
      Start a named glock process and link it to the calling process,
      passing all http and websocket configuration options for initialization.
      """
      @spec start_link(Glock.init_opts()) :: GenServer.on_start()
      def start_link(init_opts) do
        name =
          Keyword.get_lazy(init_opts, :name, fn ->
            init_opts
            |> Keyword.take([:host, :path])
            |> Keyword.values()
            |> Enum.map(fn element -> String.trim(element, "/") end)
            |> Enum.join("_")
            |> String.replace("/", "_")
            |> String.to_atom()
          end)

        GenServer.start_link(__MODULE__, init_opts, name: name)
      end

      @doc """
      Start a named glock process outside of a supervision tree,
      passing all http and websocket configuration options for initialization.
      """
      @spec start(Glock.init_opts()) :: GenServer.on_start()
      def start(init_opts) do
        GenServer.start(__MODULE__, init_opts)
      end

      @impl GenServer
      def init(init_opts) do
        Process.flag(:trap_exit, true)

        {:ok, Conn.new(init_opts), {:continue, :connect}}
      end

      @impl GenServer
      def handle_continue(:connect, conn) do
        {:ok, client} = :gun.open(conn.host, conn.port, conn.connect_opts)
        {:ok, :http} = :gun.await_up(client)

        Logger.info(fn ->
          "Connected to #{conn.host}:#{conn.port} on process : #{inspect(client)}"
        end)

        {:noreply, %{conn | client: client, monitor: Process.monitor(client)},
         {:continue, :upgrade}}
      end

      @impl GenServer
      def handle_continue(:upgrade, conn) do
        stream = :gun.ws_upgrade(conn.client, conn.path, conn.headers)

        {:noreply, %{conn | stream: stream}}
      end

      @impl GenServer
      def handle_call({:push, message}, _from, conn) do
        {result, frame, new_state} = handle_push(message, conn.stream_state)

        case result do
          :push ->
            {:reply, :gun.ws_send(conn.client, frame), update_stream_state(conn, new_state)}

          :ok ->
            {:reply, :ok, update_stream_state(conn, new_state)}

          :close ->
            {:stop, :close, :gun.ws_send(conn.client, frame),
             update_stream_state(conn, new_state)}
        end
      end

      @impl GenServer
      def handle_cast({:push, message}, conn) do
        {result, frame, new_state} = handle_push(message, conn.stream_state)

        case result do
          :push ->
            :gun.ws_send(conn.client, frame)
            {:noreply, update_stream_state(conn, new_state)}

          :ok ->
            {:noreply, update_stream_state(conn, new_state)}

          :close ->
            :gun.ws_send(conn.client, frame)
            {:stop, :close, update_stream_state(conn, new_state)}
        end
      end

      @impl GenServer
      def handle_info({:gun_ws, client, stream, frame}, %{client: client, stream: stream} = conn) do
        Logger.debug(fn -> "Received frame from socket #{inspect(stream)} : #{inspect(frame)}" end)

        {result, frame, new_state} = handle_receive(frame, conn.stream_state)

        case result do
          :push ->
            :ok = :gun.ws_send(conn.client, frame)
            {:noreply, update_stream_state(conn, new_state)}

          :ok ->
            {:noreply, update_stream_state(conn, new_state)}

          :close ->
            :gun.ws_send(conn.client, frame)
            {:stop, :close, update_stream_state(conn, new_state)}
        end
      end

      @impl GenServer
      def handle_info(
            {:gun_upgrade, client, stream, protocols, headers},
            %{client: client, stream: stream} = conn
          ) do
        stream_state = init_stream(conn: conn, protocols: protocols, headers: headers)

        Logger.info(fn ->
          "Connection #{inspect(conn.client)} successfully upgrade : #{inspect(stream)}"
        end)

        {:noreply, update_stream_state(conn, stream_state)}
      end

      @impl GenServer
      def handle_info({:gun_error, _client, {:badstate, _reason}}, state) do
        Logger.warn(fn -> "Connection not finished upgrading, too quick on the draw" end)
        {:noreply, state}
      end

      @impl GenServer
      def handle_info({:DOWN, ref, _, _, _}, %{monitor: ref} = conn) do
        Logger.warn(fn -> "Connection to socket #{inspect(conn.stream)} lost; reconnecting..." end)

        {:noreply, conn, {:continue, :connect}}
      end

      @impl GenServer
      def handle_info({:EXIT, _pid, reason}, conn) do
        {:stop, reason, conn}
      end

      @impl GenServer
      def terminate(reason, conn) do
        Logger.info(fn -> "Terminating client process with reason : #{inspect(reason)}" end)

        Process.demonitor(conn.monitor)
        :gun.flush(conn.stream)
        :gun.close(conn.client)
        conn
      end

      defoverridable init_stream: 1,
                     handle_push: 2,
                     handle_receive: 2

      defp update_stream_state(conn, state), do: Map.put(conn, :stream_state, state)
    end
  end
end
