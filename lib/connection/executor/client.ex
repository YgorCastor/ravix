defmodule Ravix.Connection.RequestExecutor.Client do
  require OK

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
    case Tesla.get(client, "/databases") do
      {:ok, %{status: 200}} ->
        {:ok,
         %ServerNode{
           node
           | client: client
         }}

      _ ->
        {:error, :invalid_node}
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
           {:ok, %{status: status}} when status in [408, 500, 502, 503, 504] -> false
           {:ok, %{body: %{"IsStale" => true}}} -> true
           {:ok, _} -> false
           {:error, _} -> true
         end
       ]}
end
