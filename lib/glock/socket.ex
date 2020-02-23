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
      @@behaviour Glock

      @doc """
      Synchronously send a message to the remote server via the glock process.
      """
      @spec send(GenServer.server(), term) :: :ok | :close
      def send(conn, message), do: GenServer.call(conn, {:send, message})

      @doc """
      Asynchronously send a message to the remote server via the glock process.
      """
      @spec send_async(GenServer.server(), term) :: :ok
      def send(conn, message), do: GenServer.cast(conn, {:send, message})

      @impl Glock
      def init_stream(opts), do: {:ok, %{}}

      @impl Glock
      def handle_send(msg, state) when is_binary(msg) do
        {{:text, msg}, {:send, state}}
      end

      @impl Glock
      def handle_receive(frame, state), do: {frame, {:ok, state}}

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

      @impl GenServer
      def init(init_opts) do
        Process.flag(:trap_exit, true)

        {:ok, Conn.new(init_opts), {:continue, :connect}}
      end

      @impl GenServer
      def handle_continue(:connect, conn) do
        {:ok, client} = :gun.open(conn.host, conn.port, conn.connect_opts)
        {:ok, :http} = :gun.await_up(client)

        Logger.info("Connected to #{conn.host}:#{conn.port} on process : #{inspect(client)}")

        {:noreply, %{conn | client: client, monitor: Process.monitor(client)},
         {:continue, :upgrade}}
      end

      @impl GenServer
      def handle_continue(:upgrade, conn) do
        stream = :gun.ws_upgrade(conn.client, conn.path, conn.headers)

        {:noreply, %{conn | stream: stream}}
      end

      @impl GenServer
      def handle_call({:send, message}, _from, conn) do
        {frame, {result, new_state}} = handle_send(message, conn.stream_state)

        case result do
          :send ->
            {:reply, :gun.ws_send(conn.client, frame), update_stream_state(conn, new_state)}

          :ok ->
            {:reply, :ok, update_stream_state(conn, new_state)}

          :close ->
            {:stop, :close, :gun.ws_send(conn.client, frame),
             update_stream_state(conn, new_state)}
        end
      end

      @impl GenServer
      def handle_cast({:send, message}, conn) do
        {frame, {result, new_state}} = handle_send(message, conn.stream_state)

        case result do
          :send ->
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
        Logger.debug("Received frame from socket #{inspect(stream)} : #{inspect(frame)}")

        {frame, {result, new_state}} = handle_receive(frame, conn.stream_state)

        case result do
          :send ->
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

        Logger.info(
          "Connection #{inspect(conn.client)} successfully upgrade : #{inspect(stream)}"
        )

        {:noreply, update_stream_state(conn, stream_state)}
      end

      @impl GenServer
      def handle_info({:DOWN, ref, _, _, _}, %{monitor: ref} = conn) do
        Logger.warn("Connection to socket #{inspect(conn.stream)} lost; reconnecting...")

        {:noreply, conn, {:continue, :connect}}
      end

      @impl GenServer
      def handle_info({:EXIT, _pid, reason}, conn) do
        {:stop, reason, conn}
      end

      @impl GenServer
      def terminate(reason, conn) do
        Logger.info("Terminating client process with reason : #{inspect(reason)}")

        Process.demonitor(conn.monitor)
        :gun.flush(conn.stream)
        :gun.close(conn.client)
        conn
      end

      defoverridable init_stream: 1,
                     handle_send: 2,
                     handle_receive: 2

      defp update_stream_state(conn, state), do: Map.put(conn, :stream_state, state)
    end
  end
end