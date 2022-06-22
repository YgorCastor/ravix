defmodule Ravix.Connection.ConnectionTest do
  use Ravix.Integration.Case

  alias Ravix.Connection
  alias Ravix.Connection.NodeSelector
  alias Ravix.Test.Store, as: Store
  alias Ravix.Test.StoreInvalid
  alias Ravix.Test.ClusteredStore

  describe "update_topology/1" do
    test "Should update the topology correctly" do
      :ok = Connection.update_topology(Store)
      {:ok, state} = Connection.fetch_state(Store)

      assert state.last_topology_update != nil
    end
  end

  describe "Validate invalid nodes" do
    test "If all nodes are unreachable, the connection will fail" do
      {:error, _} = start_supervised(StoreInvalid)
    end

    test "If one of the nodes is valid, only the healthy one should be returned" do
      {:ok, _} = start_supervised(ClusteredStore)
      {:ok, state} = Connection.fetch_state(ClusteredStore)

      pid1 = NodeSelector.current_node(state)
      pid2 = NodeSelector.current_node(state)

      assert pid1 == pid2
    end
  end
end
