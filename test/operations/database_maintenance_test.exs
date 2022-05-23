defmodule Ravix.Operations.Database.MaintenanceTest do
  use ExUnit.Case

  alias Ravix.Operations.Database.Maintenance
  alias Ravix.Test.NonRetryableStore

  setup do
    %{ravix: start_supervised!(Ravix.TestApplication)}
    :ok
  end

  describe "create_database/0 and delete_database" do
    test "should create a new database successfully" do
      db_name = Ravix.Test.Random.safe_random_string(5)

      {:ok, created} = Maintenance.create_database(NonRetryableStore, db_name)

      assert created["Name"] == db_name

      {:ok, %{"PendingDeletes" => []}} = Maintenance.delete_database(NonRetryableStore, db_name)
    end

    test "If the database already exists, should return an error" do
      db_name = Ravix.Test.Random.safe_random_string(5)

      {:ok, _created} = Maintenance.create_database(NonRetryableStore, db_name)
      {:error, err} = Maintenance.create_database(NonRetryableStore, db_name)

      assert err == :conflict
    end
  end

  describe "database_stats/1" do
    test "Should fetch database stats if it exists" do
      {:ok, %{"LastDatabaseEtag" => 0}} = Maintenance.database_stats(NonRetryableStore)
    end
  end
end
