defmodule Ravix.Connection.State.Manager do
  require OK

  alias Ravix.Connection.State, as: ConnectionState
  alias Ravix.Connection.{ServerNode, RequestExecutor, Topology}
  alias Ravix.Connection.Commands.GetTopology

  def initialize(%ConnectionState{} = state) do
    node_pids = register_nodes(state) |> IO.inspect()

    # topology =
    #   case ConnectionState.Manager.request_topology(node_pids, state.database) do
    #     {:ok, server_topology} -> server_topology
    #     _ -> raise "Invalid server topology"
    #   end

    state
  end

  def request_topology(node_pids, database) do
    topology =
      node_pids
      |> Enum.map(fn node ->
        RequestExecutor.execute_for_node(
          %GetTopology{database_name: database},
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

  def connection_id(state), do: {:via, Registry, {:sessions, state}}

  defp register_nodes(%ConnectionState{} = state) do
    state.urls
    |> Enum.map(fn url -> ServerNode.from_url(url, state.database, state.certificate) end)
    |> Enum.map(fn node ->
      RequestExecutor.Supervisor.register_node_executor(state.store, node)
    end)
  end
end
