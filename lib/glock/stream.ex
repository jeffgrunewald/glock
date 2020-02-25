defmodule Glock.Stream do
  @moduledoc """
  Implements a Glock websocket connection as an Elixir
  Stream resource, returning messages as they are received
  until the connection is terminated, either by the remote
  websocket server or by exiting the Glock process.
  """
  import Glock, only: [is_close: 1]
  use Glock.Socket

  @spec stream(Glock.init_opts()) :: Enumerable.t()
  def stream(opts) do
    stream_opts = Keyword.put(opts, :handler_init_args, %{pid: self()})

    Stream.resource(
      initialize(stream_opts),
      &receive_messages/1,
      &close/1
    )
  end

  @impl Glock
  def init_stream(opts) do
    conn = Keyword.fetch!(opts, :conn)
    conn.handler_init_args
  end

  @impl Glock
  def handle_receive(frame, state) when is_close(frame) do
    send(state.pid, {:socket_message, :close})
    {:close, {:close, state}}
  end

  @impl Glock
  def handle_receive(frame, state) do
    send(state.pid, {:socket_message, frame})
    {:ok, {:ok, state}}
  end

  defp initialize(opts) do
    fn ->
      {:ok, glock} = __MODULE__.start(opts)
      %{glock_process: glock}
    end
  end

  defp receive_messages(acc) do
    receive do
      {:socket_message, frame} when is_close(frame) ->
        {:halt, acc}

      {:socket_message, frame} ->
        {[frame], acc}
    end
  end

  defp close(%{glock_process: glock} = acc) do
    ref = Process.monitor(glock)

    receive do
      {:DOWN, ^ref, _, _, _} -> :ok
    after
      1_000 -> Process.exit(glock, :normal)
    end

    acc
  end
end
