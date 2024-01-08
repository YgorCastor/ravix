defmodule Ravix.Connection.RequestExecutor.Client do
  @moduledoc false
  use Retry
  require Logger

  alias Ravix.Connection.State, as: ConnState
  alias Ravix.Connection.NodeSelector
  alias Ravix.Connection.ServerNode
  alias Ravix.Connection.RequestExecutor.Errors.MaximumUrlLengthError
  alias Ravix.Telemetry
  alias Ravix.Documents.Protocols.CreateRequest

  @spec build(Ravix.Connection.ServerNode.t()) ::
          {:error, :invalid_node} | {:ok, ServerNode.t()}
  def build(%ServerNode{} = node) do
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

  @spec request(ConnState.t(), struct(), list()) :: {:ok, term()} | {:error, term()}
  def request(%ConnState{} = conn_state, command, headers) do
    retry with:
            constant_backoff(conn_state.retry_backoff)
            |> Stream.take(conn_state.retry_count),
          rescue_only: [MaximumUrlLengthError] do
      {_pid, node} = NodeSelector.current_node(conn_state)
      request = CreateRequest.create_request(command, node)
      path = ServerNode.node_url(node) <> request.url
      _ = maximum_url_length_reached?(conn_state, path)
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

        put_in(response.body, decode_response(response.body))
        |> check_stale(node)

      {:error, %Finch.Error{reason: :disconnected}} ->
        Telemetry.request_error(node, :http2_pool_disconnected)
        {:error, :pool_disconnected}

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

  defp decode_response(""), do: ""

  defp decode_response(body) when is_binary(body), do: Jason.decode!(body)

  defp check_stale(%{body: %{"IsStale" => true, "IndexName" => index_name}} = response, node) do
    Telemetry.request_stale(node, index_name)

    case node.settings.retry_on_stale do
      true -> {:error, response}
      false -> {:ok, response}
    end
  end

  defp check_stale(response, _), do: {:ok, response}

  @spec maximum_url_length_reached?(ConnState.t(), String.t()) ::
          :ok | {:error, :maximum_url_length_reached}
  defp maximum_url_length_reached?(conn_state, url) do
    max_url_length = conn_state.conventions.max_length_of_query_using_get_url

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
