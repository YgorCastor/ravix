defmodule Ravix.Operations.Database.MaintenanceTest do
  use ExUnit.Case

  alias Ravix.Operations.Database.Maintenance
  alias Ravix.TestStore2

  setup do
    %{ravix: start_supervised!(Ravix.TestApplication)}
    :ok
  end

  describe "create_database/0" do
    test "should create a new database successfully" do
      db_name = Ravix.Test.Random.safe_random_string(5)

      {:ok, created} = Maintenance.create_database(TestStore2, db_name)

      assert created["Name"] == db_name
    end

    test "If the database already exists, should return an error" do
      db_name = Ravix.Test.Random.safe_random_string(5)

      {:ok, _created} = Maintenance.create_database(TestStore2, db_name)
      {:error, err} = Maintenance.create_database(TestStore2, db_name)

      assert err == "Database '#{db_name}' already exists!"
    end
  end
end
