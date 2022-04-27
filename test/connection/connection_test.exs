defmodule Ravix.Connection.ConnectionTest do
  use Ravix.Integration.Case

  alias Ravix.Connection
  alias Ravix.Test.Store, as: Store
  alias Ravix.TestStoreInvalid, as: InvalidStore

  describe "update_topology/1" do
    test "Should update the topology correctly" do
      :ok = Connection.update_topology(Store)
      {:ok, state} = Connection.fetch_state(Store)

      assert state.last_topology_update != nil
    end
  end

  test "If all nodes are unreachable, the connection will fail" do
    {:error, _} = start_supervised(InvalidStore)
  end
end
