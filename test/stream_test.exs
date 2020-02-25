defmodule Glock.StreamTest do
  use ExUnit.Case

  setup do
    port = 8080
    path = "/ws"

    {:ok, server} =
      start_supervised({MockSocket.Supervisor, port: port, path: path, send_close: true})

    [server: server, host: "localhost", port: port, path: path]
  end

  describe "Glock.Stream" do
    test "streams data lazily while the connection is active", %{
      server: server,
      host: host,
      port: port,
      path: path
    } do
      stream_data =
        SimpleStream.stream(host: host, path: path, port: port)
        |> IO.inspect(label: "STREAM START")

      :timer.send_after(200, server, :close)

      stream_data |> Stream.run()

      assert stream_data == ["greetings"]
    end
  end
end

defmodule SimpleStream do
  use Glock.Stream
end
