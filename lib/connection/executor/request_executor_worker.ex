defmodule Ravix.Connection.RequestExecutor.Worker do
  @moduledoc false
  use GenServer
  use Retry

  require OK
  require Logger

  @default_headers [{"content-type", "application/json"}, {"accept", "application/json"}]

  alias Ravix.Connection
  alias Ravix.Connection.{ServerNode}
  alias Ravix.Documents.Protocols.CreateRequest

  @doc """
  Initializes the connection for the informed ServerNode

  The process will take care of the connection state, if the connection closes, the process
  will die automatically
  """
  @spec init(Ravix.Connection.ServerNode.t()) ::
          {:ok, Ravix.Connection.ServerNode.t()}
          | {:stop,
             %{
               :__exception__ => any,
               :__struct__ => Mint.HTTPError | Mint.TransportError,
               :reason => any,
               optional(:module) => any
             }}
  def init(%ServerNode{} = node) do
    Logger.info(
      "[RAVIX] Connecting to node '#{inspect(node.url)}:#{inspect(node.port)}' for store '#{inspect(node.store)}' PID: #{inspect(self())}"
    )

    Registry.register(:request_executors, node.store, [])

    case connect(node) do
      {:ok, node} -> {:ok, node}
      {:error, node} -> {:stop, node}
    end
  end

  @spec start_link(keyword()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, struct!(ServerNode, opts))
  end

  ####################
  #     Handlers     #
  ####################
  def handle_call({:request, command, headers, opts}, from, %ServerNode{} = node) do
    request = CreateRequest.create_request(command, node)

    case maximum_url_length_reached?(opts, request.url) do
      true -> {:reply, {:error, :maximum_url_length_reached}, node}
      false -> exec_request(node, from, request, command, headers, opts)
    end
  end

  def handle_info(message, %ServerNode{} = node) do
    case Mint.HTTP.stream(node.conn, message) do
      :unknown ->
        _ = Logger.error(fn -> "[RAVIX] Received unknown message: " <> inspect(message) end)
        {:noreply, node}

      {:ok, conn, responses} ->
        node = put_in(node.conn, conn)
        state = Enum.reduce(responses, node, &process_response/2)
        {:noreply, state}

      {:error, conn, error, _headers} when is_struct(error, Mint.HTTPError) ->
        node = put_in(node.conn, conn)

        _ =
          Logger.error(fn ->
            "[RAVIX] Received error message: " <> inspect(message) <> " " <> inspect(error)
          end)

        {:noreply, node}

      {:error, _conn, error, _headers} when is_struct(error, Mint.TransportError) ->
        Logger.debug(
          "[RAVIX] The connection with the node '#{inspect(node.url)}:#{inspect(node.port)}' for the store '#{inspect(node.store)}' timed out gracefully"
        )

        {:stop, :normal, node}
    end
  end

  def handle_cast({:update_cluster_tag, cluster_tag}, %ServerNode{} = node) do
    {:noreply, %ServerNode{node | cluster_tag: cluster_tag}}
  end

  defp exec_request(
         %ServerNode{conn: %{state: :closed}} = node,
         from,
         request,
         command,
         headers,
         opts
       ) do
    case connect(node) do
      {:ok, node} -> exec_request(node, from, request, command, headers, opts)
      _ -> {:error, :node_unreachable}
    end
  end

  defp exec_request(%ServerNode{} = node, from, request, command, headers, opts) do
    case Mint.HTTP.request(
           node.conn,
           request.method,
           request.url,
           @default_headers ++ [headers],
           request.data
         ) do
      {:ok, conn, request_ref} ->
        Logger.debug(
          "[RAVIX] Executing command #{inspect(command)} under the request '#{inspect(request_ref)}' for the store #{inspect(node.store)}"
        )

        node = put_in(node.conn, conn)
        node = put_in(node.requests[request_ref], %{from: from, response: %{}})
        node = put_in(node.opts, opts)
        {:noreply, node}

      {:error, conn, reason} ->
        state = put_in(node.conn, conn)
        {:reply, {:error, reason}, state}
    end
  end

  defp process_response({:status, request_ref, status}, state) do
    put_in(state.requests[request_ref].response[:status], status)
  end

  defp process_response({:headers, request_ref, headers}, state) do
    put_in(state.requests[request_ref].response[:headers], headers)
  end

  defp process_response({:data, request_ref, new_data}, state) do
    update_in(state.requests[request_ref].response[:data], fn data -> (data || "") <> new_data end)
  end

  defp process_response({:done, request_ref}, state) do
    {%{response: response, from: from}, state} = pop_in(state.requests[request_ref])
    response = put_in(response[:data], decode_body(response[:data]))

    parsed_response =
      case response do
        %{status: 404} ->
          {:non_retryable_error, :document_not_found}

        %{status: 403} ->
          {:non_retryable_error, :unauthorized}

        %{status: 409} ->
          {:error, :conflict}

        %{status: 410} ->
          {:error, :node_gone}

        %{data: :invalid_response_payload} ->
          {:non_retryable_error, "Unable to parse the response payload"}

        %{data: data} when is_map_key(data, "Error") ->
          {:non_retryable_error, data["Message"]}

        %{data: %{"IsStale" => true}} ->
          Logger.warn("[RAVIX] The request '#{inspect(request_ref)}' is Stale!")

          case ServerNode.retry_on_stale?(state) do
            true -> {:error, :stale}
            false -> {:non_retryable_error, :stale}
          end

        error_response when error_response.status in [408, 502, 503, 504] ->
          parse_error(error_response)

        parsed_response ->
          {:ok, parsed_response}
      end
      |> check_if_needs_topology_update(state)

    Logger.debug(
      "[RAVIX] Request #{inspect(request_ref)} finished with response #{inspect(parsed_response)}"
    )

    GenServer.reply(from, parsed_response)

    state
  end

  defp check_if_needs_topology_update({:ok, response}, %ServerNode{} = node) do
    case Enum.find(response.headers, fn header -> elem(header, 0) == "Refresh-Topology" end) do
      nil ->
        {:ok, response}

      _ ->
        Logger.debug(
          "[RAVIX] The database requested a topology refresh for the store '#{inspect(node.store)}'"
        )

        Connection.update_topology(node.store)
        {:ok, response}
    end
  end

  defp check_if_needs_topology_update({error_kind, err}, _), do: {error_kind, err}

  defp parse_error(error_response) do
    case Enum.find(error_response.headers, fn header -> elem(header, 0) == "Database-Missing" end) do
      nil ->
        {:retryable_error, error_response.data["Message"]}

      _ ->
        {:error, error_response.data["Message"]}
    end
  end

  defp build_params(_, :http), do: {:ok, []}

  defp build_params(ssl_config, :https) do
    case ssl_config do
      [] ->
        {:error, :no_ssl_configurations_informed}

      transport_ops ->
        {:ok, transport_opts: transport_ops}
    end
  end

  defp decode_body(raw_response) when is_binary(raw_response) do
    case Jason.decode(raw_response) do
      {:ok, parsed_response} -> parsed_response
      {:error, %Jason.DecodeError{}} -> :invalid_response_payload
    end
  end

  defp decode_body(_), do: nil

  @spec maximum_url_length_reached?(keyword(), String.t()) :: boolean()
  defp maximum_url_length_reached?(opts, url) do
    max_url_length = Keyword.get(opts, :max_length_of_query_using_get_url, 1024 + 512)

    String.length(url) > max_url_length
  end

  defp connect(node) do
    {:ok, conn_params} = build_params(node.ssl_config, node.protocol)

    case Mint.HTTP.connect(node.protocol, node.url, node.port, conn_params) do
      {:ok, conn} ->
        Logger.debug(
          "[RAVIX] Connected to node '#{inspect(node.url)}:#{inspect(node.port)}' for store '#{inspect(node.store)}'"
        )

        {:ok, %ServerNode{node | conn: conn}}

      {:error, reason} ->
        Logger.error(
          "[RAVIX] Unable to connect to the node '#{inspect(node.url)}:#{inspect(node.port)}' for store '#{inspect(node.store)}', cause: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end
end
