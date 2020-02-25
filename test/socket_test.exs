defmodule Glock.SocketTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  setup do
    port = 8080
    path = "/ws"
    start_supervised({MockSocket.Supervisor, port: port, path: path, source: self()})
    [host: "localhost", port: port, path: path]
  end

  describe "simple socket" do
    test "sends messages to the server", %{host: host, port: port, path: path} do
      {:ok, client} = start_supervised({SimpleSocket, host: host, path: path, port: port})

      Process.sleep(100)

      message1 = "hello socket"
      SimpleSocket.push(client, message1)

      assert_receive {:received_frame, message1}

      message2 = "hello async"
      SimpleSocket.push_async(client, message2)

      assert_receive {:received_frame, message2}
    end

    test "receives messages from the server", %{host: host, port: port, path: path} do
      start_and_wait = fn ->
        start_supervised({SimpleSocket, host: host, path: path, port: port})
        Process.sleep(200)
      end

      assert capture_log(start_and_wait) =~ "greetings"
    end
  end

  describe "custom handlers" do
    test "initializes stream state and handles received msgs", %{
      host: host,
      port: port,
      path: path
    } do
      start_supervised(
        {CustomSocket, host: host, port: port, path: path, handler_init_args: self()}
      )

      Process.sleep(100)

      assert_receive {:received_handled, "greetings", 2}
    end

    test "pushes messages with custom handler", %{host: host, port: port, path: path} do
      {:ok, client} =
        start_supervised(
          {CustomSocket, host: host, port: port, path: path, handler_init_args: self()}
        )

      message = "good morning"

      Process.sleep(100)

      CustomSocket.push(client, message)
      assert_receive {:received_frame, received_message}
      assert received_message == "this is message 1 : '#{message}'"
    end
  end
end

defmodule SimpleSocket do
  use Glock.Socket
end

defmodule CustomSocket do
  use Glock.Socket

  def init_stream(opts) do
    conn = Keyword.fetch!(opts, :conn)

    %{source: conn.handler_init_args, sent: 0, received: 0}
  end

  def handle_receive({_type, message} = frame, state) do
    count = state.received + 1
    send(state.source, {:received_handled, message, count})

    {frame, {:ok, %{state | received: count}}}
  end

  def handle_push(message, state) do
    count = state.sent + 1
    handled_message = "this is message #{count} : '#{message}'"
    {{:text, handled_message}, {:push, %{state | sent: count}}}
  end
end
