defmodule Glock.Stream do
  @moduledoc """
  Implements a Glock websocket connection as an Elixir
  Stream resource, returning messages as they are received
  in configurable chunks until the connection is terminated,
  either by the remote websocket server or by exiting the
  Glock process.

  Defines an optional callback c:handle_transform/1 function
  that allows for arbitrary transformation of the messages
  passing through the stream. If the callback is not implemented,
  all messages will be processed and delivered unmodified.
  """
  @callback handle_transform(Enumerable.t()) :: Enumerable.t()
  @optional_callbacks handle_transform: 1

  def __on_definition__(env, kind, name, args, _guards, _body) do
    if name == :handle_transform and length(args) == 1 and kind == :def do
      Module.put_attribute(env.module, :transform, true)
    end
  end

  defmacro __before_compile__(env) do
    Module.get_attribute(env.module, :transform)
    |> case do
      true ->
        quote do
          @spec stream(Glock.init_opts()) :: Enumerable.t()
          def stream(opts) do
            stream_opts = Keyword.put(opts, :handler_init_args, %{pid: self()})

            Stream.resource(
              initialize(stream_opts),
              &receive_messages/1,
              &close/1
            )
            |> handle_transform()
            |> Stream.chunk_every(unquote(Module.get_attribute(env.module, :chunk_size)))
          end
        end

      false ->
        quote do
          @spec stream(Glock.init_opts()) :: Enumerable.t()
          def stream(opts) do
            stream_opts = Keyword.put(opts, :handler_init_args, %{pid: self()})

            Stream.resource(
              initialize(stream_opts),
              &receive_messages/1,
              &close/1
            )
            |> Stream.chunk_every(unquote(Module.get_attribute(env.module, :chunk_size)))
          end
        end
    end
  end

  defmacro __using__(opts) do
    chunk_size = Keyword.get(opts, :chunk_every, 1)

    quote location: :keep do
      Module.put_attribute(__MODULE__, :chunk_size, unquote(chunk_size))
      import Glock, only: [is_close: 1]
      use Glock.Socket
      @on_definition Glock.Stream
      @before_compile Glock.Stream
      @behaviour Glock.Stream
      @transform false

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
  end
end
