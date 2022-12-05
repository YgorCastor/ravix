defmodule Ravix.Connection.RequestExecutor.Client do
  use Retry
  require Logger

  alias Ravix.Connection.State, as: ConnState
  alias Ravix.Connection.NodeSelector
  alias Ravix.Connection.ServerNode
  alias Ravix.Connection.RequestExecutor.Errors.MaximumUrlLengthError
  alias Ravix.Telemetry
  alias Ravix.Documents.Protocols.CreateRequest

  def build(node = %ServerNode{}) do
    path = ServerNode.node_url(node) <> "/databases"
    client = Finch.build(:get, path)

    case Finch.request(client, node.settings.http_client_name) do
      {:ok, %{status: 200}} ->
        {:ok, node}

      err ->
        Logger.error("[RAVIX] Failed to connect to the database #{inspect(err)}")
        {:error, :invalid_node}
    end
  end

  def request(%ConnState{} = conn_state, command, headers) do
    retry with:
            constant_backoff(conn_state.retry_backoff)
            |> Stream.take(conn_state.retry_count),
          rescue_only: [MaximumUrlLengthError] do
      {_pid, node} = NodeSelector.current_node(conn_state)
      request = CreateRequest.create_request(command, node)
      path = ServerNode.node_url(node) <> request.url
      _ = maximum_url_length_reached?(node, path)
      client = Finch.build(request.method, path, request.headers ++ headers, request.data)
      do_request(node, client, is_stream: command.is_stream)
    after
      {:ok, result} ->
        {:ok, result}

      {_, response} ->
        Logger.error("[RAVIX] Error received from RavenDB: #{inspect(response)}")
        {:error, response}
    else
      %MaximumUrlLengthError{} ->
        {:error, :maximum_url_length_reached}

      err ->
        err
    end
  end

  defp do_request(node, client, is_stream: false) do
    case Finch.request(client, node.settings.http_client_name) do
      {:ok, %{status: status}} when status in [408, 502, 503, 504] ->
        Telemetry.request_error(node, status)
        {:error, status}

      {:ok, %{status: status} = response} when status == 404 ->
        Telemetry.request_error(node, 404)
        {:ok, response}

      {:ok, response} ->
        Telemetry.request_success(node)

        put_in(response.body, Jason.decode!(response.body))
        |> check_stale(node)

      {:error, response} ->
        {:fatal, response}
    end
  end

  defp do_request(node, client, is_stream: true) do
    parse_response = fn
      {:status, value}, acc -> %{acc | status: value}
      {:headers, value}, acc -> %{acc | headers: acc.headers ++ value}
      {:data, value}, acc -> %{acc | body: acc.body <> value}
    end

    parse_stream = fn
      body ->
        body
        |> Jaxon.Stream.from_binary()
        |> Jaxon.Stream.query([:root, "Results", :all])
    end

    case Finch.stream(
           client,
           node.settings.http_client_name,
           %{status: nil, headers: [], body: ""},
           parse_response
         ) do
      {:ok, response} ->
        Telemetry.request_success(node)
        {:ok, put_in(response.body, parse_stream.(response.body))}
    end
  end

  defp check_stale(%{body: %{"IsStale" => true, "IndexName" => index_name}} = response, node) do
    Telemetry.request_stale(node, index_name)

    case node.settings.retry_on_stale do
      true -> {:error, response}
      false -> {:ok, response}
    end
  end

  defp check_stale(response, _), do: {:ok, response}

  @spec maximum_url_length_reached?(ServerNode.t(), String.t()) ::
          :ok | {:error, :maximum_url_length_reached}
  defp maximum_url_length_reached?(node, url) do
    max_url_length = node.settings.max_url_length

    case String.length(url) > max_url_length do
      true ->
        raise %MaximumUrlLengthError{
          message: "The URL length is over the defined limit of '#{max_url_length}'"
        }

      false ->
        :ok
    end
  end
end
