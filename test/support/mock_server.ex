defmodule MockSocket.Supervisor do
  use Supervisor

  def start_link(init_args) do
    Supervisor.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  def init(init_args) do
    port = Keyword.get(init_args, :port)
    path = Keyword.get(init_args, :path)

    [
      {Plug.Cowboy,
       [
         scheme: :http,
         plug: MockSocket.Router,
         options: [
           port: port,
           dispatch: [
             {:_,
              [
                {"/#{path}", MockSocket, init_args}
              ]}
           ],
           protocol_options: [{:idle_timeout, 60_000}]
         ]
       ]}
    ]
    |> Supervisor.init(strategy: :one_for_one)
  end
end

defmodule MockSocket.Router do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  match _ do
    send_resp(conn, 404, "not found")
  end
end

defmodule MockSocket do
  @behaviour :cowboy_websocket

  require Logger

  def init(req, opts) do
    {:cowboy_websocket, req, opts}
  end

  def websocket_init(opts) do
    source = Keyword.get(opts, :source)
    send_close = Keyword.get(opts, :send_close, false)

    :timer.send_interval(50, :interval_send)

    if send_close, do: :timer.send_after(200, :close)

    state = %{source: source, send_close: send_close, count: 0}

    {:ok, state}
  end

  def websocket_handle({:text, message}, %{source: pid} = state) do
    IO.inspect(message, label: "RECEIVED FROM TEST")
    send(pid, {:received_frame, "#{message}"})
    {:ok, state}
  end

  def websocket_handle(:ping, %{source: pid} = state) do
    send(pid, :pong_from_socket)

    {:reply, :pong, state}
  end

  def websocket_info(:interval_send, state) do
    {:reply, {:text, "greetings"}, state}
  end

  def websocket_info(:close, state) do
    {:reply, {:close, "goodbye"}, state}
  end

  def websocket_info(_, state) do
    {:ok, state}
  end
end
