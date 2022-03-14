defmodule Ravix.Connection.NetworkStateManager do
  alias Ravix.Connection.Network.State, as: NetworkState
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

  def set_node_as_unhealthy(%ServerNode{} = node, %NetworkState{} = state),
    do: set_node_state(node, state, :unhealthy)

  def set_node_as_healthy(%ServerNode{} = node, %NetworkState{} = state),
    do: set_node_state(node, state, :healthy)

  defp set_node_state(%ServerNode{} = node, %NetworkState{} = state, status) do
    updated_node = %ServerNode{
      node
      | status: status
    }

    updated_nodes = [updated_node | List.delete(state.node_selector.topology.nodes, node)]
    updated_state = put_in(state.node_selector.topology.nodes, updated_nodes)
    updated_state = put_in(updated_state.node_selector.current_node_index, 0)

    updated_state
  end

  def change_to_next_healthy_node(%NetworkState{} = state) do
    healthy_node_index =
      state.node_selector.topology.nodes
      |> Enum.find_index(fn node -> node.healthy end)

    case healthy_node_index do
      nil ->
        {:error, :no_healthy_nodes_found}

      node_index ->
        {:ok, put_in(state.node_selector.current_node_index, node_index)}
    end
  end
end
