defmodule GlockTest do
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
        Process.sleep(100)
      end

      assert capture_log(start_and_wait) =~ "greetings"
    end
  end

  describe "custom handlers" do
    test "initializes stream state" do
      :ok
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

    {:ok, %{source: conn.handler_init_args, count: 0}}
  end

  def handle_receive({_type, message} = frame, state) do
    count = state.count + 1
    send(state.source, {:received_frame, message, count})

    {frame, {:ok, %{state | count: count}}}
  end

  def handle_push(message, state) do
    {{:text, message}, {:push, state}}
  end
end
