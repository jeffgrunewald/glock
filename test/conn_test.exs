defmodule ConnTest do
  use ExUnit.Case
  alias Glock.Conn

  test "returns defaults" do
    expected =
      %Conn{
        client: nil,
        connect_opts: %{
          connect_timeout: 60000,
          protocols: [http: %{version: :"HTTP/1.1"}],
          retry: 10,
          retry_timeout: 300,
          transport: :tcp
        },
        handler_init_args: %{},
        headers: [],
        host: 'foobar.com',
        monitor: nil,
        path: '/ws',
        port: 80,
        stream: nil,
        stream_state: nil,
        ws_opts: %{closing_timeout: 15000, compress: false, keepalive: 5000}
      }

    assert expected == Conn.new(host: "foobar.com", path: "/ws")
  end

  test "returns customized connection" do
    expected =
      %Conn{
        client: nil,
        connect_opts: %{
          connect_timeout: 30000,
          protocols: [http: %{version: :"HTTP/1.1"}],
          retry: 5,
          retry_timeout: 300,
          transport: :tcp
        },
        handler_init_args: %{},
        headers: [],
        host: 'foobar.com',
        monitor: nil,
        path: '/ws',
        port: 9000,
        stream: nil,
        stream_state: nil,
        ws_opts: %{closing_timeout: 60000, compress: true, keepalive: 5000}
      }

    assert expected == Conn.new(
      host: "foobar.com",
      path: "/ws",
      connect_opts: %{connect_timeout: 30000, retry: 5},
      port: 9000,
      ws_opts: %{closing_timeout: 60000, compress: true})
  end

  test "raises exception if host and path missing" do
    assert_raise Glock.ConnError, "Must supply valid socket host and path", fn -> Conn.new(port: 8080) end
  end
end
