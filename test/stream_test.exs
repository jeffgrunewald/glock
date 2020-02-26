defmodule Glock.StreamTest do
  use ExUnit.Case

  setup do
    port = 8080
    path = "/ws"

    start_supervised({MockSocket.Supervisor, port: port, path: path, send_close: true})

    [host: "localhost", port: port, path: path]
  end

  describe "Glock.Stream" do
    test "streams data lazily while the connection is active", %{
      host: host,
      port: port,
      path: path
    } do
      received =
        Glock.stream(host: host, path: path, port: port)
        |> Enum.take(10)

      assert received == Enum.map(0..9, fn _ -> {:text, "greetings"} end)
    end

    test "terminates the stream on a close frame", %{host: host, port: port, path: path} do
      received = Glock.stream(host: host, port: port, path: path) |> Enum.to_list()

      Process.sleep(500)

      assert Enum.map(0..9, fn _ -> {:text, "greetings"} end) == Enum.take(received, 20)
    end
  end
end
