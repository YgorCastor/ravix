defmodule Ravix.Connection.RequestExecutor.Client do
  require OK
  require Logger

  alias Ravix.Connection.ServerNode

  def build(node = %ServerNode{}) do
    base_url = {Tesla.Middleware.BaseUrl, "#{node.protocol}://#{node.url}:#{node.port}"}

    Tesla.Builder.client(
      [
        base_url,
        retry(node)
      ],
      [
        Tesla.Middleware.JSON
      ],
      node.adapter
    )
    |> test_conn(node)
  end

  defp test_conn(client, node) do
    try do
      case Tesla.get(client, "/databases") do
        {:ok, %{status: 200}} ->
          {:ok,
           %ServerNode{
             node
             | client: client
           }}

        err ->
          Logger.error("[RAVIX] Failed to connect to the database #{inspect(err)}")
          {:error, :invalid_node}
      end
    catch
      :exit, failure ->
        Logger.error(
          "Failed to start the connection with the node #{inspect(node.url)} - #{inspect(failure)}"
        )
    end
  end

  defp retry(node),
    do:
      {Tesla.Middleware.Retry,
       [
         delay: node.settings.retry_backoff,
         max_retry: node.settings.retry_count,
         max_delay: 4000,
         should_retry: fn
           {:ok, %{status: status}} when status in [408, 502, 503, 504] ->
             true

           {:ok, %{body: %{"IsStale" => true, "IndexName" => index_name}}} ->
             should_retry_stale(node.settings.retry_on_stale, index_name, node)

           {:ok, _} ->
             false

           {:error, _} ->
             true
         end
       ]}

  defp should_retry_stale(false, _, _), do: false

  defp should_retry_stale(true, index, node),
    do: not Enum.member?(node.settings.allowed_stale_indexes, index)
end
