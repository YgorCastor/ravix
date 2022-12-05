defmodule Ravix.Operations.Database.MaintenanceTest do
  use Ravix.Integration.Case

  alias Ravix.Connection.State.Manager, as: ConnectionStateManager
  alias Ravix.Operations.Database.Maintenance
  alias Ravix.Test.RandomStore

  setup do
    {:ok, conn} = ConnectionStateManager.fetch_connection_state(RandomStore)
    {:ok, %{"PendingDeletes" => []}} = Maintenance.delete_database(conn)

    %{
      conn: conn
    }
  end

  describe "create_database/0 and delete_database" do
    test "should create a new database successfully", %{conn: conn} do
      {:ok, created} = Maintenance.create_database(conn)

      assert created["Name"] == conn.database
    end

    test "If the database already exists, should return an error", %{conn: conn} do
      {:ok, _created} = Maintenance.create_database(conn)
      {:error, err} = Maintenance.create_database(conn)

      assert err == :conflict
    end
  end

  describe "database_stats/1" do
    test "Should fetch database stats if it exists", %{conn: conn} do
      {:ok, _created} = Maintenance.create_database(conn)
      {:ok, %{"CountOfConflicts" => 0}} = Maintenance.database_stats(conn)
    end
  end
end
