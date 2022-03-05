defmodule Glock.ConnTest do
  use ExUnit.Case
  alias Glock.Conn

  test "returns defaults" do
    expected = %Conn{
      client: nil,
      connect_opts: %{
        connect_timeout: 60_000,
        retry: 10,
        retry_timeout: 300,
        transport: :tls,
        tls_opts: [
          verify: :verify_none,
          cacerts: :certifi.cacerts(),
          depth: 99,
          reuse_sessions: false
        ],
        protocols: [:http],
        http_opts: %{version: :"HTTP/1.1"}
      },
      handler_init_args: %{},
      headers: [],
      host: 'ws.foobar.com',
      monitor: nil,
      path: "/ws",
      port: 443,
      stream: nil,
      stream_state: nil,
      ws_opts: %{
        compress: false,
        closing_timeout: 15_000,
        keepalive: 5_000
      }
    }

    assert expected == Conn.new(host: "ws.foobar.com", path: "/ws")
  end

  test "returns default tcp" do
    expected = %Conn{
      client: nil,
      connect_opts: %{
        connect_timeout: 60_000,
        retry: 10,
        retry_timeout: 300,
        transport: :tcp,
        protocols: [:http],
        http_opts: %{version: :"HTTP/1.1"}
      },
      handler_init_args: %{},
      headers: [],
      host: 'ws.foobar.com',
      monitor: nil,
      path: "/ws",
      port: 8000,
      stream: nil,
      stream_state: nil,
      ws_opts: %{
        compress: false,
        closing_timeout: 15_000,
        keepalive: 5_000
      }
    }

    assert expected == Conn.new(host: "ws.foobar.com", path: "/ws", transport: :tcp, port: 8000)
  end

  test "returns default host name verify" do
    expected = %Conn{
      client: nil,
      connect_opts: %{
        connect_timeout: 60_000,
        retry: 10,
        retry_timeout: 300,
        transport: :tls,
        tls_opts: [
          verify: :verify_peer,
          cacerts: :certifi.cacerts(),
          depth: 99,
          server_name_indication: 'foobar.com',
          reuse_sessions: false,
          verify_fun: {&:ssl_verify_hostname.verify_fun/3, [check_hostname: 'foobar.com']}
        ],
        protocols: [:http],
        http_opts: %{version: :"HTTP/1.1"}
      },
      handler_init_args: %{},
      headers: [],
      host: 'ws.foobar.com',
      monitor: nil,
      path: "/ws",
      port: 443,
      stream: nil,
      stream_state: nil,
      ws_opts: %{
        compress: false,
        closing_timeout: 15_000,
        keepalive: 5_000
      }
    }

    assert expected ==
             Conn.new(host: "ws.foobar.com", path: "/ws", host_name_verify: "foobar.com")
  end

  test "returns customized connection" do
    expected = %Conn{
      client: nil,
      connect_opts: %{
        connect_timeout: 30000,
        retry: 5,
        retry_timeout: 300,
        transport: :tls,
        tls_opts: [
          verify: :verify_none,
          cacerts: :certifi.cacerts(),
          depth: 99,
          reuse_sessions: false
        ],
        protocols: [:http],
        http_opts: %{version: :"HTTP/1.1"}
      },
      handler_init_args: %{},
      headers: [],
      host: 'ws.foobar.com',
      monitor: nil,
      path: "/ws",
      port: 9000,
      stream: nil,
      stream_state: nil,
      ws_opts: %{
        compress: true,
        closing_timeout: 60000,
        keepalive: 5_000
      }
    }

    assert expected ==
             Conn.new(
               host: "ws.foobar.com",
               path: "/ws",
               connect_opts: %{connect_timeout: 30000, retry: 5},
               port: 9000,
               ws_opts: %{closing_timeout: 60000, compress: true}
             )
  end

  test "returns tcp connection with custom options" do
    expected = %Conn{
      client: nil,
      connect_opts: %{
        connect_timeout: 30000,
        retry: 5,
        retry_timeout: 300,
        transport: :tcp,
        protocols: [:http],
        http_opts: %{version: :"HTTP/1.1"}
      },
      handler_init_args: %{},
      headers: [],
      host: 'ws.foobar.com',
      monitor: nil,
      path: "/ws",
      port: 9000,
      stream: nil,
      stream_state: nil,
      ws_opts: %{
        compress: true,
        closing_timeout: 60000,
        keepalive: 5_000
      }
    }

    assert expected ==
             Conn.new(
               host: "ws.foobar.com",
               path: "/ws",
               connect_opts: %{connect_timeout: 30000, retry: 5},
               port: 9000,
               ws_opts: %{closing_timeout: 60000, compress: true},
               transport: :tcp
             )
  end

  test "returns customized connection with host name verification" do
    expected = %Conn{
      client: nil,
      connect_opts: %{
        connect_timeout: 30000,
        retry: 5,
        retry_timeout: 300,
        transport: :tls,
        tls_opts: [
          verify: :verify_peer,
          cacerts: :certifi.cacerts(),
          depth: 99,
          server_name_indication: 'foobar.com',
          reuse_sessions: false,
          verify_fun: {&:ssl_verify_hostname.verify_fun/3, [check_hostname: 'foobar.com']}
        ],
        protocols: [:http],
        http_opts: %{version: :"HTTP/1.1"}
      },
      handler_init_args: %{},
      headers: [],
      host: 'ws.foobar.com',
      monitor: nil,
      path: "/ws",
      port: 9000,
      stream: nil,
      stream_state: nil,
      ws_opts: %{
        compress: true,
        closing_timeout: 60000,
        keepalive: 5_000
      }
    }

    assert expected ==
             Conn.new(
               host: "ws.foobar.com",
               path: "/ws",
               connect_opts: %{connect_timeout: 30000, retry: 5},
               port: 9000,
               ws_opts: %{closing_timeout: 60000, compress: true},
               host_name_verify: "foobar.com"
             )
  end

  test "raises exception if host and path missing" do
    assert_raise Glock.ConnError,
                 "Must supply valid socket host and path. Binary strings are accepted for both. Received: #{inspect(host: nil, path: nil)}",
                 fn ->
                   Conn.new(port: 8080)
                 end
  end
end
