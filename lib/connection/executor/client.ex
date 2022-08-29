defmodule Ravix.Connection.RequestExecutor.Client do
  require OK

  alias Ravix.Connection.ServerNode

  def build(node = %ServerNode{}) do
    base_url = {Tesla.Middleware.BaseUrl, "#{node.protocol}://#{node.url}:#{node.port}"}

    {:ok,
     %ServerNode{
       node
       | client:
           Tesla.Builder.client(
             [
               base_url,
               retry(node),
               {Tesla.Middleware.Headers,
                [
                  {"raven-client-version", "Elixir"},
                  {"content-type", "application/json"},
                  {"accept", "application/json"}
                ]}
             ],
             [Tesla.Middleware.JSON],
             node.adapter
           )
     }}
  end

  defp retry(node),
    do:
      {Tesla.Middleware.Retry,
       [
         delay: node.settings.retry_backoff,
         max_retry: node.settings.retry_count,
         max_delay: 4000,
         should_retry: fn
           {:ok, %{status: status}} when status in [408, 500, 502, 503, 504] -> true
           {:ok, %{body: %{"IsStale" => true}}} -> true
           {:ok, _} -> false
           {:error, _} -> true
         end
       ]}
end
