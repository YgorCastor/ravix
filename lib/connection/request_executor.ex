defmodule Ravix.Connection.RequestExecutor do
  use Retry

  require OK

  @default_headers [{"content-type", "application/json"}, {"accept", "application/json"}]

  alias Ravix.Connection.Network.State, as: NetworkState
  alias Ravix.Connection.{NodeSelector, Response, ServerNode, InMemoryNetworkState}
  alias Ravix.Documents.Protocols.CreateRequest

  @spec execute(map, NetworkState.t(), any, keyword) :: {:ok, Response.t()} | {:error, any()}
  def execute(command, network_state, headers \\ nil, opts \\ [])

  def execute(command, %NetworkState{} = network_state, headers, opts) do
    opts =
      case network_state.disable_topology_updates do
        true -> opts
        false -> [{:topology_etag, network_state.node_selector.topology.etag} | opts]
      end

    node = NodeSelector.current_node(network_state.node_selector)

    execute_for_node(command, network_state, node, headers, opts)
  end

  @spec execute_for_node(
          map(),
          %{:certificate => any, :certificate_file => any, optional(any) => any},
          ServerNode.t(),
          any,
          keyword
        ) :: {:ok, Response.t()} | {:error, any()}
  def execute_for_node(
        command,
        %{certificate: _, certificate_file: _} = certificate,
        %ServerNode{} = node,
        headers \\ {},
        opts \\ []
      ) do
    topology_etag = Keyword.get(opts, :topology_etag, nil)
    should_retry = Keyword.get(opts, :should_retry, false)
    retry_backoff = Keyword.get(opts, :retry_backoff, 100)

    retry_count =
      case should_retry do
        true -> Keyword.get(opts, :retry_count, 3)
        false -> 0
      end

    headers =
      case topology_etag do
        nil -> headers
        _ -> [{"Topology-Etag", topology_etag}]
      end

    retry with: constant_backoff(retry_backoff) |> Stream.take(retry_count) do
      call_raven(command, certificate, node, headers)
    after
      {:ok, result} ->
        case result do
          {:non_retryable_error, response} -> {:error, response}
          {:error, error_response} -> {:error, error_response}
          response -> {:ok, response}
        end
    else
      err -> err
    end
  end

  defp call_raven(
         command,
         %{certificate: _, certificate_file: _} = certificate,
         %ServerNode{} = node,
         headers
       ) do
    OK.for do
      request = CreateRequest.create_request(command, node)
      conn_params <- build_params(certificate, node.protocol)

      conn <-
        Mint.HTTP.connect(node.protocol, node.url, node.port, conn_params)

      {:ok, conn, _ref} =
        Mint.HTTP.request(
          conn,
          request.method,
          request.url,
          @default_headers ++ [headers],
          request.data
        )
    after
      receive do
        message ->
          case Mint.HTTP.stream(conn, message) do
            {:ok, _conn, responses} ->
              case parse_response(responses) do
                %{status: 404} ->
                  {:non_retryable_error, :document_not_found}

                %{status: 403} ->
                  {:non_retryable_error, :unauthorized}

                %{status: 410} ->
                  {:error, :node_gone}

                %{data: data} when is_map_key(data, "Error") ->
                  {:non_retryable_error, data["Message"]}

                error_response when error_response.status in [408, 502, 503, 504] ->
                  parse_error(error_response)

                {:error, err} ->
                  {:non_retryable_error, err}

                parsed_response ->
                  {:ok, parsed_response}
              end
              |> check_if_needs_topology_update(node.database)

            {:error, _conn, error, _headers} when is_struct(error, Mint.HTTPError) ->
              {:error, error.reason}

            {:error, _conn, error, _headers} when is_struct(error, Mint.TransportError) ->
              InMemoryNetworkState.handle_node_failure(node)
              {:error, error.reason}

            _ ->
              {:non_retryable_error, :unexpected_request_error}
          end
      end
    end
  end

  defp check_if_needs_topology_update({:ok, response}, database_name) do
    case Enum.find(response.headers, fn header -> elem(header, 0) == "Refresh-Topology" end) do
      nil ->
        response

      _ ->
        InMemoryNetworkState.update_topology(database_name)
        response
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

  defp build_params(certificate, :https) do
    case certificate do
      %{certificate: nil, certificate_file: file} ->
        {:ok, transport_opts: [cacertfile: file]}

      %{certificate: cert, certificate_file: nil} ->
        {:ok, transport_opts: [cacert: cert]}

      _ ->
        {:error, :invalid_ssl_certificate}
    end
  end

  defp parse_response(responses) do
    responses
    |> Enum.take_while(fn response -> elem(response, 0) != :done end)
    |> Enum.map(fn content -> Map.put(%{}, elem(content, 0), elem(content, 2)) end)
    |> Enum.reduce(fn x, y ->
      Map.merge(x, y, fn _k, v1, v2 -> v2 ++ v1 end)
    end)
    |> decode_body()
  end

  defp decode_body(raw_response) when is_map_key(raw_response, :data) do
    case Jason.decode(raw_response.data) do
      {:ok, body} -> Map.replace(raw_response, :data, body)
      {:error, %Jason.DecodeError{}} -> {:error, :invalid_response_payload}
    end
  end

  defp decode_body(raw_response), do: raw_response
end
