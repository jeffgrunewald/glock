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
        SimpleStream.stream(host: host, path: path, port: port)
        |> Enum.take(10)

      assert received == Enum.map(0..9, fn _ -> [{:text, "greetings"}] end)
    end

    test "streams data through transform and chunk", %{host: host, port: port, path: path} do
      received =
        CustomStream.stream(host: host, path: path, port: port)
        |> Enum.take(3)

      assert received == [
               ["GREETINGS", "GREETINGS", "GREETINGS"],
               ["GREETINGS", "GREETINGS", "GREETINGS"],
               ["GREETINGS", "GREETINGS", "GREETINGS"]
             ]
    end

    test "terminates the stream on a close frame", %{host: host, port: port, path: path} do
      received = SimpleStream.stream(host: host, port: port, path: path) |> Enum.to_list()

      Process.sleep(500)

      assert Enum.map(0..9, fn _ -> [{:text, "greetings"}] end) == Enum.take(received, 20)
    end
  end
end

defmodule SimpleStream do
  use Glock.Stream
end

defmodule CustomStream do
  use Glock.Stream, chunk_every: 3

  @impl Glock.Stream
  def handle_transform(stream) do
    Stream.transform(stream, 0, &do_upcase/2)
  end

  defp do_upcase(elem, acc) do
    case elem do
      elem when is_close(elem) -> {:halt, acc}
      {:text, msg} -> {[String.upcase(msg)], acc + 1}
    end
  end
end
