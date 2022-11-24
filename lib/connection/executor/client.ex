defmodule Ravix.Connection.RequestExecutor.Client do
  use Retry
  require Logger

  alias Ravix.Connection.ServerNode
  alias Ravix.Telemetry

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

  def request(node, method, path, headers \\ [], body \\ []) do
    path = ServerNode.node_url(node) <> path
    client = Finch.build(method, path, headers, body)

    retry with:
            constant_backoff(node.settings.retry_backoff)
            |> Stream.take(node.settings.retry_count) do
      do_request(node, client)
    after
      {:ok, result} ->
        {:ok, result}

      {_, response} ->
        Logger.error("[RAVIX] Error received from RavenDB: #{inspect(response)}")
        {:error, response}
    else
      err -> err
    end
  end

  defp do_request(node, client) do
    case Finch.request(client, node.settings.http_client_name) do
      {:ok, %{status: status}} when status in [408, 502, 503, 504] ->
        Telemetry.retry_count(node, status)
        {:error, status}

      {:ok, %{status: status} = response} when status == 404 ->
        {:ok, response}

      {:ok, result} ->
        put_in(result.body, Jason.decode!(result.body))
        |> check_stale(node)

      {:error, response} ->
        {:fatal, response}
    end
  end

  defp check_stale(%{body: %{"IsStale" => true}} = response, node) do
    case node.settings.retry_on_stale do
      true -> {:error, response}
      false -> {:ok, response}
    end
  end

  defp check_stale(response, _), do: {:ok, response}
end
