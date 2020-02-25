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
      SimpleSocket.send(client, message1)

      assert_receive {:received_frame, message1}

      message2 = "hello async"
      SimpleSocket.send_async(client, message2)

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

  def init_stream(_opts) do
    {:ok, %{}}
  end

  def handle_receive(frame, state) do
    {frame, {:ok, state}}
  end

  def handle_send(message, state) do
    {{:text, message}, {:send, state}}
  end
end
