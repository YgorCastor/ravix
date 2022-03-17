defmodule Ravix.Connection.NetworkStateManagerTest do
  use ExUnit.Case

  require OK

  import Ravix.Factory

  alias Ravix.Connection.{InMemoryNetworkState, NetworkStateManager, ServerNode}
  alias Ravix.Documents.Store

  setup do
    ravix = %{ravix: start_supervised!(Ravix)}
    Store.create_database("test")
    ravix
  end

  describe "nodes_healthcheck/1" do
    test "If the node was unhealthy and it's reachable, should be set as healthy" do
      {:ok, updated_state} =
        OK.for do
          _session <- Store.open_session("test")
          network_state <- InMemoryNetworkState.fetch_state("test")
          node <- network_state.node_selector.topology.nodes |> Enum.fetch(0)
          network_state = NetworkStateManager.set_node_as_unhealthy(node, network_state)
        after
          NetworkStateManager.nodes_healthcheck(network_state)
        end

      assert Enum.find(updated_state.node_selector.topology.nodes, fn node ->
               node.status == :healthy
             end) != nil
    end

    test "If the node is healthy, but now it's unreachable, should be set as unhealthy" do
      {:ok, updated_state} =
        OK.for do
          _session <- Store.open_session("test")
          network_state <- InMemoryNetworkState.fetch_state("test")
          node <- network_state.node_selector.topology.nodes |> Enum.fetch(0)
          unhealthy_node = %ServerNode{node | url: "http://localhost:9999"}

          updated_nodes = [
            unhealthy_node | List.delete(network_state.node_selector.topology.nodes, node)
          ]

          updated_state = put_in(network_state.node_selector.topology.nodes, updated_nodes)
        after
          NetworkStateManager.nodes_healthcheck(updated_state)
        end

      assert Enum.find(updated_state.node_selector.topology.nodes, fn node ->
               node.status == :unhealthy
             end) != nil
    end
  end

  describe "change_to_next_healthy_node/1" do
    test "if there is a next healthy node, should swap the current index to it" do
      network_state = build(:network_state)

      {:ok, updated_state} = NetworkStateManager.change_to_next_healthy_node(network_state)

      assert updated_state.node_selector.current_node_index == 0
    end

    test "if there is no remaining healthy nodes, should return an error" do
      network_state = build(:network_state)
      {:ok, node} = network_state.node_selector.topology.nodes |> Enum.fetch(0)
      network_state = NetworkStateManager.set_node_as_unhealthy(node, network_state)

      {:error, :no_healthy_nodes_found} = NetworkStateManager.change_to_next_healthy_node(network_state)
    end
  end
end
