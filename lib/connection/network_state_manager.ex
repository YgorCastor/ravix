defmodule Ravix.Connection.NetworkStateManager do
  alias Ravix.Connection.{ServerNode, RequestExecutor, Topology}
  alias Ravix.Connection.Commands.GetTopology

  @spec request_topology(list(String.t()), String.t(), Keyword.t()) ::
          {:error, :invalid_cluster_topology} | {:ok, Topology.t()}
  def request_topology(urls, database, certificate) do
    topology =
      urls
      |> Enum.map(fn url -> ServerNode.from_url(url, database) end)
      |> Enum.map(fn node ->
        RequestExecutor.execute_for_node(
          %GetTopology{database_name: node.database},
          %{certificate: certificate[:castore], certificate_file: certificate[:castorefile]},
          node
        )
      end)
      |> Enum.find(fn topology_response -> elem(topology_response, 0) == :ok end)

    case topology do
      {:ok, response} ->
        {:ok,
         %Topology{
           etag: response.data["Etag"],
           nodes: response.data["Nodes"] |> Enum.map(&ServerNode.from_api_response/1)
         }}

      _ ->
        {:error, :invalid_cluster_topology}
    end
  end
end
