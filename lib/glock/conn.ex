defmodule Glock.Conn do
  @moduledoc """
  Defines the glock connection struct that serves as
  the configuration state of an initialized glock process.

  The struct tracks all configuration settings and arguments
  passed into the connection when it is initialized and provides
  common default values for all settings except for the host
  and path of the remote websocket server.

  Provides utility functions for creating and ensuring the proper
  default values are set within the connection struct.

  For the various connection options please see
  https://ninenines.eu/docs/en/gun/2.0/manual/gun
  https://www.erlang.org/doc/man/ssl.html#type-tls_client_option


  By default it is set up with TLS and no verification of the host name

  Minimal to pass in for common uses
  For no encryption  use
  transport: :tcp
  and it will do other sensible things

  To verify the host name set
  host_name_verify: 'example.com' | "example.com"
  and it will do other sensible things

  If you want something more custom send in a full spec properly nested and it will override the defaults
  """

  @type t :: %__MODULE__{
          client: pid,
          connect_opts: %{
            connect_timeout: non_neg_integer,
            retry: non_neg_integer,
            retry_timeout: non_neg_integer,
            transport: :tcp | :tls,
            tls_opts: %{
              verify: :verify_none | :verify_peer,
              cacerts: fun(),
              depth: integer(),
              server_name_indication: charlist() | nil,
              reuse_sessions: boolean(),
              verify_fun: tuple() | nil
            },
            # This can also be :http2, etc
            protocols: [:http],
            # Request http 1.1 from the server
            # Typically %{version: :"HTTP/1.1"}
            # Note: the second value is an atom
            http_opts: map()
          },
          handler_init_args: term,
          headers: [binary],
          host: charlist,
          monitor: reference,
          path: charlist,
          port: non_neg_integer,
          stream: reference,
          stream_state: term,
          ws_opts: %{
            compress: boolean,
            closing_timeout: non_neg_integer,
            keepalive: non_neg_integer
          }
        }

  defstruct client: nil,
            connect_opts: %{
              connect_timeout: 60_000,
              retry: 10,
              retry_timeout: 300,
              transport: :tls,
              tls_opts: [
                # If you want to use verify_peer instead you should fill in server_name_indication and verify_fun
                verify: :verify_none,
                # Alternatively something like
                # cacertfile: CAStore.file_path(),
                cacerts: :certifi.cacerts(),
                depth: 99,
                # Make sure this matches :check_hostname
                # server_name_indication: 'example.com',
                reuse_sessions: false
                # verify_fun: {&:ssl_verify_hostname.verify_fun/3, [check_hostname: 'example.com']}
              ],
              protocols: [:http],
              http_opts: %{version: :"HTTP/1.1"}
            },
            handler_init_args: %{},
            headers: [],
            host: nil,
            monitor: nil,
            path: nil,
            port: 443,
            stream: nil,
            stream_state: nil,
            ws_opts: %{
              compress: false,
              closing_timeout: 15_000,
              keepalive: 5_000
            }

  # See docs for better info
  # https://ninenines.eu/docs/en/gun/2.0/manual/gun/
  # https://www.erlang.org/doc/man/ssl.html#type-client_option
  @allowed_gun_opts [
    # non_neg_integer
    :connect_timeout,
    # gun_cookies:store()
    :cookie_store,
    # non_neg_integer
    :domain_lookup_timeout,
    # map
    :http_opts,
    # map
    :http2_opts,
    # :http or :http2 or etc see docs
    :protocols,
    # non_neg_integer
    :retry,
    # function
    :retry_fun,
    # pos_integer
    :retry_timeout,
    # boolean
    :supervise,
    # map
    :tcp_opts,
    # pos_integer
    :tls_handshake_timeout,
    # keyword https://www.erlang.org/doc/man/ssl.html#type-client_option
    :tls_opts,
    # boolean
    :trace,
    # :tcp | :tls
    :transport
  ]

  # If these are set it will set up decent choices

  @doc """
  Reduces over a keyword list of arguments for configuring the
  glock process and adds them to an empty instance of the `Glock.Conn.t`
  struct. Configs are merged with values passed by the user superseding
  default values with the exception of the http protocol which is locked
  to HTTP/1.1 for websocket compatibility.
  """
  @spec new(keyword) :: Glock.Conn.t()
  def new(opts) do
    opts
    |> Enum.reduce(%__MODULE__{}, &put_opts/2)
    |> validate_required()
  end

  defp validate_required(%__MODULE__{host: host, path: path}) when host == nil or path == nil do
    raise Glock.ConnError,
      message:
        "Must supply valid socket host and path. Binary strings are accepted for both. Received: #{inspect(host: host, path: path)}"
  end

  defp validate_required(conn), do: conn

  defp put_opts({:host, host}, conn) when is_binary(host) do
    Map.put(conn, :host, to_charlist(host))
  end

  # This can be a charlist or ip address
  # https://www.erlang.org/doc/man/inet.html#type-ip_address
  defp put_opts({:host, host}, conn) do
    Map.put(conn, :host, host)
  end

  # path should be binary
  defp put_opts({:path, path}, conn) when is_list(path) do
    Map.put(conn, :path, to_string(path))
  end

  defp put_opts({:path, path}, conn) when is_binary(path) do
    Map.put(conn, :path, path)
  end

  defp put_opts({:connect_opts, value}, conn) do
    merged_opts =
      conn.connect_opts
      |> Map.merge(value, fn _key, _default, override -> override end)

    %{conn | connect_opts: merged_opts}
  end

  # If they want no security strip out tls_opts
  defp put_opts({:transport, :tcp}, %{connect_opts: connect_opts} = conn) do
    %{
      conn
      | connect_opts:
          Map.delete(connect_opts, :tls_opts) |> Map.update!(:transport, fn _ -> :tcp end)
    }
  end

  # If they want to verify the host put that into default tls_opts
  defp put_opts({:host_name_verify, host_name}, %{connect_opts: connect_opts} = conn) do
    %{
      conn
      | connect_opts: update_in(connect_opts, [:tls_opts], fn _ -> put_verify_peer(host_name) end)
    }
  end

  defp put_opts({opt, value}, %{connect_opts: connect_opts} = conn)
       when opt in @allowed_gun_opts do
    %{conn | connect_opts: update_in(connect_opts, [opt], fn _ -> value end)}
  end

  # ws_opts gets put in no the upgrade so it doesn't go into connect_opts
  defp put_opts({:ws_opts, value}, %{ws_opts: ws_opts} = conn) do
    %{
      conn
      | ws_opts: Map.merge(ws_opts, value, fn _key, _default, override -> override end)
    }
  end

  defp put_opts({key, value}, conn), do: Map.put(conn, key, value)

  # If they send in binary change to charlist and forward
  defp put_verify_peer(host_name) when is_binary(host_name) do
    host_name |> to_charlist() |> put_verify_peer
  end

  defp put_verify_peer(host_name) do
    [
      verify: :verify_peer,
      cacerts: :certifi.cacerts(),
      depth: 99,
      server_name_indication: host_name,
      reuse_sessions: false,
      verify_fun: {&:ssl_verify_hostname.verify_fun/3, [check_hostname: host_name]}
    ]
  end
end
