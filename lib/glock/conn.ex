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
  """

  @type t :: %__MODULE__{
          client: pid,
          connect_opts: %{
            connect_timeout: non_neg_integer,
            retry: non_neg_integer,
            retry_timeout: non_neg_integer,
            transport: :tcp | :tls
          },
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
              transport: :tcp
            },
            headers: [],
            host: nil,
            monitor: nil,
            path: nil,
            port: 80,
            stream: nil,
            stream_state: nil,
            ws_opts: %{
              compress: false,
              closing_timeout: 15_000,
              keepalive: 5_000
            }

  @doc """
  Reduces over a keyword list of arguments for configuring the
  glock process and adds them to an empty instance of the `Glock.Conn.t`
  struct. Configs are merged with values passed by the user superseding
  default values with the exception of the http protocol which is locked
  to HTTP/1.1 for websocket compatibility.
  """
  @spec new(keyword) :: t
  def new(opts \\ []) do
    Enum.reduce(opts, struct(__MODULE__), &put_opts/2)
  end

  defp put_opts({required, value}, conn) when required in [:host, :path] do
    Map.put(conn, required, to_charlist(value))
  end

  defp put_opts({:connect_opts, value}, conn) do
    merged_opts =
      conn.connect_opts
      |> Map.merge(value, fn _key, _default, override -> override end)
      |> Map.put(:protocols, http: %{version: :"HTTP/1.1"})

    %{conn | connect_opts: merged_opts}
  end

  defp put_opts({:ws_opts, value}, conn) do
    %{
      conn
      | ws_opts: Map.merge(conn.ws_opts, value, fn _key, _default, override -> override end)
    }
  end

  defp put_opts({key, value}, conn), do: Map.put(conn, key, value)
end
